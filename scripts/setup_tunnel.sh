#!/bin/bash
#
# This script sets up an SSH tunnel to forward the Kubernetes API server port
# from the remote K8s VM to the local machine (e.g., the Jenkins agent).
# This is useful if direct network access to the API server is blocked.
#
# Usage: ./setup_tunnel.sh <USER>@<K8S_VM_IP>
# Example: ./setup_tunnel.sh user@192.168.50.105
#
# Your kubeconfig must then be updated to point to localhost:8443

set -e

K8S_HOST=$1
LOCAL_PORT=8443
REMOTE_PORT=8443 # Default Minikube API server port

if [ -z "$K8S_HOST" ]; then
    echo "Error: SSH host required."
    echo "Usage: $0 <USER>@<K8S_VM_IP>"
    exit 1
fi

echo "Setting up SSH tunnel: localhost:${LOCAL_PORT} -> ${K8S_HOST}:${REMOTE_PORT}"
echo "Press Ctrl+C to terminate the tunnel."

# -f: Go into the background
# -N: Do not execute a remote command
# -L: Specifies the port forwarding
ssh -f -N -L ${LOCAL_PORT}:localhost:${REMOTE_PORT} ${K8S_HOST}

echo "Tunnel established. Update your kubeconfig server to 'https://localhost:${LOCAL_PORT}'"
echo "To check if the process is running: ps aux | grep ssh"
echo "To kill the tunnel: pkill -f 'ssh -f -N -L ${LOCAL_PORT}'"