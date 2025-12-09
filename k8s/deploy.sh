#!/bin/bash
#==============================================================================
# Kubernetes Production Stack Deployment Script
# For Rancher Desktop (Linux)
#==============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_DIR="${SCRIPT_DIR}"

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    # Check if cluster is accessible
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster. Is Rancher Desktop running?"
        exit 1
    fi
    
    log_success "All prerequisites met"
}

# Wait for pods to be ready
wait_for_pods() {
    local namespace=$1
    local selector=$2
    local timeout=${3:-300}
    
    log_info "Waiting for pods with selector '$selector' in namespace '$namespace'..."
    
    if ! kubectl wait --for=condition=ready pod -l "$selector" -n "$namespace" --timeout="${timeout}s" 2>/dev/null; then
        log_warn "Some pods may not be ready yet, continuing..."
    fi
}

# Deploy namespaces
deploy_namespaces() {
    log_info "Creating namespaces..."
    kubectl apply -f "${K8S_DIR}/namespace.yaml"
    log_success "Namespaces created"
}

# Deploy monitoring stack
deploy_monitoring() {
    log_info "Deploying monitoring stack..."
    
    # Prometheus
    log_info "Deploying Prometheus..."
    kubectl apply -f "${K8S_DIR}/monitoring/prometheus-config.yaml"
    kubectl apply -f "${K8S_DIR}/monitoring/prometheus.yaml"
    
    # Alertmanager
    log_info "Deploying Alertmanager..."
    kubectl apply -f "${K8S_DIR}/monitoring/alertmanager.yaml"
    
    # Loki and Promtail
    log_info "Deploying Loki and Promtail..."
    kubectl apply -f "${K8S_DIR}/monitoring/loki-promtail.yaml"
    
    # Grafana
    log_info "Deploying Grafana..."
    kubectl apply -f "${K8S_DIR}/monitoring/grafana.yaml"
    
    log_success "Monitoring stack deployed"
}

# Deploy database tier
deploy_database() {
    log_info "Deploying database tier..."
    
    # PostgreSQL
    log_info "Deploying PostgreSQL..."
    kubectl apply -f "${K8S_DIR}/app/database/postgres.yaml"
    
    # Redis
    log_info "Deploying Redis..."
    kubectl apply -f "${K8S_DIR}/app/database/redis.yaml"
    
    # Wait for databases to be ready
    log_info "Waiting for databases to be ready..."
    sleep 10
    wait_for_pods "production" "app=postgres" 180
    wait_for_pods "production" "app=redis" 120
    
    log_success "Database tier deployed"
}

# Deploy backend tier
deploy_backend() {
    log_info "Deploying backend tier..."
    kubectl apply -f "${K8S_DIR}/app/backend/backend.yaml"
    
    # Wait for backend to be ready
    log_info "Waiting for backend to be ready..."
    sleep 5
    wait_for_pods "production" "app=backend" 180
    
    log_success "Backend tier deployed"
}

# Deploy frontend tier
deploy_frontend() {
    log_info "Deploying frontend tier..."
    kubectl apply -f "${K8S_DIR}/app/frontend/frontend.yaml"
    
    # Wait for frontend to be ready
    log_info "Waiting for frontend to be ready..."
    sleep 5
    wait_for_pods "production" "app=frontend" 120
    
    log_success "Frontend tier deployed"
}

# Deploy network policies
deploy_network_policies() {
    log_info "Deploying network policies..."
    kubectl apply -f "${K8S_DIR}/network-policies.yaml"
    log_success "Network policies deployed"
}

# Deploy ingress
deploy_ingress() {
    log_info "Deploying ingress resources..."
    kubectl apply -f "${K8S_DIR}/ingress.yaml"
    log_success "Ingress resources deployed"
}

# Show status
show_status() {
    echo ""
    echo "=============================================="
    echo "         DEPLOYMENT STATUS                    "
    echo "=============================================="
    echo ""
    
    log_info "Pods in production namespace:"
    kubectl get pods -n production -o wide
    echo ""
    
    log_info "Pods in monitoring namespace:"
    kubectl get pods -n monitoring -o wide
    echo ""
    
    log_info "Services in production namespace:"
    kubectl get svc -n production
    echo ""
    
    log_info "Services in monitoring namespace:"
    kubectl get svc -n monitoring
    echo ""
}

# Show access information
show_access_info() {
    echo ""
    echo "=============================================="
    echo "         ACCESS INFORMATION                   "
    echo "=============================================="
    echo ""
    
    # Get node IP (for Rancher Desktop, it's usually localhost)
    NODE_IP="localhost"
    
    echo -e "${GREEN}Application:${NC}"
    echo "  Frontend:     http://${NODE_IP}:30080"
    echo ""
    echo -e "${GREEN}Monitoring:${NC}"
    echo "  Grafana:      http://${NODE_IP}:30030"
    echo "    Username:   admin"
    echo "    Password:   GrafanaAdmin123!"
    echo ""
    echo "  Prometheus:   http://${NODE_IP}:30090"
    echo "  Alertmanager: http://${NODE_IP}:30093"
    echo ""
    echo -e "${YELLOW}Note:${NC} If using ingress with hostnames, add these to /etc/hosts:"
    echo "  127.0.0.1 app.local grafana.local prometheus.local alertmanager.local"
    echo ""
}

# Main deployment
main() {
    echo ""
    echo "=============================================="
    echo "  Kubernetes Production Stack Deployment     "
    echo "  For Rancher Desktop                        "
    echo "=============================================="
    echo ""
    
    check_prerequisites
    deploy_namespaces
    deploy_monitoring
    deploy_database
    deploy_backend
    deploy_frontend
    deploy_network_policies
    deploy_ingress
    
    echo ""
    log_success "Deployment completed successfully!"
    
    show_status
    show_access_info
}

# Cleanup function
cleanup() {
    log_info "Cleaning up resources..."
    kubectl delete namespace production --ignore-not-found
    kubectl delete namespace monitoring --ignore-not-found
    log_success "Cleanup completed"
}

# Parse arguments
case "${1:-deploy}" in
    deploy)
        main
        ;;
    cleanup)
        cleanup
        ;;
    status)
        show_status
        show_access_info
        ;;
    *)
        echo "Usage: $0 {deploy|cleanup|status}"
        exit 1
        ;;
esac
