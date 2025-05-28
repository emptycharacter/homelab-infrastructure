#!/bin/bash

# Advanced Libvirt Management Script
# Provides comprehensive VM lifecycle management

set -e

# Configuration
STORAGE_POOL="homelab"
NETWORK_NAME="homelab"
IMAGE_DIR="/var/lib/libvirt/images/$STORAGE_POOL"
TEMPLATE_DIR="./templates"
NETWORK_DIR="./networks"
CLOUDINIT_DIR="./cloud-init"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Generate cloud-init user-data
generate_cloud_init() {
    local hostname=$1
    local ssh_key=${2:-""}
    
    mkdir -p "$CLOUDINIT_DIR/$hostname"
    
    cat > "$CLOUDINIT_DIR/$hostname/user-data" << EOF
#cloud-config
hostname: $hostname
fqdn: $hostname.homelab.local
manage_etc_hosts: true

users:
  - default
  - n: homelab
    groups: sudo,docker
    shell: /bin/bash
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    ssh_authorized_keys:
      - $ssh_key

# Disable password authentication
ssh_pwauth: false

# Install packages
packages:
  - curl
  - wget
  - git
  - htop
  - net-tools
  - apt-transport-https
  - ca-certificates
  - gnupg
  - lsb-release

# Run commands
runcmd:
  - systemctl enable ssh
  - systemctl start ssh
  - echo "127.0.0.1 $hostname" >> /etc/hosts
  - timedatectl set-timezone UTC
  # Install Docker
  - curl -fsSL https://get.docker.com -o get-docker.sh
  - sh get-docker.sh
  - usermod -aG docker homelab
  - systemctl enable docker
  - systemctl start docker
  # Configure firewall
  - ufw --force enable
  - ufw allow ssh
  - ufw allow 6443/tcp  # Kubernetes API
  - ufw allow 2379:2380/tcp  # etcd
  - ufw allow 10250/tcp  # kubelet
  - ufw allow 10251/tcp  # kube-scheduler
  - ufw allow 10252/tcp  # kube-controller-manager
  - ufw allow 30000:32767/tcp  # NodePort services

# Final message
final_message: "Cloud-init setup complete for $hostname"

power_state:
  mode: reboot
  timeout: 30
  condition: True
EOF

    cat > "$CLOUDINIT_DIR/$hostname/meta-data" << EOF
instance-id: $hostname-$(date +%s)
local-hostname: $hostname
EOF

    # Create ISO
    genisoimage -output "$CLOUDINIT_DIR/$hostname/cloud-init.iso" \
                -volid cidata -joliet -rock \
                "$CLOUDINIT_DIR/$hostname/user-data" \
                "$CLOUDINIT_DIR/$hostname/meta-data"
                
    print_success "Cloud-init ISO created for $hostname"
}

# Create VM from template
create_vm() {
    local name=$1
    local memory=${2:-2048}
    local vcpus=${3:-2}
    local disk_size=${4:-20}
    local mac_address=${5:-""}
    local ssh_key=${6:-""}
    
    if [ -z "$name" ]; then
        print_error "VM name is required"
        return 1
    fi
    
    # Generate MAC address if not provided
    if [ -z "$mac_address" ]; then
        mac_address="52:54:00:$(openssl rand -hex 3 | sed 's/\(..\)/\1:/g; s/:$//')"
    fi
    
    # Generate UUID
    local uuid=$(uuidgen)
    
    # Create disk
    local disk_path="$IMAGE_DIR/$name.qcow2"
    if [ ! -f "$disk_path" ]; then
        qemu-img create -f qcow2 "$disk_path" "${disk_size}G"
        print_success "Created disk: $disk_path"
    fi
    
    # Generate cloud-init
    generate_cloud_init "$name" "$ssh_key"
    
    # Create VM XML from template
    local vm_xml="/tmp/$name.xml"
    cp "$TEMPLATE_DIR/homelab-node-template.xml" "$vm_xml"
    
    # Replace placeholders
    sed -i "s/HOSTNAME_PLACEHOLDER/$name/g" "$vm_xml"
    sed -i "s/UUID_PLACEHOLDER/$uuid/g" "$vm_xml"
    sed -i "s/MEMORY_PLACEHOLDER/$((memory * 1024))/g" "$vm_xml"
    sed -i "s/VCPU_PLACEHOLDER/$vcpus/g" "$vm_xml"
    sed -i "s|DISK_PATH_PLACEHOLDER|$disk_path|g" "$vm_xml"
    sed -i "s|CLOUDINIT_PATH_PLACEHOLDER|$CLOUDINIT_DIR/$name/cloud-init.iso|g" "$vm_xml"
    sed -i "s/MAC_ADDRESS_PLACEHOLDER/$mac_address/g" "$vm_xml"
    
    # Define and start VM
    virsh define "$vm_xml"
    virsh start "$name"
    
    rm "$vm_xml"
    
    print_success "VM '$name' created and started"
    print_status "MAC: $mac_address"
    print_status "Waiting for IP assignment..."
    
    # Wait for IP
    local ip=""
    local attempts=0
    while [ -z "$ip" ] && [ $attempts -lt 30 ]; do
        sleep 2
        ip=$(virsh net-dhcp-leases "$NETWORK_NAME" | grep "$mac_address" | awk '{print $5}' | cut -d'/' -f1)
        attempts=$((attempts + 1))
    done
    
    if [ -n "$ip" ]; then
        print_success "VM '$name' got IP: $ip"
        echo "$name: $ip ($mac_address)" >> vm-inventory.txt
    else
        print_warning "Could not determine IP for '$name'"
    fi
}

