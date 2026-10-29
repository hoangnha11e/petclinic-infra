resource "helm_release" "argocd" {
	name             = "argocd"
	repository       = "https://argoproj.github.io/argo-helm"
	chart            = "argo-cd"
	version          = var.argocd_version
	namespace        = "argocd"
	create_namespace = true
	timeout = 600
}

resource "helm_release" "argocd_apps" {
	name       = "argocd-apps"
	repository = "https://argoproj.github.io/argo-helm"
	chart      = "argocd-apps"
	version    = var.argocd_apps_version
	namespace  = "argocd"
	timeout    = 300
	depends_on = [helm_release.argocd]
	values = [yamlencode({
		applications = {
			petclinic = {
				namespace = "argocd"
				project   = "default"
				source = {
					repoURL        = var.gitops_repo_url
					targetRevision = "main"
					path           = "charts/petclinic"
					helm = {
						parameters = [
							{
								name  = "dbendpoint"
								value = "jdbc:mysql://${data.terraform_remote_state.terraform1.outputs["aws_db_instance_main_address"]}:3306/petclinic"
							}
						]
					}
				}
				destination = {
					server    = "https://kubernetes.default.svc"
					namespace = "petclinic"
				}
				syncPolicy = {
					automated = { 
						prune = true
						selfHeal = true 
					}
					syncOptions = [
						"CreateNamespace=true"
					]
				}
			}
		}
	})]
}

resource "helm_release" "metrics_server" {
	name       = "metrics-server"
	repository = "https://kubernetes-sigs.github.io/metrics-server/"
	chart      = "metrics-server"
	version    = var.metrics_server_version
	namespace  = "kube-system"
	timeout    = 300
}

resource "helm_release" "cluster_autoscaler" {
	name       = "cluster-autoscaler"
	repository = "https://kubernetes.github.io/autoscaler"
	chart      = "cluster-autoscaler"
	version    = var.cluster_autoscaler_version
	namespace  = "kube-system"
	timeout    = 300
	set = [
		{ name = "autoDiscovery.clusterName", value = data.terraform_remote_state.terraform1.outputs["aws_eks_cluster_main_name"] },
		{ name = "awsRegion", value = var.region },
		{ name = "rbac.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn", value = aws_iam_role.cluster_autoscaler.arn }
	]
}

resource "helm_release" "eso" {
	name             = "external-secrets"
	repository       = "https://charts.external-secrets.io"
	chart            = "external-secrets"
	version          = var.eso_version
	namespace        = "external-secrets"
	create_namespace = true
	timeout = 300
	set = [
		{ name = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn", value = aws_iam_role.eso.arn }
	]
}