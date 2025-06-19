#!/bin/bash

# Homelab Environment Validation Script
# Validates system requirements and infrastructure components
# Usage: ./validate-environment.sh [--quick|--full|--fix]

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/tmp/homelab-validation.log"
MIN_RAM_GB=8
MIN_DISK_GB=50
MIN_CPU_CORES=2

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
print_status() { echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"; }

# Global variables for tracking validation results
VALIDATION_ERRORS=0
VALIDATION_WARNINGS=0
VALIDATION_PASSED=0

# Initialize validation log
init_validation() {
    echo "Homelab Environment Validation - $(date)" > "$LOG_FILE"
    echo "=============================================" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
    
    print_status "Starting homelab environment validation..."
    print_status "Log file: $LOG_FILE"
}

# Check system requirements
check_system_requirements() {
    print_status "Checking system requirements..."
    
    # Check operating system
    if command -v lsb_release &> /dev/null; then
        local os_info=$(lsb_release -d | cut -f2)
        print_success "Operating System: $os_info"
        
        if lsb_release -d | grep -q "Ubuntu\|Debian"; then
            print_success "Supported operating system detected"
            ((VALIDATION_PASSED++))
        else
            print_warning "Operating system may not be fully supported"
            ((VALIDATION_WARNINGS++))
        fi
    else
        print_error "Cannot determine operating system"
        ((VALIDATION_ERRORS++))
    fi
    
    # Check CPU cores
    local cpu_cores=$(nproc)
    if [[ $cpu_cores -ge $MIN_CPU_CORES ]]; then
        print_success "CPU cores: $cpu_cores (minimum: $MIN_CPU_CORES)"
        ((VALIDATION_PASSED++))
    else
        print_error "Insufficient CPU cores: $cpu_cores (minimum: $MIN_CPU_CORES)"
        ((VALIDATION_ERRORS++))
    fi
    
    # Check RAM
    local ram_gb=$(free -g | grep "Mem:" | awk '{print $2}')
    if [[ $ram_gb -ge $MIN_RAM_GB ]]; then
        print_success "RAM: ${ram_gb}GB (minimum: ${MIN_RAM_GB}GB)"
        ((VALIDATION_PASSED++))
    else
        print_error "Insufficient RAM: ${ram_gb}GB (minimum: ${MIN_RAM_GB}GB)"
        ((VALIDATION_ERRORS++))
    fi
    
    # Check disk space
    local disk_gb=$(df -BG / | tail -1 | awk '{print $4}' | sed 's/G//')
    if [[ $disk_gb -ge $MIN_DISK_GB ]]; then
        print_success "Available disk space: ${disk_gb}GB (minimum: ${MIN_DISK_GB}GB)"
        ((VALIDATION_PASSED++))
    else
        print_error "Insufficient disk space: ${disk_gb}GB (minimum: ${MIN_DISK_GB}GB)"
        ((VALIDATION_ERRORS++))
    fi
    
    # Check virtualization support
    if grep -q "vmx\|svm" /proc/cpuinfo; then
        print_success "Hardware virtualization support detected"
        ((VALIDATION_PASSED++))
    else
        print_error "Hardware virtualization not supported or not enabled"
        ((VALIDATION_ERRORS++))
    fi
    
    # Check KVM modules
    if lsmod | grep -q kvm; then
        print_success "KVM modules loaded"
        ((VALIDATION_PASSED++))
    else
        print_warning "KVM modules not loaded"
        ((VALIDATION_WARNINGS++))
    fi
}

# Check required packages
check_packages() {
    print_status "Checking required packages..."
    
    local required_packages=(
        "qemu-kvm:KVM hypervisor"
        "libvirt-daemon-system:Libvirt daemon"
        "libvirt-clients:Libvirt clients"
        "bridge-utils:Network bridging"
        "virt-manager:VM management GUI"
        "virtinst:VM installation tools"
        "curl:HTTP client"
        "wget:Download utility"
        "git:Version control"
        "docker.io:Container runtime"
    )
    
    for package_info in "${required_packages[@]}"; do
        local package=$(echo "$package_info" | cut -d: -f1)
        local description=$(echo "$package_info" | cut -d: -f2)
        
        if dpkg -l | grep -q "^ii  $package "; then
            print_success "$description ($package): Installed"
            ((VALIDATION_PASSED++))
        else
            print_warning "$description ($package): Not installed"
            ((VALIDATION_WARNINGS++))
        fi
    done
}

# Check libvirt configuration
check_libvirt() {
    print_status "Checking libvirt configuration..."
    
    # Check if libvirt daemon is running
    if systemctl is-active libvirtd &>/dev/null; then
        print_success "Libvirt daemon is running"
        ((VALIDATION_PASSED++))
    else
        print_error "Libvirt daemon is not running"
        ((VALIDATION_ERRORS++))
        return
    fi
    
    # Check libvirt connection
    if virsh list &>/dev/null; then
        print_success "Libvirt connection working"
        ((VALIDATION_PASSED++))
    else
        print_error "Cannot connect to libvirt daemon"
        ((VALIDATION_ERRORS++))
    fi
    
    # Check user permissions
    if groups | grep -q libvirt; then
        print_success "User is in libvirt group"
        ((VALIDATION_PASSED++))
    else
        print_warning "User is not in libvirt group"
        ((VALIDATION_WARNINGS++))
    fi
    
    # Check default network
    if virsh net-list --all | grep -q "default"; then
        local net_status=$(virsh net-list --all | grep "default" | awk '{print $2}')
        if [[ "$net_status" == "active" ]]; then
            print_success "Default libvirt network is active"
            ((VALIDATION_PASSED++))
        else
            print_warning "Default libvirt network exists but is not active"
            ((VALIDATION_WARNINGS++))
        fi
    else
        print_warning "Default libvirt network does not exist"
        ((VALIDATION_WARNINGS++))
    fi
    
    # Check storage pools
    local pools=$(virsh pool-list --all | grep -c "default\|homelab" || echo "0")
    if [[ $pools -gt 0 ]]; then
        print_success "Storage pools available: $pools"
        ((VALIDATION_PASSED++))
    else
        print_warning "No storage pools found"
        ((VALIDATION_WARNINGS++))
    fi
}

# Check network configuration
check_network() {
    print_status "Checking network configuration..."
    
    # Check network interfaces
    local interfaces=$(ip link show | grep -E "^[0-9]+:" | grep -v "lo:" | wc -l)
    if [[ $interfaces -gt 0 ]]; then
        print_success "Network interfaces available: $interfaces"
        ((VALIDATION_PASSED++))
    else
        print_error "No network interfaces found"
        ((VALIDATION_ERRORS++))
    fi
    
    # Check internet connectivity
    if ping -c 1 8.8.8.8 &>/dev/null; then
        print_success "Internet connectivity working"
        ((VALIDATION_PASSED++))
    else
        print_error "No internet connectivity"
        ((VALIDATION_ERRORS++))
    fi
    
    # Check DNS resolution
    if nslookup google.com &>/dev/null; then
        print_success "DNS resolution working"
        ((VALIDATION_PASSED++))
    else
        print_error "DNS resolution not working"
        ((VALIDATION_ERRORS++))
    fi
    
    # Check for bridge interfaces
    if ip link show | grep -q "virbr"; then
        print_success "Virtual bridge interfaces detected"
        ((VALIDATION_PASSED++))
    else
        print_warning "No virtual bridge interfaces found"
        ((VALIDATION_WARNINGS++))
    fi
}

# Check Docker installation and configuration
check_docker() {
    print_status "Checking Docker configuration..."
    
    # Check if Docker is installed
    if command -v docker &> /dev/null; then
        print_success "Docker is installed"
        ((VALIDATION_PASSED++))
        
        # Check Docker version
        local docker_version=$(docker --version | awk '{print $3}' | sed 's/,//')
        print_success "Docker version: $docker_version"
        
        # Check if Docker daemon is running
        if systemctl is-active docker &>/dev/null; then
            print_success "Docker daemon is running"
            ((VALIDATION_PASSED++))
        else
            print_error "Docker daemon is not running"
            ((VALIDATION_ERRORS++))
        fi
        
        # Check Docker permissions
        if groups | grep -q docker; then
            print_success "User is in docker group"
            ((VALIDATION_PASSED++))
        else
            print_warning "User is not in docker group"
            ((VALIDATION_WARNINGS++))
        fi
        
        # Test Docker functionality
        if docker run --rm hello-world &>/dev/null; then
            print_success "Docker functionality test passed"
            ((VALIDATION_PASSED++))
        else
            print_warning "Docker functionality test failed"
            ((VALIDATION_WARNINGS++))
        fi
    else
        print_warning "Docker is not installed"
        ((VALIDATION_WARNINGS++))
    fi
}

# Check monitoring tools
check_monitoring() {
    print_status "Checking monitoring tools..."
    
    # Check for Prometheus
    if command -v prometheus &> /dev/null; then
        print_success "Prometheus is installed"
        ((VALIDATION_PASSED++))
    else
        print_warning "Prometheus is not installed"
        ((VALIDATION_WARNINGS++))
    fi
    
    # Check for monitoring stack via Docker
    if docker ps | grep -q "prometheus\|grafana"; then
        print_success "Monitoring stack containers running"
        ((VALIDATION_PASSED++))
    else
        print_warning "No monitoring stack containers detected"
        ((VALIDATION_WARNINGS++))
    fi
    
    # Check monitoring ports
    local monitoring_ports=("9090" "3000" "9093")
    for port in "${monitoring_ports[@]}"; do
        if netstat -tuln 2>/dev/null | grep -q ":$port "; then
            print_success "Port $port is in use (monitoring service)"
            ((VALIDATION_PASSED++))
        else
            print_warning "Port $port is not in use"
            ((VALIDATION_WARNINGS++))
        fi
    done
}

# Check security configuration
check_security() {
    print_status "Checking security configuration..."
    
    # Check firewall status
    if command -v ufw &> /dev/null; then
        if ufw status | grep -q "Status: active"; then
            print_success "UFW firewall is active"
            ((VALIDATION_PASSED++))
        else
            print_warning "UFW firewall is installed but not active"
            ((VALIDATION_WARNINGS++))
        fi
    else
        print_warning "UFW firewall is not installed"
        ((VALIDATION_WARNINGS++))
    fi
    
    # Check fail2ban
    if command -v fail2ban-client &> /dev/null; then
        if systemctl is-active fail2ban &>/dev/null; then
            print_success "Fail2ban is active"
            ((VALIDATION_PASSED++))
        else
            print_warning "Fail2ban is installed but not active"
            ((VALIDATION_WARNINGS++))
        fi
    else
        print_warning "Fail2ban is not installed"
        ((VALIDATION_WARNINGS++))
    fi
    
    # Check SSH configuration
    if [[ -f /etc/ssh/sshd_config ]]; then
        if grep -q "^PasswordAuthentication no" /etc/ssh/sshd_config; then
            print_success "SSH password authentication is disabled"
            ((VALIDATION_PASSED++))
        else
            print_warning "SSH password authentication may be enabled"
            ((VALIDATION_WARNINGS++))
        fi
        
        if grep -q "^PermitRootLogin no" /etc/ssh/sshd_config; then
            print_success "SSH root login is disabled"
            ((VALIDATION_PASSED++))
        else
            print_warning "SSH root login may be enabled"
            ((VALIDATION_WARNINGS++))
        fi
    else
        print_error "SSH configuration file not found"
        ((VALIDATION_ERRORS++))
    fi
}

# Check project structure
check_project_structure() {
    print_status "Checking project structure..."
    
    local required_files=(
        "README.md:Project documentation"
        "setup-homelab.sh:Main setup script"
        "libvirt-manager.sh:VM management script"
        "storage/create-storage-pools.sh:Storage setup script"
        "networks/homelab-network.xml:Network configuration"
        "templates/homelab-node-template.xml:VM template"
    )
    
    local project_root
    if [[ -f "$SCRIPT_DIR/../README.md" ]]; then
        project_root="$SCRIPT_DIR/.."
    elif [[ -f "./README.md" ]]; then
        project_root="."
    else
        print_error "Cannot locate project root directory"
        ((VALIDATION_ERRORS++))
        return
    fi
    
    for file_info in "${required_files[@]}"; do
        local file=$(echo "$file_info" | cut -d: -f1)
        local description=$(echo "$file_info" | cut -d: -f2)
        
        if [[ -f "$project_root/$file" ]]; then
            print_success "$description: Found"
            ((VALIDATION_PASSED++))
        else
            print_warning "$description: Missing ($file)"
            ((VALIDATION_WARNINGS++))
        fi
    done
    
    # Check for scripts execution permissions
    local scripts=("setup-homelab.sh" "libvirt-manager.sh" "storage/create-storage-pools.sh")
    for script in "${scripts[@]}"; do
        if [[ -f "$project_root/$script" ]]; then
            if [[ -x "$project_root/$script" ]]; then
                print_success "Script $script has execute permissions"
                ((VALIDATION_PASSED++))
            else
                print_warning "Script $script lacks execute permissions"
                ((VALIDATION_WARNINGS++))
            fi
        fi
    done
}

# Perform infrastructure health check
check_infrastructure_health() {
    print_status "Checking infrastructure health..."
    
    # Check running VMs
    if command -v virsh &> /dev/null; then
        local running_vms=$(virsh list --state-running | grep -c "running" || echo "0")
        if [[ $running_vms -gt 0 ]]; then
            print_success "Running VMs: $running_vms"
            ((VALIDATION_PASSED++))
        else
            print_warning "No VMs currently running"
            ((VALIDATION_WARNINGS++))
        fi
        
        # Check VM resources
        local total_vms=$(virsh list --all | grep -c "homelab" || echo "0")
        if [[ $total_vms -gt 0 ]]; then
            print_success "Total homelab VMs: $total_vms"
            ((VALIDATION_PASSED++))
        else
            print_warning "No homelab VMs found"
            ((VALIDATION_WARNINGS++))
        fi
    fi
    
    # Check system load
    local load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    local load_threshold="2.0"
    if (( $(echo "$load_avg < $load_threshold" | bc -l) )); then
        print_success "System load average: $load_avg (acceptable)"
        ((VALIDATION_PASSED++))
    else
        print_warning "High system load average: $load_avg"
        ((VALIDATION_WARNINGS++))
    fi
    
    # Check memory usage
    local mem_usage=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')
    local mem_threshold="80.0"
    if (( $(echo "$mem_usage < $mem_threshold" | bc -l) )); then
        print_success "Memory usage: ${mem_usage}% (acceptable)"
        ((VALIDATION_PASSED++))
    else
        print_warning "High memory usage: ${mem_usage}%"
        ((VALIDATION_WARNINGS++))
    fi
    
    # Check disk usage
    local disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    local disk_threshold="80"
    if [[ $disk_usage -lt $disk_threshold ]]; then
        print_success "Disk usage: ${disk_usage}% (acceptable)"
        ((VALIDATION_PASSED++))
    else
        print_warning "High disk usage: ${disk_usage}%"
        ((VALIDATION_WARNINGS++))
    fi
}

# Fix common issues
fix_issues() {
    print_status "Attempting to fix common issues..."
    
    # Start libvirt daemon if not running
    if ! systemctl is-active libvirtd &>/dev/null; then
        print_status "Starting libvirt daemon..."
        sudo systemctl start libvirtd
        sudo systemctl enable libvirtd
    fi
    
    # Add user to required groups
    if ! groups | grep -q libvirt; then
        print_status "Adding user to libvirt group..."
        sudo usermod -a -G libvirt "$USER"
        print_warning "Please log out and log back in for group changes to take effect"
    fi
    
    if ! groups | grep -q docker; then
        print_status "Adding user to docker group..."
        sudo usermod -a -G docker "$USER"
        print_warning "Please log out and log back in for group changes to take effect"
    fi
    
    # Start default libvirt network
    if virsh net-list --all | grep -q "default.*inactive"; then
        print_status "Starting default libvirt network..."
        virsh net-start default
        virsh net-autostart default
    fi
    
    # Create homelab storage pool if missing
    if ! virsh pool-list --all | grep -q "homelab"; then
        print_status "Creating homelab storage pool..."
        if [[ -x "$SCRIPT_DIR/../storage/create-storage-pools.sh" ]]; then
            "$SCRIPT_DIR/../storage/create-storage-pools.sh" create-homelab
        fi
    fi
    
    # Set execute permissions on scripts
    local scripts=("$SCRIPT_DIR/../setup-homelab.sh" "$SCRIPT_DIR/../libvirt-manager.sh")
    for script in "${scripts[@]}"; do
        if [[ -f "$script" ]] && [[ ! -x "$script" ]]; then
            print_status "Setting execute permissions on $(basename "$script")"
            chmod +x "$script"
        fi
    done
    
    print_success "Common issues fix attempt complete"
}

# Generate validation report
generate_report() {
    print_status "Generating validation report..."
    
    local report_file="/tmp/homelab-validation-report-$(date +%Y%m%d_%H%M%S).txt"
    
    cat > "$report_file" << EOF
Homelab Environment Validation Report
====================================
Generated: $(date)
System: $(hostname) ($(lsb_release -d | cut -f2 2>/dev/null || echo "Unknown"))

Summary:
- Checks Passed: $VALIDATION_PASSED
- Warnings: $VALIDATION_WARNINGS  
- Errors: $VALIDATION_ERRORS

System Requirements:
- CPU Cores: $(nproc) (minimum: $MIN_CPU_CORES)
- RAM: $(free -h | grep "Mem:" | awk '{print $2}') (minimum: ${MIN_RAM_GB}GB)
- Disk Space: $(df -h / | tail -1 | awk '{print $4}') available (minimum: ${MIN_DISK_GB}GB)
- Virtualization: $(grep -q "vmx\|svm" /proc/cpuinfo && echo "Supported" || echo "Not supported")

Service Status:
$(systemctl is-active libvirtd &>/dev/null && echo "✅ libvirtd: Active" || echo "❌ libvirtd: Inactive")
$(systemctl is-active docker &>/dev/null && echo "✅ docker: Active" || echo "❌ docker: Inactive")
$(command -v virsh &>/dev/null && echo "✅ libvirt-clients: Installed" || echo "❌ libvirt-clients: Not installed")

Network Status:
$(ping -c 1 8.8.8.8 &>/dev/null && echo "✅ Internet: Connected" || echo "❌ Internet: Disconnected")
$(nslookup google.com &>/dev/null && echo "✅ DNS: Working" || echo "❌ DNS: Not working")

Security Status:
$(command -v ufw &>/dev/null && ufw status | grep -q "active" && echo "✅ UFW: Active" || echo "❌ UFW: Inactive")
$(systemctl is-active fail2ban &>/dev/null && echo "✅ Fail2ban: Active" || echo "❌ Fail2ban: Inactive")

Recommendations:
EOF

    if [[ $VALIDATION_ERRORS -gt 0 ]]; then
        echo "- Fix critical errors before proceeding with homelab setup" >> "$report_file"
    fi
    
    if [[ $VALIDATION_WARNINGS -gt 0 ]]; then
        echo "- Review warnings and consider addressing them" >> "$report_file"
    fi
    
    if [[ $VALIDATION_ERRORS -eq 0 ]] && [[ $VALIDATION_WARNINGS -eq 0 ]]; then
        echo "- System is ready for homelab deployment!" >> "$report_file"
    fi
    
    echo "" >> "$report_file"
    echo "Detailed log: $LOG_FILE" >> "$report_file"
    
    cat "$report_file"
    print_success "Validation report saved to: $report_file"
}

# Display final summary
display_summary() {
    echo ""
    echo "======================================"
    echo "Environment Validation Summary"
    echo "======================================"
    
    if [[ $VALIDATION_ERRORS -eq 0 ]] && [[ $VALIDATION_WARNINGS -eq 0 ]]; then
        print_success "All checks passed! System is ready for homelab deployment."
        echo ""
        echo "Next steps:"
        echo "1. Run ./setup-homelab.sh to create VMs"
        echo "2. Use ./libvirt-manager.sh to manage VMs"
        echo "3. Deploy monitoring stack with docker-compose"
    elif [[ $VALIDATION_ERRORS -eq 0 ]]; then
        print_warning "$VALIDATION_WARNINGS warning(s) found. System should work but may have issues."
        echo ""
        echo "Consider running: $0 --fix"
    else
        print_error "$VALIDATION_ERRORS critical error(s) found. Please fix before proceeding."
        echo ""
        echo "Try running: $0 --fix"
    fi
    
    echo ""
    echo "Summary: $VALIDATION_PASSED passed, $VALIDATION_WARNINGS warnings, $VALIDATION_ERRORS errors"
}

# Main execution logic
main() {
    local mode="${1:-full}"
    
    init_validation
    
    case "$mode" in
        --quick)
            print_status "Running quick validation check..."
            check_system_requirements
            check_libvirt
            check_network
            ;;
        --full)
            print_status "Running full validation check..."
            check_system_requirements
            check_packages
            check_libvirt
            check_network
            check_docker
            check_monitoring
            check_security
            check_project_structure
            check_infrastructure_health
            ;;
        --fix)
            print_status "Running validation with auto-fix..."
            check_system_requirements
            check_packages
            check_libvirt
            check_network
            fix_issues
            ;;
        *)
            echo "Usage: $0 [--quick|--full|--fix]"
            echo ""
            echo "Options:"
            echo "  --quick  Run basic system checks only"
            echo "  --full   Run comprehensive validation (default)"
            echo "  --fix    Run validation and attempt to fix issues"
            echo ""
            echo "Examples:"
            echo "  $0 --quick    # Quick system check"
            echo "  $0 --full     # Full validation"
            echo "  $0 --fix      # Fix common issues"
            exit 1
            ;;
    esac
    
    generate_report
    display_summary
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 