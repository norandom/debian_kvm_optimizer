#!/bin/bash

# Host Optimization Setup Script
# This script prepares the host for manual Ansible playbook execution

set -e

# Configuration variables - modify these for your environment
PROJECT_NAME="${PROJECT_NAME:-Debian_KVM_Optimization}"
LOG_FILE="${LOG_FILE:-/var/log/${PROJECT_NAME}-setup.log}"

echo "=== ${PROJECT_NAME} Setup ===" | tee -a $LOG_FILE
echo "Started at: $(date)" | tee -a $LOG_FILE

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" | tee -a $LOG_FILE
   exit 1
fi

# Update system
echo "Updating system packages..." | tee -a $LOG_FILE
apt-get update && apt-get upgrade -y >> $LOG_FILE 2>&1

# Install required packages
echo "Installing required packages..." | tee -a $LOG_FILE
apt-get install -y \
    ansible \
    git \
    python3-pip \
    python3-venv \
    curl \
    wget \
    gnupg \
    software-properties-common >> $LOG_FILE 2>&1

# Run optimization (manual execution only)
echo "Running KVM host optimization..." | tee -a $LOG_FILE
ansible-playbook -c local -i inventory/hosts.yml site.yml >> $LOG_FILE 2>&1

# Create log rotation for our logs
cat > /etc/logrotate.d/${PROJECT_NAME} << EOF
${LOG_FILE} {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0644 root root
}

/var/log/${PROJECT_NAME}.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 0644 root root
}
EOF

# Display completion status
echo "=== Setup Complete ===" | tee -a $LOG_FILE
echo "Setup completed at: $(date)" | tee -a $LOG_FILE

echo ""
echo "=== Manual Execution Instructions ==="
echo ""
echo "To run optimization manually:"
echo "  ansible-playbook -c local -i inventory/hosts.yml site.yml"
echo ""
echo "To check logs:"
echo "  tail -f $LOG_FILE"
echo ""
echo "Note: This playbook should only be run manually to avoid system instability."
echo "Automatic execution via systemd/cron is not recommended."