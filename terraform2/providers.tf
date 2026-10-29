provider "aws" {
    region = var.region
}

provider "helm" {
	kubernetes = {
	    host = data.terraform_remote_state.terraform1.outputs["aws_eks_cluster_main_endpoint"]
		cluster_ca_certificate = base64decode(
			data.terraform_remote_state.terraform1.outputs["aws_eks_cluster_main_certificate_authority_data"]
		)
		exec = {
			api_version = "client.authentication.k8s.io/v1beta1"
			command     = "aws"
			args = ["eks", "get-token", "--cluster-name", data.terraform_remote_state.terraform1.outputs["aws_eks_cluster_main_name"], "--region", var.region]
		}
	}
}