# Clone VM
clone_vm() {
    local source=$1
    local target=$2
    
    if [ -z "$source" ] || [ -z "$target" ]; then
        print_error "Source and target VM names are required"
        return 1
    fi
    
    print_status "Cloning $source to $target..."
    
    virt-clone --original "$source" \
               --n "$target" \
               --file "$IMAGE_DIR/$target.qcow2"
    
    print_success "VM '$target' cloned from '$source'"
}

# Snapshot management
create_snapshot() {
    local vm_name=$1
    local snapshot_name=${2:-"snapshot-$(date +%Y%m%d-%H%M%S)"}
    
    if [ -z "$vm_name" ]; then
        print_error "VM name is required"
        return 1
    fi
    
    print_status "Creating snapshot '$snapshot_name' for VM '$vm_name'..."
    
    virsh snapshot-create-as "$vm_name" "$snapshot_name" \
        "Snapshot created on $(date)"
    
    print_success "Snapshot '$snapshot_name' created"
}

restore_snapshot() {
    local vm_name=$1
    local snapshot_name=$2
    
    if [ -z "$vm_name" ] || [ -z "$snapshot_name" ]; then
        print_error "VM name and snapshot name are required"
        return 1
    fi
    
    print_status "Restoring snapshot '$snapshot_name' for VM '$vm_name'..."
    
    virsh shutdown "$vm_name" 2>/dev/null || true
    sleep 5
    virsh snapshot-revert "$vm_name" "$snapshot_name"
    virsh start "$vm_name"
    
    print_success "Snapshot '$snapshot_name' restored"
}

list_snapshots() {
    local vm_name=$1
    
    if [ -z "$vm_name" ]; then
        print_error "VM name is required"
        return 1
    fi
    
    virsh snapshot-list "$vm_name"
}

# VM operations
start_vm() {
    local vm_name=$1
    virsh start "$vm_name" 2>/dev/null && print_success "Started $vm_name" || print_warning "$vm_name already running or failed to start"
}

stop_vm() {
    local vm_name=$1
    virsh shutdown "$vm_name" 2>/dev/null && print_success "Stopping $vm_name" || print_warning "$vm_name already stopped"
}

force_stop_vm() {
    local vm_name=$1
    virsh destroy "$vm_name" 2>/dev/null && print_success "Force stopped $vm_name" || print_warning "$vm_name already stopped"
}

delete_vm() {
    local vm_name=$1
    local keep_disk=${2:-false}
    
    print_warning "This will delete VM '$vm_name'"
    read -p "Are you sure? (y/N): " confirm
    
    if [[ $confirm =~ ^[Yy]$ ]]; then
        virsh destroy "$vm_name" 2>/dev/null || true
        virsh undefine "$vm_name" --remove-all-storage
        
        if [ "$keep_disk" = "false" ]; then
            rm -f "$IMAGE_DIR/$vm_name.qcow2"
            rm -rf "$CLOUDINIT_DIR/$vm_name"
        fi
        
        print_success "VM '$vm_name' deleted"
    else
        print_status "Cancelled"
    fi
}

# Network operations
show_network_info() {
    print_status "Network: $NETWORK_NAME"
    virsh net-info "$NETWORK_NAME"
    echo ""
    print_status "DHCP Leases:"
    virsh net-dhcp-leases "$NETWORK_NAME"
}

