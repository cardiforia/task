# DevOps Engineer Practical Task: Advanced Kubernetes Deployment with GitOps & Helm

This project demonstrates an advanced Kubernetes deployment workflow using GitOps principles, Helm for application packaging, and Terraform for infrastructure setup (Argo CD). It includes a multi-component application (frontend, backend) and a stateful MySQL database with automated backups.

## Objective

The goal is to showcase the ability to:
* Create and manage a local Kubernetes cluster.
* Deploy and configure Argo CD using Terraform.
* Package applications with Helm charts.
* Manage the entire application lifecycle, including stateful workloads and operational tasks (database backups), via a GitOps workflow.

## Technologies Used

* **Local Kubernetes:** `k3d` (or `k3s`/`minikube`)
* **Infrastructure as Code:** `Terraform`
* **GitOps:** `Argo CD`
* **Application Packaging:** `Helm`
* **Database:** `MySQL` (via Bitnami Helm Chart)
* **Application Images:** `nginx` (frontend), `hashicorp/http-echo` (backend placeholder), `mysql:8.0` (for backup job)
* **Version Control:** `Git` (Your repository: `git@github.com:cardiforia/task.git`)
* **Containerization Runtime:** `Docker`/`Containerd` (used by `k3d`)

## Repository Structure

Certainly! This is a comprehensive request, and I'll generate the core files for your project based on the structure and requirements we've discussed.

I'll provide the content for the following key files:

    applications/my-app/Chart.yaml
    applications/my-app/values.yaml
    applications/my-app/templates/frontend-deployment.yaml
    applications/my-app/templates/frontend-service.yaml
    applications/my-app/templates/backend-deployment.yaml
    applications/my-app/templates/backend-service.yaml
    applications/my-app/templates/configmap.yaml
    infrastructure/mysql/values.yaml (for Bitnami MySQL chart)
    infrastructure/backup-pvc.yaml
    infrastructure/backup-cronjob.yaml
    terraform/main.tf
    README.md

applications/my-app/Chart.yaml
YAML

apiVersion: v2
name: my-app
description: A Helm chart for a simple frontend and backend application.
type: application
version: 0.1.0
appVersion: "1.0.0"

applications/my-app/values.yaml
YAML

frontend:
  image:
    repository: nginx
    tag: 1.25.3-alpine
    pullPolicy: IfNotPresent
  replicaCount: 1
  service:
    type: ClusterIP
    port: 80
  config:
    backendApiUrl: "http://my-app-backend:8080" # Default, assuming backend service name and port

backend:
  image:
    # You can replace this with your actual backend image (e.g., a simple Go server, Node.js, Python app)
    # For demonstration, we'll use a placeholder or a simple echo server
    repository: hashicorp/http-echo
    tag: latest
    pullPolicy: IfNotPresent
  replicaCount: 1
  service:
    type: ClusterIP
    port: 8080
  env:
    # Example for a simple http-echo backend
    # For a real app, these would be database connection strings, etc.
    - name: "HTTP_PORT"
      value: "8080"
    - name: "MESSAGE"
      value: "Hello from the backend!"
    # Example for database connection (you'd need to configure your backend app to use these)
    # - name: DB_HOST
    #   value: "mysql-service" # Name of the MySQL service deployed by infrastructure app
    # - name: DB_USER
    #   valueFrom:
    #     secretKeyRef:
    #       name: my-mysql-secret # This secret is created by the Bitnami MySQL chart
    #       key: mysql-user # Key for your application user, from Bitnami chart's values
    # - name: DB_PASSWORD
    #   valueFrom:
    #     secretKeyRef:
    #       name: my-mysql-secret
    #       key: mysql-password # Key for your application user password
    # - name: DB_NAME
    #   value: "myapp_db" # The database name from Bitnami MySQL chart's values

applications/my-app/templates/frontend-deployment.yaml
YAML

apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "my-app.fullname" . }}-frontend
  labels:
    {{- include "my-app.labels" . | nindent 4 }}
    app.kubernetes.io/component: frontend
