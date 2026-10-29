resource "aws_eks_cluster" "main" {
	name     = "petclinic-eks-cluster"
	role_arn = aws_iam_role.eks_cluster.arn
	version  = var.eks_version
	vpc_config {
		subnet_ids = concat(
			[for s in aws_subnet.public : s.id],
			[for s in aws_subnet.private : s.id]
		)
		endpoint_private_access = true
		endpoint_public_access  = true
	}
	depends_on = [
		aws_iam_role_policy_attachments_exclusive.eks_cluster
	]
	tags = {
		Name = "petclinic-eks-cluster"
	}
}

resource "aws_security_group" "eks_node" {
	name_prefix = "petclinic-eks-node-"
	vpc_id      = aws_vpc.main.id
	ingress {
		from_port       = 30080
		to_port         = 30080
		protocol        = "tcp"
		security_groups = [aws_security_group.alb.id]
	}
	egress {
		from_port   = 0
		to_port     = 0
		protocol    = "-1"
		cidr_blocks = ["0.0.0.0/0"]
	}
	tags = {
		Name = "petclinic-eks-node-sg"
	}
}

resource "aws_launch_template" "eks_node" {
	name_prefix = "petclinic-eks-node-"
	vpc_security_group_ids = [
		aws_eks_cluster.main.vpc_config[0].cluster_security_group_id,
		aws_security_group.eks_node.id
	]
	tags = {
		Name = "petclinic-eks-node-lt"
	}
}

resource "aws_eks_node_group" "main" {
	cluster_name    = aws_eks_cluster.main.name
	node_group_name = "petclinic-eks-node"
	node_role_arn   = aws_iam_role.eks_node.arn
	subnet_ids      = [for s in aws_subnet.private : s.id]
	instance_types  = [var.node_instance_type]
	scaling_config {
		desired_size = var.node_desired_size
		min_size     = var.node_min_size
		max_size     = var.node_max_size
	}
	lifecycle {
		ignore_changes = [
			scaling_config[0].desired_size
		]
	}
	node_repair_config {
		enabled = true
	}
	launch_template {
		id      = aws_launch_template.eks_node.id
		version = aws_launch_template.eks_node.latest_version
	}
	depends_on = [
		aws_iam_role_policy_attachments_exclusive.eks_node
	]
	tags = {
		Name 												= "petclinic-eks-node"
		"k8s.io/cluster-autoscaler/enabled"             	= "true"
		"k8s.io/cluster-autoscaler/petclinic-eks-cluster"   = "owned"
	}
}