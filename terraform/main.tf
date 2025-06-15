# Define Terraform providers
terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "2.12.1"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.23.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "0.9.1"
    }
  }
}

# Configure the Kubernetes provider to connect to your local k3d cluster
provider "kubernetes" {
  config_path = "~/.kube/config"
  # context     = "k3d-devops-cluster" # Removed, as it worked without it!
}

# Configure the Helm provider
provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
    # context     = "k3d-devops-cluster" # Removed, as it worked without it!
  }
}

# Add the Argo CD Helm repository
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = "argocd"
  create_namespace = true
}

# ADDED: Introduce a delay to allow Argo CD CRDs to become available after helm_release
resource "time_sleep" "wait_for_argocd_crds" {
  depends_on = [helm_release.argocd]
  create_duration = "30s"
}

# Define the Argo CD Application for infrastructure components
resource "kubernetes_manifest" "argocd_app_infrastructure" {
  depends_on = [time_sleep.wait_for_argocd_crds] # Now depends on the time_sleep resource

  manifest = yamldecode(<<-EOT
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: infrastructure
      namespace: argocd
    spec:
      project: default
      source:
        repoURL: git@github.com:cardiforia/task.git
        targetRevision: HEAD
        path: infrastructure
      destination:
        server: https://kubernetes.default.svc
        namespace: default
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
  EOT
  )
}

# Define the Argo CD Application for your custom frontend/backend applications
resource "kubernetes_manifest" "argocd_app_applications" {
  depends_on = [time_sleep.wait_for_argocd_crds] # Now depends on the time_sleep resource

  manifest = yamldecode(<<-EOT
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: applications
      namespace: argocd
    spec:
      project: default
      source:
        repoURL: git@github.com:cardiforia/task.git
        targetRevision: HEAD
        path: applications/my-app
        helm:
          valueFiles:
            - values.yaml
      destination:
        server: https://kubernetes.default.svc
        namespace: default
      syncPolicy:
          automated:
            prune: true
            selfHeal: true
          syncOptions:
            - CreateNamespace=true
  EOT
  )
}
