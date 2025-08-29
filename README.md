# WhoAmIApp Crossplane Template

A Crossplane Composite Resource (XR) template for deploying the Traefik whoami demo application with automatic environment detection.

## Overview

This template demonstrates:
- **Dual deployment modes** - Direct Kubernetes or GitOps via GitHub
- **Dynamic subdomain creation** - deploy any app name as subdomain
- **Automatic domain detection** - uses cluster's dns-config zone or defaults to localhost
- **Zero configuration** - no environment parameter needed
- **Go-templating** for flexible resource generation  
- **GitOps compatibility** - XRs can be deployed via Flux
- **Namespaced XRs** - Following Crossplane v2 best practices for multi-tenancy

## Structure

```
.
├── xrd.yaml                    # WhoAmIApp XR Definition
├── composition-direct.yaml     # Direct deployment to Kubernetes
├── composition-gitops.yaml     # GitOps deployment via GitHub repo
├── kustomization.yaml         # For installing via Flux
└── example/
    ├── myapp.yaml             # Simple deployment example
    ├── demo-direct.yaml       # Direct mode example
    └── demo-gitops.yaml       # GitOps mode example
```

## Installation

### Prerequisites
- Kubernetes cluster with Crossplane v2.0+
- provider-kubernetes installed
- NGINX Ingress Controller
- System-wide dns-config EnvironmentConfig (installed by setup-cluster.sh)

### Important: Namespaced XR Architecture

This template uses **namespaced XRs** (Crossplane v2 pattern), which means:
- XRs are created in a specific namespace (not cluster-wide)
- All resources are deployed in the **same namespace as the XR**
- No new namespace is created - the XR's namespace is used
- Object resources include `namespaceSelector.matchControllerRef: true` to be namespace-scoped

**Why this matters:**
- Crossplane v2 enforces that namespaced XRs cannot create cluster-scoped resources
- Without `namespaceSelector`, Object resources are cluster-scoped and will fail
- This follows the security principle that namespace boundaries should be respected

