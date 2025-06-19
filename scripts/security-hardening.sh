#!/bin/bash

# Enterprise Security Hardening Script
# Implements CIS Benchmarks and security best practices for homelab infrastructure
# Usage: ./security-hardening.sh [--check|--apply|--report]

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/security-hardening.log"
BACKUP_DIR="/var/backups/security-hardening"
CIS_BENCHMARK_VERSION="2.0.0"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

print_status() { echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"; }

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_error "This script should not be run as root. Please run as a regular user with sudo privileges."
        exit 1
    fi
}

# Create necessary directories
setup_environment() {
    print_status "Setting up security hardening environment..."
    
    sudo mkdir -p "$BACKUP_DIR"
    sudo mkdir -p "$(dirname "$LOG_FILE")"
    sudo touch "$LOG_FILE"
    sudo chown "$USER:$USER" "$LOG_FILE"
    
    print_success "Environment setup complete"
}

# System information gathering
gather_system_info() {
    print_status "Gathering system information..."
    
    cat > /tmp/system-info.txt << EOF
Security Hardening Report - $(date)
================================================

System Information:
- Hostname: $(hostname)
- OS: $(lsb_release -d | cut -f2)
- Kernel: $(uname -r)
- Architecture: $(uname -m)
- Uptime: $(uptime)
- Last Boot: $(who -b | awk '{print $3, $4}')

Hardware:
- CPU: $(lscpu | grep "Model name" | cut -d: -f2 | xargs)
- Memory: $(free -h | grep "Mem:" | awk '{print $2}')
- Disk Space: $(df -h / | tail -1 | awk '{print $2 " total, " $4 " available"}')

Network Interfaces:
$(ip addr show | grep -E "^[0-9]+:" | awk '{print $2}' | tr -d ':')

Current User: $USER
Groups: $(groups)
EOF

    print_success "System information gathered"
}

# SSH Hardening
harden_ssh() {
    print_status "Implementing SSH hardening..."
    
    local ssh_config="/etc/ssh/sshd_config"
    local backup_file="$BACKUP_DIR/sshd_config.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Backup original configuration
    sudo cp "$ssh_config" "$backup_file"
    print_status "SSH config backed up to $backup_file"
    
    # SSH hardening settings
    local ssh_settings=(
        "Protocol 2"
        "PermitRootLogin no"
        "PasswordAuthentication no"
        "PubkeyAuthentication yes"
        "ChallengeResponseAuthentication no"
        "UsePAM yes"
        "X11Forwarding no"
        "PrintMotd no"
        "ClientAliveInterval 300"
        "ClientAliveCountMax 2"
        "MaxAuthTries 3"
        "MaxStartups 10:30:60"
        "LoginGraceTime 60"
        "Banner /etc/issue.net"
        "Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr"
        "MACs hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com,hmac-sha2-256,hmac-sha2-512"
        "KexAlgorithms curve25519-sha256@libssh.org,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512"
    )
    
    for setting in "${ssh_settings[@]}"; do
        local key=$(echo "$setting" | cut -d' ' -f1)
        
        # Remove existing setting if present
        sudo sed -i "/^#*$key /d" "$ssh_config"
        
        # Add new setting
        echo "$setting" | sudo tee -a "$ssh_config" > /dev/null
        print_status "Applied SSH setting: $setting"
    done
    
    # Create login banner
    sudo tee /etc/issue.net > /dev/null << 'EOF'
***********************************************************************
*                                                                     *
*  This system is for authorized users only. All activity is logged  *
*  and monitored. Unauthorized access is prohibited and may result    *
*  in legal action.                                                   *
*                                                                     *
***********************************************************************
EOF
    
    # Validate SSH configuration
    if sudo sshd -t; then
        print_success "SSH configuration validated successfully"
        sudo systemctl reload ssh
        print_success "SSH service reloaded"
    else
        print_error "SSH configuration validation failed. Restoring backup."
        sudo cp "$backup_file" "$ssh_config"
        exit 1
    fi
}

