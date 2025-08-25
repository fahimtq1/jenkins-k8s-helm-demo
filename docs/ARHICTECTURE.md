# Architecture & Diagrams

This document provides a visual and technical overview of the system architecture and the pipeline's flow.

---

## System Architecture

The infrastructure consists of three virtual machines on the same network segment. The Jenkins VM orchestrates changes across the other two.

```mermaid
flowchart TD
    subgraph Network["Network: 192.168.50.0/24"]
        subgraph JenkinsVM["Jenkins VM (192.168.50.110)"]
            J[Jenkins\nController/Agent]
            J -.-> |kubectl| KT[kubectl]
            J -.-> |psql/pg_dump| DBT[PostgreSQL Client]
            J -.-> |curl| CURL[curl]
        end

        subgraph K8sVM["Kubernetes VM (192.168.50.112)"]
            subgraph Minikube["Minikube Cluster"]
                API[Kube API Server\n:6443]
                SVC[Service: simplewebapp\nType: NodePort\n(e.g., :30245)]
                DEP[Deployment: simplewebapp]
                POD[Pod: nginx]
                SVC --> POD
            end
        end

        subgraph PostgresVM["PostgreSQL VM (192.168.50.111)"]
            DB[(PostgreSQL\ncks_test_db)]
        end
    end

    JenkinsVM -- "SSH Tunnel" --- K8sVM
    JenkinsVM -- "Direct Connection\nTCP 5432" --- PostgresVM

    KT -.-> |"Via Tunnel 8443 → :6443"| API
    CURL -.-> |"Via Tunnel → NodePort (e.g., 30245)"| SVC
    DBT -.-> |"Port 5432"| DB
```

### Key Connections

- **SSH Tunnels (Jenkins ⇄ K8s):**
  - **Local 8443 → Remote 192.168.50.112:6443** (Kubernetes API)
  - **Local &lt;NodePort&gt; → Remote 192.168.50.112:&lt;NodePort&gt;** (Application NodePort)
- **PostgreSQL:** Direct TCP connection from the Jenkins VM to the PostgreSQL VM on **port 5432**.

---

## Pipeline Stage Flow

The Jenkins pipeline executes the following sequence of stages to perform the upgrade.

```mermaid
sequenceDiagram
    autonumber
    participant J as Jenkins Pipeline
    participant K as Kubernetes API
    participant S as SimpleWebApp (Service/Deployment)
    participant DB as PostgreSQL

    Note over J: Prepare Environment
    J->>J: Create backup & health-check dirs

    Note over J,S: Pre-Flight
    J->>S: curl / (health check v1.0)
    J->>DB: pg_dump (backup)

    Note over J,DB: Apply DB Schema
    J->>DB: psql -f v2.0_upgrade.sql

    Note over J,K,S: Helm Upgrade
    J->>K: helm upgrade --install v2.0
    K-->>S: Rollout new Deployment
    J->>K: kubectl rollout status

    Note over J,S: Post-Upgrade Health Check
    J->>S: curl / (verify v2.0 content)

    Note over J: Archive Artifacts
    J->>J: Archive dumps, logs, evidence
```

---

## Helm Chart Structure

The application is packaged as a Helm chart for simplified deployment and version management.

```text
simplewebapp-chart-v2.0/
├── Chart.yaml          # Metadata (name, version, appVersion)
├── values.yaml         # Default configuration (replicas, image, HTML content)
└── templates/
    ├── _helpers.tpl    # Reusable naming templates
    ├── deployment.yaml # Defines the Pod spec, probes, volumes
    ├── service.yaml    # Defines the NodePort service
    └── configmap.yaml  # Stores the HTML content from values.yaml
```

### Deployment Flow

- `values.yaml` contains the HTML page content for the app.
- During `helm install/upgrade`, this value is injected into the **ConfigMap** template.
- The **Deployment** mounts the ConfigMap as a volume into the **Nginx** container, which serves the page.
`
