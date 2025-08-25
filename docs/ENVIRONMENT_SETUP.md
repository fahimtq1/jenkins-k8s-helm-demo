# Environment Setup Guide

This guide details the steps to prepare three dedicated Virtual Machines (PostgreSQL VM, Jenkins VM, Kubernetes VM) and perform the initial manual deployment of "SimpleWebApp Version 1.0". This initial state is required before the automated Jenkins pipeline can run.

## VM Inventory & Network

| Role              | Hostname    | IP Address       | Notes                                                                 |
| :---------------- | :---------- | :--------------- | :-------------------------------------------------------------------- |
| **PostgreSQL VM** | `postgres`  | `192.168.50.111` | Hosts the `cks_test_db` database.                                     |
| **Jenkins VM**    | `jenkins`   | `192.168.50.110` | Hosts Jenkins controller/agent and acts as the "ops" machine.         |
| **Kubernetes VM** | `k8s`       | `192.168.50.112` | Hosts a Minikube Kubernetes cluster (control-plane + worker).         |

Ensure all VMs have basic OS installed (e.g., Ubuntu Server 22.04 LTS) and can ping each other.

---

## Phase 1: VM Preparation

### A. PostgreSQL VM (`192.168.50.111`)

1.  **Install PostgreSQL:**
    ```bash
    sudo apt update && sudo apt upgrade -y
    sudo apt install postgresql postgresql-contrib -y
    ```

2.  **Configure Remote Access:**
    *   Edit the config file to listen on all interfaces:
        ```bash
        sudo nano /etc/postgresql/*/main/postgresql.conf
        # Find `listen_addresses` and change it to:
        listen_addresses = '*'
        ```
    *   Edit the client authentication file to allow the Jenkins VM:
        ```bash
        sudo nano /etc/postgresql/*/main/pg_hba.conf
        # Add this line at the end:
        host all all 192.168.50.110/32 md5
        ```
    *   Restart PostgreSQL: `sudo systemctl restart postgresql`

3.  **Create Test Database and User:**
    ```bash
    sudo -u postgres psql -c "CREATE DATABASE cks_test_db;"
    sudo -u postgres psql -c "CREATE USER cks_test_user WITH PASSWORD 'testpass';"
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE cks_test_db TO cks_test_user;"
    ```

### B. Jenkins VM (`192.168.50.110`)

1.  **Install Prerequisites:**
    ```bash
    sudo apt update && sudo apt upgrade -y
    sudo apt install openjdk-11-jdk -y
    ```

2.  **Install Docker and Run Jenkins:**
    ```bash
    # Install Docker
    sudo apt install apt-transport-https ca-certificates curl software-properties-common -y
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    sudo apt update
    sudo apt install docker-ce -y
    sudo usermod -aG docker $USER
    newgrp docker # Or log out and back in

    # Run Jenkins in a container
    docker run -d -p 8080:8080 -p 50000:50000 -v jenkins_home_test:/var/jenkins_home --name jenkins-cks-test jenkins/jenkins:lts-jdk11
    ```
    Access Jenkins at `http://<jenkins-vm-ip>:8080`. Unlock it with the password from `docker exec jenkins-cks-test cat /var/jenkins_home/secrets/initialAdminPassword`.

3.  **Install CLI Tools on the VM (for the agent):**
    ```bash
    # PostgreSQL Client
    sudo apt install postgresql-client -y

    # kubectl
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

    # Helm
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    ```