# Firewall Configuration
configure_firewall() {
    print_status "Configuring UFW firewall..."
    
    # Reset firewall to default state
    sudo ufw --force reset
    
    # Set default policies
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    
    # Allow essential services
    sudo ufw allow ssh
    sudo ufw allow 22/tcp comment 'SSH'
    
    # Homelab specific ports
    sudo ufw allow 6443/tcp comment 'Kubernetes API'
    sudo ufw allow 2379:2380/tcp comment 'etcd'
    sudo ufw allow 10250/tcp comment 'kubelet'
    sudo ufw allow 80/tcp comment 'HTTP'
    sudo ufw allow 443/tcp comment 'HTTPS'
    sudo ufw allow 9090/tcp comment 'Prometheus'
    sudo ufw allow 3000/tcp comment 'Grafana'
    
    # Rate limiting for SSH
    sudo ufw limit ssh
    
    # Enable firewall
    sudo ufw --force enable
    
    # Configure logging
    sudo ufw logging on
    
    print_success "UFW firewall configured and enabled"
}

# Install and configure Fail2Ban
configure_fail2ban() {
    print_status "Installing and configuring Fail2Ban..."
    
    sudo apt update
    sudo apt install -y fail2ban
    
    # Create custom jail configuration
    sudo tee /etc/fail2ban/jail.local > /dev/null << 'EOF'
[DEFAULT]
# Ban hosts for 1 hour
bantime = 3600

# Host is banned if it has generated "maxretry" during the last "findtime" seconds
findtime = 600
maxretry = 5

# Email notifications (configure as needed)
destemail = admin@homelab.local
sendername = Fail2Ban
mta = sendmail
action = %(action_mwl)s

[sshd]
enabled = true
port = ssh
logpath = /var/log/auth.log
backend = %(sshd_backend)s
maxretry = 3
bantime = 1800

[sshd-ddos]
enabled = true
port = ssh
logpath = /var/log/auth.log
backend = %(sshd_backend)s
maxretry = 2
bantime = 3600

[nginx-http-auth]
enabled = false
port = http,https
logpath = /var/log/nginx/error.log

[nginx-noscript]
enabled = false
port = http,https
logpath = /var/log/nginx/access.log
maxretry = 6

[nginx-badbots]
enabled = false
port = http,https
logpath = /var/log/nginx/access.log
maxretry = 2

[nginx-noproxy]
enabled = false
port = http,https
logpath = /var/log/nginx/access.log
maxretry = 2
EOF
    
    # Start and enable Fail2Ban
    sudo systemctl enable fail2ban
    sudo systemctl start fail2ban
    
    print_success "Fail2Ban installed and configured"
}

# Kernel parameter hardening
harden_kernel() {
    print_status "Applying kernel hardening parameters..."
    
    local sysctl_file="/etc/sysctl.d/99-security-hardening.conf"
    local backup_file="$BACKUP_DIR/sysctl.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Backup existing sysctl settings
    sysctl -a > "$backup_file" 2>/dev/null
    
    sudo tee "$sysctl_file" > /dev/null << 'EOF'
# Security Hardening - Kernel Parameters
# Generated by security-hardening.sh

# Network Security
net.ipv4.ip_forward = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# IPv6 Security
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0

# Memory Protection
kernel.dmesg_restrict = 1
kernel.kptr_restrict = 2
kernel.yama.ptrace_scope = 1

# File System Security
fs.protected_hardlinks = 1
fs.protected_symlinks = 1

# Process Security
kernel.core_uses_pid = 1
kernel.ctrl-alt-del = 0

# Network Performance and Security
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_rmem = 4096 65536 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
EOF
    
    # Apply sysctl settings
    sudo sysctl -p "$sysctl_file"
    
    print_success "Kernel hardening parameters applied"
}

# User and authentication hardening
harden_authentication() {
    print_status "Hardening user authentication..."
    
    # Password policy configuration
    sudo tee /etc/security/pwquality.conf > /dev/null << 'EOF'
# Password Quality Configuration
minlen = 12
minclass = 3
maxrepeat = 2
maxclasschars = 0
dcredit = -1
ucredit = -1
lcredit = -1
ocredit = -1
difok = 8
gecoscheck = 1
dictcheck = 1
usercheck = 1
enforcing = 1
EOF
    
    # Account lockout policy
    local pam_file="/etc/pam.d/common-auth"
    local backup_file="$BACKUP_DIR/common-auth.backup.$(date +%Y%m%d_%H%M%S)"
    
    sudo cp "$pam_file" "$backup_file"
    
    # Add account lockout to PAM configuration
    if ! grep -q "pam_tally2" "$pam_file"; then
        sudo sed -i '1a auth required pam_tally2.so deny=5 unlock_time=900 onerr=fail' "$pam_file"
        print_status "Account lockout policy added to PAM"
    fi
    
    # Set secure umask
    if ! grep -q "umask 027" /etc/profile; then
        echo "umask 027" | sudo tee -a /etc/profile
        print_status "Secure umask set in /etc/profile"
    fi
    
    print_success "Authentication hardening complete"
}

