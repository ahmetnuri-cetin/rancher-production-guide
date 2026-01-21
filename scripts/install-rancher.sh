#!/bin/bash
#
# Rancher Production Installation Script
# Author: Infrastructure & DevOps Specialist
# Date: January 2025
# Description: Automated Rancher deployment on RKE2
#
# Usage: sudo bash install-rancher.sh
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
RANCHER_HOSTNAME="${RANCHER_HOSTNAME:-rancher.gwdc.local}"
RANCHER_VERSION="${RANCHER_VERSION:-2.9.3}"
BOOTSTRAP_PASSWORD="${BOOTSTRAP_PASSWORD:-RancherAdmin2025!}"
RKE2_VERSION="v1.28.15+rke2r1"
CERT_MANAGER_VERSION="v1.13.0"
KUBECTL_VERSION="v1.28.15"

# Certificate details
CERT_COUNTRY="TR"
CERT_STATE="Istanbul"
CERT_CITY="Istanbul"
CERT_ORG="Gateway Management"
CERT_OU="IT"
CERT_EMAIL="admin@gwdc.local"

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

print_header() {
    echo "========================================"
    echo "  Rancher Production Installation"
    echo "========================================"
    echo "Hostname: $RANCHER_HOSTNAME"
    echo "RKE2: $RKE2_VERSION"
    echo "Rancher: $RANCHER_VERSION"
    echo "========================================"
    echo ""
}

check_os() {
    if ! command -v lsb_release &> /dev/null; then
        log_error "lsb_release not found. Is this Ubuntu?"
        exit 1
    fi
    
    OS_VERSION=$(lsb_release -rs)
    log_success "Detected Ubuntu $OS_VERSION"
}

check_requirements() {
    log_info "Checking system requirements..."
    
    # CPU
    CPU_CORES=$(nproc)
    if [[ $CPU_CORES -lt 4 ]]; then
        log_warning "Less than 4 CPU cores detected: $CPU_CORES"
    else
        log_success "CPU cores: $CPU_CORES"
    fi
    
    # RAM
    TOTAL_RAM=$(free -g | awk '/^Mem:/{print $2}')
    if [[ $TOTAL_RAM -lt 8 ]]; then
        log_warning "Less than 8GB RAM detected: ${TOTAL_RAM}GB"
    else
        log_success "RAM: ${TOTAL_RAM}GB"
    fi
    
    # /data directory
    if [[ ! -d /data ]]; then
        log_error "/data directory not found. Please mount your data disk first."
        exit 1
    fi
    log_success "Data directory exists: /data"
}

install_packages() {
    log_info "Installing required packages..."
    apt-get update -qq
    apt-get install -y curl wget net-tools openssl > /dev/null 2>&1
    log_success "Packages installed"
}

setup_directories() {
    log_info "Creating directories..."
    mkdir -p /data/rancher/{rke2,rancher-data}
    mkdir -p /etc/rancher/{rke2,ssl}
    log_success "Directories created"
}

configure_rke2() {
    log_info "Configuring RKE2..."
    
    SERVER_IP=$(hostname -I | awk '{print $1}')
    HOSTNAME=$(hostname)
    
    cat > /etc/rancher/rke2/config.yaml <<EOF
data-dir: /data/rancher/rke2
write-kubeconfig-mode: "0644"
tls-san:
  - ${RANCHER_HOSTNAME}
  - ${HOSTNAME}
  - ${SERVER_IP}
node-name: ${HOSTNAME}
EOF
    
    log_success "RKE2 configured"
}

install_rke2() {
    log_info "Downloading RKE2..."
    
    wget -q https://github.com/rancher/rke2/releases/download/${RKE2_VERSION}/rke2.linux-amd64.tar.gz \
        -O /tmp/rke2.tar.gz
    
    log_info "Installing RKE2..."
    tar -xzf /tmp/rke2.tar.gz -C /usr/local
    
    log_info "Creating systemd service..."
    cat > /etc/systemd/system/rke2-server.service <<'EOF'
[Unit]
Description=Rancher Kubernetes Engine v2 (server)
Documentation=https://github.com/rancher/rke2#readme
Wants=network-online.target
After=network-online.target
Conflicts=rke2-agent.service

[Service]
Type=notify
EnvironmentFile=-/etc/default/rke2-server
EnvironmentFile=-/etc/sysconfig/rke2-server
KillMode=process
Delegate=yes
LimitNOFILE=1048576
LimitNPROC=infinity
LimitCORE=infinity
TasksMax=infinity
TimeoutStartSec=0
Restart=always
RestartSec=5s
ExecStartPre=/bin/sh -xc '! /usr/bin/systemctl is-enabled --quiet nm-cloud-setup.service'
ExecStart=/usr/local/bin/rke2 server

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable rke2-server.service
    systemctl start rke2-server.service
    
    log_info "Waiting for RKE2 to start..."
    sleep 30
    
    if systemctl is-active --quiet rke2-server; then
        log_success "RKE2 is running"
    else
        log_error "RKE2 failed to start"
        systemctl status rke2-server
        exit 1
    fi
}

