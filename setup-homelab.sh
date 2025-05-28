#!/bin/bash

# Homelab Infrastructure Setup Script
# Automated libvirt/KVM setup for development and learning
# Usage: ./setup-homelab.sh [--nodes=N] [--ram=XXXX]

set -e

# Default configuration
DEFAULT_NODES=3
DEFAULT_RAM=2048
DEFAULT_DISK=20
NETWORK_NAME="homelab"
STORAGE_POOL="homelab"
ISO_URL="https://releases.ubuntu.com/22.04/ubuntu-22.04.3-live-server-amd64.iso"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse command line arguments
NODES=$DEFAULT_NODES
RAM=$DEFAULT_RAM
DISK=$DEFAULT_DISK

for arg in "$@"; do
    case $arg in
        --nodes=*)
            NODES="${arg#*=}"
            shift
            ;;
        --ram=*)
            RAM="${arg#*=}"
            shift
            ;;
        --disk=*)
            DISK="${arg#*=}"
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --nodes=N     Number of nodes to create (default: $DEFAULT_NODES)"
            echo "  --ram=XXXX    RAM per node in MB (default: $DEFAULT_RAM)"
            echo "  --disk=XX     Disk size per node in GB (default: $DEFAULT_DISK)"
            echo "  --help        Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $arg"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    if ! command_exists virsh; then
        print_error "libvirt not found. Please install: sudo apt install qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils"
        exit 1
    fi
    
    if ! command_exists virt-install; then
        print_error "virt-install not found. Please install: sudo apt install virtinst"
        exit 1
    fi
    
    if ! groups | grep -q libvirt; then
        print_warning "User not in libvirt group. Adding user to libvirt group..."
        sudo usermod -a -G libvirt $USER
        print_warning "Please log out and log back in, then run this script again."
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Create storage pool
setup_storage() {
    print_status "Setting up storage pool..."
    
    STORAGE_PATH="/var/lib/libvirt/images/$STORAGE_POOL"
    
    if virsh pool-list --all | grep -q "$STORAGE_POOL"; then
        print_warning "Storage pool '$STORAGE_POOL' already exists"
    else
        sudo mkdir -p "$STORAGE_PATH"
        virsh pool-define-as "$STORAGE_POOL" dir - - - - "$STORAGE_PATH"
        virsh pool-start "$STORAGE_POOL"
        virsh pool-autostart "$STORAGE_POOL"
        print_success "Storage pool '$STORAGE_POOL' created"
    fi
}

# Create network
setup_network() {
    print_status "Setting up network..."
    
    if virsh net-list --all | grep -q "$NETWORK_NAME"; then
        print_warning "Network '$NETWORK_NAME' already exists"
    else
        cat > /tmp/homelab-net.xml << EOF
<network>
  <name>$NETWORK_NAME</name>
  <bridge name='virbr-homelab'/>
  <forward mode='nat'/>
  <ip address='192.168.100.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.100.10' end='192.168.100.100'/>
    </dhcp>
  </ip>
</network>
EOF
        
        virsh net-define /tmp/homelab-net.xml
        virsh net-start "$NETWORK_NAME"
        virsh net-autostart "$NETWORK_NAME"
        rm /tmp/homelab-net.xml
        print_success "Network '$NETWORK_NAME' created"
    fi
}

# Download ISO
download_iso() {
    print_status "Checking for Ubuntu Server ISO..."
    
    ISO_PATH="/var/lib/libvirt/images/$STORAGE_POOL/ubuntu-22.04.3-live-server-amd64.iso"
    
    if [ ! -f "$ISO_PATH" ]; then
        print_status "Downloading Ubuntu Server ISO..."
        sudo wget -O "$ISO_PATH" "$ISO_URL"
        print_success "ISO downloaded"
    else
        print_warning "ISO already exists"
    fi
}

# Create VMs
create_vms() {
    print_status "Creating $NODES virtual machines..."
    
    for i in $(seq 1 $NODES); do
        VM_NAME="homelab-node$i"
        DISK_PATH="/var/lib/libvirt/images/$STORAGE_POOL/node$i.qcow2"
        
        if virsh list --all | grep -q "$VM_NAME"; then
            print_warning "VM '$VM_NAME' already exists, skipping"
            continue
        fi
        
        print_status "Creating VM: $VM_NAME"
        
        # First node gets more RAM (master node)
        NODE_RAM=$RAM
        if [ $i -eq 1 ]; then
            NODE_RAM=$((RAM * 2))
        fi
        
        virt-install \
            --name "$VM_NAME" \
            --ram "$NODE_RAM" \
            --disk path="$DISK_PATH,size=$DISK" \
            --vcpus 2 \
            --os-variant ubuntu22.04 \
            --network network="$NETWORK_NAME" \
            --graphics none \
            --console pty,target_type=serial \
            --location "/var/lib/libvirt/images/$STORAGE_POOL/ubuntu-22.04.3-live-server-amd64.iso" \
            --extra-args 'console=ttyS0,115200n8 serial' \
            --noautoconsole &
        
        print_success "VM '$VM_NAME' creation started"
    done
    
    wait
    print_success "All VMs created successfully"
}