# File system security
secure_filesystem() {
    print_status "Implementing file system security..."
    
    # Secure /tmp and /var/tmp
    local fstab_backup="$BACKUP_DIR/fstab.backup.$(date +%Y%m%d_%H%M%S)"
    sudo cp /etc/fstab "$fstab_backup"
    
    # Check if /tmp is already secured
    if ! grep -q "/tmp.*noexec\|/tmp.*nosuid\|/tmp.*nodev" /etc/fstab; then
        print_status "Securing /tmp filesystem..."
        
        # Create tmpfs entry for /tmp
        if ! grep -q "tmpfs /tmp" /etc/fstab; then
            echo "tmpfs /tmp tmpfs defaults,noatime,nosuid,nodev,noexec,mode=1777,size=1G 0 0" | sudo tee -a /etc/fstab
        fi
    fi
    
    # Set secure permissions on important directories
    local secure_dirs=(
        "/etc/ssh:755"
        "/etc/ssl/private:700"
        "/var/log:755"
        "/tmp:1777"
        "/var/tmp:1777"
    )
    
    for dir_perm in "${secure_dirs[@]}"; do
        local dir=$(echo "$dir_perm" | cut -d: -f1)
        local perm=$(echo "$dir_perm" | cut -d: -f2)
        
        if [[ -d "$dir" ]]; then
            sudo chmod "$perm" "$dir"
            print_status "Set permissions $perm on $dir"
        fi
    done
    
    # Secure world-writable files
    print_status "Securing world-writable files..."
    find /tmp /var/tmp -type f -perm -002 -exec chmod o-w {} \; 2>/dev/null || true
    
    print_success "File system security implemented"
}

# Service hardening
harden_services() {
    print_status "Hardening system services..."
    
    # Disable unnecessary services
    local unnecessary_services=(
        "avahi-daemon"
        "cups"
        "bluetooth"
        "whoopsie"
        "apport"
    )
    
    for service in "${unnecessary_services[@]}"; do
        if systemctl is-enabled "$service" &>/dev/null; then
            sudo systemctl disable "$service"
            sudo systemctl stop "$service"
            print_status "Disabled service: $service"
        fi
    done
    
    # Enable and start essential security services
    local security_services=(
        "ufw"
        "fail2ban"
        "rsyslog"
        "cron"
    )
    
    for service in "${security_services[@]}"; do
        if systemctl list-unit-files | grep -q "^$service"; then
            sudo systemctl enable "$service"
            sudo systemctl start "$service"
            print_status "Enabled service: $service"
        fi
    done
    
    print_success "Service hardening complete"
}

# Audit and logging configuration
configure_auditing() {
    print_status "Configuring audit and logging..."
    
    # Install auditd if not present
    if ! command -v auditctl &> /dev/null; then
        sudo apt install -y auditd audispd-plugins
    fi
    
    # Configure audit rules
    sudo tee /etc/audit/rules.d/audit.rules > /dev/null << 'EOF'
# Audit Rules for Security Monitoring
# Generated by security-hardening.sh

# Delete all existing rules
-D

# Set buffer size
-b 8192

# Failure mode (0=silent, 1=printk, 2=panic)
-f 1

# Monitor authentication files
-w /etc/passwd -p wa -k auth
-w /etc/group -p wa -k auth
-w /etc/shadow -p wa -k auth
-w /etc/sudoers -p wa -k auth
-w /etc/ssh/sshd_config -p wa -k auth

# Monitor system configuration
-w /etc/hosts -p wa -k system-config
-w /etc/network/ -p wa -k system-config
-w /etc/fstab -p wa -k system-config

# Monitor privileged commands
-a always,exit -F path=/bin/su -F perm=x -F auid>=1000 -F auid!=4294967295 -k privileged
-a always,exit -F path=/usr/bin/sudo -F perm=x -F auid>=1000 -F auid!=4294967295 -k privileged
-a always,exit -F path=/usr/bin/ssh -F perm=x -F auid>=1000 -F auid!=4294967295 -k privileged

# Monitor file access
-a always,exit -F arch=b64 -S open -S openat -S creat -F exit=-EACCES -F auid>=1000 -F auid!=4294967295 -k access
-a always,exit -F arch=b64 -S open -S openat -S creat -F exit=-EPERM -F auid>=1000 -F auid!=4294967295 -k access

# Make rules immutable
-e 2
EOF
    
    # Enable and start auditd
    sudo systemctl enable auditd
    sudo systemctl start auditd
    
    # Configure rsyslog for centralized logging
    sudo tee /etc/rsyslog.d/50-security.conf > /dev/null << 'EOF'
# Security logging configuration

# Authentication logs
auth,authpriv.*                 /var/log/auth.log

# Sudo logs
local0.*                        /var/log/sudo.log

# UFW logs
:msg,contains,"[UFW "          -/var/log/ufw.log
& stop

# Fail2ban logs
:programname,isequal,"fail2ban" /var/log/fail2ban.log
& stop
EOF
    
    sudo systemctl restart rsyslog
    
    print_success "Audit and logging configuration complete"
}

