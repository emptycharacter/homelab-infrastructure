# Homelab Infrastructure

A production-grade homelab environment featuring enterprise network security, virtualization, and automation. Built to understand and implement real-world network infrastructure concepts at scale.

## Overview

This repository documents my homelab infrastructure that has been running 24/7 for the past two years. The setup mirrors enterprise environments with network segmentation, security monitoring, virtualization, and automated management.

**Key Stats:**
- 99.8% uptime over 18 months
- 5 VLANs with granular security policies
- Multiple virtualization hosts
- Automated backup and monitoring systems

## Architecture

### Core Infrastructure
- **Firewall/Router:** pfSense on dedicated hardware
- **Hypervisors:** Proxmox + KVM / libvirt / QEMU nodes
- **Network Switch:** TL-SG108E (managed, VLAN-aware)
- **Storage:** Custom Linux NAS with NFS/Samba
- **DNS/Ad-blocking:** AdGuard Home in LXC container

### Network Segmentation
| VLAN | Purpose | Subnet | Access Policy |
|------|---------|--------|---------------|
| 10 | Admin/Management | 192.168.10.0/24 | Restricted to admin devices |
| 20 | Trusted Devices | 192.168.20.0/24 | Full LAN access |
| 30 | IoT Devices | 192.168.30.0/24 | Internet only, no inter-VLAN |
| 40 | Guest Network | 192.168.40.0/24 | Internet only, isolated |
| 50 | VPN Clients | 192.168.50.0/24 | Policy-based access |

### Security & Monitoring
- **IDS/IPS:** Zeek and Suricata for network traffic analysis
- **VPN:** WireGuard server with policy-based routing
- **Firewall Rules:** Granular inter-VLAN communication policies
- **DNS Filtering:** Network-wide ad blocking and malware protection

## Key Technical Implementations

### Cross-VLAN Security
Implemented granular firewall rules allowing specific services between VLANs while maintaining isolation. Example: Trusted devices can access NAS on Admin VLAN via NFS (port 2049) but cannot access management interfaces.

### GPU Passthrough
Configured KVM with VFIO for AMD 780M GPU passthrough to Windows VMs, enabling native graphics performance for development and testing environments.

### Automated Management
- Python scripts for VM health monitoring and automated backups
- Bash scripts for routine maintenance (log rotation, service checks)
- Automated DHCP reservation management for new devices

### Storage Infrastructure
- NFS shares for VM storage with cross-VLAN accessibility
- Samba shares for Windows compatibility
- Automated backup verification and integrity checking

## Technologies Used

**Virtualization:** Proxmox, KVM, QEMU, libvirt, LXC containers  
**Networking:** pfSense, VLANs, WireGuard, DHCP/DNS management  
**Security:** Zeek, Suricata, firewall policy management  
**Automation:** Python, Bash, cron, systemd services  
**Storage:** NFS, Samba, ext4, automated backup scripts  

## Documentation & Best Practices

- Maintained detailed network topology diagrams
- Documented all firewall rules with business justification
- Created troubleshooting runbooks for common issues
- Version-controlled configuration files
- Automated configuration backup procedures

## Learning Outcomes

This project provided hands-on experience with:
- Enterprise network security principles
- VLAN design and implementation
- Network traffic analysis and monitoring
- Virtualization at scale
- Infrastructure automation and documentation
- Troubleshooting complex multi-system environments

## Performance Metrics

- **Network Throughput:** Consistent gigabit performance across all VLANs
- **Storage Availability:** 99.9% uptime with automated failover
- **Security:** Zero successful intrusions, comprehensive monitoring
- **Maintenance:** 95% of routine tasks automated

## Future Improvements

- [ ] Implement Prometheus + Grafana monitoring stack
- [ ] Expand containerization with Kubernetes cluster
- [ ] Add distributed storage with Ceph
- [ ] Implement Infrastructure as Code with Terraform
- [ ] Enhanced security monitoring with ELK stack

## Repository Structure

```
├── network/                 # Network configuration and diagrams
├── scripts/                 # Automation and monitoring scripts
├── docs/                    # Detailed documentation and guides
├── configs/                 # Configuration file examples
└── monitoring/              # Health check and alerting setup
```

## Contact

For questions about specific implementations or technical details, feel free to reach out:
- Email: joshua@emptycharacter.dev
- LinkedIn: [joshua-farin](https://linkedin.com/in/joshua-farin)
- Portfolio: [emptycharacter.dev](https://emptycharacter.dev)

---

*This homelab represents 500+ hours of research, implementation, and continuous improvement. It serves as both a learning platform and a production environment for personal projects.*