# Generate management script
create_management_script() {
    print_status "Creating management script..."
    
    cat > homelab-manage.sh << 'EOF'
#!/bin/bash

# Homelab Management Script
# Generated automatically by setup-homelab.sh

NETWORK_NAME="homelab"
NODES=NODE_COUNT_PLACEHOLDER

case "$1" in
    start)
        echo "Starting all homelab VMs..."
        for i in $(seq 1 $NODES); do
            virsh start "homelab-node$i" 2>/dev/null || echo "homelab-node$i already running or failed to start"
        done
        ;;
    stop)
        echo "Stopping all homelab VMs..."
        for i in $(seq 1 $NODES); do
            virsh shutdown "homelab-node$i" 2>/dev/null || echo "homelab-node$i already stopped or failed to stop"
        done
        ;;
    status)
        echo "Homelab VM Status:"
        virsh list --all | grep homelab-node
        echo ""
        echo "Network DHCP Leases:"
        virsh net-dhcp-leases "$NETWORK_NAME"
        ;;
    console)
        if [ -z "$2" ]; then
            echo "Usage: $0 console <node_number>"
            echo "Example: $0 console 1"
            exit 1
        fi
        virsh console "homelab-node$2"
        ;;
    destroy)
        echo "WARNING: This will completely destroy all homelab VMs and data!"
        read -p "Are you sure? (type 'yes' to confirm): " confirm
        if [ "$confirm" = "yes" ]; then
            for i in $(seq 1 $NODES); do
                virsh destroy "homelab-node$i" 2>/dev/null || true
                virsh undefine "homelab-node$i" 2>/dev/null || true
            done
            virsh net-destroy "$NETWORK_NAME" 2>/dev/null || true
            virsh net-undefine "$NETWORK_NAME" 2>/dev/null || true
            virsh pool-destroy homelab 2>/dev/null || true
            virsh pool-undefine homelab 2>/dev/null || true
            sudo rm -rf /var/lib/libvirt/images/homelab/
            echo "Homelab destroyed"
        else
            echo "Cancelled"
        fi
        ;;
    *)
        echo "Homelab Management Script"
        echo "Usage: $0 {start|stop|status|console <node>|destroy}"
        echo ""
        echo "Commands:"
        echo "  start     - Start all homelab VMs"
        echo "  stop      - Stop all homelab VMs"
        echo "  status    - Show VM status and IP addresses"
        echo "  console   - Connect to VM console (use Ctrl+] to exit)"
        echo "  destroy   - Completely remove homelab (DANGEROUS)"
        ;;
esac
EOF
    
    # Replace placeholder with actual node count
    sed -i "s/NODE_COUNT_PLACEHOLDER/$NODES/g" homelab-manage.sh
    chmod +x homelab-manage.sh
    
    print_success "Management script 'homelab-manage.sh' created"
}

# Print post-installation instructions
print_instructions() {
    print_success "Homelab setup complete!"
    echo ""
    echo -e "${BLUE}Next Steps:${NC}"
    echo "1. Wait for VMs to finish installing (check with: ./homelab-manage.sh status)"
    echo "2. Connect to VMs using: ./homelab-manage.sh console <node_number>"
    echo "3. Configure your VMs as needed"
    echo ""
    echo -e "${BLUE}Management Commands:${NC}"
    echo "  ./homelab-manage.sh start    # Start all VMs"
    echo "  ./homelab-manage.sh stop     # Stop all VMs"
    echo "  ./homelab-manage.sh status   # Check status and IPs"
    echo "  ./homelab-manage.sh console 1 # Connect to node 1"
    echo ""
    echo -e "${BLUE}VM Configuration:${NC}"
    echo "  Nodes: $NODES"
    echo "  RAM per node: ${RAM}MB (node1: $((RAM * 2))MB)"
    echo "  Disk per node: ${DISK}GB"
    echo "  Network: 192.168.100.0/24"
    echo ""
    echo -e "${YELLOW}TIP:${NC} Install Docker and K3s on your VMs for a complete container platform!"
}

# Main execution
main() {
    echo -e "${GREEN}🚀 Homelab Infrastructure Setup${NC}"
    echo "=================================="
    echo ""
    
    check_prerequisites
    setup_storage
    setup_network
    download_iso
    create_vms
    create_management_script
    print_instructions
}

# Run main function
main "$@"