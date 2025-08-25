#!/usr/bin/env bash
set -euo pipefail

K8S_HOST="${K8S_HOST:-192.168.50.112}"
APL_PORT_REMOTE=6443
APL_PORT_LOCAL=8443

# Get NodePort from service name (defaults to simpleapp-release1-simplewebapp)
SVC_NAME="${1:-simpleapp-release1-simplewebapp}"
TARGET_PORT="${2:-80}"
NODEPORT=$(kubectl get svc "$SVC_NAME" -o jsonpath="{.spec.ports[?(@.port==$TARGET_PORT)].nodePort}")

echo "Discovered NodePort for service $SVC_NAME: $NODEPORT"

# Kill existing listeners on our local ports
pids=$(lsof -ti :$APL_PORT_LOCAL,:$NODEPORT 2>/dev/null || true)
if [[ -n "$pids" ]]; then
    echo "Killing existing tunnel PIDs: $pids"
    kill $pids || true
    sleep 2
fi

# Start the tunnel
echo "Establishing SSH tunnel to $K8S_HOST..."
ssh -f -N \
-L ${APL_PORT_LOCAL}:${K8S_HOST}:${APL_PORT_REMOTE} \
-L ${NODEPORT}:${K8S_HOST}:${NODEPORT} \
k8sadmin@${K8S_HOST} \
-i ~/.ssh/id_rsa \
-o ExitOnForwardFailure=yes -o ServerAliveInterval=60

echo "Tunnel established successfully:"
echo "  - KubeAPI: https://127.0.0.1:${APL_PORT_LOCAL}"
echo "  - App Service: http://127.0.0.1:${NODEPORT}"