# Rancher Production Deployment Guide

<div align="center">

![Rancher](https://img.shields.io/badge/Rancher-v2.9.3-0075A8?logo=rancher&logoColor=white)
![Kubernetes](https://img.shields.io/badge/Kubernetes-v1.28-326CE5?logo=kubernetes&logoColor=white)
![RKE2](https://img.shields.io/badge/RKE2-Production-FF6C37)
![Ubuntu](https://img.shields.io/badge/Ubuntu-24.04-E95420?logo=ubuntu&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-green)
![Stars](https://img.shields.io/github/stars/ahmetnuri/rancher-production-guide?style=social)

**Production-ready Rancher Management Server with High Availability**  
*Lessons learned from managing 8+ Kubernetes clusters in production*

[🚀 Quick Start](#-quick-start) • [📖 Documentation](#-documentation) • [🏗️ Architecture](#️-architecture) • [⭐ Star Us](#)

</div>

---

## 🎯 Overview

This comprehensive guide provides battle-tested instructions for deploying Rancher Management Server in production environments with High Availability (HA) configuration.

### What You'll Get

✅ **3-Node HA Setup** - Production-ready RKE2 cluster configuration  
✅ **Load Balancer Config** - HAProxy/NGINX setup examples  
✅ **Backup Strategy** - Automated etcd snapshots and Rancher backups  
✅ **Multi-Cluster Management** - Best practices from managing 8+ clusters  
✅ **Security Hardening** - SSL/TLS, RBAC, network policies  
✅ **Monitoring Setup** - Prometheus/Grafana integration  
✅ **Real-World Troubleshooting** - Common issues and solutions  

### Why This Guide?

- 💪 **Battle-tested**: Used in production managing 800+ pods across 8 clusters
- ⏱️ **Time-saving**: Complete setup in 45 minutes
- 🔒 **Secure**: Security best practices included
- 📚 **Complete**: From installation to disaster recovery
- 🎓 **Educational**: Learn from real-world experiences

---

## 📊 Production Stats

| Metric | Value |
|--------|-------|
| Clusters Managed | 8+ |
| Total Pods | 800+ |
| Namespaces | 40+ |
| Uptime | 99.9% |
| Time Saved Daily | 3-4 hours |
| Team Efficiency | +60% |

---

## 🏗️ Architecture

### High Availability Setup

```
                ┌──────────────────────┐
                │   Load Balancer      │
                │   (HAProxy/NGINX)    │
                │   VIP: 192.168.1.100 │
                └───────────┬──────────┘
                            │
          ┌─────────────────┼─────────────────┐
          │                 │                 │
    ┌─────▼─────┐     ┌─────▼─────┐     ┌─────▼─────┐
    │  Node 1   │     │  Node 2   │     │  Node 3   │
    │  RKE2     │     │  RKE2     │     │  RKE2     │
    │  Rancher  │     │  Rancher  │     │  Rancher  │
    │  8C/16GB  │     │  8C/16GB  │     │  8C/16GB  │
    └─────┬─────┘     └─────┬─────┘     └─────┬─────┘
          │                 │                 │
          └─────────────────┼─────────────────┘
                            │
                  ┌─────────▼─────────┐
                  │  Shared Storage   │
                  │    (Longhorn)     │
                  │     500GB SSD     │
                  └───────────────────┘
```

### Technology Stack

| Component | Version | Purpose |
|-----------|---------|---------|
| **OS** | Ubuntu 24.04 LTS | Base operating system |
| **RKE2** | v1.28.15 | Kubernetes distribution |
| **Rancher** | v2.9.3 | Management platform |
| **cert-manager** | v1.13.0 | Certificate management |
| **Longhorn** | v1.5.x | Distributed storage |
| **HAProxy** | v2.8 | Load balancing |
| **Prometheus** | v2.45 | Monitoring |
| **Grafana** | v10.0 | Visualization |

---

## 📦 Prerequisites

### Hardware Requirements

**Per Node (Minimum):**
- CPU: 8 cores
- RAM: 16 GB
- Disk: 100 GB SSD
- Network: 1 Gbps

**For HA Setup (3 nodes minimum):**
- Total CPU: 24 cores
- Total RAM: 48 GB
- Total Disk: 300 GB
- Low latency between nodes (<5ms)

### Software Requirements

- Ubuntu 24.04 LTS (or RHEL 8+, Rocky Linux 8+)
- Root or sudo access
- Internet connectivity (for package downloads)
- DNS resolution configured
- Firewall ports open (see [Network Requirements](docs/NETWORK.md))

### Network Requirements

| Port | Protocol | Source | Destination | Purpose |
|------|----------|--------|-------------|---------|
| 443 | TCP | Clients | Load Balancer | HTTPS |
| 6443 | TCP | Load Balancer | RKE2 Nodes | Kubernetes API |
| 9345 | TCP | RKE2 Nodes | RKE2 Nodes | RKE2 Supervisor |
| 10250 | TCP | RKE2 Nodes | RKE2 Nodes | Kubelet |
| 2379-2380 | TCP | RKE2 Nodes | RKE2 Nodes | etcd |

---

## 🚀 Quick Start

### Single-Node Setup (Development/Test)

```bash
# Clone the repository
git clone https://github.com/ahmetnuri/rancher-production-guide.git
cd rancher-production-guide

# Run installation script
chmod +x scripts/install-rancher.sh
sudo ./scripts/install-rancher.sh
```

Installation completes in **~15 minutes**.

### HA Setup (Production)

```bash
# On all 3 nodes, run:
chmod +x scripts/install-rke2-ha.sh
sudo ./scripts/install-rke2-ha.sh

# On first node only:
sudo ./scripts/install-rancher-ha.sh
```

Installation completes in **~45 minutes**.

---

## 📖 Documentation

### Getting Started
- [Installation Guide](docs/INSTALLATION.md) - Step-by-step single-node setup
- [HA Deployment](docs/HA-SETUP.md) - 3-node High Availability setup
- [Load Balancer Config](docs/LOAD-BALANCER.md) - HAProxy and NGINX examples

### Operations
- [Backup & Restore](docs/BACKUP.md) - Automated backup strategies
- [Monitoring Setup](docs/MONITORING.md) - Prometheus and Grafana integration
- [Upgrading Rancher](docs/UPGRADE.md) - Safe upgrade procedures

### Security
- [Security Hardening](docs/SECURITY.md) - SSL/TLS, RBAC, policies
- [Network Policies](docs/NETWORK-POLICIES.md) - Cluster isolation
- [Certificate Management](docs/CERTIFICATES.md) - Let's Encrypt integration

### Advanced Topics
- [Multi-Cluster Management](docs/MULTI-CLUSTER.md) - Managing 8+ clusters
- [GitOps with Fleet](docs/GITOPS.md) - Git-based deployments
- [Disaster Recovery](docs/DISASTER-RECOVERY.md) - Recovery procedures
- [Performance Tuning](docs/PERFORMANCE.md) - Optimization tips

### Troubleshooting
- [Common Issues](docs/TROUBLESHOOTING.md) - Real-world problems and solutions
- [Debug Commands](docs/DEBUG.md) - Useful commands for debugging
- [FAQ](docs/FAQ.md) - Frequently asked questions

---

## 🎓 Lessons Learned

Managing 8+ production Kubernetes clusters taught us valuable lessons:

### ✅ Do This

1. **Start with HA from Day One**  
   Single-node to HA migration is painful. Plan HA architecture from the beginning.

2. **Implement Backup Strategy Immediately**  
   Don't wait until you need it. Daily etcd snapshots + weekly full backups saved us multiple times.

3. **Use GitOps from the Start**  
   Fleet integration for Git-based deployments is a game-changer. Version control everything.

4. **Plan Network Segmentation**  
   Proper network policies and segmentation prevent cascade failures between clusters.

5. **Set Resource Quotas**  
   Per-namespace limits prevent one application from affecting others.

### ❌ Don't Do This

1. **Self-Signed Certificates in Production**  
   Use Let's Encrypt or CA-signed certificates. Certificate renewal became a nightmare.

2. **Single Points of Failure**  
   Load balancer, storage, network - everything must be redundant.

3. **Skip Monitoring Setup**  
   Install Prometheus/Grafana on day one. You can't fix what you can't see.

4. **Forget to Test Backups**  
   Untested backups = no backups. Test restore procedures regularly.

5. **Use External Database**  
   RKE2's embedded etcd is stable. External MySQL/PostgreSQL adds complexity.

[Read full lessons learned →](docs/LESSONS-LEARNED.md)

---

## 🔧 Command Cheatsheet

### Quick Commands

```bash
# Check cluster status
kubectl get nodes
kubectl get pods -A

# Rancher status
kubectl -n cattle-system get pods
kubectl -n cattle-system rollout status deploy/rancher

# Get bootstrap password
kubectl get secret --namespace cattle-system bootstrap-secret \
  -o go-template='{{.data.bootstrapPassword|base64decode}}'

# Create etcd snapshot
sudo rke2 etcd-snapshot save --name manual-backup-$(date +%Y%m%d)

# View logs
kubectl logs -n cattle-system -l app=rancher -f
```

[Full command reference →](docs/CHEATSHEET.md)

---

## 🤝 Contributing

Contributions are welcome! Whether it's:

- 🐛 Bug reports
- 📝 Documentation improvements
- ✨ Feature requests
- 💡 Best practice suggestions

Please read our [Contributing Guide](CONTRIBUTING.md) before submitting PRs.

### Contributors

Thanks to these wonderful people:

<!-- ALL-CONTRIBUTORS-LIST:START -->
<!-- ALL-CONTRIBUTORS-LIST:END -->

---

## 📊 Project Stats

![GitHub last commit](https://img.shields.io/github/last-commit/ahmetnuri/rancher-production-guide)
![GitHub issues](https://img.shields.io/github/issues/ahmetnuri/rancher-production-guide)
![GitHub pull requests](https://img.shields.io/github/issues-pr/ahmetnuri/rancher-production-guide)

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 👤 Author

**Ahmet Nuri Çetin**

Infrastructure & DevOps Specialist  
*2+ years managing production Kubernetes clusters*

- 📧 Email: ahmet.cetin@example.com
- 💼 LinkedIn: [linkedin.com/in/ahmetnuri](https://linkedin.com/in/ahmetnuri)
- 🐙 GitHub: [@ahmetnuri](https://github.com/ahmetnuri)
- 📝 Blog: [yourblog.com](https://yourblog.com)

---

## 🙏 Acknowledgments

- [Rancher](https://rancher.com/) - For the amazing platform
- [RKE2](https://docs.rke2.io/) - For secure Kubernetes
- [CNCF](https://www.cncf.io/) - For the ecosystem
- Community contributors - For valuable feedback

---

## ⭐ Star History

[![Star History Chart](https://api.star-history.com/svg?repos=ahmetnuri/rancher-production-guide&type=Date)](https://star-history.com/#ahmetnuri/rancher-production-guide&Date)

---

<div align="center">

**If you found this helpful, please ⭐ star the repository!**

Made with ❤️ by Infrastructure Engineers, for Infrastructure Engineers

[🔝 Back to Top](#rancher-production-deployment-guide)

</div>
