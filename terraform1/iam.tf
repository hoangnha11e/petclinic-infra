resource "aws_iam_role" "eks_cluster" {
	name = "petclinic-eks-cluster-role"
	assume_role_policy = jsonencode({
		Version = "2012-10-17"
		Statement = [
			{
				Effect = "Allow"
				Principal = {
					Service = "eks.amazonaws.com"
				}
				Action = "sts:AssumeRole"
			}
		]
	})
	tags = {
		Name = "petclinic-eks-cluster-role"
	}
}

resource "aws_iam_role_policy_attachments_exclusive" "eks_cluster" {
	role_name = aws_iam_role.eks_cluster.name
	policy_arns = [
		"arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
	]
}

resource "aws_iam_role" "eks_node" {
	name = "petclinic-eks-node-role"
	assume_role_policy = jsonencode({
		Version = "2012-10-17"
		Statement = [
			{
				Effect = "Allow"
				Principal = {
					Service = "ec2.amazonaws.com"
				}
				Action = "sts:AssumeRole"
			}
		]
	})
	tags = {
		Name = "petclinic-eks-node-role"
	}
}

resource "aws_iam_role_policy_attachments_exclusive" "eks_node" {
	role_name = aws_iam_role.eks_node.name
	policy_arns = [
		"arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
		"arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
		"arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
	]
}