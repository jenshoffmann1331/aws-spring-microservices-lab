# AWS Spring Microservices Lab

Ein persönlicher Playground für:

- CloudFormation-Setups für AWS Managed Kubernetes (EKS) und Managed Kafka (MSK)
- Spring Boot Microservices
- Build-Pipelines mit GitHub Actions
- Deployment mit Helm und Argo CD

Dieses Repo ist als Lern- und Experimentierumgebung gedacht, nicht als Produktionssetup.


## Kubectl einrichten

Authentifizierung:

```bash
aws eks update-kubeconfig --region eu-central-1 --name microservices-lab-dev
```

Test:

```bash
kubectl get svc
```