spec:
  replicas: {{ .Values.frontend.replicaCount }}
  selector:
    matchLabels:
      {{- include "my-app.selectorLabels" . | nindent 6 }}
      app.kubernetes.io/component: frontend
  template:
    metadata:
      labels:
        {{- include "my-app.selectorLabels" . | nindent 8 }}
        app.kubernetes.io/component: frontend
    spec:
      containers:
        - name: frontend
          image: "{{ .Values.frontend.image.repository }}:{{ .Values.frontend.image.tag }}"
          imagePullPolicy: {{ .Values.frontend.image.pullPolicy }}
          ports:
            - name: http
              containerPort: 80
              protocol: TCP
          volumeMounts:
            - name: nginx-config-volume
              mountPath: /etc/nginx/conf.d/default.conf
              subPath: default.conf
          readinessProbe:
            httpGet:
              path: /
              port: http
            initialDelaySeconds: 5
            periodSeconds: 10
          livenessProbe:
            httpGet:
              path: /
              port: http
            initialDelaySeconds: 15
            periodSeconds: 20
      volumes:
        - name: nginx-config-volume
          configMap:
            name: {{ include "my-app.fullname" . }}-frontend-config
            items:
              - key: default.conf
                path: default.conf

applications/my-app/templates/frontend-service.yaml
YAML

apiVersion: v1
kind: Service
metadata:
  name: {{ include "my-app.fullname" . }}-frontend
  labels:
    {{- include "my-app.labels" . | nindent 4 }}
    app.kubernetes.io/component: frontend
spec:
  type: {{ .Values.frontend.service.type }}
  ports:
    - port: {{ .Values.frontend.service.port }}
      targetPort: http
      protocol: TCP
      name: http
  selector:
    {{- include "my-app.selectorLabels" . | nindent 4 }}
    app.kubernetes.io/component: frontend

applications/my-app/templates/backend-deployment.yaml
YAML

apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "my-app.fullname" . }}-backend
  labels:
    {{- include "my-app.labels" . | nindent 4 }}
    app.kubernetes.io/component: backend
spec:
  replicas: {{ .Values.backend.replicaCount }}
  selector:
    matchLabels:
      {{- include "my-app.selectorLabels" . | nindent 6 }}
      app.kubernetes.io/component: backend
  template:
    metadata:
      labels:
        {{- include "my-app.selectorLabels" . | nindent 8 }}
        app.kubernetes.io/component: backend
    spec:
      containers:
        - name: backend
          image: "{{ .Values.backend.image.repository }}:{{ .Values.backend.image.tag }}"
          imagePullPolicy: {{ .Values.backend.image.pullPolicy }}
          ports:
            - name: http
              containerPort: {{ .Values.backend.service.port }}
              protocol: TCP
          env:
            {{- toYaml .Values.backend.env | nindent 12 }}
          readinessProbe:
            httpGet:
              path: /
              port: http
            initialDelaySeconds: 5
            periodSeconds: 10
          livenessProbe:
            httpGet:
              path: /
              port: http
            initialDelaySeconds: 15
            periodSeconds: 20

applications/my-app/templates/backend-service.yaml
YAML

apiVersion: v1
kind: Service
metadata:
  name: {{ include "my-app.fullname" . }}-backend
  labels:
    {{- include "my-app.labels" . | nindent 4 }}
    app.kubernetes.io/component: backend
spec:
  type: {{ .Values.backend.service.type }}
  ports:
    - port: {{ .Values.backend.service.port }}
      targetPort: http
      protocol: TCP
      name: http
  selector:
    {{- include "my-app.selectorLabels" . | nindent 4 }}
    app.kubernetes.io/component: backend

applications/my-app/templates/configmap.yaml
YAML

apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "my-app.fullname" . }}-frontend-config
  labels:
    {{- include "my-app.labels" . | nindent 4 }}
