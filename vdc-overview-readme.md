# Virtual Container Datacenter (VCD) Documentation

## What is VCD?

A Virtual Container Datacenter (VCD) is a lightweight, container-based infrastructure that simulates a multi-node datacenter environment using LXC containers. This setup is perfect for:
- Kubernetes development and testing
- Learning cluster management
- Running production-like environments on limited hardware
- CI/CD pipeline testing

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                    Host System (muc)                     │
│                  ARM64 Debian Trixie                     │
├─────────────────────────────────────────────────────────┤
│                    lxcbr0 Bridge                         │
│                   10.0.3.0/24 Network                    │
├──────────┬──────────┬──────────┬────────────────────────┤
│          │          │          │                        │
┌──────────┴───┐ ┌────┴────┐ ┌───┴────┐ ┌───────────────┐
│ k0rdent-mgmt │ │k0s-master│ │worker1 │ │   worker2     │
│  10.0.3.10   │ │10.0.3.20 │ │10.0.3.21│ │  10.0.3.22    │
│              │ │          │ │         │ │               │
│ Management   │ │  Child   │ │ Child   │ │    Child      │
│   Node       │ │ Master   │ │ Worker  │ │    Worker     │
└──────────────┘ └──────────┘ └─────────┘ └───────────────┘
```

## Components

### 1. Network Infrastructure
- **Bridge**: lxcbr0 (10.0.3.1/24)
- **DHCP**: Static reservations via dnsmasq
- **DNS**: Local domain `.lxc.local`
- **NAT**: Internet access via host

### 2. Container Nodes
| Container | IP | Role | Resources |
|-----------|-----|------|-----------|
| k0rdent-mgmt | 10.0.3.10 | Management/Control plane | 4GB RAM, 2 CPU |
| k0s-child-master | 10.0.3.20 | K8s master | 4GB RAM, 2 CPU |
| k0s-child-worker1 | 10.0.3.21 | K8s worker | 4GB RAM, 2 CPU |
| k0s-child-worker2 | 10.0.3.22 | K8s worker | 4GB RAM, 2 CPU |

### 3. Management Scripts

#### Core Setup Scripts
- **`full-vcd-setup.sh`** - Complete VCD environment setup
- **`create-containers.sh`** - Container creation with networking
- **`init-containers.sh`** - Container package initialization
- **`vcd-production-ready.sh`** - Production hardening

#### Operational Scripts
- **`check-vdc-health.sh`** - Health monitoring
- **`vdc-k8s-powerup.sh`** - Startup automation
- **`/usr/local/bin/backup-lxc-containers.sh`** - Backup automation
- **`/usr/local/bin/maintain-lxc-containers.sh`** - Maintenance tasks

## Quick Start Guide

### 1. Initial Setup
```bash
cd ~/vcd
sudo ./full-vcd-setup.sh
# Choose option 1 for complete setup
```

### 2. Production Hardening
```bash
sudo ./vcd-production-ready.sh
```

### 3. Verify Setup
```bash
sudo ./check-vdc-health.sh
```

### 4. Access Containers
```bash
# Direct access
sudo lxc-attach -n k0rdent-mgmt

# SSH access (password: 123robot)
ssh robot@10.0.3.10  # Management node
ssh robot@10.0.3.20  # Master node
```

## Features

### High Availability
- **Auto-start**: Containers start automatically on boot
- **Persistent networking**: iptables rules saved
- **Health monitoring**: Automated health checks

### Security
- **User management**: robot user with sudo access
- **SSH access**: Password and key-based authentication
- **Resource limits**: CPU and memory constraints

### Kubernetes Ready
- **Kernel parameters**: Optimized for K8s
- **Time sync**: Chrony for cluster timing
- **Swap disabled**: K8s requirement
- **Bridge networking**: For pod communication

## Maintenance

### Daily Tasks
```bash
# Health check (automated via cron)
sudo ./check-vdc-health.sh

