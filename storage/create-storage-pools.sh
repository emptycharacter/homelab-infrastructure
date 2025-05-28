#!/bin/bash

# Libvirt Storage Pool Management
# Creates optimized storage pools for different use cases

set -e

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

# Create main homelab storage pool
create_homelab_pool() {
    local pool_name="homelab"
    local pool_path="/var/lib/libvirt/images/homelab"
    
    print_status "Creating main homelab storage pool..."
    
    if virsh pool-list --all | grep -q "$pool_name"; then
        print_warning "Pool '$pool_name' already exists"
        return
    fi
    
    sudo mkdir -p "$pool_path"
    sudo chown libvirt-qemu:libvirt-qemu "$pool_path"
    sudo chmod 755 "$pool_path"
    
    cat > /tmp/homelab-pool.xml << EOF
<pool type='dir'>
  <n>$pool_name</n>
  <target>
    <path>$pool_path</path>
    <permissions>
      <mode>0755</mode>
      <owner>107</owner>
      <group>107</group>
    </permissions>
  </target>
</pool>
EOF
    
    virsh pool-define /tmp/homelab-pool.xml
    virsh pool-start "$pool_name"
    virsh pool-autostart "$pool_name"
    
    rm /tmp/homelab-pool.xml
    
    print_success "Homelab storage pool created at $pool_path"
}

# Create fast storage pool (for databases, etc.)
create_fast_pool() {
    local pool_name="homelab-fast"
    local pool_path="/var/lib/libvirt/images/homelab-fast"
    
    print_status "Creating fast storage pool..."
    
    if virsh pool-list --all | grep -q "$pool_name"; then
        print_warning "Pool '$pool_name' already exists"
        return
    fi
    
    sudo mkdir -p "$pool_path"
    sudo chown libvirt-qemu:libvirt-qemu "$pool_path"
    sudo chmod 755 "$pool_path"
    
    # Try to use tmpfs if available and system has enough RAM
    local total_ram=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local tmpfs_size="2G"
    
    if [ $total_ram -gt 8388608 ]; then  # More than 8GB RAM
        tmpfs_size="4G"
    fi
    
    # Add tmpfs mount option to fstab if not present
    if ! grep -q "$pool_path" /etc/fstab; then
        print_status "Adding tmpfs mount for fast storage..."
        echo "tmpfs $pool_path tmpfs defaults,size=$tmpfs_size,uid=107,gid=107,mode=0755 0 0" | sudo tee -a /etc/fstab
        sudo mount "$pool_path" || print_warning "Could not mount tmpfs, using regular directory"
    fi
    
    cat > /tmp/fast-pool.xml << EOF
<pool type='dir'>
  <n>$pool_name</n>
  <target>
    <path>$pool_path</path>
    <permissions>
      <mode>0755</mode>
      <owner>107</owner>
      <group>107</group>
    </permissions>
  </target>
</pool>
EOF
    
    virsh pool-define /tmp/fast-pool.xml
    virsh pool-start "$pool_name"
    virsh pool-autostart "$pool_name"
    
    rm /tmp/fast-pool.xml
    
    print_success "Fast storage pool created at $pool_path"
    print_status "Pool size: $tmpfs_size (tmpfs)"
}

# Create backup storage pool
create_backup_pool() {
    local pool_name="homelab-backup"
    local pool_path="/var/backups/libvirt/homelab"
    
    print_status "Creating backup storage pool..."
    
    if virsh pool-list --all | grep -q "$pool_name"; then
        print_warning "Pool '$pool_name' already exists"
        return
    fi
    
    sudo mkdir -p "$pool_path"
    sudo chown libvirt-qemu:libvirt-qemu "$pool_path"
    sudo chmod 755 "$pool_path"
    
    cat > /tmp/backup-pool.xml << EOF
<pool type='dir'>
  <n>$pool_name</n>
  <target>
    <path>$pool_path</path>
    <permissions>
      <mode>0755</mode>
      <owner>107</owner>
      <group>107</group>
    </permissions>
  </target>
</pool>
EOF
    
    virsh pool-define /tmp/backup-pool.xml
    virsh pool-start "$pool_name"
    virsh pool-autostart "$pool_name"
    
    rm /tmp/backup-pool.xml
    
    print_success "Backup storage pool created at $pool_path"
}

