resource "aws_iam_openid_connect_provider" "eks_cluster" {
	url             = data.terraform_remote_state.terraform1.outputs["aws_eks_cluster_main_identity_oidc_issuer"]
	client_id_list  = ["sts.amazonaws.com"]
}

resource "aws_iam_policy" "cluster_autoscaler" {
	name = "petclinic-cluster-autoscaler-policy"
	policy = jsonencode({
		Version = "2012-10-17"
		Statement = [
			{
				Effect = "Allow"
				Action = [
					"autoscaling:DescribeAutoScalingGroups",
					"autoscaling:DescribeAutoScalingInstances",
					"autoscaling:DescribeLaunchConfigurations",
					"autoscaling:DescribeScalingActivities",
					"autoscaling:DescribeTags",
					"ec2:DescribeLaunchTemplateVersions",
					"ec2:DescribeInstanceTypes",
					"ec2:DescribeImages",
					"ec2:GetInstanceTypesFromInstanceRequirements",
					"eks:DescribeNodegroup"
				]
				Resource = "*"
			},
			{
				Effect = "Allow"
				Action = [
					"autoscaling:SetDesiredCapacity",
					"autoscaling:TerminateInstanceInAutoScalingGroup"
				]
				Resource = "*"
				Condition = {
					StringEquals = {
						"aws:ResourceTag/k8s.io/cluster-autoscaler/petclinic-eks-cluster" = "owned"
					}
				}
			}
		]
	})
}

resource "aws_iam_role" "cluster_autoscaler" {
	name = "petclinic-cluster-autoscaler-role"
	assume_role_policy = jsonencode({
		Version = "2012-10-17"
		Statement = [
			{
				Effect = "Allow"
				Principal = {
					Federated = aws_iam_openid_connect_provider.eks_cluster.arn
				}
				Action = "sts:AssumeRoleWithWebIdentity"
				Condition = {
					StringEquals = {
						"${replace(aws_iam_openid_connect_provider.eks_cluster.url, "https://", "")}:sub" = "system:serviceaccount:kube-system:cluster-autoscaler"
					}
				}
			}
		]
	})
	force_detach_policies = true
	depends_on            = [aws_iam_policy.cluster_autoscaler]
}

resource "aws_iam_role_policy_attachments_exclusive" "cluster_autoscaler" {
	role_name   = aws_iam_role.cluster_autoscaler.name
	policy_arns = [aws_iam_policy.cluster_autoscaler.arn]
}

resource "aws_iam_policy" "eso" {
	name = "petclinic-eso-policy"
	policy = jsonencode({
		Version = "2012-10-17"
		Statement = [
			{
				Effect   = "Allow"
				Action   = [
					"secretsmanager:GetSecretValue", 
					"secretsmanager:DescribeSecret"
				]
				Resource = "arn:aws:secretsmanager:ap-southeast-1:${data.aws_caller_identity.current.account_id}:secret:petclinic-*"
			}
		]
	})
}

resource "aws_iam_role" "eso" {
	name = "petclinic-eso-role"
	assume_role_policy = jsonencode({
		Version = "2012-10-17"
		Statement = [{
			Effect    = "Allow"
			Principal = { 
				Federated = aws_iam_openid_connect_provider.eks_cluster.arn 
			}
			Action    = "sts:AssumeRoleWithWebIdentity"
			Condition = {
				StringEquals = {
					"${replace(aws_iam_openid_connect_provider.eks_cluster.url, "https://", "")}:sub" = "system:serviceaccount:external-secrets:external-secrets"
				}
			}
		}]
	})
	force_detach_policies = true
	depends_on            = [aws_iam_policy.eso]
}

resource "aws_iam_role_policy_attachments_exclusive" "eso" {
	role_name   = aws_iam_role.eso.name
	policy_arns = [aws_iam_policy.eso.arn]
}