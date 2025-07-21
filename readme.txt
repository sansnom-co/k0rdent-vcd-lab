# LXC Setup for k0rdent + k0smotron Child Cluster
# Date: July 21, 2025
# System: ARM64 Debian Trixie (muc)

## Overview
This setup creates 4 LXC containers:
- 1 management node for k0rdent/k0smotron
- 3 nodes for the child Kubernetes cluster

## Network Architecture
- Network: 10.0.3.0/24 on lxcbr0
- k0rdent-mgmt: 10.0.3.10
- k0s-child-master: 10.0.3.20
- k0s-child-worker1: 10.0.3.21
- k0s-child-worker2: 10.0.3.22
- DNS Domain: .lxc.local
- Gateway: 10.0.3.1 (lxcbr0)

## Prerequisites Installation

sudo apt update
sudo apt install lxc lxc-templates bridge-utils dnsmasq-base iptables

## Step 1: Configure LXC Networking

sudo vi /etc/default/lxc-net

Content:
USE_LXC_BRIDGE="true"
LXC_BRIDGE="lxcbr0"
LXC_ADDR="10.0.3.1"
LXC_NETMASK="255.255.255.0"
LXC_NETWORK="10.0.3.0/24"
LXC_DHCP_RANGE="10.0.3.200,10.0.3.254"
LXC_DHCP_MAX="55"
LXC_DOMAIN="lxc.local"
LXC_DHCP_CONFILE="/etc/lxc/dnsmasq.d/hosts.conf"

## Step 2: Create Container Creation Script

sudo vi /usr/local/bin/create-k8s-lxc.sh

#!/bin/bash
NAME=$1

# Create container using download template for ARM64
sudo lxc-create -n $NAME -t download -- -d debian -r trixie -a arm64

# Configure for k8s (no static IP - will use DHCP reservations)
cat << EOF | sudo tee -a /var/lib/lxc/$NAME/config
# Kubernetes requirements
lxc.apparmor.profile = unconfined
lxc.cap.drop =
lxc.mount.auto = proc:rw sys:rw cgroup:rw
EOF

echo "Created $NAME with Debian Trixie ARM64"

sudo chmod +x /usr/local/bin/create-k8s-lxc.sh

## Step 3: Create All Containers

sudo /usr/local/bin/create-k8s-lxc.sh k0rdent-mgmt
sudo /usr/local/bin/create-k8s-lxc.sh k0s-child-master
sudo /usr/local/bin/create-k8s-lxc.sh k0s-child-worker1
sudo /usr/local/bin/create-k8s-lxc.sh k0s-child-worker2

## Step 4: Start Containers to Get MAC Addresses

# Start containers
for container in k0rdent-mgmt k0s-child-master k0s-child-worker1 k0s-child-worker2; do
    sudo lxc-start -n $container
done

# Get MAC addresses
for container in k0rdent-mgmt k0s-child-master k0s-child-worker1 k0s-child-worker2; do
    echo -n "$container MAC: "
    sudo lxc-attach -n $container -- cat /sys/class/net/eth0/address
done

## Step 5: Configure DHCP Reservations and DNS

sudo mkdir -p /etc/lxc/dnsmasq.d
sudo vi /etc/lxc/dnsmasq.d/hosts.conf

# Expand hosts (allows short names)
expand-hosts
domain=lxc.local

# Static DHCP reservations (UPDATE MAC ADDRESSES FROM STEP 4)
dhcp-host=8a:63:75:13:0b:8c,10.0.3.10,k0rdent-mgmt
dhcp-host=e6:7b:26:10:94:b9,10.0.3.20,k0s-child-master
dhcp-host=8e:77:0c:da:82:a1,10.0.3.21,k0s-child-worker1
dhcp-host=1a:7e:3e:2d:a3:3a,10.0.3.22,k0s-child-worker2

# Static hosts
host-record=k0rdent-mgmt.lxc.local,k0rdent-mgmt,10.0.3.10
host-record=k0s-child-master.lxc.local,k0s-child-master,10.0.3.20
host-record=k0s-child-worker1.lxc.local,k0s-child-worker1,10.0.3.21
host-record=k0s-child-worker2.lxc.local,k0s-child-worker2,10.0.3.22

## Step 6: Apply Network Configuration

# Stop containers
for container in k0rdent-mgmt k0s-child-master k0s-child-worker1 k0s-child-worker2; do
    sudo lxc-stop -n $container
done

# Clear old DHCP leases
sudo systemctl stop lxc-net
sudo rm -f /var/lib/misc/dnsmasq.lxcbr0.leases*

# Restart networking
sudo systemctl start lxc-net

# Start containers with new config
for container in k0rdent-mgmt k0s-child-master k0s-child-worker1 k0s-child-worker2; do
    sudo lxc-start -n $container