# Manual backup
sudo /usr/local/bin/backup-lxc-containers.sh
```

### Weekly Tasks
```bash
# System maintenance (automated via cron)
sudo /usr/local/bin/maintain-lxc-containers.sh
```

### Crontab Entries
```cron
# Health check on reboot
@reboot sleep 60 && /usr/local/bin/check-lxc-health.sh > /var/log/lxc-health-boot.log 2>&1

# Daily backup at 2 AM
0 2 * * * /usr/local/bin/backup-lxc-containers.sh > /var/log/lxc-backup.log 2>&1

# Weekly maintenance on Sunday at 3 AM
0 3 * * 0 /usr/local/bin/maintain-lxc-containers.sh > /var/log/lxc-maintenance.log 2>&1
```

## Troubleshooting

### Common Issues

#### Containers not starting
```bash
# Check service status
sudo systemctl status lxc-net
sudo systemctl status lxc-k8s-setup

# Manual start
sudo /usr/local/bin/vdc-k8s-powerup.sh
```

#### Network connectivity issues
```bash
# Check NAT rules
sudo iptables -t nat -L POSTROUTING -n

# Check forwarding
cat /proc/sys/net/ipv4/ip_forward

# Restart networking
sudo systemctl restart lxc-net
```

#### Time sync problems
```bash
# Check chrony in container
sudo lxc-attach -n k0rdent-mgmt -- chronyc tracking
```

### Log Files
- `/var/log/lxc-k8s-status.log` - Container status
- `/var/log/lxc-health-boot.log` - Boot health check
- `/var/log/lxc-backup.log` - Backup logs
- `/var/log/lxc-maintenance.log` - Maintenance logs

## Advanced Usage

### Scaling the VCD
To add more worker nodes:
```bash
# Create new container
sudo /usr/local/bin/create-k8s-lxc.sh k0s-child-worker3

# Add to DHCP config
sudo vi /etc/lxc/dnsmasq.d/hosts.conf
# Add: dhcp-host=<MAC>,10.0.3.23,k0s-child-worker3

# Update scripts to include new container
```

### Resource Tuning
Edit container configs in `/var/lib/lxc/<container>/config`:
```
# Adjust CPU (example: 4 CPUs)
lxc.cgroup2.cpu.max = 400000 1000000

# Adjust memory (example: 8GB)
lxc.cgroup2.memory.max = 8G
```

### Backup and Restore
```bash
# Manual backup
cd /var/backups/lxc
sudo tar -czf k0rdent-mgmt-manual.tar.gz -C /var/lib/lxc/k0rdent-mgmt .

# Restore
sudo lxc-stop -n k0rdent-mgmt
sudo rm -rf /var/lib/lxc/k0rdent-mgmt
sudo mkdir /var/lib/lxc/k0rdent-mgmt
sudo tar -xzf k0rdent-mgmt-manual.tar.gz -C /var/lib/lxc/k0rdent-mgmt
sudo lxc-start -n k0rdent-mgmt
```

## Next Steps

1. **Install k0rdent** on management node
   ```bash
   sudo lxc-attach -n k0rdent-mgmt
   # Follow k0rdent installation guide
   # https://docs.k0rdent-enterprise.io/latest/quickstart/

   ```

2. **k0smotron remoteserver** worker nodes
   the vdc scripts create a set of three worker for a child cluster
   use the remoteserver provider template to provision and test k0rdent.

## System Requirements

- **Host OS**: Debian-based (tested on Trixie)
- **Architecture**: ARM64 or x86_64
- **Memory**: Minimum 16GB (4GB per container)
- **Storage**: 50GB+ recommended
- **CPU**: 4+ cores recommended

## Version Information

- **LXC**: System default
- **Container OS**: Debian Trixie
- **Network**: 10.0.3.0/24
- **Created**: July 2025

---

This VCD setup provides a complete, production-ready container infrastructure for Kubernetes development and testing. The automation scripts ensure reliable operation and easy maintenance.
