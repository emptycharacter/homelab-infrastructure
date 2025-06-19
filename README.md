# Homelab Infrastructure

My personal homelab learning journey - exploring networking, virtualization, and automation concepts through hands-on experimentation over the past two years as a CS student.

## 🎓 Overview

This repository documents my homelab learning adventure. As a computer science student, I've been exploring how enterprise networking and infrastructure actually work by building and breaking things in my own environment.

**What I'm Learning:**
- Network segmentation and security principles (VLANs, firewalls, VPNs)
- Virtualization basics with KVM and Proxmox
- How to automate repetitive tasks (still figuring this out!)
- Documentation and troubleshooting practices
- Why enterprise networks are designed the way they are

**Current Status:**
- Been running for 18+ months with decent uptime (when I don't break things while learning)
- Services go up and down as I experiment with new configs and try new things
- Sometimes I accidentally break networking while testing VLANs or trying new setups
- Usually back up within a few hours once I figure out what I did wrong
- 5 VLANs that took me forever to understand and configure properly
- A mix of VMs for different experiments and learning projects
- Scripts that sometimes work, sometimes don't (getting better at this!)

**Reality Check:**
- **Not production uptime** - this is a learning lab where breaking things is expected
- **Downtime happens** when I'm pushing myself to learn new concepts  
- **That's the point** - safe environment to make mistakes and learn from them
- **No security issues so far** (that I know of) - still learning about proper security

**Student Reality Check:** This is my personal learning environment where I experiment with concepts from my coursework. Configurations are specific to my setup and hardware. I'm sharing this as a learning resource and to document my technical growth, not as a deployment guide that'll work everywhere.

## 🗺️ My Learning Path

### How I Got Here:
1. **Started Simple** - Basic pfSense setup because I wanted to understand how "real" networks work
2. **Added VLANs Gradually** - Took me months to really get network segmentation
3. **Tried Automation** - Lots of broken scripts and failed attempts before anything worked
4. **Documentation** - Writing things down helped me actually understand what I was doing
5. **Kept Experimenting** - Always finding new things to try or better ways to do existing stuff

### Major Learning Moments:
- **GPU Passthrough** - This took weeks to figure out and I broke the VM like 10 times
- **Network Security** - Learning why you actually need firewall rules (spoiler: everything breaks without them)
- **Automation Scripts** - Discovering that scripts break when you change literally anything
- **Storage Management** - Understanding why enterprise storage is so complicated

## 🏗️ What I've Built (So Far)

### Network Experiments
My network setup has evolved as I've learned more about how enterprise networks actually work:

| VLAN | What I Use It For | What I Learned |
|------|-------------------|-----------------|
| 10 (Admin) | Management interfaces, my admin machine | Why you isolate management traffic |
| 20 (Trusted) | My daily-use devices | How to set up "normal" network access |
| 30 (IoT) | Smart home devices that I don't trust | Why IoT isolation matters |
| 40 (Guest) | Friends' devices | Internet-only access is harder than it sounds |
| 50 (VPN) | Remote access when I'm not home | VPN routing is confusing but cool |

### Infrastructure Learning Lab
- **pfSense Router/Firewall** - My introduction to "real" networking gear
- **Proxmox + KVM** - Learning virtualization beyond VirtualBox
- **Custom NAS** - File sharing and understanding storage concepts
- **AdGuard Home** - DNS and network-wide ad blocking
- **Monitoring Setup** - Trying to understand what "observability" means

### Current VM Experiments
- **Master Node** - Learning Kubernetes basics (still very confused)
- **Worker Nodes** - Understanding distributed systems concepts
- **Storage VM** - Experimenting with different storage solutions
- **Monitoring** - Prometheus and Grafana (pretty graphs!)

## 📚 Learning Together

**If you're interested in building something similar:**

### What Might Be Helpful:
- **My Network Design** - Study my VLAN setup, but you'll need to adapt it for your needs
- **Script Examples** - See how I solved problems, but expect to rewrite everything for your environment
- **Documentation Approach** - Maybe my way of documenting infrastructure will give you ideas
- **Failure Stories** - Check my commit history to see what went wrong and how I fixed it

### Reality Check:
- **This won't work out-of-the-box** - It's completely customized for my specific hardware and network
- **Some things are over-engineered** - I was learning and wanted to try complex concepts
- **Scripts have bugs** - I'm still fixing things as I discover them
- **Documentation is incomplete** - Always a work in progress

### My Learning Resources:
- **YouTube Channels** - NetworkChuck, Jeff Geerling, Craft Computing
- **Reddit Communities** - r/homelab, r/selfhosted, r/networking
- **Documentation** - Reading official docs even when they're confusing
- **Trial and Error** - Breaking things and figuring out how to fix them

## 🛠️ Current Project Structure

```
homelab-infrastructure/
├── docs/                    # My notes and architecture diagrams
├── monitoring/              # Prometheus/Grafana setup attempts
├── networks/                # libvirt network configs
├── scripts/                 # Automation scripts (work in progress)
├── storage/                 # Storage pool management
├── templates/               # VM templates that mostly work
└── setup files/            # Main setup scripts
```

## 🚧 What I'm Working On

### Current Challenges:
- **Kubernetes Learning** - Container orchestration is way harder than I thought
- **Script Reliability** - Making my automation scripts not break everything when I change one thing
- **Useful Monitoring** - Understanding what metrics actually matter vs. just making pretty graphs
- **Security Learning** - Figuring out proper security practices without breaking functionality
- **Documentation** - Keeping up with what I've learned and changed (always behind on this)

### Things That Broke Recently:
- **VM Networking** - Changed something and lost connectivity for a day (still not sure what I did)
- **Storage Permissions** - NFS permissions are still really confusing to me
- **Monitoring Alerts** - Way too many false positives, trying to learn how to tune them properly
- **Docker Containers** - Accidentally deleted the wrong container and lost some configs
- **SSH Access** - Locked myself out while testing firewall rules (had to use console access)

### Next Learning Goals:
- **Infrastructure as Code** - Want to try Terraform and Ansible properly (instead of my current manual approach)
- **Container Security** - Learning how to secure containers without breaking everything
- **Better Networking** - Maybe try setting up a service mesh if I ever understand regular networking
- **Backup Strategies** - Actually implementing disaster recovery instead of just hoping nothing breaks
- **Testing Environment** - Setting up a separate lab so I can break things without affecting my main setup

## 🎓 Student Learning Project

**Full Transparency:** I'm a CS student learning through hands-on projects. This homelab represents:

- **2+ years of gradual learning** - Definitely not built overnight, lots of incremental progress
- **Lots of trial and error** - Many failed attempts, restarts, and "why doesn't this work?!" moments
- **Personal experiment** - Exploring concepts from my networking and systems courses
- **Work in progress** - Always finding better ways to do things or learning I did something wrong

**I'm not claiming to be an expert** - Just sharing my learning journey and hoping it might help other students who are also exploring infrastructure concepts. If you're a fellow student or hobbyist, feel free to learn from my mistakes!

## 🐛 When Things Don't Work

### Common Issues I've Encountered:
- **Permission Problems** - libvirt groups, file permissions, etc.
- **Network Connectivity** - VMs not getting IPs, DNS not resolving
- **Storage Issues** - NFS mounts failing, permission errors
- **Script Failures** - Environment differences, missing dependencies

### My Debugging Approach:
1. **Check the logs** - Usually there's an error message somewhere
2. **Google the error** - Someone else has probably had this problem
3. **Try the simplest solution first** - Often it's something basic
4. **Ask for help** - Reddit, Discord, or classmates usually have ideas
5. **Document the fix** - So I don't forget next time

## 🤝 Learning Community

### Always Happy to Chat About:
- **Homelab learning experiences** - Both successes and spectacular failures
- **CS coursework connections** - How classroom concepts apply to real infrastructure
- **Beginner questions** - I remember being confused about everything
- **Better approaches** - Always looking to learn from others who've figured things out

### What I Can Help With:
- **Getting started** - Basic homelab setup and common beginner mistakes
- **Network concepts** - VLAN setup, firewall basics, VPN configuration
- **VM management** - libvirt/KVM basics, common troubleshooting
- **Documentation tips** - How I organize and track my learning

### What I'm Still Learning:
- **Basic automation** - Getting better at writing scripts that don't break when I change things
- **Security best practices** - Learning proper security approaches (still making lots of mistakes)
- **System optimization** - Understanding why things are slow and how to fix them
- **Kubernetes** - Container orchestration is still very confusing to me
- **Not breaking things** - Working on testing changes before applying them to everything

## 📞 Questions & Collaboration

**Email:** joshua@emptycharacter.dev  
**Fellow student/hobbyist looking to learn and share knowledge**

**Note:** I'm definitely still learning! If you spot issues, have suggestions for improvement, or just want to share your own homelab experiences, I'd love to hear from you. This repository reflects my current understanding, which continues to evolve as I learn more.

---

## 🔗 Related Projects

- **Portfolio:** [emptycharacter.dev](https://emptycharacter.dev) - My other learning projects
- **LinkedIn:** [joshua-farin](https://linkedin.com/in/joshua-farin) - Professional learning journey

---

*This homelab represents hundreds of hours of learning, experimenting, breaking things, and troubleshooting. It's been an incredible (and often frustrating) hands-on complement to my CS coursework, helping me understand how the infrastructure behind modern applications actually works. Still lots to learn and plenty more things to break, but that's the fun part!* 🚀📚