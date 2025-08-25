#!/usr/bin/env bash
set -euo pipefail

SVC="${1:-simpleapp-release1-simplewebapp}"
PORT="${2:-80}"

kubectl get svc "$SVC" -o jsonpath="{.spec.ports[?(@.port==$PORT)].nodePort}{'\n'}"