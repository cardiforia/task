resource "helm_release" "argo_cd" {
  name       = "argo-cd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = "argocd"
  create_namespace = true
  version    = "5.46.2"
}

resource "null_resource" "wait_for_argo_cd_crds" {
  depends_on = [helm_release.argo_cd]

  provisioner "local-exec" {
    command = "echo 'Waiting for Argo CD CRDs...'; sleep 30"
  }
}

resource "kubectl_manifest" "infrastructure_app" {
  depends_on = [null_resource.wait_for_argo_cd_crds]
  yaml_body  = file("${path.module}/infrastructure-app.yaml")
}

resource "kubectl_manifest" "applications_app" {
  depends_on = [null_resource.wait_for_argo_cd_crds]
  yaml_body  = file("${path.module}/applications-app.yaml")
}
