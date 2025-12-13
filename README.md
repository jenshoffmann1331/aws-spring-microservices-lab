# AWS Spring Microservices Lab

Ein persönlicher Playground für:

- CloudFormation-Setups für AWS Managed Kubernetes (EKS) und Managed Kafka (MSK)
- Spring Boot Microservices
- Build-Pipelines mit GitHub Actions
- Deployment mit Helm und Argo CD

Dieses Repo ist als Lern- und Experimentierumgebung gedacht, nicht als Produktionssetup.

## GitHub Identity Provider in AWS IAM anlegen

```bash
./scripts/deploy-github-identity-provider.sh
```

## CloudFormation Service Rolle anlegen

```bash
./scripts/deploy-cfn-service-role.sh
```

## GitHub Deploy Rolle anlegen

```bash
./scripts/deploy-github-deploy-role.sh
```

## Kubectl einrichten

Authentifizierung:

```bash
aws eks update-kubeconfig --region eu-central-1 --name microservices-lab-dev
```

Test:

```bash
kubectl get svc
```

## ArgoCD

```bash
kubectl create namespace argocd
kubectl apply -n argocd \                                                                                
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl -n argocd get pods
```

Sobald die PODs initialisiert sind:

```bash
kubectl -n argocd port-forward svc/argocd-server 8080:443
```

Browser:

```bash
https://localhost:8080
```

Login:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 --decode
```

User: `admin`


Argo-Client installieren unter Mac:

```bash
brew install argocd
```