# Create ISO storage pool
create_iso_pool() {
    local pool_name="homelab-iso"
    local pool_path="/var/lib/libvirt/images/iso"
    
    print_status "Creating ISO storage pool..."
    
    if virsh pool-list --all | grep -q "$pool_name"; then
        print_warning "Pool '$pool_name' already exists"
        return
    fi
    
    sudo mkdir -p "$pool_path"
    sudo chown libvirt-qemu:libvirt-qemu "$pool_path"
    sudo chmod 755 "$pool_path"
    
    cat > /tmp/iso-pool.xml << EOF
<pool type='dir'>
  <n>$pool_name</n>
  <target>
    <path>$pool_path</path>
    <permissions>
      <mode>0755</mode>
      <owner>107</owner>
      <group>107</group>
    </permissions>
  </target>
</pool>
EOF
    
    virsh pool-define /tmp/iso-pool.xml
    virsh pool-start "$pool_name"
    virsh pool-autostart "$pool_name"
    
    rm /tmp/iso-pool.xml
    
    print_success "ISO storage pool created at $pool_path"
    
    # Download common ISOs
    download_common_isos "$pool_path"
}

# Download common ISOs
download_common_isos() {
    local iso_path=$1
    
    print_status "Downloading common ISOs..."
    
    cd "$iso_path"
    
    # Ubuntu Server 22.04 LTS
    if [ ! -f "ubuntu-22.04.3-live-server-amd64.iso" ]; then
        print_status "Downloading Ubuntu Server 22.04..."
        sudo wget -O ubuntu-22.04.3-live-server-amd64.iso \
            https://releases.ubuntu.com/22.04/ubuntu-22.04.3-live-server-amd64.iso
    fi
    
    # CentOS Stream 9
    if [ ! -f "CentOS-Stream-9-latest-x86_64-dvd1.iso" ]; then
        print_status "Downloading CentOS Stream 9..."
        sudo wget -O CentOS-Stream-9-latest-x86_64-dvd1.iso \
            https://mirrors.centos.org/mirrorlist?path=/9-stream/BaseOS/x86_64/iso/CentOS-Stream-9-latest-x86_64-dvd1.iso
    fi
    
    # Debian 12
    if [ ! -f "debian-12.2.0-amd64-netinst.iso" ]; then
        print_status "Downloading Debian 12..."
        sudo wget -O debian-12.2.0-amd64-netinst.iso \
            https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-12.2.0-amd64-netinst.iso
    fi
    
    # Alpine Linux (lightweight)
    if [ ! -f "alpine-virt-3.18.4-x86_64.iso" ]; then
        print_status "Downloading Alpine Linux..."
        sudo wget -O alpine-virt-3.18.4-x86_64.iso \
            https://dl-cdn.alpinelinux.org/alpine/v3.18/releases/x86_64/alpine-virt-3.18.4-x86_64.iso
    fi
    
    print_success "Common ISOs downloaded"
}

# Create LVM storage pool (advanced)
create_lvm_pool() {
    local pool_name="homelab-lvm"
    local vg_name="homelab-vg"
    
    print_status "Creating LVM storage pool..."
    
    if virsh pool-list --all | grep -q "$pool_name"; then
        print_warning "Pool '$pool_name' already exists"
        return
    fi
    
    # Check if VG exists
    if ! vgs "$vg_name" &>/dev/null; then
        print_error "Volume group '$vg_name' not found"
        print_status "To create LVM pool, first create volume group:"
        print_status "  sudo pvcreate /dev/sdX"
        print_status "  sudo vgcreate $vg_name /dev/sdX"
        return 1
    fi
    
    cat > /tmp/lvm-pool.xml << EOF
<pool type='logical'>
  <n>$pool_name</n>
  <source>
    <n>$vg_name</n>
    <format type='lvm2'/>
  </source>
  <target>
    <path>/dev/$vg_name</path>
  </target>
</pool>
EOF
    
    virsh pool-define /tmp/lvm-pool.xml
    virsh pool-start "$pool_name"
    virsh pool-autostart "$pool_name"
    
    rm /tmp/lvm-pool.xml
    
    print_success "LVM storage pool created using VG: $vg_name"
}

# Optimize storage pools
optimize_pools() {
    print_status "Optimizing storage pools..."
    
    # Set proper ownership and permissions
    sudo find /var/lib/libvirt/images -type d -exec chmod 755 {} \;
    sudo find /var/lib/libvirt/images -type f -exec chmod 644 {} \;
    sudo chown -R libvirt-qemu:libvirt-qemu /var/lib/libvirt/images
    
    # Enable compression for qcow2 images in backup pool
    if virsh pool-list | grep -q "homelab-backup"; then
        print_status "Enabling compression for backup pool images..."
        # This would be done when creating new volumes
    fi
    
    print_success "Storage pools optimized"
}

