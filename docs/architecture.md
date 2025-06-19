# Homelab Infrastructure Architecture

This document provides a comprehensive overview of the homelab infrastructure architecture, including network topology, system components, security boundaries, and deployment workflows.

## 🏗️ Infrastructure Overview

```mermaid
graph TB
    subgraph "Physical Infrastructure"
        PF[pfSense Firewall/Router]
        SW[TL-SG108E Managed Switch]
        NAS[Custom Linux NAS]
        HV1[Proxmox Hypervisor 1]
        HV2[KVM/libvirt Host]
    end
    
    subgraph "Network Segments"
        VLAN10[VLAN 10<br/>Admin/Management<br/>192.168.10.0/24]
        VLAN20[VLAN 20<br/>Trusted Devices<br/>192.168.20.0/24]
        VLAN30[VLAN 30<br/>IoT Devices<br/>192.168.30.0/24]
        VLAN40[VLAN 40<br/>Guest Network<br/>192.168.40.0/24]
        VLAN50[VLAN 50<br/>VPN Clients<br/>192.168.50.0/24]
    end
    
    subgraph "Virtual Machines"
        VM1[Master Node<br/>Kubernetes Control Plane]
        VM2[Worker Node 1<br/>Application Workloads]
        VM3[Worker Node 2<br/>Application Workloads]
        VM4[Storage Node<br/>Distributed Storage]
        VM5[Monitoring Node<br/>Prometheus/Grafana]
    end
    
    subgraph "Services"
        DNS[AdGuard Home<br/>DNS + Ad Blocking]
        VPN[WireGuard<br/>VPN Server]
        MON[Monitoring Stack<br/>Metrics + Logs]
        IDS[Zeek + Suricata<br/>Network Security]
    end
    
    PF --> SW
    SW --> VLAN10
    SW --> VLAN20
    SW --> VLAN30
    SW --> VLAN40
    SW --> VLAN50
    
    HV1 --> VM1
    HV1 --> VM2
    HV2 --> VM3
    HV2 --> VM4
    HV2 --> VM5
    
    VLAN10 --> DNS
    VLAN10 --> VPN
    VLAN10 --> MON
    VLAN10 --> IDS
    
    NAS --> VM1
    NAS --> VM2
    NAS --> VM3
    NAS --> VM4
```

## 🌐 Network Architecture

### VLAN Segmentation Strategy

```mermaid
graph LR
    subgraph "Network Security Zones"
        DMZ[DMZ Zone<br/>Public Services]
        MGMT[Management Zone<br/>VLAN 10]
        TRUST[Trusted Zone<br/>VLAN 20]
        IOT[IoT Zone<br/>VLAN 30]
        GUEST[Guest Zone<br/>VLAN 40]
        VPN[VPN Zone<br/>VLAN 50]
    end
    
    subgraph "Security Policies"
        FW[pfSense Firewall<br/>Stateful Inspection]
        IDS_IPS[IDS/IPS<br/>Zeek + Suricata]
        DNS_FILTER[DNS Filtering<br/>AdGuard Home]
    end
    
    MGMT --> TRUST
    TRUST --> IOT
    IOT -.-> GUEST
    VPN --> TRUST
    
    FW --> MGMT
    FW --> TRUST
    FW --> IOT
    FW --> GUEST
    FW --> VPN
    
    IDS_IPS --> FW
    DNS_FILTER --> FW
```

### Network Access Control Matrix

| Source VLAN | Target VLAN | Access Level | Services Allowed |
|-------------|-------------|--------------|------------------|
| Admin (10) | All VLANs | Full Access | SSH, HTTPS, SNMP, All |
| Trusted (20) | Admin (10) | Limited | NFS, SMB, HTTPS |
| Trusted (20) | IoT (30) | Restricted | HTTPS, MQTT |
| IoT (30) | Internet | Limited | HTTPS, NTP |
| Guest (40) | Internet | Basic | HTTP, HTTPS |
| VPN (50) | Policy-based | Variable | Per-user policies |

## 🖥️ Virtualization Architecture

### KVM/libvirt Infrastructure

