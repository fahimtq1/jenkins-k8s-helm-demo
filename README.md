# Jenkins - Kubernetes Mock App Upgrade Pipeline

Automated upgrade pipeline for a mock web app ("SimpleWebApp") on Kubernetes with a PostgreSQL backend. This project demonstrates a full CI/CD cycle, including health checks, database backup, schema upgrades, Helm-based application deployment, and artifact archiving.

## Architecture Overview

```mermaid
flowchart LR
    subgraph Jenkins_VM["Jenkins VM (192.168.50.110)"]
        J[Jenkins Pipeline]
        J-- "kubectl, helm" -->KT[K8s Tools]
        J-- "psql, pg_dump" -->DBT[DB Tools]
        J-- "curl" -->CURL
    end

    subgraph SSH_Tunnel[SSH Tunnel]
        T1["Local 8443 ↔ K8s VM:6443"]
        T2["Local:NodePort ↔ K8s VM:NodePort"]
    end

    subgraph K8s_VM["K8s VM (192.168.50.112)"]
        API[Kube API :6443]
        SVC[Service: NodePort]
        DEP[Deployment simplewebapp]
        POD[Pod]
        API -- "kubectl" --> J
        SVC -- "curl via Tunnel" --> CURL
    end

    subgraph DB_VM["DB VM (192.168.50.111)"]
        DB[(PostgreSQL)]
        DBT -- "psql/pg_dump" --> DB
    end

Prerequisites
3 x Virtual Machines: Jenkins VM, Kubernetes VM, PostgreSQL VM.

Jenkins VM: Jenkins controller/agent with labels jenkins-vm. Must have kubectl, helm, psql, pg_dump, curl installed.

Kubernetes VM: Minikube cluster with 1 control-plane and 1 worker node, CNI (e.g., Flannel) installed.

PostgreSQL VM: PostgreSQL server configured to allow connections from the Jenkins VM IP.

Network: VMs must be on the same network segment (e.g., 192.168.50.0/24).

Quick Start
1. Environment Setup
Follow the detailed guide in docs/ENVIRONMENT_SETUP.md to prepare your VMs and deploy the initial v1.0 state.

2. Repository Setup
```bash
git clone https://github.com/<your-username>/jenkins-k8s-mockapp.git
cd jenkins-k8s-mockapp
```

3. Configure Jenkins
Create Credential:

Kind: Secret text

ID: cks-test-db-password

Secret: testpass

Create Pipeline Job:

New Item → Pipeline

Name: app-upgrade-pipeline

Definition: Pipeline script from SCM

SCM: Git

Repository URL: Your fork's URL

Script Path: Jenkinsfile

Save.

4. Run the Pipeline
Open the job and click "Build with Parameters".

Verify parameters (IPs, paths) match your environment.

Click "Build".

Pipeline Stages
Prepare Environment: Creates directory structure for backups and health checks.

Pre-Flight: Performs a health check on the v1.0 app and takes a pg_dump backup of the database.

Apply DB Schema: Executes the v2.0_upgrade.sql script to upgrade the database.

Helm Upgrade: Upgrades the Kubernetes deployment to the v2.0 Helm chart and waits for rollout.

Mock DTA Upgrade: Executes a mock script to simulate updating a third-party integration system.

Post-Upgrade Health Check: Verifies the v2.0 app is healthy and serving the correct content.

