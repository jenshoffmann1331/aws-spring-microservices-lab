#!/usr/bin/env bash
set -euo pipefail

REGION="${INPUT_REGION:-${AWS_REGION:-eu-central-1}}"
CLUSTER_NAME="${INPUT_CLUSTER_NAME:-microservices-lab-dev}"
NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
RELEASE_NAME="${ARGOCD_RELEASE_NAME:-argocd}"
VALUES_FILE="${ARGOCD_VALUES_FILE:-infra/helm/argocd/values.yaml}"

echo "Region:   $REGION"
echo "Cluster:  $CLUSTER_NAME"
echo "Namespace:$NAMESPACE"
echo "Release:  $RELEASE_NAME"
echo "Values:   $VALUES_FILE"
echo

[[ -f "$VALUES_FILE" ]] || { echo "ERROR: Values file not found: $VALUES_FILE" >&2; exit 1; }

aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER_NAME"

# Idempotent namespace creation
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# Idempotent helm repo setup
helm repo list | grep -q '^argo[[:space:]]' || helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# Idempotent install/upgrade
helm upgrade --install "$RELEASE_NAME" argo/argo-cd \
  --namespace "$NAMESPACE" \
  -f "$VALUES_FILE" \
  --wait \
  --timeout 15m

# Extra safety: wait for server deployment
kubectl -n "$NAMESPACE" rollout status deploy/argocd-server --timeout=10m || true

kubectl -n "$NAMESPACE" get pods
echo
echo "Argo CD installed/updated."

echo "To access locally:"
echo "  kubectl -n $NAMESPACE port-forward svc/argocd-server 8080:80"

if kubectl -n "$NAMESPACE" get secret argocd-initial-admin-secret >/dev/null 2>&1; then
  echo "Initial admin password:"
  echo "  kubectl -n $NAMESPACE get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo"
else
  echo "Initial admin password secret not found (may be disabled by your values/SSO setup)."
fi
