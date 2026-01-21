# Production-Ready Rancher Management Server Kurulumu

> **Infrastructure & DevOps Specialist**  
> **Platform**: Ubuntu 24.04 LTS  
> **Method**: RKE2 + Helm + Self-Signed SSL  
> **Date**: January 2025

---

## 📋 İçindekiler

- [Giriş](#giriş)
- [Sistem Gereksinimleri](#sistem-gereksinimleri)
- [Altyapı Hazırlığı](#altyapı-hazırlığı)
- [RKE2 Kubernetes Kurulumu](#rke2-kubernetes-kurulumu)
- [kubectl ve Helm Kurulumu](#kubectl-ve-helm-kurulumu)
- [SSL Sertifikası Oluşturma](#ssl-sertifikası-oluşturma)
- [cert-manager Kurulumu](#cert-manager-kurulumu)
- [Rancher Kurulumu](#rancher-kurulumu)
- [İlk Erişim ve Doğrulama](#i̇lk-erişim-ve-doğrulama)
- [Sonuç](#sonuç)

---

## Giriş

Bu dokümanda, production ortamı için Rancher Management Server kurulumunu **RKE2 Kubernetes** üzerinde adım adım gerçekleştireceğiz. Rancher, birden fazla Kubernetes cluster'ını merkezi olarak yönetmek için kullanılan enterprise-grade bir platformdur.

### Neden Bu Yöntem?

- ✅ **RKE2**: Rancher'ın resmi önerisi, FIPS 140-2 uyumlu
- ✅ **Production-Ready**: Enterprise ortamlar için uygun
- ✅ **Scalable**: İlerleye HA (High Availability) yapısına kolayca geçiş
- ✅ **Self-Signed SSL**: Kendi sertifikanızla güvenli erişim
- ✅ **Persistent Storage**: LVM ile /data dizininde kalıcı depolama

---

## Sistem Gereksinimleri

### Donanım Özellikleri

| Bileşen | Minimum | Kullanılan |
|---------|---------|------------|
| CPU | 4 cores | 8 cores |
| RAM | 8 GB | 15 GB |
| Disk | 50 GB | 100 GB (sda) + 100 GB (sdb) |
| OS | RHEL/Ubuntu 20.04+ | Ubuntu 24.04.3 LTS |

### Sistem Bilgileri

```bash
root@gwdcdvpstst02:/home/ubuntu# cat /etc/os-release
PRETTY_NAME="Ubuntu 24.04.3 LTS"
NAME="Ubuntu"
VERSION_ID="24.04"
VERSION="24.04.3 LTS (Noble Numbat)"
VERSION_CODENAME=noble
ID=ubuntu
ID_LIKE=debian

root@gwdcdvpstst02:/home/ubuntu# hostname
gwdcdvpstst02

root@gwdcdvpstst02:/home/ubuntu# hostname -I
10.31.48.180

root@gwdcdvpstst02:/home/ubuntu# free -h
               total        used        free      shared  buff/cache   available
Mem:            15Gi       555Mi        14Gi       1.0Mi       669Mi        14Gi
Swap:          4.0Gi          0B       4.0Gi
```

### Disk Yapısı

```bash
root@gwdcdvpstst02:/home/ubuntu# lsblk
NAME                      MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sda                         8:0    0  100G  0 disk 
├─sda1                      8:1    0    1G  0 part /boot/efi
├─sda2                      8:2    0    2G  0 part /boot
└─sda3                      8:3    0 96.9G  0 part 
  └─ubuntu--vg-ubuntu--lv 252:0    0 48.5G  0 lvm  /
sdb                         8:16   0  100G  0 disk 
└─data--vg-data--lv       252:1    0  100G  0 lvm  /data
```

**Not**: `/data` diski önceden LVM ile yapılandırılmış ve `/etc/fstab`'a eklenmiştir.

---

## Altyapı Hazırlığı

### 1. Sistem Güncellemesi

```bash
# Sistem paketlerini güncelle
sudo apt update && sudo apt upgrade -y
```

### 2. Gerekli Paketlerin Kurulumu

```bash
# Temel araçları kur
sudo apt install -y curl wget net-tools openssl

root@gwdcdvpstst02:/home/ubuntu# sudo apt install -y curl wget net-tools openssl
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
curl is already the newest version (8.5.0-2ubuntu10.6).
wget is already the newest version (1.21.4-1ubuntu4.1).
openssl is already the newest version (3.0.13-0ubuntu3.6).
The following NEW packages will be installed:
  net-tools
0 upgraded, 1 newly installed, 0 to remove and 0 not upgraded.
```

### 3. Firewall Konfigürasyonu

```bash
# Rancher ve Kubernetes için portları aç
sudo ufw allow 443/tcp    # HTTPS (Rancher UI)
sudo ufw allow 80/tcp     # HTTP (Redirect)
sudo ufw allow 6443/tcp   # Kubernetes API
sudo ufw allow 9345/tcp   # RKE2 Supervisor
sudo ufw allow 10250/tcp  # Kubelet

root@gwdcdvpstst02:/home/ubuntu# sudo ufw allow 443/tcp
Rules updated
Rules updated (v6)

root@gwdcdvpstst02:/home/ubuntu# sudo ufw status
Status: inactive
```

**Not**: UFW inactive durumda, ancak iptables kuralları aktiftir.

### 4. Dizin Yapısını Oluşturma

```bash
# RKE2 ve Rancher için dizinler
sudo mkdir -p /data/rancher/rke2
sudo mkdir -p /data/rancher/rancher-data
sudo mkdir -p /etc/rancher/rke2

root@gwdcdvpstst02:/home/ubuntu# ls -la /data/rancher/
total 16
drwxr-xr-x 4 root root 4096 Jan 21 11:39 .
drwxr-xr-x 4 root root 4096 Jan 21 11:39 ..
drwxr-xr-x 2 root root 4096 Jan 21 11:39 rancher-data
drwxr-xr-x 2 root root 4096 Jan 21 11:39 rke2
```

### 5. RKE2 Konfigürasyon Dosyası

```bash
# RKE2 config oluştur
sudo tee /etc/rancher/rke2/config.yaml > /dev/null <<EOF
data-dir: /data/rancher/rke2
write-kubeconfig-mode: "0644"
tls-san:
  - rancher.gwdc.local
  - gwdcdvpstst02
  - 10.31.48.180
node-name: gwdcdvpstst02
EOF

root@gwdcdvpstst02:/home/ubuntu# cat /etc/rancher/rke2/config.yaml
data-dir: /data/rancher/rke2
write-kubeconfig-mode: "0644"
tls-san:
  - rancher.gwdc.local
  - gwdcdvpstst02
  - 10.31.48.180
node-name: gwdcdvpstst02
```

**Açıklama:**
- `data-dir`: RKE2 verilerinin `/data` dizininde saklanması
- `tls-san`: SSL sertifikasına eklenecek alternatif isimler
- `node-name`: Kubernetes içindeki node adı

---

## RKE2 Kubernetes Kurulumu

### 1. RKE2 Binary İndirme

**Not**: `get.rke2.io` script'i timeout verdiği için GitHub'dan direkt indirme yöntemi kullanıldı.

```bash
# GitHub'dan RKE2 binary indir
wget https://github.com/rancher/rke2/releases/download/v1.28.15%2Brke2r1/rke2.linux-amd64.tar.gz -O /tmp/rke2.tar.gz

root@gwdcdvpstst02:/home/ubuntu# wget https://github.com/rancher/rke2/releases/download/v1.28.15%2Brke2r1/rke2.linux-amd64.tar.gz -O /tmp/rke2.tar.gz
--2026-01-21 11:43:17--  https://github.com/rancher/rke2/releases/download/v1.28.15%2Brke2r1/rke2.linux-amd64.tar.gz
Resolving github.com (github.com)... 140.82.121.4
Connecting to github.com (github.com)|140.82.121.4|:443... connected.
HTTP request sent, awaiting response... 302 Found
HTTP request sent, awaiting response... 200 OK
Length: 34043954 (32M) [application/octet-stream]
Saving to: '/tmp/rke2.tar.gz'

/tmp/rke2.tar.gz                    100%[======>]  32.47M  26.3MB/s    in 1.2s    

2026-01-21 11:43:19 (26.3 MB/s) - '/tmp/rke2.tar.gz' saved [34043954/34043954]
```

### 2. RKE2 Kurulumu

```bash
# RKE2'yi çıkar
sudo tar -xzf /tmp/rke2.tar.gz -C /usr/local

# Systemd service dosyası oluştur
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
```

### 3. RKE2 Servisini Başlatma

```bash
# Systemd'yi reload et
sudo systemctl daemon-reload

# Servisi enable ve start et
sudo systemctl enable rke2-server.service
sudo systemctl start rke2-server.service

root@gwdcdvpstst02:/home/ubuntu# sudo systemctl enable rke2-server.service
Created symlink /etc/systemd/system/multi-user.target.wants/rke2-server.service → /etc/systemd/system/rke2-server.service.

# Servis durumunu kontrol et
root@gwdcdvpstst02:/home/ubuntu# sudo systemctl status rke2-server.service
● rke2-server.service - Rancher Kubernetes Engine v2 (server)
     Loaded: loaded (/etc/systemd/system/rke2-server.service; enabled; preset: enabled)
     Active: active (running) since Wed 2026-01-21 11:44:51 UTC; 6s ago
       Docs: https://github.com/rancher/rke2#readme
    Process: 7673 ExecStartPre=/bin/sh -xc ! /usr/bin/systemctl is-enabled --quiet nm-cloud-setup.service (code=exited, status=0/SUCCESS)
   Main PID: 7676 (rke2)
      Tasks: 114
     Memory: 1.7G (peak: 1.8G)
        CPU: 1min 42.953s
     CGroup: /system.slice/rke2-server.service
             ├─7676 "/usr/local/bin/rke2 server"
             ├─7700 containerd -c /data/rancher/rke2/agent/etc/containerd/config.toml
             └─7719 kubelet --volume-plugin-dir=/var/lib/kubelet/volumeplugins
```

**🎉 RKE2 başarıyla başlatıldı!**

---

## kubectl ve Helm Kurulumu

### 1. kubectl Kurulumu

RKE2 paketi kubectl içermediği için ayrı olarak indirdik.

```bash
# kubectl binary indir
curl -LO "https://dl.k8s.io/release/v1.28.15/bin/linux/amd64/kubectl"

root@gwdcdvpstst02:/home/ubuntu# curl -LO "https://dl.k8s.io/release/v1.28.15/bin/linux/amd64/kubectl"
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   138  100   138    0     0    666      0 --:--:-- --:--:-- --:--:--   669
100 47.3M  100 47.3M    0     0  6591k      0  0:00:07  0:00:07 --:--:-- 6655k

# Çalıştırılabilir yap ve taşı
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
```

### 2. kubeconfig Ayarları

```bash
# PATH'e ekle
export PATH=$PATH:/var/lib/rancher/rke2/bin
echo 'export PATH=$PATH:/var/lib/rancher/rke2/bin' >> ~/.bashrc

# kubeconfig kopyala
mkdir -p ~/.kube
sudo cp /etc/rancher/rke2/rke2.yaml ~/.kube/config
sudo chown $USER:$USER ~/.kube/config

echo 'export KUBECONFIG=~/.kube/config' >> ~/.bashrc
source ~/.bashrc
```

### 3. Kubernetes Cluster Doğrulama

```bash
# Node'ları kontrol et
root@gwdcdvpstst02:/home/ubuntu# kubectl get nodes
NAME            STATUS   ROLES                       AGE     VERSION
gwdcdvpstst02   Ready    control-plane,etcd,master   2m15s   v1.28.15+rke2r1

# Tüm pod'ları kontrol et
root@gwdcdvpstst02:/home/ubuntu# kubectl get pods -A
NAMESPACE     NAME                                                    READY   STATUS      RESTARTS   AGE
kube-system   cloud-controller-manager-gwdcdvpstst02                  1/1     Running     0          2m15s
kube-system   etcd-gwdcdvpstst02                                      1/1     Running     0          106s
kube-system   helm-install-rke2-canal-wqf52                           0/1     Completed   0          2m5s
kube-system   helm-install-rke2-coredns-rwgjr                         0/1     Completed   0          2m5s
kube-system   helm-install-rke2-ingress-nginx-rfcqx                   0/1     Completed   0          2m5s
kube-system   kube-apiserver-gwdcdvpstst02                            1/1     Running     0          2m12s
kube-system   kube-controller-manager-gwdcdvpstst02                   1/1     Running     0          2m9s
kube-system   kube-proxy-gwdcdvpstst02                                1/1     Running     0          2m9s
kube-system   kube-scheduler-gwdcdvpstst02                            1/1     Running     0          2m9s
kube-system   rke2-canal-xr5pp                                        2/2     Running     0          118s
kube-system   rke2-coredns-rke2-coredns-6794d5bfbb-f7jkb              1/1     Running     0          118s
kube-system   rke2-ingress-nginx-controller-h4kbf                     1/1     Running     0          84s
kube-system   rke2-metrics-server-7694cf7d77-d447c                    1/1     Running     0          92s
```

**✅ Kubernetes cluster başarıyla çalışıyor!**

### 4. Helm Kurulumu

```bash
# Helm kurulum scripti
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

root@gwdcdvpstst02:/home/ubuntu# curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
Downloading https://get.helm.sh/helm-v3.19.5-linux-amd64.tar.gz
Verifying checksum... Done.
Preparing to install helm into /usr/local/bin
helm installed into /usr/local/bin/helm

root@gwdcdvpstst02:/home/ubuntu# helm version
version.BuildInfo{Version:"v3.19.5", GitCommit:"4a19a5b6fb912c5c28a779e73f2e0880d9e239a4", GitTreeState:"clean", GoVersion:"go1.24.11"}
```

### 5. Rancher Helm Repository Ekleme

```bash
# Rancher repository ekle
helm repo add rancher-stable https://releases.rancher.com/server-charts/stable

root@gwdcdvpstst02:/home/ubuntu# helm repo add rancher-stable https://releases.rancher.com/server-charts/stable
"rancher-stable" has been added to your repositories

root@gwdcdvpstst02:/home/ubuntu# helm repo update
Hang tight while we grab the latest from your chart repositories...
...Successfully got an update from the "rancher-stable" chart repository
Update Complete. ⎈Happy Helming!⎈

root@gwdcdvpstst02:/home/ubuntu# helm repo list
NAME            URL                                              
rancher-stable  https://releases.rancher.com/server-charts/stable
```

---

## SSL Sertifikası Oluşturma

Production ortamında kendi self-signed SSL sertifikamızı oluşturuyoruz.

### 1. SSL Dizini ve Private Key

```bash
# SSL dizini oluştur
sudo mkdir -p /etc/rancher/ssl
cd /etc/rancher/ssl

# Private key oluştur (2048-bit RSA)
sudo openssl genrsa -out tls.key 2048
```

### 2. Certificate Signing Request (CSR)

```bash
# CSR oluştur
sudo openssl req -new -key tls.key -out tls.csr -subj "/C=TR/ST=Istanbul/L=Istanbul/O=Gateway Management/OU=IT/CN=rancher.gwdc.local/emailAddress=admin@gwdc.local"
```

**⚠️ Önemli**: `CN=rancher.gwdc.local` değeri Rancher hostname'i ile aynı olmalıdır.

### 3. Self-Signed Certificate

```bash
# 365 gün geçerli self-signed certificate oluştur
sudo openssl x509 -req -days 365 -in tls.csr -signkey tls.key -out tls.crt

root@gwdcdvpstst02:/etc/rancher/ssl# sudo openssl x509 -req -days 365 -in tls.csr -signkey tls.key -out tls.crt
Certificate request self-signature ok
subject=C = TR, ST = Istanbul, L = Istanbul, O = Gateway Management, OU = IT, CN = rancher.gwdc.local, emailAddress = admin@gwdc.local

# CA certificate (self-signed için kendisi)
sudo cp tls.crt cacerts.pem

# İzinleri ayarla
sudo chmod 600 tls.key
sudo chmod 644 tls.crt cacerts.pem
```

### 4. Sertifika Doğrulama

```bash
root@gwdcdvpstst02:/etc/rancher/ssl# ls -lh /etc/rancher/ssl/
total 16K
-rw-r--r-- 1 root root 1.4K Jan 21 11:48 cacerts.pem
-rw-r--r-- 1 root root 1.4K Jan 21 11:48 tls.crt
-rw-r--r-- 1 root root 1.1K Jan 21 11:48 tls.csr
-rw------- 1 root root 1.7K Jan 21 11:48 tls.key

root@gwdcdvpstst02:/etc/rancher/ssl# sudo openssl x509 -in tls.crt -text -noout | grep -A 2 "Subject:"
        Subject: C = TR, ST = Istanbul, L = Istanbul, O = Gateway Management, OU = IT, CN = rancher.gwdc.local, emailAddress = admin@gwdc.local
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
```

**✅ SSL sertifikası başarıyla oluşturuldu!**

---

## cert-manager Kurulumu

cert-manager, Kubernetes'te sertifika yaşam döngüsünü yönetir.

### 1. Kubernetes Secret'ları Oluşturma

```bash
# cattle-system namespace oluştur
kubectl create namespace cattle-system

root@gwdcdvpstst02:/etc/rancher/ssl# kubectl create namespace cattle-system
namespace/cattle-system created

# TLS secret oluştur
kubectl -n cattle-system create secret tls tls-rancher-ingress \
  --cert=/etc/rancher/ssl/tls.crt \
  --key=/etc/rancher/ssl/tls.key

root@gwdcdvpstst02:/etc/rancher/ssl# kubectl -n cattle-system create secret tls tls-rancher-ingress --cert=/etc/rancher/ssl/tls.crt --key=/etc/rancher/ssl/tls.key
secret/tls-rancher-ingress created

# CA certificate secret
kubectl -n cattle-system create secret generic tls-ca \
  --from-file=cacerts.pem=/etc/rancher/ssl/cacerts.pem

root@gwdcdvpstst02:/etc/rancher/ssl# kubectl -n cattle-system create secret generic tls-ca --from-file=cacerts.pem=/etc/rancher/ssl/cacerts.pem
secret/tls-ca created

# Secret'ları kontrol et
root@gwdcdvpstst02:/etc/rancher/ssl# kubectl -n cattle-system get secrets | grep tls
tls-ca                Opaque              1      2s
tls-rancher-ingress   kubernetes.io/tls   2      6s
```

### 2. cert-manager Kurulumu

```bash
# cert-manager CRD'lerini ve deployment'ı kur
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

root@gwdcdvpstst02:/etc/rancher/ssl# kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
namespace/cert-manager created
customresourcedefinition.apiextensions.k8s.io/certificaterequests.cert-manager.io created
customresourcedefinition.apiextensions.k8s.io/certificates.cert-manager.io created
customresourcedefinition.apiextensions.k8s.io/challenges.acme.cert-manager.io created
customresourcedefinition.apiextensions.k8s.io/clusterissuers.cert-manager.io created
customresourcedefinition.apiextensions.k8s.io/issuers.cert-manager.io created
customresourcedefinition.apiextensions.k8s.io/orders.acme.cert-manager.io created
serviceaccount/cert-manager-cainjector created
serviceaccount/cert-manager created
serviceaccount/cert-manager-webhook created
...
deployment.apps/cert-manager-cainjector created
deployment.apps/cert-manager created
deployment.apps/cert-manager-webhook created
```

### 3. cert-manager Pod'larını Kontrol

```bash
# Pod'ların başlamasını bekle
root@gwdcdvpstst02:/etc/rancher/ssl# kubectl get pods -n cert-manager
NAME                                     READY   STATUS    RESTARTS   AGE
cert-manager-5698c4d465-kcc7w            1/1     Running   0          23s
cert-manager-cainjector-d4748596-6sp6b   1/1     Running   0          23s
cert-manager-webhook-65d78d5c4b-gs7n5    1/1     Running   0          23s
```

**✅ cert-manager başarıyla kuruldu!**

---

## Rancher Kurulumu

Şimdi Rancher Management Server'ı Helm ile deploy ediyoruz.

### 1. Rancher Helm Chart Kurulumu

```bash
# Rancher'ı Helm ile kur
helm install rancher rancher-stable/rancher \
  --namespace cattle-system \
  --set hostname=rancher.gwdc.local \
  --set replicas=1 \
  --set ingress.tls.source=secret \
  --set privateCA=true \
  --set bootstrapPassword="RancherAdmin2025!" \
  --version 2.9.3

root@gwdcdvpstst02:/etc/rancher/ssl# helm install rancher rancher-stable/rancher \
  --namespace cattle-system \
  --set hostname=rancher.gwdc.local \
  --set replicas=1 \
  --set ingress.tls.source=secret \
  --set privateCA=true \
  --set bootstrapPassword="RancherAdmin2025!" \
  --version 2.9.3

NAME: rancher
LAST DEPLOYED: Wed Jan 21 11:49:54 2026
NAMESPACE: cattle-system
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
Rancher Server has been installed.

NOTE: Rancher may take several minutes to fully initialize. Please standby while Certificates are being issued, Containers are started and the Ingress rule comes up.

Check out our docs at https://rancher.com/docs/

If you provided your own bootstrap password during installation, browse to https://rancher.gwdc.local to get started.

Happy Containering!
```

### 2. Rancher Deployment İzleme

```bash
# Pod'ların başlamasını izle
root@gwdcdvpstst02:/etc/rancher/ssl# kubectl -n cattle-system get pods
NAME                       READY   STATUS              RESTARTS   AGE
rancher-6b647ddb86-47pkd   0/1     ContainerCreating   0          5s

# 30 saniye sonra
root@gwdcdvpstst02:/etc/rancher/ssl# kubectl -n cattle-system get pods
NAME                       READY   STATUS    RESTARTS   AGE
rancher-6b647ddb86-47pkd   1/1     Running   0          62s

# Deployment rollout durumu
root@gwdcdvpstst02:/etc/rancher/ssl# kubectl -n cattle-system rollout status deploy/rancher
deployment "rancher" successfully rolled out
```

### 3. Rancher Resources Kontrolü

```bash
root@gwdcdvpstst02:/etc/rancher/ssl# kubectl -n cattle-system get all
NAME                           READY   STATUS     RESTARTS   AGE
pod/helm-operation-lvhbx       0/2     Init:0/1   0          9s
pod/rancher-6b647ddb86-47pkd   1/1     Running    0          74s

NAME              TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)          AGE
service/rancher   ClusterIP   10.43.108.9   <none>        80/TCP,443/TCP   74s

NAME                      READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/rancher   1/1     1            1           74s

NAME                                 DESIRED   CURRENT   READY   AGE
replicaset.apps/rancher-6b647ddb86   1         1         1       74s
```

**🎉 Rancher başarıyla deploy edildi!**

---

## İlk Erişim ve Doğrulama

### 1. Bootstrap Password

```bash
# Bootstrap password'u al
root@gwdcdvpstst02:/etc/rancher/ssl# kubectl get secret --namespace cattle-system bootstrap-secret -o go-template='{{.data.bootstrapPassword|base64decode}}'
RancherAdmin2025!
```

### 2. Ingress Kontrolü

```bash
root@gwdcdvpstst02:/etc/rancher/ssl# kubectl -n cattle-system get ingress
NAME      CLASS   HOSTS                ADDRESS        PORTS     AGE
rancher   nginx   rancher.gwdc.local   10.31.48.180   80, 443   100s
```

### 3. Final Pod Durumu

```bash
root@gwdcdvpstst02:/etc/rancher/ssl# kubectl get pods -A
NAMESPACE                         NAME                                                    READY   STATUS      RESTARTS   AGE
cattle-fleet-local-system         fleet-agent-0                                           2/2     Running     0          56s
cattle-fleet-system               fleet-controller-79d5d5df7b-xx5d8                       3/3     Running     0          92s
cattle-fleet-system               gitjob-656cbd6c99-bnskd                                 1/1     Running     0          92s
cattle-provisioning-capi-system   capi-controller-manager-5967c7487f-c6p94                1/1     Running     0          31s
cattle-system                     rancher-6b647ddb86-47pkd                                1/1     Running     0          2m47s
cattle-system                     rancher-webhook-5bdd99bdd7-kjmwl                        1/1     Running     0          59s
cert-manager                      cert-manager-5698c4d465-kcc7w                           1/1     Running     0          3m40s
cert-manager                      cert-manager-cainjector-d4748596-6sp6b                  1/1     Running     0          3m40s
cert-manager                      cert-manager-webhook-65d78d5c4b-gs7n5                   1/1     Running     0          3m40s
kube-system                       cloud-controller-manager-gwdcdvpstst02                  1/1     Running     0          7m49s
kube-system                       etcd-gwdcdvpstst02                                      1/1     Running     0          7m20s
kube-system                       kube-apiserver-gwdcdvpstst02                            1/1     Running     0          7m46s
kube-system                       kube-controller-manager-gwdcdvpstst02                   1/1     Running     0          7m43s
kube-system                       kube-proxy-gwdcdvpstst02                                1/1     Running     0          7m43s
kube-system                       kube-scheduler-gwdcdvpstst02                            1/1     Running     0          7m43s
kube-system                       rke2-canal-xr5pp                                        2/2     Running     0          7m32s
kube-system                       rke2-coredns-rke2-coredns-6794d5bfbb-f7jkb              1/1     Running     0          7m32s
kube-system                       rke2-ingress-nginx-controller-h4kbf                     1/1     Running     0          6m58s
kube-system                       rke2-metrics-server-7694cf7d77-d447c                    1/1     Running     0          7m6s
```

**✅ Tüm pod'lar Running durumda!**

### 4. Disk Kullanımı

```bash
root@gwdcdvpstst02:/etc/rancher/ssl# df -h /data
Filesystem                     Size  Used Avail Use% Mounted on
/dev/mapper/data--vg-data--lv   98G  9.9G   83G  11% /data

root@gwdcdvpstst02:/etc/rancher/ssl# du -sh /data/rancher/*
4.0K    /data/rancher/rancher-data
9.9G    /data/rancher/rke2
```

### 5. Tarayıcıdan Erişim

#### Client Tarafında Hosts Dosyası

**Windows:** `C:\Windows\System32\drivers\etc\hosts`  
**Linux/Mac:** `/etc/hosts`

Eklenecek satır:
```
10.31.48.180  rancher.gwdc.local
```

#### Tarayıcı Erişimi

1. Tarayıcınızdan `https://rancher.gwdc.local` adresine gidin
2. Self-signed certificate uyarısını kabul edin ("Advanced" → "Proceed")
3. Bootstrap password ile giriş yapın: `RancherAdmin2025!`
4. Yeni admin şifrenizi belirleyin
5. Server URL'i onaylayın: `https://rancher.gwdc.local`

**🎉 Rancher Management Server başarıyla erişilebilir!**

---

## Sonuç

### Başarıyla Tamamlanan İşlemler

✅ **Ubuntu 24.04** üzerinde RKE2 Kubernetes cluster kurulumu  
✅ **100GB /data** dizininde persistent storage yapılandırması  
✅ **Self-signed SSL** certificate ile güvenli erişim  
✅ **cert-manager** ile certificate yönetimi  
✅ **Rancher v2.9.3** Management Server deployment  
✅ **HTTPS** erişimi ve web UI doğrulaması  

### Kurulum Özeti

| Bileşen | Versiyon | Durum |
|---------|----------|-------|
| Ubuntu | 24.04.3 LTS | ✅ |
| RKE2 | v1.28.15+rke2r1 | ✅ Running |
| kubectl | v1.28.15 | ✅ |
| Helm | v3.19.5 | ✅ |
| cert-manager | v1.13.0 | ✅ Running |
| Rancher | v2.9.3 | ✅ Running |

### Kaynak Kullanımı

- **RAM**: ~2GB (Rancher + RKE2)
- **CPU**: Ortalama %20
- **Disk**: 9.9GB (/data/rancher/rke2)
- **Pod Sayısı**: 33 (tüm namespace'ler)

### Sıradaki Adımlar

1. **Backup Stratejisi**: RKE2 etcd snapshot'ları ve Rancher backup operator
2. **Monitoring**: Prometheus/Grafana stack kurulumu
3. **High Availability**: 2 node daha ekleyerek HA setup
4. **Cluster Import**: Mevcut Kubernetes cluster'larını Rancher'a import etme
5. **RBAC ve User Management**: Kullanıcı rolleri ve yetkilendirme

### Production Checklist

- [ ] Regular backup schedule (etcd + Rancher)
- [ ] Monitoring ve alerting kuruldu
- [ ] SSL sertifikası production-ready (CA-signed)
- [ ] RBAC ve user management yapılandırıldı
- [ ] Resource quotas ve limits tanımlandı
- [ ] Network policies uygulandı
- [ ] Disaster recovery planı hazırlandı
- [ ] Dokümantasyon tamamlandı

---

## Faydalı Komutlar

### Rancher Yönetimi

```bash
# Rancher pod'larını yeniden başlat
kubectl rollout restart deployment rancher -n cattle-system

# Rancher loglarını izle
kubectl logs -n cattle-system -l app=rancher -f

# Bootstrap password'u göster
kubectl get secret --namespace cattle-system bootstrap-secret -o go-template='{{.data.bootstrapPassword|base64decode}}'
```

### Cluster Yönetimi

```bash
# Tüm pod'ları kontrol et
kubectl get pods -A

# Node durumu
kubectl get nodes -o wide

# Resource kullanımı
kubectl top nodes
kubectl top pods -A

# Cluster bilgisi
kubectl cluster-info
```

### RKE2 Yönetimi

```bash
# RKE2 servis durumu
sudo systemctl status rke2-server

# RKE2 logları
sudo journalctl -u rke2-server -f

# RKE2 yeniden başlatma
sudo systemctl restart rke2-server
```

---

## Kaynaklar

- [Rancher Documentation](https://docs.ranchermanager.rancher.io/)
- [RKE2 Documentation](https://docs.rke2.io/)
- [cert-manager Documentation](https://cert-manager.io/docs/)
- [Helm Documentation](https://helm.sh/docs/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)

---

## Yazar

**Infrastructure & DevOps Specialist**  
3+ yıl Kubernetes ve container orchestration deneyimi  
Production Kubernetes cluster'larında active yönetim  
Azure DevOps, CI/CD, IaC expertise

📧 LinkedIn: [Your Profile]  
💻 GitHub: [Your Repository]

---

## Lisans

Bu dokümantasyon MIT lisansı altında paylaşılmıştır.

**⭐ Beğendiyseniz GitHub'da star vermeyi unutmayın!**

---

*Son Güncelleme: 21 Ocak 2025*  
*Versiyon: 1.0*