```mermaid
graph TD
    subgraph "Host System"
        HOST[Ubuntu 22.04 LTS<br/>KVM Hypervisor]
        LIBVIRT[libvirt Daemon<br/>VM Management]
        QEMU[QEMU/KVM<br/>Virtualization Engine]
    end
    
    subgraph "Storage Pools"
        MAIN[homelab<br/>Main Storage<br/>Dir-based]
        FAST[homelab-fast<br/>Fast Storage<br/>tmpfs]
        BACKUP[homelab-backup<br/>Backup Storage<br/>Dir-based]
        ISO[homelab-iso<br/>ISO Images<br/>Dir-based]
    end
    
    subgraph "Network Bridges"
        BR_HOMELAB[virbr-homelab<br/>192.168.100.0/24]
        BR_MGMT[virbr-mgmt<br/>Management]
    end
    
    subgraph "VM Templates"
        TEMPLATE[Ubuntu 22.04<br/>Cloud-init Template]
        CONFIG[VM Configuration<br/>CPU, Memory, Disk]
    end
    
    HOST --> LIBVIRT
    LIBVIRT --> QEMU
    LIBVIRT --> MAIN
    LIBVIRT --> FAST
    LIBVIRT --> BACKUP
    LIBVIRT --> ISO
    LIBVIRT --> BR_HOMELAB
    LIBVIRT --> BR_MGMT
    TEMPLATE --> CONFIG
```

### VM Deployment Workflow

```mermaid
sequenceDiagram
    participant U as User
    participant S as Setup Script
    participant L as libvirt
    participant Q as QEMU
    participant V as VM
    
    U->>S: ./libvirt-manager.sh create vm-name
    S->>S: Generate cloud-init ISO
    S->>S: Create VM XML from template
    S->>L: Define VM configuration
    L->>Q: Create VM instance
    Q->>V: Boot VM with cloud-init
    V->>V: Run cloud-init setup
    V->>S: Report IP address
    S->>U: VM ready with IP
```

## 🔒 Security Architecture

### Defense-in-Depth Strategy

```mermaid
graph TB
    subgraph "Perimeter Security"
        FW[pfSense Firewall<br/>Stateful Rules]
        VPN_GW[WireGuard VPN<br/>Secure Remote Access]
        DNS_SEC[DNS Security<br/>AdGuard Home]
    end
    
    subgraph "Network Security"
        VLAN_SEG[VLAN Segmentation<br/>Micro-segmentation]
        IDS[Network IDS/IPS<br/>Zeek + Suricata]
        MONITOR[Traffic Monitoring<br/>Real-time Analysis]
    end
    
    subgraph "Host Security"
        SSH_KEYS[SSH Key Auth<br/>No Passwords]
        SUDO[Sudo Policies<br/>Least Privilege]
        UFW[Host Firewall<br/>ufw Rules]
    end
    
    subgraph "Application Security"
        TLS[TLS/SSL<br/>Encrypted Transit]
        RBAC[Role-Based Access<br/>Service Accounts]
        AUDIT[Audit Logging<br/>Compliance]
    end
    
    FW --> VLAN_SEG
    VPN_GW --> SSH_KEYS
    DNS_SEC --> MONITOR
    VLAN_SEG --> UFW
    IDS --> AUDIT
    SSH_KEYS --> RBAC
    UFW --> TLS
```

### Security Monitoring Flow

```mermaid
graph LR
    subgraph "Data Collection"
        NET[Network Traffic<br/>Zeek/Suricata]
        LOGS[System Logs<br/>rsyslog]
        METRICS[System Metrics<br/>Node Exporter]
    end
    
    subgraph "Analysis & Storage"
        PROM[Prometheus<br/>Metrics Storage]
        ELK[ELK Stack<br/>Log Analysis]
        GRAF[Grafana<br/>Visualization]
    end
    
    subgraph "Alerting"
        ALERT[AlertManager<br/>Alert Routing]
        NOTIFY[Notifications<br/>Email/Slack]
        TICKET[Ticket System<br/>Issue Tracking]
    end
    
    NET --> PROM
    LOGS --> ELK
    METRICS --> PROM
    PROM --> GRAF
    ELK --> GRAF
    GRAF --> ALERT
    ALERT --> NOTIFY
    ALERT --> TICKET
```

## 📊 Monitoring & Observability

### Monitoring Stack Architecture

