#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
REPO_URL="https://github.com/open-service-portal/deploy-whoami"
BRANCH="main"
NAMESPACE="flux-system"


# Function to deploy
deploy() {
    echo -e "${YELLOW}Deploying whoami...${NC}"
    
    # Step 1: Create or update GitRepository
    echo -e "${GREEN}Step 1: Creating GitRepository source...${NC}"
    flux create source git deploy-whoami \
        --url="$REPO_URL" \
        --branch="$BRANCH" \
        --interval=1m \
        --export | kubectl apply -f -
    
    # Wait for source to be ready
    echo "Waiting for source to be ready..."
    kubectl wait --for=condition=ready --timeout=60s \
        gitrepository/deploy-whoami -n "$NAMESPACE" || true
    
    # Step 2: Create Kustomization (single deployment for all environments)
    echo -e "${GREEN}Step 2: Creating Kustomization...${NC}"
    
    flux create kustomization whoami \
        --source=GitRepository/deploy-whoami \
        --path="./" \
        --prune=true \
        --interval=1m \
        --export | kubectl apply -f -
    
    echo -e "${GREEN}✓ Deployed whoami${NC}"
    
    # Wait for environment detection job to complete
    echo "Waiting for environment detection..."
    kubectl wait --for=condition=complete --timeout=60s job/detect-environment -n whoami-demo 2>/dev/null || true
    
    # Get the configured domain from ConfigMap
    DOMAIN=$(kubectl get configmap environment-config -n whoami-demo -o jsonpath='{.data.domain}' 2>/dev/null || echo "whoami.localhost")
    INGRESS_IP=$(kubectl get configmap environment-config -n whoami-demo -o jsonpath='{.data.ingress-ip}' 2>/dev/null || echo "127.0.0.1")
    
    echo -e "${GREEN}Environment detected:${NC}"
    echo -e "  Domain: ${YELLOW}$DOMAIN${NC}"
    
    if [[ "$DOMAIN" == "whoami.openportal.dev" ]]; then
        echo -e "  Access at: ${YELLOW}https://$DOMAIN${NC}"
    elif [[ "$DOMAIN" == "whoami.localhost" ]]; then
        echo -e "  Access at: ${YELLOW}http://$DOMAIN:8080${NC}"
        echo -e "  Note: Run port-forward first: ${YELLOW}kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8080:80${NC}"
    else
        echo -e "  Access at: ${YELLOW}http://$DOMAIN${NC}"
    fi
    
    echo ""
    echo "Deployment status:"
    kubectl get pods -n whoami-demo
}

# Function to remove deployment
remove() {
    echo -e "${YELLOW}Removing whoami deployment...${NC}"
    
    # Delete the kustomization
    flux delete kustomization whoami --silent
    
    # Delete the source
    flux delete source git deploy-whoami --silent
    
    echo -e "${GREEN}✓ Removed whoami deployment${NC}"
}

# Function to check status
status() {
    echo -e "${YELLOW}=== Flux Sources ===${NC}"
    flux get sources git | grep -E "(NAME|deploy-whoami)" || echo "No deploy-whoami source found"
    
    echo ""
    echo -e "${YELLOW}=== Flux Kustomizations ===${NC}"
    flux get kustomizations | grep -E "(NAME|whoami)" || echo "No whoami kustomizations found"
    
    echo ""
    echo -e "${YELLOW}=== Whoami Pods ===${NC}"
    kubectl get pods -n whoami-demo 2>/dev/null || echo "No pods found in whoami-demo namespace"
    
    echo ""
    echo -e "${YELLOW}=== Ingress ===${NC}"
    kubectl get ingress -n whoami-demo 2>/dev/null || echo "No ingress found"
}


case "$1" in
    deploy)
        deploy
        ;;
    
    remove)
        remove
        ;;
    
    status)
        status
        ;;
    
    *)
        echo "Usage: $0 {deploy|remove|status}"
        echo ""
        echo "Commands:"
        echo "  deploy  - Deploy whoami (auto-detects environment)"
        echo "  remove  - Remove whoami deployment"
        echo "  status  - Check deployment status"
        echo ""
        echo "Examples:"
        echo "  $0 deploy   # Deploy with automatic environment detection"
        echo "  $0 remove   # Remove deployment"
        echo "  $0 status   # Check status"
        exit 1
        ;;
esac