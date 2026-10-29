resource "aws_security_group" "db" {
    name_prefix = "petclinic-db-"
    vpc_id = aws_vpc.main.id
    ingress {
        from_port       = 3306
        to_port         = 3306
        protocol        = "tcp"
        security_groups = [
            aws_eks_cluster.main.vpc_config[0].cluster_security_group_id,
            var.jenkins_infra_agent_sg
        ]
    }
    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
    tags = {
        Name = "petclinic-db-security-group"
    }
}

resource "aws_db_subnet_group" "main" {
    name       = "petclinic-db-subnet-group"
    subnet_ids = [for s in aws_subnet.private : s.id]
    tags = {
        Name = "petclinic-db-subnet-group"
    }
}

resource "aws_db_instance" "main" {
    identifier                  = "petclinic-db"
    engine                      = "mysql"
    engine_version              = "8.0"
    instance_class              = "db.t4g.micro"
    allocated_storage           = 20
    storage_type                = "gp3"
    db_name                     = "petclinic"
    username                    = var.db_admin_username
    password_wo                 = var.db_admin_password
    password_wo_version         = 1
    db_subnet_group_name        = aws_db_subnet_group.main.name
    vpc_security_group_ids      = [aws_security_group.db.id]
    publicly_accessible         = false
    multi_az                    = false
    skip_final_snapshot         = true
    deletion_protection         = false
    tags = {
        Name = "petclinic-db"
    }
}