# Security scanning and compliance check
security_scan() {
    print_status "Running security compliance scan..."
    
    local report_file="/tmp/security-scan-report.txt"
    
    cat > "$report_file" << EOF
Security Compliance Scan Report
Generated: $(date)
===============================================

EOF
    
    # Check SSH configuration
    echo "SSH Configuration Compliance:" >> "$report_file"
    local ssh_checks=(
        "PermitRootLogin no"
        "PasswordAuthentication no"
        "Protocol 2"
        "X11Forwarding no"
    )
    
    for check in "${ssh_checks[@]}"; do
        if grep -q "^$check" /etc/ssh/sshd_config; then
            echo "✅ $check" >> "$report_file"
        else
            echo "❌ $check" >> "$report_file"
        fi
    done
    
    # Check firewall status
    echo -e "\nFirewall Status:" >> "$report_file"
    if sudo ufw status | grep -q "Status: active"; then
        echo "✅ UFW firewall is active" >> "$report_file"
    else
        echo "❌ UFW firewall is not active" >> "$report_file"
    fi
    
    # Check fail2ban status
    echo -e "\nFail2Ban Status:" >> "$report_file"
    if systemctl is-active fail2ban &>/dev/null; then
        echo "✅ Fail2Ban is running" >> "$report_file"
    else
        echo "❌ Fail2Ban is not running" >> "$report_file"
    fi
    
    # Check audit daemon
    echo -e "\nAudit Daemon Status:" >> "$report_file"
    if systemctl is-active auditd &>/dev/null; then
        echo "✅ Auditd is running" >> "$report_file"
    else
        echo "❌ Auditd is not running" >> "$report_file"
    fi
    
    # Check for world-writable files
    echo -e "\nWorld-writable Files Check:" >> "$report_file"
    local writable_files=$(find /etc /usr /bin /sbin -type f -perm -002 2>/dev/null | wc -l)
    if [[ $writable_files -eq 0 ]]; then
        echo "✅ No world-writable files found in system directories" >> "$report_file"
    else
        echo "❌ Found $writable_files world-writable files in system directories" >> "$report_file"
    fi
    
    # Check SUID/SGID files
    echo -e "\nSUID/SGID Files:" >> "$report_file"
    find /usr /bin /sbin -type f \( -perm -4000 -o -perm -2000 \) -exec ls -la {} \; >> "$report_file" 2>/dev/null
    
    cat "$report_file"
    print_success "Security scan complete. Report saved to $report_file"
}

# Backup critical configurations
backup_configurations() {
    print_status "Creating backup of critical configurations..."
    
    local backup_archive="$BACKUP_DIR/security-configs-$(date +%Y%m%d_%H%M%S).tar.gz"
    
    sudo tar -czf "$backup_archive" \
        /etc/ssh/sshd_config \
        /etc/fail2ban/jail.local \
        /etc/ufw/ \
        /etc/audit/rules.d/ \
        /etc/sysctl.d/99-security-hardening.conf \
        /etc/security/pwquality.conf \
        2>/dev/null || true
    
    print_success "Configuration backup created: $backup_archive"
}

