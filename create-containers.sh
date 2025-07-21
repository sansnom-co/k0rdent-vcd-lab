#!/bin/bash
# Create and configure LXC containers
# Run as: sudo ./create-containers.sh

set -e

# Container definitions
declare -A CONTAINERS=(
    ["k0rdent-mgmt"]="10.0.3.10"
    ["k0s-child-master"]="10.0.3.20"
    ["k0s-child-worker1"]="10.0.3.21"
    ["k0s-child-worker2"]="10.0.3.22"
)

# Step 1: Create containers
echo "=== Creating containers ==="
for container in k0rdent-mgmt k0s-child-master k0s-child-worker1 k0s-child-worker2; do
    echo "Creating $container..."
    /usr/local/bin/create-k8s-lxc.sh $container
done

# Step 2: Start containers to get MAC addresses
echo "=== Starting containers to get MAC addresses ==="
systemctl restart lxc-net

for container in "${!CONTAINERS[@]}"; do
    lxc-start -n $container
done

sleep 5

# Step 3: Get MAC addresses and create DHCP config
echo "=== Configuring DHCP reservations ==="
DHCP_CONFIG="/etc/lxc/dnsmasq.d/hosts.conf"

cat > $DHCP_CONFIG <<EOF
# Expand hosts (allows short names)
expand-hosts
domain=lxc.local

# Static DHCP reservations
EOF

for container in "${!CONTAINERS[@]}"; do
    MAC=$(lxc-attach -n $container -- cat /sys/class/net/eth0/address)
    IP="${CONTAINERS[$container]}"
    echo "dhcp-host=$MAC,$IP,$container" >> $DHCP_CONFIG
    echo "$container: MAC=$MAC, IP=$IP"
done

# Add host records
echo "" >> $DHCP_CONFIG
echo "# Static hosts" >> $DHCP_CONFIG
for container in "${!CONTAINERS[@]}"; do
    IP="${CONTAINERS[$container]}"
    echo "host-record=$container.lxc.local,$container,$IP" >> $DHCP_CONFIG
done

# Step 4: Restart with new config
echo "=== Applying network configuration ==="
for container in "${!CONTAINERS[@]}"; do
    lxc-stop -n $container
done

systemctl stop lxc-net
rm -f /var/lib/misc/dnsmasq.lxcbr0.leases*
systemctl start lxc-net

for container in "${!CONTAINERS[@]}"; do
    lxc-start -n $container
done

echo "=== Waiting for containers to get IPs ==="
sleep 10

# Step 5: Show status
lxc-ls -f

echo "=== Setup complete! ==="
echo "Next: Run ./init-containers.sh to initialize containers"
