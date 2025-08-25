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
