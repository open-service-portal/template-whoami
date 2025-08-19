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

# Function to check if flux is installed
check_flux() {
    if ! command -v flux &> /dev/null; then
        echo -e "${RED}Error: flux CLI is not installed${NC}"
        echo "Install it from: https://fluxcd.io/flux/installation/"
        exit 1
    fi
}

# Function to deploy
deploy() {
    local ENV=$1
    
    if [[ "$ENV" != "local" && "$ENV" != "production" ]]; then
        echo -e "${RED}Error: Environment must be 'local' or 'production'${NC}"
        exit 1
    fi
    
    echo -e "${YELLOW}Deploying whoami to $ENV environment...${NC}"
    
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
    
    # Step 2: Create Kustomization for the environment
    echo -e "${GREEN}Step 2: Creating Kustomization for $ENV...${NC}"
    
    if [[ "$ENV" == "local" ]]; then
        flux create kustomization whoami-local \
            --source=GitRepository/deploy-whoami \
            --path="./overlays/local" \
            --prune=true \
            --interval=1m \
            --export | kubectl apply -f -
        
        echo -e "${GREEN}✓ Deployed to local environment${NC}"
        echo -e "Access at: ${YELLOW}http://whoami.127.0.0.1.nip.io:8080${NC}"
        echo -e "Note: Run port-forward first: ${YELLOW}kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8080:80${NC}"
        
    else
        flux create kustomization whoami-prod \
            --source=GitRepository/deploy-whoami \
            --path="./overlays/production" \
            --prune=true \
            --interval=1m \
            --export | kubectl apply -f -
        
        echo -e "${GREEN}✓ Deployed to production environment${NC}"
        echo -e "Access at: ${YELLOW}https://whoami.openportal.dev${NC}"
    fi
    
    echo ""
    echo "Deployment status:"
    kubectl get pods -n whoami-demo
}

# Function to remove deployment
remove() {
    local ENV=$1
    
    if [[ "$ENV" != "local" && "$ENV" != "production" ]]; then
        echo -e "${RED}Error: Environment must be 'local' or 'production'${NC}"
        exit 1
    fi
    
    echo -e "${YELLOW}Removing whoami from $ENV environment...${NC}"
    
    if [[ "$ENV" == "local" ]]; then
        flux delete kustomization whoami-local --silent
    else
        flux delete kustomization whoami-prod --silent
    fi
    
    # Check if any other kustomizations use this source
    KUSTOMIZATIONS=$(flux get kustomizations -A 2>/dev/null | grep -c "deploy-whoami" || echo "0")
    
    if [[ "$KUSTOMIZATIONS" == "0" ]]; then
        echo "No other kustomizations using this source, removing GitRepository..."
        flux delete source git deploy-whoami --silent
    fi
    
    echo -e "${GREEN}✓ Removed whoami from $ENV${NC}"
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

# Main script logic
check_flux

case "$1" in
    deploy)
        if [[ -z "$2" ]]; then
            echo -e "${RED}Error: Please specify environment (local/production)${NC}"
            echo "Usage: $0 deploy {local|production}"
            exit 1
        fi
        deploy "$2"
        ;;
    
    remove)
        if [[ -z "$2" ]]; then
            echo -e "${RED}Error: Please specify environment (local/production)${NC}"
            echo "Usage: $0 remove {local|production}"
            exit 1
        fi
        remove "$2"
        ;;
    
    status)
        status
        ;;
    
    *)
        echo "Usage: $0 {deploy|remove|status} [environment]"
        echo ""
        echo "Commands:"
        echo "  deploy {local|production}  - Deploy whoami to specified environment"
        echo "  remove {local|production}  - Remove whoami from specified environment"
        echo "  status                     - Check deployment status"
        echo ""
        echo "Examples:"
        echo "  $0 deploy local      # Deploy to local environment"
        echo "  $0 deploy production # Deploy to production"
        echo "  $0 remove local      # Remove from local"
        echo "  $0 status           # Check status"
        exit 1
        ;;
esac