terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.7.1"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.21.1"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.14.0"
    }
  }
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "kubectl" {
  config_path = "~/.kube/config"
}

resource "helm_release" "argo_cd" {
  name             = "argo-cd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  version          = "5.46.2"

  set {
    name  = "server.service.type"
    value = "NodePort"
  }
}

resource "null_resource" "wait_for_argo_cd_crds" {
  depends_on = [helm_release.argo_cd]

  provisioner "local-exec" {
    command = "echo 'Waiting for Argo CD CRDs to be installed...'; sleep 30"
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
