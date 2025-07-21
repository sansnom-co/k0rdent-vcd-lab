#!/bin/bash
# Initialize containers with required packages
# Run as: sudo ./init-containers.sh

set -e

CONTAINERS="k0rdent-mgmt k0s-child-master k0s-child-worker1 k0s-child-worker2"

echo "=== Initializing containers ==="

for container in $CONTAINERS; do
    echo "=== Initializing $container ==="
    lxc-attach -n $container -- bash -c "
        echo 'Updating packages...'
        apt update && apt upgrade -y
        
        echo 'Installing required packages...'
        apt install -y curl wget gnupg2 apt-transport-https ca-certificates \
            lsb-release iptables iproute2 systemd-resolved
        
        echo 'Setting hostname...'
        hostnamectl set-hostname $container
        
        echo 'Enabling systemd-resolved...'
        systemctl enable systemd-resolved
        systemctl start systemd-resolved
        
        echo 'Testing connectivity...'
        ping -c 1 google.com && echo 'Internet: OK' || echo 'Internet: FAIL'
        
        echo 'Container $container initialized successfully'
    "
    echo
done

echo "=== Testing network connectivity ==="
/usr/local/bin/test-lxc-network.sh

echo "=== All containers initialized! ==="
echo "Containers are ready for Kubernetes installation"
