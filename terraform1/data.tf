data "aws_security_group" "jenkins_infra_agent" {
    id = var.jenkins_infra_agent_sg
}

data "aws_vpc" "jenkins_infra_agent" {
    id = data.aws_security_group.jenkins_infra_agent.vpc_id
}

data "aws_route_table" "jenkins_infra_agent" {
    vpc_id = data.aws_vpc.jenkins_infra_agent.id
}