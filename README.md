# Traefik Whoami Demo Deployment

A simple demo application that displays HTTP request information, deployed via Flux GitOps.

## Overview

This repository contains Kubernetes manifests for deploying the [Traefik whoami](https://github.com/traefik/whoami) application, structured for GitOps with Flux.

## Structure

```
.
├── namespace.yaml           # Dedicated namespace for the app
├── deployment.yaml          # 2-replica deployment
├── service.yaml            # ClusterIP service
├── ingress.yaml            # NGINX ingress configuration
├── kustomization.yaml      # Base kustomization
└── overlays/
    ├── local/              # Local development overlay
    │   └── kustomization.yaml
    └── production/         # Production overlay
        └── kustomization.yaml
```

## Deployment with Flux

### Important: Two-Step Process

Flux requires two resources to deploy from a Git repository:
1. **GitRepository** - Points to the source code
2. **Kustomization** - Deploys the manifests from the source

### 1. Add Repository to Flux (Creates GitRepository)

```bash
flux create source git deploy-whoami \
  --url=https://github.com/open-service-portal/deploy-whoami \
  --branch=main \
  --interval=1m
```

### 2. Create Kustomization for Your Environment (Deploys the app)

For **local development**:
```bash
flux create kustomization whoami-local \
  --source=GitRepository/deploy-whoami \
  --path="./overlays/local" \
  --prune=true \
  --interval=1m
```

For **production**:
```bash
flux create kustomization whoami-prod \
  --source=GitRepository/deploy-whoami \
  --path="./overlays/production" \
  --prune=true \
  --interval=1m
```

### Quick Deploy Script

Use the provided `flux-deploy.sh` script for easy deployment:

```bash
# Deploy to local environment
./flux-deploy.sh deploy local

# Deploy to production
./flux-deploy.sh deploy production

# Remove deployment
./flux-deploy.sh remove local
# or
./flux-deploy.sh remove production

# Check status
./flux-deploy.sh status
```

## Manual Deployment (Testing)

### Deploy to Local Cluster
```bash
kubectl apply -k overlays/local/
```

### Deploy to Production
```bash
kubectl apply -k overlays/production/
```

### Remove Deployment
```bash
kubectl delete -k overlays/local/   # or overlays/production/
```

## Accessing the Application

### Local (with nip.io)
```bash
curl http://whoami.127.0.0.1.nip.io:8080
# Note: Requires port-forward: kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8080:80
```

### Production (with real domain)
```bash
curl https://whoami.openportal.dev
```

## What the Application Does

The whoami application returns information about the HTTP request:
- Hostname (pod name)
- IP addresses
- Request headers
- Request method and path

Example output:
```
Hostname: whoami-5d8f9d6c9b-4xkzj
IP: 10.42.0.10
RemoteAddr: 10.42.0.1:52918
GET / HTTP/1.1
Host: whoami.openportal.dev
User-Agent: curl/7.68.0
```

## Environment Differences

### Local
- Host: `whoami.127.0.0.1.nip.io`
- Replicas: 2
- No TLS

### Production
- Host: `whoami.openportal.dev`
- Replicas: 3
- TLS with cert-manager (when configured)

## Monitoring

Check deployment status:
```bash
kubectl get all -n whoami-demo
```

View logs:
```bash
kubectl logs -n whoami-demo -l app=whoami --tail=50 -f
```

## Troubleshooting

1. **Pods not starting**: Check resource limits and node capacity
2. **Ingress not working**: Verify NGINX ingress controller is installed
3. **DNS issues**: Ensure DNS is configured for production domain

## GitOps Workflow

1. Make changes to manifests in this repository
2. Commit and push to main branch
3. Flux automatically syncs changes (within 1 minute)
4. Monitor deployment: `flux get kustomizations`

## License

This deployment configuration is open source. The whoami application is maintained by Traefik Labs.