done

## Step 7: Configure NAT for Internet Access

# Enable IP forwarding
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -w net.ipv4.ip_forward=1

# Add NAT rule if missing
sudo iptables -t nat -A POSTROUTING -s 10.0.3.0/24 -o eth0 -j MASQUERADE

# Add forwarding rules
sudo iptables -I FORWARD -i lxcbr0 -j ACCEPT
sudo iptables -I FORWARD -o lxcbr0 -j ACCEPT

# Save rules (optional)
sudo apt install iptables-persistent
sudo netfilter-persistent save

## Step 8: Initialize Containers

# Initialize all containers
for container in k0rdent-mgmt k0s-child-master k0s-child-worker1 k0s-child-worker2; do
    echo "=== Initializing $container ==="
    sudo lxc-attach -n $container -- bash -c "
        apt update && apt upgrade -y
        apt install -y curl wget gnupg2 apt-transport-https ca-certificates \
            lsb-release iptables iproute2 systemd-resolved
        hostnamectl set-hostname $container
        systemctl enable systemd-resolved
        systemctl start systemd-resolved
        echo 'Container $container initialized'
    "
done

## Step 9: Network Test Script

sudo vi /usr/local/bin/test-lxc-network.sh

#!/bin/bash
echo "=== LXC Network Test ==="
echo "Bridge Status:"
ip addr show lxcbr0

echo -e "\nContainers:"
sudo lxc-ls -f

echo -e "\nDNS Resolution Test:"
for host in k0rdent-mgmt k0s-child-master k0s-child-worker1 k0s-child-worker2; do
    echo -n "$host: "
    getent hosts $host.lxc.local | awk '{print $1}'
done

echo -e "\nConnectivity Test:"
for ip in 10.0.3.10 10.0.3.20 10.0.3.21 10.0.3.22; do
    ping -c 1 -W 1 $ip &>/dev/null && echo "$ip: OK" || echo "$ip: FAIL"
done

sudo chmod +x /usr/local/bin/test-lxc-network.sh

## Container Management Commands

# Access container
sudo lxc-attach -n k0rdent-mgmt

# List containers
sudo lxc-ls -f

# Stop container
sudo lxc-stop -n k0rdent-mgmt

# Start container
sudo lxc-start -n k0rdent-mgmt

# Destroy container (careful!)
sudo lxc-destroy -n k0rdent-mgmt

# Test network
sudo /usr/local/bin/test-lxc-network.sh

## Troubleshooting

1. If containers don't get IPs:
   - Check: sudo systemctl status lxc-net
   - Check: ps aux | grep dnsmasq | grep lxc
   - Verify: /etc/lxc/dnsmasq.d/hosts.conf exists

2. If no internet access:
   - Check NAT: sudo iptables -t nat -L POSTROUTING -n
   - Check forwarding: cat /proc/sys/net/ipv4/ip_forward (should be 1)

3. If DNS doesn't work:
   - Inside container: resolvectl status
   - Check: cat /etc/resolv.conf

4. View logs:
   - sudo journalctl -u lxc-net
   - sudo lxc-start -n container-name -F (foreground mode)

## Next Steps

1. Install k0rdent on k0rdent-mgmt container
2. Install k0smotron on k0rdent-mgmt
3. Bootstrap child cluster using k0smotron on the 3 child nodes
4. Configure kubectl access from management node

## Important Notes

- We use DHCP with static reservations instead of hardcoded IPs
- DNS/DHCP config: /etc/lxc/dnsmasq.d/hosts.conf
- Network config: /etc/default/lxc-net
- Containers use systemd-resolved for DNS
- NAT is required for internet access from containers

## Quick Setup Using Scripts

1. Run the main setup script (as root):
   sudo ./setup-lxc-k8s.sh

2. Create and configure containers:
   sudo ./create-containers.sh

3. Initialize containers:
   sudo ./init-containers.sh

4. Test the setup:
   sudo /usr/local/bin/test-lxc-network.sh

The scripts will:
- Install all prerequisites
- Configure LXC networking
- Create 4 containers with proper settings
- Set up DHCP reservations automatically
- Configure NAT for internet access
- Initialize containers with required packages


## Persistence Across Reboots

1. Containers are set to autostart
2. iptables rules saved with iptables-persistent
3. IP forwarding enabled in sysctl.conf
4. Custom systemd service ensures setup

To check health after reboot:
  sudo /usr/local/bin/check-lxc-health.sh

To manually start everything:
  sudo systemctl start lxc-net
  sudo systemctl start lxc-k8s-setup

Logs:
  /var/log/lxc-k8s-status.log
  /var/log/lxc-health-boot.log
