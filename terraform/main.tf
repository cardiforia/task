resource "helm_release" "argo_cd" {
  name       = "argo-cd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = "argocd"
  create_namespace = true
}

resource "kubernetes_manifest" "infrastructure_app" {
  manifest = yamldecode(file("${path.module}/infrastructure-app.yaml"))
}

resource "kubernetes_manifest" "applications_app" {
  manifest = yamldecode(file("${path.module}/applications-app.yaml"))
}