install_kubectl() {
    log_info "Installing kubectl..."
    
    curl -sLO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
    chmod +x kubectl
    mv kubectl /usr/local/bin/
    
    log_success "kubectl installed"
}

setup_kubeconfig() {
    log_info "Setting up kubeconfig..."
    
    mkdir -p /root/.kube
    cp /etc/rancher/rke2/rke2.yaml /root/.kube/config
    
    echo 'export PATH=$PATH:/var/lib/rancher/rke2/bin' >> /root/.bashrc
    echo 'export KUBECONFIG=/root/.kube/config' >> /root/.bashrc
    
    export PATH=$PATH:/var/lib/rancher/rke2/bin
    export KUBECONFIG=/root/.kube/config
    
    # Wait for Kubernetes API
    log_info "Waiting for Kubernetes API..."
    TIMEOUT=300
    ELAPSED=0
    while ! kubectl get nodes > /dev/null 2>&1 && [[ $ELAPSED -lt $TIMEOUT ]]; do
        sleep 5
        ELAPSED=$((ELAPSED + 5))
    done
    
    if kubectl get nodes > /dev/null 2>&1; then
        log_success "Kubernetes API is ready"
    else
        log_error "Kubernetes API not responding"
        exit 1
    fi
}

install_helm() {
    log_info "Installing Helm..."
    
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash > /dev/null 2>&1
    
    helm repo add rancher-stable https://releases.rancher.com/server-charts/stable
    helm repo update
    
    log_success "Helm installed"
}

create_ssl_certificate() {
    log_info "Creating SSL certificate..."
    
    cd /etc/rancher/ssl
    
    # Private key
    openssl genrsa -out tls.key 2048 2>/dev/null
    
    # CSR
    openssl req -new -key tls.key -out tls.csr \
        -subj "/C=${CERT_COUNTRY}/ST=${CERT_STATE}/L=${CERT_CITY}/O=${CERT_ORG}/OU=${CERT_OU}/CN=${RANCHER_HOSTNAME}/emailAddress=${CERT_EMAIL}" \
        2>/dev/null
    
    # Self-signed certificate
    openssl x509 -req -days 365 -in tls.csr -signkey tls.key -out tls.crt 2>/dev/null
    
    # CA certificate
    cp tls.crt cacerts.pem
    
    # Permissions
    chmod 600 tls.key
    chmod 644 tls.crt cacerts.pem
    
    log_success "SSL certificate created"
}

create_k8s_secrets() {
    log_info "Creating Kubernetes secrets..."
    
    kubectl create namespace cattle-system
    
    kubectl -n cattle-system create secret tls tls-rancher-ingress \
        --cert=/etc/rancher/ssl/tls.crt \
        --key=/etc/rancher/ssl/tls.key
    
    kubectl -n cattle-system create secret generic tls-ca \
        --from-file=cacerts.pem=/etc/rancher/ssl/cacerts.pem
    
    log_success "Secrets created"
}

install_cert_manager() {
    log_info "Installing cert-manager..."
    
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/${CERT_MANAGER_VERSION}/cert-manager.yaml
    
    log_info "Waiting for cert-manager..."
    sleep 60
    
    kubectl wait --for=condition=available --timeout=300s \
        deployment/cert-manager -n cert-manager > /dev/null 2>&1
    
    log_success "cert-manager installed"
}

install_rancher() {
    log_info "Installing Rancher..."
    
    helm install rancher rancher-stable/rancher \
        --namespace cattle-system \
        --set hostname=${RANCHER_HOSTNAME} \
        --set replicas=1 \
        --set ingress.tls.source=secret \
        --set privateCA=true \
        --set bootstrapPassword="${BOOTSTRAP_PASSWORD}" \
        --version ${RANCHER_VERSION}
    
    log_info "Waiting for Rancher..."
    kubectl -n cattle-system rollout status deploy/rancher --timeout=600s
    
    log_success "Rancher installed"
}

print_summary() {
    echo ""
    echo "========================================"
    echo "  Installation Complete!"
    echo "========================================"
    echo ""
    echo "Access Information:"
    echo "  URL: https://${RANCHER_HOSTNAME}"
    echo "  Bootstrap Password: ${BOOTSTRAP_PASSWORD}"
    echo ""
    echo "Add to hosts file (on client machine):"
    echo "  $(hostname -I | awk '{print $1}')  ${RANCHER_HOSTNAME}"
    echo ""
    echo "Useful Commands:"
    echo "  kubectl get pods -A"
    echo "  kubectl -n cattle-system get all"
    echo "  kubectl get secret --namespace cattle-system bootstrap-secret -o go-template='{{.data.bootstrapPassword|base64decode}}'"
    echo ""
    echo "Documentation:"
    echo "  https://docs.ranchermanager.rancher.io/"
    echo ""
    echo "========================================"
}

# Main execution
main() {
    print_header
    check_root
    check_os
    check_requirements
    install_packages
    setup_directories
    configure_rke2
    install_rke2
    install_kubectl
    setup_kubeconfig
    install_helm
    create_ssl_certificate
    create_k8s_secrets
    install_cert_manager
    install_rancher
    print_summary
}

# Run main function
main

exit 0
