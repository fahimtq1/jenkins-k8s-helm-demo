# Troubleshooting Guide

This document catalogs common issues encountered when setting up and running the **Jenkins–K8s upgrade pipeline**, their root causes, and step-by-step solutions.

## Table of Contents

- [Pod Scheduling Issues](#pod-scheduling-issues)
- [Application Health & Probes](#application-health--probes)
- [Network Connectivity](#network-connectivity)
- [Authentication & Certificates](#authentication--certificates)
- [Pipeline & Script Errors](#pipeline--script-errors)

---

## Pod Scheduling Issues

### Symptom: `0/1 nodes are available: 1 node(s) had untolerated taint...`
**Root Cause:** The control-plane node has a taint (`node-role.kubernetes.io/control-plane:NoSchedule`) preventing regular pods from being scheduled on it.

**Solutions:**
- **Add a worker node (recommended):** Use Minikube to add a worker node.
  ```bash
  minikube node add
  ```
- **Remove the taint (testing only):**
  ```bash
  kubectl taint nodes <control-plane-node-name> node-role.kubernetes.io/control-plane:NoSchedule-
  ```

---

### Symptom: Pods on worker have no IP address and are stuck in `ContainerCreating`
**Root Cause:** A multi-node Minikube cluster was started **without** a Container Network Interface (CNI) plugin. The Docker driver’s built-in network doesn’t span multiple nodes.

**Solution:** Always start Minikube with a CNI, or enable one (e.g., **Flannel**).
```bash
minikube delete
minikube start --driver=docker --cni=flannel --nodes=2
# Or enable CNI after creation
minikube addons enable flannel
```

---

## Application Health & Probes

### Symptom: Pods in `CrashLoopBackOff`; logs show `Readiness probe failed: HTTP probe failed with statuscode: 404`
**Root Cause:** The default `livenessProbe` and `readinessProbe` in the Helm chart check `/index.html`, but `nginx:latest` serves content from `/`.

**Solution:** Update probe paths in `helm/simplewebapp-chart-v1.0/templates/deployment.yaml` and the v2.0 equivalent.
```yaml
livenessProbe:
  httpGet:
    path: /
    port: http
  initialDelaySeconds: 10
  periodSeconds: 10
readinessProbe:
  httpGet:
    path: /
    port: http
  initialDelaySeconds: 10
  periodSeconds: 10
```

---

## Network Connectivity

### Symptom: `curl: (7) Failed to connect to 127.0.0.1 port 18080` (or another port) from Jenkins pipeline
**Root Cause 1:** The SSH tunnel is not running, uses the wrong port, or forwards to the wrong IP (e.g., `127.0.0.1` **on the remote VM** instead of the K8s VM’s main IP).

**Solution 1:** Use `scripts/setup_tunnel.sh`. It discovers the correct NodePort and forwards to the K8s VM IP (e.g., `192.168.50.112`).

**Root Cause 2:** The pipeline uses a **hard-coded** NodePort that changed after the Service was recreated.

**Solution 2:** Discover the NodePort dynamically (as in the `Jenkinsfile`).
```bash
kubectl get svc ${params.K8S_HELM_RELEASE_NAME}-simplewebapp -o jsonpath='{.spec.ports[0].nodePort}'
```

---

### Symptom: `kubectl` commands from Jenkins VM timeout or fail
**Root Cause:** The kubeconfig on the Jenkins VM points to an **unreachable** address (e.g., the cluster’s internal IP `192.168.49.2`) instead of the SSH tunnel.

**Solution:** Ensure the kubeconfig server URL is `https://127.0.0.1:8443` (local end of the tunnel), and that `KUBECONFIG` points to the correct file.

---

## Authentication & Certificates

### Symptom: `x509: certificate is valid for 192.168.50.112, not 127.0.0.1`
**Root Cause:** The kubeconfig was copied from the K8s VM and still points to the VM’s IP, but `kubectl` is connecting via the tunnel at `127.0.0.1:8443`. TLS hostname mismatch.

**Solutions:**
- **Edit kubeconfig (preferred):** Change the cluster server URL in `~/.kube/config` on the Jenkins VM to `https://127.0.0.1:8443`.
- **Testing only:** Append `--insecure-skip-tls-verify=true` to `kubectl` commands.

### Symptom: `The server has asked for the client to provide credentials` or `Error from server (Forbidden)`
**Root Cause:** The kubeconfig lacks valid authentication credentials (certs or tokens).

**Solution:** Use a complete, working kubeconfig. Prefer the `~/jenkins-kubeconfig.yaml` generated on the K8s VM in the setup guide (contains admin credentials).

---

## Pipeline & Script Errors

### Symptom: `bash: sudo: command not found` in pipeline logs
**Root Cause:** The Jenkins agent runs in a minimal container without `sudo`. It’s usually unnecessary if the agent user already has access to the target paths.

**Solution:** Remove `sudo` from Jenkins pipeline commands. For example:
```groovy
// Jenkinsfile snippet
sh """
  mkdir -p ${env.DB_BACKUP}
  kubectl get pods --request-timeout=10s
"""
```

### Symptom: `Groovy: unexpected char: '\\'` error
**Root Cause:** Using backslashes for line continuation in multi-line shell commands.

**Solution:** Use triple double-quotes for multi-line `sh` steps (no backslashes needed).
```groovy
// Correct
sh """
  echo "This is a multi-line command"
  kubectl get pods
"""
```

### Symptom: `Permission denied` when the DTA script writes its state file
**Root Cause:** The `/opt/mock_apps/dta_state` path is owned by `root` or another user; the Jenkins agent user cannot write to it.

**Solution:** Ensure the agent user (often `jenkins` or the service user) has write access on the VM.
```bash
# Run on the VM shell (not inside a minimal agent container)
sudo chown -R $USER:jenkins /opt/mock_apps/
sudo chmod -R 775 /opt/mock_apps/
```
`
