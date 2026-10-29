output "aws_eks_cluster_main_endpoint" {
    value = aws_eks_cluster.main.endpoint
}

output "aws_eks_cluster_main_certificate_authority_data" {
    value = aws_eks_cluster.main.certificate_authority[0].data
}

output "aws_eks_cluster_main_name" {
    value = aws_eks_cluster.main.name
}

output "aws_eks_cluster_main_identity_oidc_issuer" {
    value = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

output "aws_db_instance_main_address" {
    value = aws_db_instance.main.address
}