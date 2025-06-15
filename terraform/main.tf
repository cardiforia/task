# Define Terraform providers
terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "2.12.1" # Use a compatible version
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.23.0" # Use a compatible version
    }
  }
}

# Configure the Kubernetes provider to connect to your local k3d cluster
# Assumes kubectl context is already set to k3d-my-gitops-cluster
provider "kubernetes" {
  # You might need to explicitly configure host, client_certificate, etc.
  # if kubectl context is not automatically picked up or if you use a different setup.
  # For k3d, it generally works by default if your KUBECONFIG is set.
}

# Configure the Helm provider
provider "helm" {
  kubernetes {
    config_path = "~/.kube/config" # Adjust if your kubeconfig is elsewhere
    # For k3d, it often uses the default context, which is picked up from here.
  }
}

# Add the Argo CD Helm repository
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = "argocd"
  create_namespace = true

  # Optional: Customize Argo CD values if needed
  # values = [file("${path.module}/argocd-values.yaml")]
}

# Define the Argo CD Application for infrastructure components
resource "kubernetes_manifest" "argocd_app_infrastructure" {
  # Ensure Argo CD is deployed before attempting to create its applications
  depends_on = [helm_release.argocd]

  yaml_body = <<-EOT
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: infrastructure
      namespace: argocd
    spec:
      project: default
      source:
        repoURL: git@github.com:cardiforia/task.git # Your Git repository URL
        targetRevision: HEAD
        path: infrastructure
      destination:
        server: https://kubernetes.default.svc
        namespace: default # Deploy infrastructure components to the 'default' namespace
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
  EOT
}

# Define the Argo CD Application for your custom frontend/backend applications
resource "kubernetes_manifest" "argocd_app_applications" {
  # Ensure Argo CD is deployed before attempting to create its applications
  depends_on = [helm_release.argocd]

  yaml_body = <<-EOT
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: applications
      namespace: argocd
    spec:
      project: default
      source:
        repoURL: git@github.com:cardiforia/task.git # Your Git repository URL
        targetRevision: HEAD
        path: applications/my-app
        helm:
          valueFiles:
            - values.yaml # This tells Argo CD to use values.yaml from within the Helm chart path
      destination:
        server: https://kubernetes.default.svc
        namespace: default # Deploy applications to the 'default' namespace
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
  EOT
}

