# Rancher Kurulum Komutları - Hızlı Referans

## Sistem Bilgileri

```bash
cat /etc/os-release
hostname
hostname -I
free -h
df -h
lsblk
```

---

## Sistem Hazırlığı

```bash
# Paket güncellemesi
sudo apt update && sudo apt upgrade -y

# Gerekli paketler
sudo apt install -y curl wget net-tools openssl

# Dizinler
sudo mkdir -p /data/rancher/rke2
sudo mkdir -p /data/rancher/rancher-data
sudo mkdir -p /etc/rancher/rke2
sudo mkdir -p /etc/rancher/ssl
```

---

## RKE2 Config

```bash
# Config dosyası
sudo tee /etc/rancher/rke2/config.yaml > /dev/null <<EOF
data-dir: /data/rancher/rke2
write-kubeconfig-mode: "0644"
tls-san:
  - rancher.gwdc.local
  - $(hostname)
  - $(hostname -I | awk '{print $1}')
node-name: $(hostname)
EOF
```

---

## RKE2 Kurulumu

```bash
# GitHub'dan indir
wget https://github.com/rancher/rke2/releases/download/v1.28.15%2Brke2r1/rke2.linux-amd64.tar.gz -O /tmp/rke2.tar.gz

# Çıkar
sudo tar -xzf /tmp/rke2.tar.gz -C /usr/local

# Systemd service
sudo tee /etc/systemd/system/rke2-server.service > /dev/null <<'EOF'
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

# Başlat
sudo systemctl daemon-reload
sudo systemctl enable rke2-server.service
sudo systemctl start rke2-server.service
sudo systemctl status rke2-server.service
```

---

## kubectl Kurulumu

```bash
# kubectl indir
curl -LO "https://dl.k8s.io/release/v1.28.15/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Kubeconfig
mkdir -p ~/.kube
sudo cp /etc/rancher/rke2/rke2.yaml ~/.kube/config
sudo chown $USER:$USER ~/.kube/config

# PATH ve KUBECONFIG
echo 'export PATH=$PATH:/var/lib/rancher/rke2/bin' >> ~/.bashrc
echo 'export KUBECONFIG=~/.kube/config' >> ~/.bashrc
source ~/.bashrc

# Test
kubectl get nodes
kubectl get pods -A
```

---

## Helm Kurulumu

```bash
# Helm indir ve kur
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Test
helm version

# Rancher repo ekle
helm repo add rancher-stable https://releases.rancher.com/server-charts/stable
helm repo update
helm repo list
```

---

## SSL Certificate

```bash
# Private key
cd /etc/rancher/ssl
sudo openssl genrsa -out tls.key 2048

# CSR
sudo openssl req -new -key tls.key -out tls.csr \
  -subj "/C=TR/ST=Istanbul/L=Istanbul/O=Gateway Management/OU=IT/CN=rancher.gwdc.local/emailAddress=admin@gwdc.local"

# Self-signed certificate
sudo openssl x509 -req -days 365 -in tls.csr -signkey tls.key -out tls.crt

# CA cert
sudo cp tls.crt cacerts.pem

# İzinler
sudo chmod 600 tls.key
sudo chmod 644 tls.crt cacerts.pem

# Kontrol
ls -lh /etc/rancher/ssl/
sudo openssl x509 -in tls.crt -text -noout | grep -A 2 "Subject:"
```

---

## Kubernetes Secrets

```bash
# Namespace
kubectl create namespace cattle-system

# TLS secret
kubectl -n cattle-system create secret tls tls-rancher-ingress \
  --cert=/etc/rancher/ssl/tls.crt \
  --key=/etc/rancher/ssl/tls.key

# CA secret
kubectl -n cattle-system create secret generic tls-ca \
  --from-file=cacerts.pem=/etc/rancher/ssl/cacerts.pem

# Kontrol
kubectl -n cattle-system get secrets | grep tls
```

---

## cert-manager

```bash
# Kur
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Bekle
sleep 60

# Kontrol
kubectl get pods -n cert-manager
```

---

## Rancher Kurulumu

```bash
# Rancher deploy
helm install rancher rancher-stable/rancher \
  --namespace cattle-system \
  --set hostname=rancher.gwdc.local \
  --set replicas=1 \
  --set ingress.tls.source=secret \
  --set privateCA=true \
  --set bootstrapPassword="RancherAdmin2025!" \
  --version 2.9.3

# Pod'ları izle
kubectl -n cattle-system get pods -w

# Rollout status
kubectl -n cattle-system rollout status deploy/rancher

# Tüm kaynaklar
kubectl -n cattle-system get all
```

---

## Bootstrap Password

```bash
kubectl get secret --namespace cattle-system bootstrap-secret \
  -o go-template='{{.data.bootstrapPassword|base64decode}}'
echo ""
```

---

## Kontroller

```bash
# Tüm pod'lar
kubectl get pods -A

# Ingress
kubectl -n cattle-system get ingress

# Node durumu
kubectl get nodes -o wide

# Disk kullanımı
df -h /data
du -sh /data/rancher/*

# Servis durumu
sudo systemctl status rke2-server
```

---

## Hosts Dosyası (Client)

**Windows:** `C:\Windows\System32\drivers\etc\hosts`  
**Linux/Mac:** `/etc/hosts`

```
10.31.48.180  rancher.gwdc.local
```

---

## Tarayıcı Erişimi

```
URL: https://rancher.gwdc.local
Bootstrap Password: RancherAdmin2025!
```

---

## Troubleshooting

