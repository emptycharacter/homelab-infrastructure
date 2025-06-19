# Contributing to Homelab Infrastructure

Thank you for your interest in contributing to this homelab infrastructure project! This repository serves as both a learning platform and a showcase of enterprise-level infrastructure practices.

## 🎯 Project Goals

- Demonstrate modern infrastructure and DevOps practices
- Provide educational examples for enterprise networking and virtualization
- Showcase automation and infrastructure-as-code principles
- Maintain production-quality code and documentation standards

## 🚀 Getting Started

### Prerequisites

- Linux system with KVM/libvirt support
- Minimum 16GB RAM (32GB recommended)
- 100GB+ available storage
- Basic understanding of virtualization and networking concepts

### Development Environment Setup

1. **Clone the repository:**
   ```bash
   git clone https://github.com/your-username/homelab-infrastructure.git
   cd homelab-infrastructure
   ```

2. **Install dependencies:**
   ```bash
   # Ubuntu/Debian
   sudo apt install qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils
   sudo apt install virtinst genisoimage curl wget
   
   # Add user to libvirt group
   sudo usermod -a -G libvirt $USER
   ```

3. **Validate installation:**
   ```bash
   ./scripts/validate-environment.sh
   ```

## 📋 Code Standards

### Shell Scripting Standards

- **Shebang:** Always use `#!/bin/bash`
- **Error handling:** Use `set -e` and proper error checking
- **Variables:** Use uppercase for constants, lowercase for local variables
- **Functions:** Clear, descriptive names with proper documentation
- **Logging:** Implement colored output with consistent format

**Example:**
```bash
#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

validate_prerequisites() {
    if ! command -v virsh >/dev/null 2>&1; then
        print_error "libvirt not found"
        return 1
    fi
}
```

### Documentation Standards

- **Comments:** Explain complex logic and business decisions
- **README files:** Every major component should have documentation
- **Examples:** Include working configuration examples
- **Architecture decisions:** Document rationale for technical choices

### Configuration Management

- **Templates:** Use placeholder variables for reusable configurations
- **Validation:** Include configuration validation scripts
- **Versioning:** Track configuration changes with meaningful commit messages
- **Security:** Never commit sensitive data or credentials

## 🔧 Development Workflow

### Branch Strategy

- **main:** Production-ready code only
- **develop:** Integration branch for new features
- **feature/\<name\>:** Individual feature development
- **hotfix/\<name\>:** Critical bug fixes

### Commit Message Format

```
type(scope): brief description

Detailed explanation of changes made and why.

Closes #issue-number
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `refactor`: Code improvements without functional changes
- `test`: Adding or updating tests
- `ci`: CI/CD changes

**Examples:**
```
feat(networking): add multi-VLAN support with security policies

Added support for creating multiple VLANs with granular firewall rules.
Implements network segmentation best practices for homelab environments.

Closes #15
```

### Pull Request Process

1. **Create feature branch** from `develop`
2. **Implement changes** following code standards
3. **Test thoroughly** in local environment
4. **Update documentation** as needed
5. **Submit pull request** with detailed description
6. **Address review feedback** promptly
7. **Squash commits** before merge if requested

### Testing Requirements

- **Script validation:** All scripts must pass shellcheck
- **Functional testing:** Test in clean environment
- **Documentation:** Verify all examples work as documented
- **Security review:** Check for security implications

## 🔍 Code Review Guidelines

### For Contributors

- **Self-review:** Review your own changes before submitting
- **Clear description:** Explain what and why, not just what
- **Small changes:** Keep PRs focused and manageable
- **Tests:** Include testing steps in PR description

### For Reviewers

- **Constructive feedback:** Focus on code quality and standards
- **Security mindset:** Consider security implications
- **Documentation:** Ensure changes are properly documented
- **Learning opportunity:** Help contributors improve their skills

## 🏗️ Architecture Guidelines

### Infrastructure as Code Principles

- **Declarative:** Describe desired state, not steps
- **Idempotent:** Safe to run multiple times
- **Version controlled:** All infrastructure changes tracked
- **Modular:** Reusable components and configurations

### Security Considerations

- **Defense in depth:** Multiple security layers
- **Least privilege:** Minimal required permissions
- **Encryption:** Data in transit and at rest
- **Monitoring:** Comprehensive logging and alerting

### Scalability Planning

- **Resource management:** Efficient resource utilization
- **Horizontal scaling:** Design for growth
- **Performance monitoring:** Track and optimize performance
- **Capacity planning:** Plan for future requirements

## 📚 Learning Resources

### Recommended Reading

- **Infrastructure:** "Infrastructure as Code" by Kief Morris
- **Networking:** "Computer Networking: A Top-Down Approach"
- **Security:** "The Practice of System and Network Administration"
- **DevOps:** "The DevOps Handbook" by Gene Kim

### Online Resources

- [Libvirt Documentation](https://libvirt.org/docs.html)
- [KVM Documentation](https://www.linux-kvm.org/page/Documents)
- [Networking Fundamentals](https://www.cloudflare.com/learning/network-layer/)
- [Infrastructure as Code Best Practices](https://docs.aws.amazon.com/whitepapers/latest/introduction-devops-aws/infrastructure-as-code.html)

## 🐛 Issue Reporting

### Bug Reports

Use the bug report template and include:

- **Environment details:** OS, versions, hardware specs
- **Reproduction steps:** Clear, step-by-step instructions
- **Expected vs actual behavior:** What should happen vs what does
- **Logs and errors:** Relevant error messages or log files
- **Screenshots:** Visual evidence when applicable

### Feature Requests

Use the feature request template and include:

- **Problem statement:** What problem does this solve?
- **Proposed solution:** High-level approach
- **Alternatives considered:** Other solutions evaluated
- **Additional context:** Use cases, examples, references

## 🎓 Learning Focus Areas

This project emphasizes learning enterprise practices:

- **Network Architecture:** VLAN design, security policies, monitoring
- **Virtualization:** KVM, libvirt, resource management, automation
- **Infrastructure Automation:** Scripting, configuration management, CI/CD
- **Security Engineering:** Hardening, monitoring, incident response
- **Platform Engineering:** Self-service infrastructure, developer experience

## 📞 Getting Help

- **Documentation:** Check README files and inline comments
- **Issues:** Search existing issues before creating new ones
- **Discussions:** Use GitHub Discussions for questions and ideas
- **Community:** Join relevant Discord/Slack communities for broader support

## 🙏 Recognition

Contributors will be recognized in:

- **README contributors section**
- **Release notes** for significant contributions
- **LinkedIn recommendations** for substantial contributions (with permission)

---

By contributing to this project, you're not just improving code – you're helping create educational resources that demonstrate enterprise-level infrastructure practices. Thank you for being part of this learning journey! 🚀 