# List VMs with detailed info
list_vms() {
    print_status "Homelab VMs:"
    virsh list --all | grep -E "(homelab|State)"
    echo ""
    
    print_status "VM Resources:"
    for vm in $(virsh list --all --n | grep homelab); do
        if virsh domstate "$vm" | grep -q running; then
            local memory=$(virsh dominfo "$vm" | grep "Used memory" | awk '{print $3 " " $4}')
            local vcpus=$(virsh dominfo "$vm" | grep "CPU(s)" | awk '{print $2}')
            echo "  $vm: ${vcpus} vCPUs, ${memory}"
        fi
    done
}

# Bulk operations
start_all() {
    print_status "Starting all homelab VMs..."
    for vm in $(virsh list --all --n | grep homelab); do
        start_vm "$vm"
    done
}

stop_all() {
    print_status "Stopping all homelab VMs..."
    for vm in $(virsh list --n | grep homelab); do
        stop_vm "$vm"
    done
}

# Performance monitoring
monitor_performance() {
    local vm_name=$1
    
    if [ -z "$vm_name" ]; then
        print_error "VM name is required"
        return 1
    fi
    
    print_status "Performance stats for $vm_name (press Ctrl+C to stop):"
    
    while true; do
        local cpu_time=$(virsh domstats "$vm_name" | grep "cpu.time" | cut -d'=' -f2)
        local memory_rss=$(virsh domstats "$vm_name" | grep "balloon.rss" | cut -d'=' -f2)
        
        clear
        echo "=== $vm_name Performance ==="
        echo "CPU Time: $cpu_time ns"
        echo "Memory RSS: $((memory_rss / 1024)) MB"
        echo "$(date)"
        
        sleep 2
    done
}

# Setup SSH keys
setup_ssh_key() {
    if [ ! -f ~/.ssh/id_rsa.pub ]; then
        print_status "Generating SSH key..."
        ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
    fi
    
    cat ~/.ssh/id_rsa.pub
}

# Main command dispatcher
case "$1" in
    create)
        create_vm "$2" "$3" "$4" "$5" "$6" "$(setup_ssh_key)"
        ;;
    clone)
        clone_vm "$2" "$3"
        ;;
    start)
        if [ -n "$2" ]; then
            start_vm "$2"
        else
            start_all
        fi
        ;;
    stop)
        if [ -n "$2" ]; then
            stop_vm "$2"
        else
            stop_all
        fi
        ;;
    force-stop)
        force_stop_vm "$2"
        ;;
    delete)
        delete_vm "$2" "$3"
        ;;
    snapshot)
        create_snapshot "$2" "$3"
        ;;
    restore)
        restore_snapshot "$2" "$3"
        ;;
    snapshots)
        list_snapshots "$2"
        ;;
    list)
        list_vms
        ;;
    network)
        show_network_info
        ;;
    monitor)
        monitor_performance "$2"
        ;;
    ssh)
        setup_ssh_key
        ;;
    *)
        echo "Libvirt Management Script"
        echo "========================"
        echo ""
        echo "Usage: $0 <command> [options]"
        echo ""
        echo "VM Management:"
        echo "  create <n> [ram] [vcpus] [disk] [mac]  - Create new VM"
        echo "  clone <source> <target>                 - Clone existing VM"
        echo "  start [vm]                              - Start VM(s)"
        echo "  stop [vm]                               - Stop VM(s)"
        echo "  force-stop <vm>                         - Force stop VM"
        echo "  delete <vm> [keep-disk]                 - Delete VM"
        echo "  list                                    - List all VMs"
        echo ""
        echo "Snapshots:"
        echo "  snapshot <vm> [n]                      - Create snapshot"
        echo "  restore <vm> <snapshot>                 - Restore snapshot"
        echo "  snapshots <vm>                          - List snapshots"
        echo ""
        echo "Monitoring:"
        echo "  monitor <vm>                            - Show performance stats"
        echo "  network                                 - Show network info"
        echo ""
        echo "Utilities:"
        echo "  ssh                                     - Show/generate SSH key"
        echo ""
        echo "Examples:"
        echo "  $0 create worker1 4096 4 30            - Create VM with 4GB RAM, 4 CPUs, 30GB disk"
        echo "  $0 clone worker1 worker2                - Clone worker1 to worker2"
        echo "  $0 snapshot master1 before-k8s          - Create named snapshot"
        ;;
esac