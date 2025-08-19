# WhoareApp Crossplane Template

A Crossplane Composite Resource (XR) template for deploying the Traefik whoami demo application with automatic environment detection.

## Overview

This template demonstrates:
- **Dynamic subdomain creation** - deploy any app name as subdomain
- **Automatic domain detection** - uses cluster's dns-config zone or defaults to localhost
- **Zero configuration** - no environment parameter needed
- **Go-templating** for flexible resource generation  
- **GitOps compatibility** - XRs can be deployed via Flux

## Structure

```
.
├── xrd.yaml                    # WhoareApp XR Definition
├── composition.yaml            # Implementation using go-templating
├── kustomization.yaml         # For installing via Flux
└── example/
    ├── myapp.yaml             # Simple deployment example
    └── demo-scaled.yaml       # Example with 3 replicas
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

### Deploy an Application

```yaml
apiVersion: demo.openportal.dev/v1alpha1
kind: WhoareApp
metadata:
  name: myapp
  namespace: default
spec:
  name: myapp      # Application name (becomes subdomain)
  replicas: 1
```

Apply:
```bash
kubectl apply -f example/myapp.yaml
```

The domain is automatically determined:
- **With dns-config**: `myapp.<zone>` (e.g., myapp.openportal.dev)
- **Without dns-config**: `myapp.localhost`

Access:
```bash
# For local development (myapp.localhost)
kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8080:80
curl http://myapp.localhost:8080

# For production (myapp.openportal.dev)
curl https://myapp.openportal.dev
```

### Deploy Multiple Apps

You can deploy multiple apps with different names:

```yaml
# frontend.yaml
apiVersion: demo.openportal.dev/v1alpha1
kind: WhoareApp
metadata:
  name: frontend
spec:
  name: frontend  # Creates frontend.<zone> or frontend.localhost
---
# api.yaml
apiVersion: demo.openportal.dev/v1alpha1
kind: WhoareApp
metadata:
  name: backend
spec:
  name: api      # Creates api.<zone> or api.localhost
```

### Deploy with Scaling

```yaml
apiVersion: demo.openportal.dev/v1alpha1
kind: WhoareApp
metadata:
  name: demo
  namespace: default
spec:
  name: demo       # Application name (becomes subdomain)
  replicas: 3      # Scale to 3 replicas
```

Apply:
```bash
kubectl apply -f example/demo-scaled.yaml
```

## How It Works

1. **DNS Config Check**: The Composition checks for the global dns-config
2. **Automatic Domain Selection**:
   - If `dns-config` exists with zone: `<name>.<zone>` (e.g., demo.openportal.dev)
   - Otherwise: `<name>.localhost` for local development
3. **Resource Creation**: Creates namespace, deployment, service, and ingress
4. **Auto-Ready**: Marks the XR as ready when all resources are created

## Domain Configuration

The template automatically determines the domain:

| Condition | Domain Pattern | Example (name=myapp) |
|-----------|---------------|----------|
| dns-config exists with zone | `<name>.<zone>` | myapp.openportal.dev |
| No dns-config | `<name>.localhost` | myapp.localhost |

**Zero configuration required!** Deploy the same XR to any cluster and it automatically uses the right domain.

## API Reference

### WhoareApp Spec

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `name` | string | whoami | Application name (becomes subdomain) |
| `replicas` | integer | 1 | Number of pod replicas (1-3) |
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

- **Zero Configuration**: No environment parameter needed - just works everywhere
- **Dynamic Subdomains**: Deploy any app name without modifying manifests
- **Automatic Domain Detection**: Uses cluster's dns-config or defaults to localhost
- **True Portability**: Same XR works in local, staging, and production
- **No Manual Patching**: Everything is automatic
- **Reusable**: Same XRD for multiple deployments with different names
- **Type-Safe**: Schema validation for inputs
- **Self-Documenting**: XRD describes available options
- **GitOps Ready**: Deploy XRs via Flux

## License

This template is open source. The whoami application is maintained by Traefik Labs.