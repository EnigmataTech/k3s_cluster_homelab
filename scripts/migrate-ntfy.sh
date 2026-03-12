#!/bin/bash
# migrate-ntfy.sh — Copy ntfy auth.db and cache.db from local /tmp into the k8s pod
# Run AFTER the ntfy pod is Running and the PVC is provisioned.
# Prerequisites: kubectl configured, ntfy pod Running

set -e

NAMESPACE="ntfy"
PODNAME=$(kubectl get pod -n "$NAMESPACE" -l app=ntfy -o jsonpath='{.items[0].metadata.name}')

if [ -z "$PODNAME" ]; then
    echo "ERROR: No ntfy pod found in namespace $NAMESPACE. Is it deployed?"
    exit 1
fi

echo "Found ntfy pod: $PODNAME"
echo "Checking for source files..."

if [ ! -f /tmp/ntfy-auth.db ]; then
    echo "Fetching auth.db from monitorlizard..."
    scp enigma@100.81.46.87:/home/enigma/Docker_Deployments/ntfy-deployment/data/auth.db /tmp/ntfy-auth.db
fi

if [ ! -f /tmp/ntfy-cache.db ]; then
    echo "Fetching cache.db from monitorlizard..."
    scp enigma@100.81.46.87:/home/enigma/Docker_Deployments/ntfy-deployment/data/cache.db /tmp/ntfy-cache.db
fi

echo "Copying auth.db to pod..."
kubectl cp /tmp/ntfy-auth.db "$NAMESPACE/$PODNAME:/data/auth.db"

echo "Copying cache.db to pod..."
kubectl cp /tmp/ntfy-cache.db "$NAMESPACE/$PODNAME:/data/cache.db"

echo "Restarting ntfy pod to reload databases..."
kubectl rollout restart deployment/ntfy -n "$NAMESPACE"
kubectl rollout status deployment/ntfy -n "$NAMESPACE"

echo ""
echo "Migration complete. Verify with:"
echo "  curl -H 'Authorization: Bearer <token>' http://ntfy.enigmata.local/v1/health"
