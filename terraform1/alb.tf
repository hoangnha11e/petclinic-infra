resource "aws_security_group" "alb" {
	name_prefix = "petclinic-alb-"
	vpc_id      = aws_vpc.main.id
	ingress {
		from_port   = 80
		to_port     = 80
		protocol    = "tcp"
		cidr_blocks = ["0.0.0.0/0"]
	}
	egress {
		from_port   = 0
		to_port     = 0
		protocol    = "-1"
		cidr_blocks = ["0.0.0.0/0"]
	}
	tags = {
		Name = "petclinic-alb-sg"
	}
}

resource "aws_lb" "alb" {
	name                       = "petclinic-alb"
	load_balancer_type         = "application"
	internal                   = false
	enable_deletion_protection = false
	security_groups    		   = [aws_security_group.alb.id]
	subnets                    = [for s in aws_subnet.public : s.id]
	tags = {
		Name = "petclinic-alb"
	}
}

resource "aws_lb_target_group" "api_gateway" {
	name        = "petclinic-api-gateway-tg"
	port        = 30080
	protocol    = "HTTP"
	vpc_id      = aws_vpc.main.id
	target_type = "instance"
	health_check {
		path                = "/actuator/health/readiness"
		port                = "30080"
		healthy_threshold   = 2
		unhealthy_threshold = 3
		interval            = 15
		timeout             = 5
	}
	tags = {
		Name = "petclinic-api-gateway-tg"
	}
}

resource "aws_lb_listener" "api_gateway" {
	load_balancer_arn = aws_lb.alb.arn
	port              = 80
	protocol          = "HTTP"
	default_action {
		type             = "forward"
		target_group_arn = aws_lb_target_group.api_gateway.arn
	}
}

resource "aws_autoscaling_attachment" "api_gateway" {
	autoscaling_group_name = aws_eks_node_group.main.resources[0].autoscaling_groups[0].name
	lb_target_group_arn    = aws_lb_target_group.api_gateway.arn
}