# 1. Container Autostart
# Enable autostart for all containers
for container in k0rdent-mgmt k0s-child-master k0s-child-worker1 k0s-child-worker2; do
    echo "Enabling autostart for $container"
    echo "lxc.start.auto = 1" | sudo tee -a /var/lib/lxc/$container/config
    echo "lxc.start.delay = 5" | sudo tee -a /var/lib/lxc/$container/config
done


# 2. Persist iptables Rules
# Install iptables-persistent to save rules

sudo apt install -y iptables-persistent

# Save current rules
sudo netfilter-persistent save
sudo systemctl enable netfilter-persistent

# 3. Create a System Service for LXC Setup

sudo vi /etc/systemd/system/lxc-k8s-setup.service

ini[Unit]
Description=LXC Kubernetes Setup
After=network.target lxc-net.service
Wants=lxc-net.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/bin/lxc-k8s-startup.sh

[Install]
WantedBy=multi-user.target

# 4. Create Startup Script
sudo vi /usr/local/bin/lxc-k8s-startup.sh


#!/bin/bash
# LXC K8s Startup Script

# Ensure IP forwarding
sysctl -w net.ipv4.ip_forward=1

# Ensure NAT rules (in case iptables-persistent fails)
iptables -t nat -C POSTROUTING -s 10.0.3.0/24 -o eth0 -j MASQUERADE 2>/dev/null || \
    iptables -t nat -A POSTROUTING -s 10.0.3.0/24 -o eth0 -j MASQUERADE

iptables -C FORWARD -i lxcbr0 -j ACCEPT 2>/dev/null || \
    iptables -I FORWARD -i lxcbr0 -j ACCEPT

iptables -C FORWARD -o lxcbr0 -j ACCEPT 2>/dev/null || \
    iptables -I FORWARD -o lxcbr0 -j ACCEPT

# Wait for network
sleep 10

# Ensure containers are started
for container in k0rdent-mgmt k0s-child-master k0s-child-worker1 k0s-child-worker2; do
    if ! lxc-info -n $container --state | grep -q RUNNING; then
        echo "Starting $container"
        lxc-start -n $container
    fi
done

# Log status

lxc-ls -f > /var/log/lxc-k8s-status.log

sudo chmod +x /usr/local/bin/lxc-k8s-startup.sh
sudo systemctl enable lxc-k8s-setup.service

# 5. Check Required Services
# Ensure all required services start on boot

sudo systemctl enable lxc-net
sudo systemctl enable lxc
sudo systemctl enable systemd-networkd  # if used