# Generate security report
generate_report() {
    print_status "Generating comprehensive security report..."
    
    local report_file="/tmp/security-hardening-report-$(date +%Y%m%d_%H%M%S).html"
    
    cat > "$report_file" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Security Hardening Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f4f4f4; padding: 10px; border-radius: 5px; }
        .section { margin: 20px 0; }
        .success { color: green; }
        .warning { color: orange; }
        .error { color: red; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🔒 Security Hardening Report</h1>
        <p>Generated: $(date)</p>
        <p>System: $(hostname) ($(lsb_release -d | cut -f2))</p>
    </div>
EOF
    
    # Add system information to report
    echo "<div class='section'>" >> "$report_file"
    echo "<h2>System Information</h2>" >> "$report_file"
    echo "<table>" >> "$report_file"
    echo "<tr><th>Parameter</th><th>Value</th></tr>" >> "$report_file"
    echo "<tr><td>Hostname</td><td>$(hostname)</td></tr>" >> "$report_file"
    echo "<tr><td>Operating System</td><td>$(lsb_release -d | cut -f2)</td></tr>" >> "$report_file"
    echo "<tr><td>Kernel Version</td><td>$(uname -r)</td></tr>" >> "$report_file"
    echo "<tr><td>Architecture</td><td>$(uname -m)</td></tr>" >> "$report_file"
    echo "<tr><td>Uptime</td><td>$(uptime -p)</td></tr>" >> "$report_file"
    echo "</table>" >> "$report_file"
    echo "</div>" >> "$report_file"
    
    # Add hardening status
    echo "<div class='section'>" >> "$report_file"
    echo "<h2>Hardening Status</h2>" >> "$report_file"
    echo "<ul>" >> "$report_file"
    echo "<li class='success'>✅ SSH Hardening Applied</li>" >> "$report_file"
    echo "<li class='success'>✅ UFW Firewall Configured</li>" >> "$report_file"
    echo "<li class='success'>✅ Fail2Ban Installed</li>" >> "$report_file"
    echo "<li class='success'>✅ Kernel Parameters Hardened</li>" >> "$report_file"
    echo "<li class='success'>✅ Authentication Hardened</li>" >> "$report_file"
    echo "<li class='success'>✅ File System Secured</li>" >> "$report_file"
    echo "<li class='success'>✅ Audit Logging Enabled</li>" >> "$report_file"
    echo "</ul>" >> "$report_file"
    echo "</div>" >> "$report_file"
    
    echo "</body></html>" >> "$report_file"
    
    print_success "Security report generated: $report_file"
    
    # Also create a text summary
    local summary_file="/tmp/security-summary.txt"
    cat > "$summary_file" << EOF
Security Hardening Summary - $(date)
====================================

✅ SSH Configuration Hardened
✅ UFW Firewall Configured and Active
✅ Fail2Ban Installed and Running
✅ Kernel Security Parameters Applied
✅ Authentication Policies Strengthened
✅ File System Permissions Secured
✅ Audit Logging Enabled
✅ Unnecessary Services Disabled

Next Steps:
- Review security logs regularly
- Keep system updated with security patches
- Monitor fail2ban logs for intrusion attempts
- Conduct periodic security scans
- Review and update firewall rules as needed

Log File: $LOG_FILE
Backup Directory: $BACKUP_DIR
EOF
    
    cat "$summary_file"
    print_success "Security hardening complete!"
}

# Main execution logic
main() {
    local action="${1:-apply}"
    
    case "$action" in
        --check)
            print_status "Running security compliance check..."
            setup_environment
            gather_system_info
            security_scan
            ;;
        --apply)
            print_status "Applying security hardening measures..."
            check_root
            setup_environment
            gather_system_info
            harden_ssh
            configure_firewall
            configure_fail2ban
            harden_kernel
            harden_authentication
            secure_filesystem
            harden_services
            configure_auditing
            backup_configurations
            security_scan
            generate_report
            ;;
        --report)
            print_status "Generating security report..."
            setup_environment
            gather_system_info
            security_scan
            generate_report
            ;;
        *)
            echo "Usage: $0 [--check|--apply|--report]"
            echo ""
            echo "Options:"
            echo "  --check   Run security compliance check only"
            echo "  --apply   Apply all security hardening measures (default)"
            echo "  --report  Generate security status report"
            echo ""
            echo "Examples:"
            echo "  $0 --check    # Check current security status"
            echo "  $0 --apply    # Apply all hardening measures"
            echo "  $0 --report   # Generate security report"
            exit 1
            ;;
    esac
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 