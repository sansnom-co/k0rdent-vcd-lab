# Virtual Container Datacenter (VCD)

A lightweight, container-based infrastructure that simulates a multi-node datacenter environment using LXC containers. Perfect for Kubernetes development, testing, and learning cluster management on limited hardware. The virtual container-based datacenter (VCD) approach leverages LXC containers to simulate a realistic, multi-node Kubernetes environment on a single physical host. Unlike tools such as Kind or Minikube—which offer limited, single-node or nested-cluster setups—LXC provides lightweight system containers that boot quickly, support systemd, and share the host kernel. This enables the simulation of actual node roles (control plane, workers) with full networking and SSH access, making it ideal for k0rdent and k0s development, cluster management testing, and education, even on modest hardware.

By combining automated scripts (`full-vcd-setup.sh`, `vcd-production-ready.sh`) with optimised kernel parameters and production-hardening routines, VCD allows users to replicate real-world k8s behaviours including CNI networking, service exposure, RBAC, and node failure testing. This makes it suitable for CI workflows, platform engineering validation (e.g. k0rdent), and infrastructure-as-code scenarios. The use of cron jobs for backup, health checks, and boot-time container orchestration further supports production-like lifecycle management.

Overall, VCD provides a middle ground between heavyweight VM-based clusters and abstraction-heavy dev tools, offering both performance efficiency and low-level control. Its design allows developers and  engineers to test, simulate, and iterate quickly on k8s cluster topologies and behaviours, while keeping the barrier to entry low—no hypervisor or cloud credits required. For teams building, operating, or teaching k8s, VCD offers a powerful, scriptable, and resource-efficient foundation.


## 🚀 Features

- **Full datacenter simulation** using LXC containers
- **Kubernetes-ready** environment with optimized kernel parameters
- **Automated setup** with production-ready scripts
- **Resource-efficient** - Run multiple nodes on a single host
- **Built-in monitoring** and health checks
- **Automated backups** and maintenance

## 📋 Architecture

```
Host System (ARM64/x86_64)
    └── lxcbr0 Bridge (10.0.3.0/24)
         ├── k0rdent-mgmt (10.0.3.10) - Management Node
         ├── k0s-master (10.0.3.20) - K8s Master
         ├── worker1 (10.0.3.21) - K8s Worker
         └── worker2 (10.0.3.22) - K8s Worker
```

## 🛠️ Quick Start

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/vcd.git
   cd vcd
   ```

2. **Run the setup**
   ```bash
   sudo ./full-vcd-setup.sh
   # Choose option 1 for complete setup
   ```

3. **Harden for production**
   ```bash
   sudo ./vcd-production-ready.sh
   ```

4. **Verify installation**
   ```bash
   sudo ./check-vdc-health.sh
   ```

## 💻 Usage

### Access containers
```bash
# Direct access
sudo lxc-attach -n k0rdent-mgmt

# SSH access (default password: 123robot)
ssh robot@10.0.3.10  # Management node
ssh robot@10.0.3.20  # Master node
```

### Start/Stop VCD
```bash
# Start all containers
sudo /usr/local/bin/vdc-k8s-powerup.sh

# Stop a container
sudo lxc-stop -n k0rdent-mgmt
```

### Monitor health
```bash
sudo ./check-vdc-health.sh
```

## 📊 Container Resources

| Container | CPU | Memory | Role |
|-----------|-----|--------|------|
| k0rdent-mgmt | 2 | 4GB | Management/Control |
| k0s-child-master | 2 | 4GB | Kubernetes Master |
| k0s-child-worker1 | 2 | 4GB | Kubernetes Worker |
| k0s-child-worker2 | 2 | 4GB | Kubernetes Worker |

## 📚 Scripts Overview

- `full-vcd-setup.sh` - Complete environment setup
- `vcd-production-ready.sh` - Production hardening
- `check-vdc-health.sh` - Health monitoring
- `vdc-k8s-powerup.sh` - Startup automation

## 🔧 Requirements

- **OS**: Debian-based Linux (tested on Debian Trixie)
- **Architecture**: ARM64 or x86_64
- **Memory**: Minimum 16GB RAM
- **Storage**: 50GB+ recommended
- **CPU**: 4+ cores recommended
- **Privileges**: Root access required

## 📁 Project Structure

```
vcd/
├── full-vcd-setup.sh           # Main setup script
├── create-containers.sh        # Container creation
├── init-containers.sh          # Container initialization
├── vcd-production-ready.sh     # Production hardening
├── check-vdc-health.sh         # Health monitoring
├── vdc-k8s-powerup.sh         # Startup automation
└── README.md                   # This file
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

## ⚡ Quick Tips

- Containers auto-start on system boot
- Daily backups run at 2 AM via cron
- Default network: `10.0.3.0/24`
- All containers use `robot` user with sudo access
- Logs available in `/var/log/lxc-*.log`

## 🐛 Troubleshooting

If containers don't start:
```bash
sudo systemctl status lxc-net
sudo systemctl restart lxc-net
```

For more detailed documentation, see the [full documentation](vdc-overview-readme.md).

---

**Note**: This project creates a simulated datacenter environment. While production-ready features are included, always test thoroughly before using in critical environments.