```bash
# RKE2 logs
sudo journalctl -u rke2-server -f

# Rancher logs
kubectl logs -n cattle-system -l app=rancher -f

# Pod describe
kubectl describe pod <pod-name> -n cattle-system

# Events
kubectl get events -A --sort-by='.lastTimestamp'

# Certificate check
kubectl get certificate -A
kubectl describe certificate -n cattle-system

# Ingress details
kubectl describe ingress rancher -n cattle-system
```

---

## Yönetim Komutları

```bash
# Rancher restart
kubectl rollout restart deployment rancher -n cattle-system

# RKE2 restart
sudo systemctl restart rke2-server

# Etcd snapshot
sudo rke2 etcd-snapshot save --name manual-backup

# Resource kullanımı
kubectl top nodes
kubectl top pods -A

# Cluster info
kubectl cluster-info
kubectl version
```

---

## Temizleme (Uninstall)

```bash
# Rancher kaldır
helm uninstall rancher -n cattle-system

# cert-manager kaldır
kubectl delete namespace cert-manager

# cattle-system kaldır
kubectl delete namespace cattle-system

# RKE2 durdur
sudo systemctl stop rke2-server
sudo systemctl disable rke2-server

# RKE2 dosyaları temizle
sudo rm -rf /data/rancher/rke2
sudo rm -rf /etc/rancher/rke2
sudo rm -rf /var/lib/rancher/rke2
```

---

## Upgrade

```bash
# Rancher upgrade
helm repo update
helm upgrade rancher rancher-stable/rancher \
  --namespace cattle-system \
  --version <new-version>

# RKE2 upgrade
wget <new-rke2-version>
sudo systemctl stop rke2-server
sudo tar -xzf rke2-new.tar.gz -C /usr/local
sudo systemctl start rke2-server
```

---

## Backup

```bash
# Etcd snapshot
sudo /usr/local/bin/rke2 etcd-snapshot save \
  --name backup-$(date +%Y%m%d-%H%M%S)

# Snapshot listesi
sudo ls -lh /var/lib/rancher/rke2/server/db/snapshots/

# Rancher backup (Helm values)
helm get values rancher -n cattle-system > rancher-values-backup.yaml

# SSL certificates backup
sudo tar -czf ssl-backup.tar.gz /etc/rancher/ssl/
```

---

## Monitoring

```bash
# Node resources
kubectl top nodes

# Pod resources
kubectl top pods -A --sort-by=memory
kubectl top pods -A --sort-by=cpu

# Disk I/O
iostat -x 1 5

# Network
netstat -tlnp | grep -E '443|6443|9345'

# Processes
ps aux | grep -E 'rke2|rancher'
```

---

## Quick Reference URLs

- Rancher UI: https://rancher.gwdc.local
- Kubernetes API: https://10.31.48.180:6443
- Rancher Docs: https://docs.ranchermanager.rancher.io/
- RKE2 Docs: https://docs.rke2.io/
- cert-manager Docs: https://cert-manager.io/docs/

---

## Environment Variables

```bash
export KUBECONFIG=~/.kube/config
export PATH=$PATH:/var/lib/rancher/rke2/bin
export RANCHER_URL=https://rancher.gwdc.local
export CATTLE_SYSTEM_NS=cattle-system
```

---

## Useful Aliases

```bash
# kubectl shortcuts
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgpa='kubectl get pods -A'
alias kgn='kubectl get nodes'
alias kgs='kubectl get svc'
alias kd='kubectl describe'
alias kl='kubectl logs'

# Rancher specific
alias rancher-logs='kubectl logs -n cattle-system -l app=rancher -f'
alias rancher-pods='kubectl get pods -n cattle-system'
alias rancher-restart='kubectl rollout restart deployment rancher -n cattle-system'

# Add to ~/.bashrc
echo "alias k='kubectl'" >> ~/.bashrc
```

---

## Port Reference

| Port | Protocol | Service | Purpose |
|------|----------|---------|---------|
| 443 | TCP | HTTPS | Rancher UI |
| 80 | TCP | HTTP | Redirect to HTTPS |
| 6443 | TCP | K8s API | Kubernetes API Server |
| 9345 | TCP | RKE2 | Supervisor API |
| 10250 | TCP | Kubelet | Kubelet API |
| 2379-2380 | TCP | etcd | etcd client/peer |

---

## Common Issues & Solutions

### Issue: RKE2 won't start
```bash
# Check logs
sudo journalctl -u rke2-server -n 100

# Check config
cat /etc/rancher/rke2/config.yaml

# Check permissions
ls -la /data/rancher/rke2
```

### Issue: kubectl not found
```bash
# Add to PATH
export PATH=$PATH:/var/lib/rancher/rke2/bin

# Or download kubectl separately
curl -LO "https://dl.k8s.io/release/v1.28.15/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
```

### Issue: Rancher pod not starting
```bash
# Check events
kubectl get events -n cattle-system --sort-by='.lastTimestamp'

# Describe pod
kubectl describe pod -n cattle-system <pod-name>

# Check secrets
kubectl get secrets -n cattle-system
```

### Issue: SSL certificate error
```bash
# Recreate secrets
kubectl delete secret tls-rancher-ingress -n cattle-system
kubectl -n cattle-system create secret tls tls-rancher-ingress \
  --cert=/etc/rancher/ssl/tls.crt \
  --key=/etc/rancher/ssl/tls.key
```

---

## Performance Tuning

```bash
# Increase file descriptors
echo "fs.file-max = 2097152" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# Kernel parameters
cat <<EOF | sudo tee -a /etc/sysctl.conf
net.ipv4.ip_forward=1
net.bridge.bridge-nf-call-iptables=1
vm.swappiness=0
vm.overcommit_memory=1
EOF

sudo sysctl -p
```

---

**Last Updated**: January 21, 2025  
**Version**: 1.0
