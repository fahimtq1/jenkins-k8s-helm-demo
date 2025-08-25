#!/bin/bash
#
# Retrieves the NodePort for a given service in Kubernetes.
#
# Usage: ./check_nodeport.sh <SERVICE_NAME>
# Example: ./check_nodeport.sh simpleapp-release1-simplewebapp

set -e

SERVICE_NAME=$1

if [ -z "$SERVICE_NAME" ]; then
    echo "Error: Service name is required."
    echo "Usage: $0 <SERVICE_NAME>"
    exit 1
fi

echo "Fetching NodePort for service: ${SERVICE_NAME}"

NODE_PORT=$(kubectl get service ${SERVICE_NAME} -o jsonpath='{.spec.ports[0].nodePort}')

if [ -z "$NODE_PORT" ]; then
    echo "Error: Could not find NodePort for service '${SERVICE_NAME}'. Is the service type NodePort?"
    exit 1
fi

echo "NodePort is: ${NODE_PORT}"
exit 0