For more details, see [Crossplane PR #6588](https://github.com/crossplane/crossplane/pull/6588).

### Install the Template

```bash
# Apply XRD and both Compositions
kubectl apply -k .

# Or individually:
kubectl apply -f xrd.yaml
kubectl apply -f composition-direct.yaml
kubectl apply -f composition-gitops.yaml
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

## Deployment Modes

This template provides two deployment modes:

### 1. Direct Mode (Default)
Creates Kubernetes resources directly using provider-kubernetes. Resources are immediately deployed to the cluster. This is the default mode when no composition selector is specified.

### 2. GitOps Mode  
Creates a GitHub repository with deployment manifests and configures Flux to deploy from it. This enables GitOps workflows with version control and PR-based changes. Requires explicit composition selector.

## Usage

### Creating XRs in Namespaces

Since this is a namespaced XR, you **must specify a namespace** when creating instances:

```bash
# Create in a specific namespace
kubectl apply -f myapp.yaml -n my-team

# Or include namespace in the YAML
apiVersion: openportal.dev/v1alpha1
kind: WhoAmIApp
metadata:
  name: my-app
  namespace: my-team  # Required!
spec:
  name: my-app
```

**Important:** All resources (Deployment, Service, Ingress) will be created in the **same namespace** as the XR.

### Deploy an Application (Direct Mode - Default)

```yaml
apiVersion: demo.openportal.dev/v1alpha1
kind: WhoAmIApp
metadata:
  name: myapp
  namespace: default
  # No composition selector needed - defaults to direct mode
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

### Deploy an Application (GitOps Mode)

```yaml
apiVersion: demo.openportal.dev/v1alpha1
kind: WhoAmIApp
metadata:
  name: myapp-gitops
  namespace: default
  labels:
    # Select GitOps deployment mode
    crossplane.io/composition-selector: mode=gitops
spec:
  name: myapp      # Application name (becomes subdomain)
  replicas: 1
```

This will:
1. Create a ConfigMap with deployment manifests
2. Set up Flux GitRepository source pointing to `https://github.com/open-service-portal/deploy-myapp`
3. Configure Flux Kustomization to deploy from the repository

**Note**: You'll need to manually create the GitHub repository and push the generated manifests from the ConfigMap.

### Deploy Multiple Apps

You can deploy multiple apps with different names and modes:

```yaml
# frontend.yaml - Direct deployment (default)
apiVersion: demo.openportal.dev/v1alpha1
kind: WhoAmIApp
metadata:
  name: frontend
  # No selector needed - defaults to direct mode
spec:
  name: frontend  # Creates frontend.<zone> or frontend.localhost
---
# api.yaml - GitOps deployment
apiVersion: demo.openportal.dev/v1alpha1
kind: WhoAmIApp
metadata:
  name: backend
  labels:
    crossplane.io/composition-selector: mode=gitops
spec:
  name: api      # Creates api.<zone> or api.localhost
```

### Deploy with Scaling

```yaml
apiVersion: demo.openportal.dev/v1alpha1
kind: WhoAmIApp
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

### Direct Mode
1. **DNS Config Check**: The Composition checks for the global dns-config
2. **Automatic Domain Selection**:
   - If `dns-config` exists with zone: `<name>.<zone>` (e.g., demo.openportal.dev)
   - Otherwise: `<name>.localhost` for local development
3. **Resource Creation**: Creates namespace, deployment, service, and ingress directly
4. **Auto-Ready**: Marks the XR as ready when all resources are created

### GitOps Mode
1. **DNS Config Check**: Same as Direct mode
2. **Automatic Domain Selection**: Same as Direct mode
3. **Manifest Generation**: Creates deployment manifests in a ConfigMap
4. **GitOps Setup**: Configures Flux GitRepository and Kustomization
5. **Repository Creation**: Provides instructions for creating GitHub repository
6. **Auto-Ready**: Marks the XR as ready when GitOps resources are configured

## Domain Configuration

The template automatically determines the domain:

| Condition | Domain Pattern | Example (name=myapp) |
|-----------|---------------|----------|
| dns-config exists with zone | `<name>.<zone>` | myapp.openportal.dev |
| No dns-config | `<name>.localhost` | myapp.localhost |

**Zero configuration required!** Deploy the same XR to any cluster and it automatically uses the right domain.

## API Reference

### WhoAmIApp Spec

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `name` | string | whoami | Application name (becomes subdomain) |
| `replicas` | integer | 1 | Number of pod replicas (1-3) |
| `image` | string | traefik/whoami:v1.10.1 | Container image to deploy |

## Restaurant Analogy

- **Menu (XRD)**: WhoAmIApp - what developers can order
- **Recipe (Composition)**: How to prepare the whoami deployment
- **Ingredients (EnvironmentConfig)**: Environment-specific settings like domains
- **Kitchen (provider-kubernetes)**: Creates the actual Kubernetes resources
- **Order (XR)**: `kubectl apply -f example/example-local.yaml`

## Troubleshooting

### Check XR Status
```bash
kubectl get whoamiapp
kubectl describe whoamiapp whoami-dev
```

### Check Generated Resources
```bash
# Resources are created in a namespace matching the XR name
kubectl get all -n whoami-dev
```

### View Composition Pipeline
```bash
# View direct composition
kubectl get composition whoamiapp-direct -o yaml

# View GitOps composition
kubectl get composition whoamiapp-gitops -o yaml
```

## Benefits Over Plain Kubernetes

- **Dual Deployment Modes**: Choose between direct deployment or GitOps workflows
- **Zero Configuration**: No environment parameter needed - just works everywhere
- **Dynamic Subdomains**: Deploy any app name without modifying manifests
- **Automatic Domain Detection**: Uses cluster's dns-config or defaults to localhost
- **True Portability**: Same XR works in local, staging, and production
- **No Manual Patching**: Everything is automatic
- **Reusable**: Same XRD for multiple deployments with different names
- **Type-Safe**: Schema validation for inputs
- **Self-Documenting**: XRD describes available options
- **GitOps Ready**: Deploy XRs via Flux or create GitOps repositories

## License

This template is open source. The whoami application is maintained by Traefik Labs.