```mermaid
graph TD
    subgraph "Data Sources"
        VM1[VMs<br/>Node Exporter]
        VM2[Services<br/>Service Metrics]
        VM3[Network<br/>SNMP/Flow]
        VM4[Applications<br/>Custom Metrics]
    end
    
    subgraph "Collection & Storage"
        PROM[Prometheus<br/>Time Series DB]
        INFLUX[InfluxDB<br/>High-res Metrics]
        ELASTIC[Elasticsearch<br/>Log Storage]
    end
    
    subgraph "Visualization"
        GRAF[Grafana<br/>Dashboards]
        KIBANA[Kibana<br/>Log Analysis]
        ALERT[AlertManager<br/>Alerting]
    end
    
    subgraph "Notifications"
        EMAIL[Email Alerts]
        SLACK[Slack Integration]
        WEBHOOK[Webhook APIs]
    end
    
    VM1 --> PROM
    VM2 --> PROM
    VM3 --> INFLUX
    VM4 --> PROM
    
    PROM --> GRAF
    INFLUX --> GRAF
    ELASTIC --> KIBANA
    
    GRAF --> ALERT
    ALERT --> EMAIL
    ALERT --> SLACK
    ALERT --> WEBHOOK
```

## 🔄 CI/CD & Automation

### Infrastructure Deployment Pipeline

```mermaid
graph LR
    subgraph "Source Control"
        GIT[Git Repository<br/>Infrastructure Code]
        PR[Pull Request<br/>Code Review]
        MERGE[Merge to Main<br/>Approved Changes]
    end
    
    subgraph "CI Pipeline"
        LINT[Linting<br/>shellcheck, yamllint]
        TEST[Testing<br/>Infrastructure Tests]
        SCAN[Security Scan<br/>Vulnerability Check]
    end
    
    subgraph "CD Pipeline"
        PLAN[Terraform Plan<br/>Infrastructure Plan]
        APPLY[Terraform Apply<br/>Resource Creation]
        CONFIG[Ansible Config<br/>Configuration Mgmt]
    end
    
    subgraph "Validation"
        HEALTH[Health Checks<br/>Service Validation]
        MONITOR[Monitoring<br/>Metrics Collection]
        ROLLBACK[Rollback<br/>Failure Recovery]
    end
    
    GIT --> PR
    PR --> MERGE
    MERGE --> LINT
    LINT --> TEST
    TEST --> SCAN
    SCAN --> PLAN
    PLAN --> APPLY
    APPLY --> CONFIG
    CONFIG --> HEALTH
    HEALTH --> MONITOR
    MONITOR --> ROLLBACK
```

## 🚀 Scalability & Growth

### Current vs. Future Architecture

```mermaid
graph TB
    subgraph "Current State (Single Host)"
        H1[KVM Host 1<br/>All Services]
        S1[Local Storage<br/>Single Point]
        N1[Single Network<br/>Basic Segmentation]
    end
    
    subgraph "Future State (Multi-Host)"
        H2[KVM Host 1<br/>Control Plane]
        H3[KVM Host 2<br/>Worker Nodes]
        H4[KVM Host 3<br/>Storage Cluster]
        
        S2[Distributed Storage<br/>Ceph/GlusterFS]
        N2[Advanced Networking<br/>SDN/Service Mesh]
        
        K8S[Kubernetes<br/>Container Orchestration]
        ISTIO[Istio Service Mesh<br/>Advanced Networking]
    end
    
    H1 --> H2
    S1 --> S2
    N1 --> N2
    
    H2 --> K8S
    H3 --> K8S
    H4 --> S2
    
    K8S --> ISTIO
    N2 --> ISTIO
```

## 📚 Architecture Decisions

### Key Design Principles

1. **Security First**: Every component designed with security as primary concern
2. **Infrastructure as Code**: All configuration version-controlled and automated
3. **Observability**: Comprehensive monitoring and logging throughout
4. **Scalability**: Designed to grow from single-host to multi-host cluster
5. **Learning Focus**: Architecture chosen to demonstrate enterprise practices

### Technology Choices

| Component | Technology | Rationale |
|-----------|------------|-----------|
| Hypervisor | KVM/libvirt | Open source, enterprise-grade, full hardware support |
| Networking | pfSense + VLANs | Professional firewall features, VLAN support |
| Storage | Multiple pools | Different performance tiers for different workloads |
| Monitoring | Prometheus/Grafana | Industry standard, scalable, extensible |
| Security | Zeek + Suricata | Professional network security monitoring |
| Automation | Shell + Python | Reliable, portable, easy to understand |

### Lessons Learned

- **Start Simple**: Begin with basic setup, add complexity gradually
- **Document Everything**: Architecture decisions, configurations, procedures
- **Automate Early**: Manual processes become technical debt quickly
- **Plan for Growth**: Design with scalability in mind from beginning
- **Security Integration**: Build security in, don't bolt it on later

---

*This architecture represents 2+ years of continuous learning and improvement, demonstrating enterprise-level infrastructure practices in a homelab environment.* 🏗️🚀 