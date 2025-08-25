#!/bin/bash
#
# A simple script to verify network connectivity to the test environment VMs.
#
# Usage: ./verify_connectivity.sh <K8S_VM_IP> <POSTGRES_VM_IP>

set -e

K8S_VM_IP=$1
POSTGRES_VM_IP=$2
K8S_API_PORT=8443
POSTGRES_PORT=5432

if [ -z "$K8S_VM_IP" ] || [ -z "$POSTGRES_VM_IP" ]; then
    echo "Error: Both Kubernetes and PostgreSQL VM IPs are required."
    echo "Usage: $0 <K8S_VM_IP> <POSTGRES_VM_IP>"
    exit 1
fi

echo "--- Verifying Connectivity ---"

# Check basic ping
echo -n "Pinging Kubernetes VM (${K8S_VM_IP})... "
ping -c 1 -W 2 ${K8S_VM_IP} > /dev/null 2>&1 && echo "SUCCESS" || echo "FAILED"

echo -n "Pinging PostgreSQL VM (${POSTGRES_VM_IP})... "
ping -c 1 -W 2 ${POSTGRES_VM_IP} > /dev/null 2>&1 && echo "SUCCESS" || echo "FAILED"

# Check port connectivity using nc (netcat)
echo -n "Checking K8s API port (${K8S_VM_IP}:${K8S_API_PORT})... "
nc -z -w 2 ${K8S_VM_IP} ${K8S_API_PORT} && echo "SUCCESS" || echo "FAILED"

echo -n "Checking PostgreSQL port (${POSTGRES_VM_IP}:${POSTGRES_PORT})... "
nc -z -w 2 ${POSTGRES_VM_IP} ${POSTGRES_PORT} && echo "SUCCESS" || echo "FAILED"

echo "--- Verification Complete ---"