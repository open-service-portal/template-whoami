# WhoareApp Crossplane Template

A Crossplane Composite Resource (XR) template for deploying the Traefik whoami demo application with automatic environment detection.

## Overview

This template demonstrates:
- **Environment-aware configuration** using EnvironmentConfig
- **Dynamic domain selection** based on environment (localhost vs openportal.dev)
- **Go-templating** for flexible resource generation  
- **GitOps compatibility** - XRs can be deployed via Flux

## Structure

```
.
├── xrd.yaml                    # WhoareApp XR Definition
├── composition.yaml            # Implementation using go-templating
├── environment-configs.yaml    # Environment-specific settings
├── kustomization.yaml         # For installing via Flux
└── example/
    ├── example-local.yaml     # Local deployment (whoami.localhost)
    └── example-production.yaml # Production deployment (whoami.openportal.dev)
```

## Installation

### Prerequisites
- Kubernetes cluster with Crossplane v2.0+
- provider-kubernetes installed
- NGINX Ingress Controller

### Install the Template

```bash
# Apply XRD, Composition, and EnvironmentConfigs
kubectl apply -k .

# Or individually:
kubectl apply -f xrd.yaml
kubectl apply -f composition.yaml
kubectl apply -f environment-configs.yaml
```

### Install via Flux

Add to your Flux catalog or create a dedicated source:

```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: template-whoami
  namespace: flux-system
spec:
  interval: 1m0s
  url: https://github.com/open-service-portal/template-whoami
  ref:
    branch: main
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: template-whoami
  namespace: flux-system
spec:
  interval: 1m0s
  sourceRef:
    kind: GitRepository
    name: template-whoami
  path: "./"
  prune: true
```

## Usage

### Deploy for Local Development

```yaml
apiVersion: demo.openportal.dev/v1alpha1
kind: WhoareApp
metadata:
  name: whoami-dev
  namespace: default
spec:
  replicas: 1
  environment: local  # Uses whoami.localhost
```

Apply:
```bash
kubectl apply -f example/example-local.yaml
```

Access:
```bash
# Port-forward the ingress controller
kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8080:80

# Access the app
curl http://whoami.localhost:8080
```

### Deploy for Production

```yaml
apiVersion: demo.openportal.dev/v1alpha1
kind: WhoareApp
metadata:
  name: whoami-prod
  namespace: default
spec:
  replicas: 3
  environment: production  # Uses whoami.openportal.dev
```

Apply:
```bash
kubectl apply -f example/example-production.yaml
```

Access:
```bash
curl https://whoami.openportal.dev
```

## How It Works

1. **EnvironmentConfig Selection**: The Composition loads environment-specific configurations based on the `environment` field
2. **Go-Templating**: Dynamically generates Kubernetes resources with the correct domain
3. **Resource Creation**: Creates namespace, deployment, service, and ingress
4. **Auto-Ready**: Marks the XR as ready when all resources are created

## Environment Configurations

### Local (whoami.localhost)
- Domain: `whoami.localhost`
- Suitable for local development with port-forwarding

### Production (whoami.openportal.dev)
- Domain: `whoami.openportal.dev`
- Can include TLS configuration (cert-manager annotations)

### Staging (whoami-staging.openportal.dev)
- Domain: `whoami-staging.openportal.dev`
- For testing before production

## API Reference

### WhoareApp Spec

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `replicas` | integer | 2 | Number of pod replicas (1-10) |
| `environment` | string | auto-detect | Environment: local, production, staging, auto-detect |
| `image` | string | traefik/whoami:v1.10.1 | Container image to deploy |

## Restaurant Analogy

- **Menu (XRD)**: WhoareApp - what developers can order
- **Recipe (Composition)**: How to prepare the whoami deployment
- **Ingredients (EnvironmentConfig)**: Environment-specific settings like domains
- **Kitchen (provider-kubernetes)**: Creates the actual Kubernetes resources
- **Order (XR)**: `kubectl apply -f example/example-local.yaml`

## Troubleshooting

### Check XR Status
```bash
kubectl get whoareapp
kubectl describe whoareapp whoami-dev
```

### Check Generated Resources
```bash
# Resources are created in a namespace matching the XR name
kubectl get all -n whoami-dev
```

### View Composition Pipeline
```bash
kubectl get composition xwhoareapp-kubernetes -o yaml
```

## Benefits Over Plain Kubernetes

- **No Manual Patching**: Environment settings are declarative
- **Reusable**: Same XRD for multiple deployments
- **Type-Safe**: Schema validation for inputs
- **Self-Documenting**: XRD describes available options
- **GitOps Ready**: Deploy XRs via Flux

## License

This template is open source. The whoami application is maintained by Traefik Labs.