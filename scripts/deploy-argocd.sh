#!/usr/bin/env bash
set -euo pipefail

REGION="${AWS_REGION:-eu-central-1}"
CLUSTER_NAME="${CLUSTER_NAME:-microservices-lab-dev}"
NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
RELEASE_NAME="${ARGOCD_RELEASE_NAME:-argocd}"
VALUES_FILE="${ARGOCD_VALUES_FILE:-infra/helm/argocd/values.yaml}"

echo "Region: $REGION"
echo "Cluster: $CLUSTER_NAME"
echo "Namespace: $NAMESPACE"
echo "Release: $RELEASE_NAME"
echo "Values: $VALUES_FILE"
echo

aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER_NAME"

kubectl get ns "$NAMESPACE" >/dev/null 2>&1 || kubectl create ns "$NAMESPACE"

helm repo add argo https://argoproj.github.io/argo-helm >/dev/null 2>&1 || true
helm repo update >/dev/null

helm upgrade --install "$RELEASE_NAME" argo/argo-cd \
  --namespace "$NAMESPACE" \
  -f "$VALUES_FILE" \
  --wait \
  --timeout 15m

kubectl -n "$NAMESPACE" get pods
echo
echo "Argo CD installed."
echo "To access locally:"
echo "  kubectl -n $NAMESPACE port-forward svc/argocd-server 8080:80"
echo "Initial admin password:"
echo "  kubectl -n $NAMESPACE get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo"
