#!/bin/bash

# Update system
apt-get update
apt-get upgrade -y

# Install minimal packages required for basic system setup
apt-get install -y \
    curl \
    wget \
    unzip \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    fail2ban \
    unattended-upgrades

cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
systemctl enable fail2ban
systemctl start fail2ban

mkdir -p /opt/visitor-counter/production
mkdir -p /opt/visitor-counter/development
chmod 755 /opt/visitor-counter/production
chmod 755 /opt/visitor-counter/development

echo 'APT::Periodic::Update-Package-Lists "1";' > /etc/apt/apt.conf.d/20auto-upgrades
echo 'APT::Periodic::Unattended-Upgrade "1";' >> /etc/apt/apt.conf.d/20auto-upgrades
systemctl enable unattended-upgrades
systemctl start unattended-upgrades

# Run the setup-server.sh script
echo "Running setup-server.sh..."
chmod +x /tmp/setup-server.sh
/tmp/setup-server.sh

echo "Startup script completed - server fully configured and ready!"