data:
  default.conf: |
    server {
        listen 80;
        location / {
            root /usr/share/nginx/html;
            index index.html index.htm;
        }
        location /api/ {
            proxy_pass {{ .Values.frontend.config.backendApiUrl }};
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
    }
  # You can add a simple index.html here for the Nginx frontend for testing
  # index.html: |
  #   <!DOCTYPE html>
  #   <html>
  #   <head>
  #       <title>Frontend App</title>
  #   </head>
  #   <body>
  #       <h1>Hello from Frontend!</h1>
  #       <div id="backend-response">Loading backend message...</div>
  #       <script>
  #           fetch('/api/')
  #               .then(response => response.text())
  #               .then(data => {
  #                   document.getElementById('backend-response').innerText = 'Backend says: ' + data;
  #               })
  #               .catch(error => {
  #                   document.getElementById('backend-response').innerText = 'Error fetching backend: ' + error;
  #               });
  #       </script>
  #   </body>
  #   </html>

infrastructure/mysql/values.yaml
YAML

# This file will override values for the Bitnami MySQL Helm Chart
# You would typically install this chart using:
# helm repo add bitnami https://charts.bitnami.com/bitnami
# helm install my-mysql bitnami/mysql -f values.yaml

auth:
  # IMPORTANT: For a production environment, generate strong, random passwords.
  # For this task, we'll use simple ones for demonstration.
  rootPassword: "mysecretpassword" # This will be stored in a Kubernetes Secret
  username: "myapp_user"
  password: "myapp_password" # This will be stored in a Kubernetes Secret
  database: "myapp_db"

primary:
  persistence:
    enabled: true
    size: 5Gi # Adjust as needed for your data volume
    storageClass: standard # Or your cluster's default StorageClass

infrastructure/backup-pvc.yaml
YAML

apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysql-backup-pvc
  namespace: default # Ensure this matches your deployment namespace
spec:
  accessModes:
    - ReadWriteOnce # Can be mounted as read-write by a single node
  resources:
    requests:
      storage: 1Gi # Allocate 1GB for backups
  storageClassName: standard # Use your cluster's default StorageClass or define one

infrastructure/backup-cronjob.yaml
YAML

apiVersion: batch/v1
kind: CronJob
metadata:
  name: mysql-backup-job
  namespace: default # Ensure this matches your MySQL deployment namespace
spec:
  schedule: "*/5 * * * *" # Runs every 5 minutes for demonstration
  jobTemplate:
    spec:
      template:
        spec:
          containers:
            - name: mysql-backup
              # Use a mysql client image. mysql:8.0 includes mysql-client.
              image: mysql:8.0
              imagePullPolicy: IfNotPresent
              command: ["/bin/bash", "-c"]
              args:
                - |
                  TIMESTAMP=$(date +%F-%H-%M-%S)
                  echo "Starting MySQL backup at $TIMESTAMP"
                  mysqldump -h mysql-service \
                    -u ${MYSQL_USER} \
                    -p${MYSQL_PASSWORD} \
                    ${MYSQL_DATABASE} > /backups/mysql-backup-${TIMESTAMP}.sql
                  if [ $? -eq 0 ]; then
                    echo "Backup successful: /backups/mysql-backup-${TIMESTAMP}.sql"
                  else
                    echo "Backup failed!"
                    exit 1
                  fi
              env:
                # These environment variables retrieve values from the Secret created by the Bitnami MySQL chart
                - name: MYSQL_USER
                  valueFrom:
                    secretKeyRef:
                      name: my-mysql-secret # Name of the secret created by Bitnami MySQL
                      key: mysql-user
                - name: MYSQL_PASSWORD
                  valueFrom:
                    secretKeyRef:
                      name: my-mysql-secret
                      key: mysql-password
                - name: MYSQL_DATABASE
                  value: myapp_db # The database name you configured in mysql/values.yaml
              volumeMounts:
                - name: backup-storage
                  mountPath: /backups
          restartPolicy: OnFailure
          volumes:
            - name: backup-storage
              persistentVolumeClaim:
                claimName: mysql-backup-pvc # Link to the PVC defined above

terraform/main.tf
Terraform

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

README.md
Markdown

# DevOps Engineer Practical Task: Advanced Kubernetes Deployment with GitOps & Helm

This project demonstrates an advanced Kubernetes deployment workflow using GitOps principles, Helm for application packaging, and Terraform for infrastructure setup (Argo CD). It includes a multi-component application (frontend, backend) and a stateful MySQL database with automated backups.

## Objective

The goal is to showcase the ability to:
* Create and manage a local Kubernetes cluster.
* Deploy and configure Argo CD using Terraform.
* Package applications with Helm charts.
* Manage the entire application lifecycle, including stateful workloads and operational tasks (database backups), via a GitOps workflow.

## Technologies Used

* **Local Kubernetes:** `k3d` (or `k3s`/`minikube`)
* **Infrastructure as Code:** `Terraform`
* **GitOps:** `Argo CD`
* **Application Packaging:** `Helm`
* **Database:** `MySQL` (via Bitnami Helm Chart)
* **Application Images:** `nginx` (frontend), `hashicorp/http-echo` (backend placeholder), `mysql:8.0` (for backup job)
* **Version Control:** `Git` (Your repository: `git@github.com:cardiforia/task.git`)
* **Containerization Runtime:** `Docker`/`Containerd` (used by `k3d`)

## Repository Structure

```bash
.
├── applications/
│   └── my-app/                # Helm chart for frontend and backend
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
│           ├── frontend-deployment.yaml
│           ├── frontend-service.yaml
│           ├── backend-deployment.yaml
│           ├── backend-service.yaml
│           └── configmap.yaml
├── infrastructure/
│   ├── mysql/                 # Helm chart values for Bitnami MySQL
│   │   └── values.yaml
│   ├── backup-cronjob.yaml    # Kubernetes manifest for the backup CronJob
│   └── backup-pvc.yaml        # PersistentVolumeClaim for backups
└── terraform/
└── main.tf                    # Terraform code for Argo CD and Argo CD Applications
└── README.md
```

## Prerequisites

Before you begin, ensure you have the following installed on your **MacBook Pro**:

* **Git:** For cloning this repository.
* **kubectl:** The Kubernetes command-line tool.
    * Installation: `brew install kubectl`
* **k3d:** A lightweight wrapper to run `k3s` (Lightweight Kubernetes) in Docker.
    * Installation: `brew install k3d`
* **Terraform:** For infrastructure as code.
    * Installation: `brew install terraform`
* **Docker Desktop:** This is required as `k3d` uses Docker as its container runtime. Ensure it's running.

## Setup & Deployment Instructions

Follow these steps to set up your local Kubernetes environment and deploy the applications using GitOps.

### 1. Clone the Repository

First, clone this Git repository to your local machine:

```bash
git clone git@github.com:cardiforia/task.git
cd task
```

2. Create the Local Kubernetes Cluster with k3d

We'll create a multi-node k3d cluster.

```bash
k3d cluster create my-gitops-cluster --servers 1 --agents 2 --port 8080:80@loadbalancer --api-port 6443
```

Verify Cluster Operational:

```bash
kubectl get nodes -o wide
kubectl config current-context
```

3. Deploy Argo CD and Applications with Terraform

```bash
cd terraform/
terraform init
terraform apply --auto-approve
```

4. Access the Argo CD UI

Get the Argo CD initial admin password: 

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo "" # Add a newline for better readability
```

Port-forward the Argo CD UI: 

```bash
kubectl -n argocd port-forward svc/argocd-server 8080:443
```

Verify MySQL pods are running: 

```bash
kubectl get pods -l app.kubernetes.io/name=mysql -n default
```

Verify the backup CronJob is configured: 

```bash
kubectl get cronjobs -n default
```

Trigger a backup manually (optional, for immediate verification) or wait for 5 minutes:

```bash
kubectl create job --from=cronjob/mysql-backup-job manual-mysql-backup -n default
```

Check backup pod status: 

```bash
kubectl get pods -l job-name=mysql-backup-job -n default
# Or if you manually triggered:
kubectl get pods -l job-name=manual-mysql-backup -n default
```

Verify backup files on the PVC: Find the name of a running or completed backup pod:

```bash
kubectl exec -it <backup-pod-name> -n default -- ls /backups/
# To view the content of a backup file:
kubectl exec -it <backup-pod-name> -n default -- cat /backups/<latest-backup-file.sql>
```

Access the Frontend Application:

```bash
kubectl get svc -n default
```

Access the application in your browser:

```bash
Open http://localhost:8080 in your web browser.
```

Cleanup:

```bash
# Destroy Terraform-managed resources
cd terraform/
terraform destroy --auto-approve

# Delete the k3d cluster
k3d cluster delete my-gitops-cluster
```