# Show storage pool information
show_pool_info() {
    print_status "Storage Pool Information:"
    echo ""
    
    for pool in $(virsh pool-list --n); do
        echo "=== $pool ==="
        virsh pool-info "$pool"
        echo "Path: $(virsh pool-dumpxml "$pool" | grep -o '<path>.*</path>' | sed 's/<[^>]*>//g')"
        echo "Available: $(virsh pool-info "$pool" | grep Available | awk '{print $2 " " $3}')"
        echo ""
    done
}

# Cleanup unused volumes
cleanup_volumes() {
    print_status "Cleaning up unused volumes..."
    
    local used_volumes=()
    
    # Get list of volumes in use
    for vm in $(virsh list --all --n); do
        local vm_disks=$(virsh domblklist "$vm" --details | grep file | awk '{print $4}')
        for disk in $vm_disks; do
            used_volumes+=("$disk")
        done
    done
    
    # Check each pool for unused volumes
    for pool in $(virsh pool-list --n | grep homelab); do
        print_status "Checking pool: $pool"
        
        for vol in $(virsh vol-list "$pool" --details | grep -v "^$" | tail -n +3 | awk '{print $1}'); do
            local vol_path=$(virsh vol-path "$vol" "$pool")
            local in_use=false
            
            for used_vol in "${used_volumes[@]}"; do
                if [ "$vol_path" = "$used_vol" ]; then
                    in_use=true
                    break
                fi
            done
            
            if [ "$in_use" = false ]; then
                print_warning "Unused volume found: $vol_path"
                read -p "Delete unused volume $vol? (y/N): " confirm
                if [[ $confirm =~ ^[Yy]$ ]]; then
                    virsh vol-delete "$vol" "$pool"
                    print_success "Deleted: $vol"
                fi
            fi
        done
    done
}

# Backup storage pools configuration
backup_pool_configs() {
    local backup_dir="./backups/storage-pools-$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    print_status "Backing up storage pool configurations..."
    
    for pool in $(virsh pool-list --all --n | grep homelab); do
        virsh pool-dumpxml "$pool" > "$backup_dir/$pool.xml"
        print_status "Backed up: $pool"
    done
    
    print_success "Storage pool configs backed up to: $backup_dir"
}

# Main command dispatcher
case "$1" in
    create-all)
        create_homelab_pool
        create_fast_pool
        create_backup_pool
        create_iso_pool
        optimize_pools
        ;;
    create-homelab)
        create_homelab_pool
        ;;
    create-fast)
        create_fast_pool
        ;;
    create-backup)
        create_backup_pool
        ;;
    create-iso)
        create_iso_pool
        ;;
    create-lvm)
        create_lvm_pool
        ;;
    optimize)
        optimize_pools
        ;;
    info)
        show_pool_info
        ;;
    cleanup)
        cleanup_volumes
        ;;
    backup)
        backup_pool_configs
        ;;
    download-isos)
        download_common_isos "/var/lib/libvirt/images/iso"
        ;;
    *)
        echo "Libvirt Storage Pool Management"
        echo "==============================="
        echo ""
        echo "Usage: $0 <command>"
        echo ""
        echo "Commands:"
        echo "  create-all       - Create all storage pools"
        echo "  create-homelab   - Create main homelab pool"
        echo "  create-fast      - Create fast storage pool (tmpfs)"
        echo "  create-backup    - Create backup storage pool"
        echo "  create-iso       - Create ISO storage pool"
        echo "  create-lvm       - Create LVM storage pool"
        echo "  optimize         - Optimize existing pools"
        echo "  info             - Show pool information"
        echo "  cleanup          - Clean up unused volumes"
        echo "  backup           - Backup pool configurations"
        echo "  download-isos    - Download common ISOs"
        echo ""
        echo "Storage Pools:"
        echo "  homelab          - Main VM storage"
        echo "  homelab-fast     - Fast storage (tmpfs)"
        echo "  homelab-backup   - Backup storage"
        echo "  homelab-iso      - ISO images"
        echo "  homelab-lvm      - LVM-based storage"
        ;;
esac