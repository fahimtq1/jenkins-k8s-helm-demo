#!/usr/bin/env bash
set -euo pipefail

NODEPORT="${1:-}"
K8S_API_LOCAL_PORT="${2:-8443}"

set -x
# Check if ports are listening locally
lsof -i :${K8S_API_LOCAL_PORT} || echo "No process listening on API port $K8S_API_LOCAL_PORT"
lsof -i :${NODEPORT} || echo "No process listening on NodePort $NODEPORT"

# Test application connectivity
curl -I "http://127.0.0.1:${NODEPORT}/" || echo "Curl to app failed"

# Test Kubernetes API connectivity (insecure for testing)
kubectl --server="https://127.0.0.1:${K8S_API_LOCAL_PORT}" --insecure-skip-tls-verify get nodes -o wide || echo "kubectl check failed"