4.  **Create Directory Structure and Mock DTA Script:**
    ```bash
    # Create directories
    sudo mkdir -p /opt/mock_apps/{simplewebapp_helm_charts,db_scripts,dta_source_files/v1.0,dta_source_files/v2.0} /srv/mock_fileserver
    sudo chown -R $USER:$USER /opt/mock_apps
    sudo chmod -R 777 /srv/mock_fileserver # For easy testing only

    # Create the mock DTA script
    cat << 'EOF' > /opt/mock_apps/dta_v2.sh
    #!/bin/bash
    ACTION=$1
    COMPONENT=$2
    VERSION=$3
    STATE_FILE="/opt/mock_apps/dta_state"

    if [[ $ACTION == "listrevisions" ]]; then
        if [[ -f $STATE_FILE ]]; then
            cat $STATE_FILE
        else
            echo "1.0.0" # Default version if no state exists
        fi
    elif [[ $ACTION == "setrevision" ]]; then
        echo "Setting revision for $COMPONENT to $VERSION"
        echo "$VERSION" > $STATE_FILE
    else
        echo "Usage: $0 {listrevisions|setrevision} [component] [version]"
        exit 1
    fi
    EOF
    chmod +x /opt/mock_apps/dta_v2.sh
    ```

### C. Kubernetes VM (`192.168.50.112`)

1.  **Install Docker and Minikube:**
    ```bash
    # Install Docker (same as Jenkins VM steps)
    sudo apt update && sudo apt upgrade -y
    sudo apt install apt-transport-https ca-certificates curl software-properties-common -y
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    sudo apt update
    sudo apt install docker-ce -y
    sudo usermod -aG docker $USER
    newgrp docker

    # Install Minikube
    curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
    sudo install minikube-linux-amd64 /usr/local/bin/minikube
    ```

2.  **Start a Multi-Node Cluster with CNI:**
    ```bash
    # Start a cluster with 2 nodes and Flannel CNI
    minikube start --driver=docker --cni=flannel --nodes=2

    # Verify the cluster
    minikube kubectl -- get nodes -o wide
    ```

3.  **Prepare Kubeconfig for Jenkins:**
    ```bash
    # Generate a kubeconfig with the VM's IP, not localhost
    minikube kubectl -- config view --raw > ~/jenkins-kubeconfig.yaml
    sed -i 's|server: https://127.0.0.1:[0-9]*|server: https://192.168.50.112:6443|' ~/jenkins-kubeconfig.yaml

    # Copy it to the Jenkins VM (run this from the Jenkins VM)
    # scp k8sadmin@192.168.50.112:~/jenkins-kubeconfig.yaml ~/.kube/config
    ```

---

## Phase 2: Populate Mock Application Files

On the **Jenkins VM**, populate the `/opt/mock_apps/` directory with the files from this repository's `helm/` and `sql/` directories.

1.  **Helm Charts:** Copy the `simplewebapp-chart-v1.0/` and `simplewebapp-chart-v2.0/` directories to `/opt/mock_apps/simplewebapp_helm_charts/`.
2.  **SQL Scripts:** Copy `v1.0_init.sql` and `v2.0_upgrade.sql` to `/opt/mock_apps/db_scripts/`.
3.  **DTA Source:** Create mock config files in `/opt/mock_apps/dta_source_files/v1.0/` and `.../v2.0/` if needed.

---

## Phase 3: Initial Manual Deployment (v1.0)

These commands are run from the **Jenkins VM**.

1.  **Deploy SimpleWebApp v1.0 to Kubernetes:**
    ```bash
    helm install simpleapp-release1 /opt/mock_apps/simplewebapp_helm_charts/simplewebapp-chart-v1.0/
    ```
    Verify: `kubectl get pods,svc`

2.  **Initialize PostgreSQL Database to v1.0:**
    ```bash
    PGPASSWORD='testpass' psql -h 192.168.50.111 -U cks_test_user -d cks_test_db -a -f /opt/mock_apps/db_scripts/v1.0_init.sql
    ```
    Verify: `PGPASSWORD='testpass' psql -h 192.168.50.111 -U cks_test_user -d cks_test_db -c "SELECT * FROM app_config;"`

3.  **Set Initial DTA Mock State:**
    ```bash
    /opt/mock_apps/dta_v2.sh setrevision app 1.0.0
    ```
    Verify: `/opt/mock_apps/dta_v2.sh listrevisions` (should output `1.0.0`)

The system is now in the initial v1.0 state and ready for the Jenkins pipeline to upgrade it to v2.0.