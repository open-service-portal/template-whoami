# WhoareApp Crossplane Template

A Crossplane Composite Resource (XR) template for deploying the Traefik whoami demo application with automatic environment detection.

## Overview

This template demonstrates:
- **Dynamic subdomain creation** - deploy any app name as subdomain
- **Environment-aware domains** - automatic domain selection based on environment
- **System config integration** - uses platform-wide dns-config
- **Go-templating** for flexible resource generation  
- **GitOps compatibility** - XRs can be deployed via Flux

## Structure

```
.
├── xrd.yaml                    # WhoareApp XR Definition
├── composition.yaml            # Implementation using go-templating
├── kustomization.yaml         # For installing via Flux
└── example/
    ├── example-local.yaml     # Local deployment (myapp.localhost)
    └── example-production.yaml # Production deployment (demo.openportal.dev)
```

## Installation

### Prerequisites
- Kubernetes cluster with Crossplane v2.0+
- provider-kubernetes installed
- NGINX Ingress Controller
- System-wide dns-config EnvironmentConfig (installed by setup-cluster.sh)

### Install the Template

```bash
# Apply XRD and Composition
kubectl apply -k .

# Or individually:
kubectl apply -f xrd.yaml
kubectl apply -f composition.yaml
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
  name: myapp-local
  namespace: default
spec:
  name: myapp      # Application name (becomes subdomain)
  replicas: 1
  environment: local  # Uses localhost domain
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
curl http://myapp.localhost:8080
```

### Deploy Multiple Apps

You can deploy multiple apps with different names:

```yaml
# app1.yaml
apiVersion: demo.openportal.dev/v1alpha1
kind: WhoareApp
metadata:
  name: frontend
spec:
  name: frontend
  environment: production  # Creates frontend.openportal.dev
---
# app2.yaml
apiVersion: demo.openportal.dev/v1alpha1
kind: WhoareApp
metadata:
  name: backend
spec:
  name: api
  environment: production  # Creates api.openportal.dev
```

### Deploy for Production

```yaml
apiVersion: demo.openportal.dev/v1alpha1
kind: WhoareApp
metadata:
  name: demo-prod
  namespace: default
spec:
  name: demo       # Application name (becomes subdomain)
  replicas: 3
  environment: production  # Uses openportal.dev domain
```

Apply:
```bash
kubectl apply -f example/example-production.yaml
```

Access:
```bash
curl https://demo.openportal.dev
```

## How It Works

1. **DNS Zone Loading**: The Composition loads the global dns-config to get the zone (openportal.dev)
2. **Domain Construction**: Based on the `environment` field:
   - `local`: `<name>.localhost`
   - `production`: `<name>.<zone>` (e.g., demo.openportal.dev)
   - `staging`: `<name>-staging.<zone>` (e.g., demo-staging.openportal.dev)
3. **Resource Creation**: Creates namespace, deployment, service, and ingress
4. **Auto-Ready**: Marks the XR as ready when all resources are created

## Domain Configuration

The template uses the system-wide `dns-config` EnvironmentConfig (provides zone: `openportal.dev`) and constructs domains based on the `environment` parameter:

| Environment | Domain Pattern | Example (name=myapp) |
|------------|---------------|----------|
| `local` | `<name>.localhost` | myapp.localhost |
| `production` | `<name>.<zone>` | myapp.openportal.dev |
| `staging` | `<name>-staging.<zone>` | myapp-staging.openportal.dev |

No additional environment configs needed - the template handles domain construction internally!

## API Reference

### WhoareApp Spec

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `name` | string | whoami | Application name (becomes subdomain) |
| `replicas` | integer | 1 | Number of pod replicas (1-3) |
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

- **Dynamic Subdomains**: Deploy any app name without modifying manifests
- **Smart Domain Logic**: Automatic domain construction based on environment
- **System Config Integration**: Uses platform-wide DNS zone configuration
- **No Manual Patching**: Environment settings are declarative
- **Reusable**: Same XRD for multiple deployments with different names
- **Type-Safe**: Schema validation for inputs
- **Self-Documenting**: XRD describes available options
- **GitOps Ready**: Deploy XRs via Flux

## License

This template is open source. The whoami application is maintained by Traefik Labs.