#!/bin/bash

# Host Optimization Setup Script
# This script prepares the host for Ansible pull workflow

set -e

# Configuration variables - modify these for your environment
PROJECT_NAME="${PROJECT_NAME:-Debian_KVM_Optimization}"
INSTALL_DIR="${INSTALL_DIR:-/opt/${PROJECT_NAME}}"
LOG_FILE="${LOG_FILE:-/var/log/${PROJECT_NAME}-setup.log}"
SERVICE_NAME="${SERVICE_NAME:-ansible-pull}"
ARCHIVE_NAME="${ARCHIVE_NAME:-${PROJECT_NAME}.tar.gz}"

# Interactive repository configuration
if [[ -z "$REPO_URL" ]]; then
    echo ""
    echo "Repository Configuration:"
    echo "Please enter the Git repository URL for ansible-pull to use."
    echo "Examples:"
    echo "  https://github.com/username/repo.git"
    echo "  git@github.com:username/repo.git"
    echo "  https://gitlab.com/username/repo.git"
    echo ""
    read -p "Repository URL: " REPO_URL
    
    if [[ -z "$REPO_URL" ]]; then
        echo "Error: Repository URL is required for ansible-pull to work."
        exit 1
    fi
    
    echo "Using repository: $REPO_URL"
    echo ""
fi

# Ansible pull service defaults
ANSIBLE_PULL_INTERVAL="${ANSIBLE_PULL_INTERVAL:-30min}"
ANSIBLE_PULL_RANDOM_DELAY="${ANSIBLE_PULL_RANDOM_DELAY:-10min}"
ANSIBLE_PULL_PLAYBOOK="${ANSIBLE_PULL_PLAYBOOK:-site.yml}"
ANSIBLE_PULL_INVENTORY="${ANSIBLE_PULL_INVENTORY:-inventory/hosts.yml}"
ANSIBLE_PULL_USER="${ANSIBLE_PULL_USER:-root}"
ANSIBLE_PULL_CHECKOUT_DIR="${ANSIBLE_PULL_CHECKOUT_DIR:-${INSTALL_DIR}}"

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

# Create installation directory
echo "Creating installation directory..." | tee -a $LOG_FILE
mkdir -p $INSTALL_DIR
cd $INSTALL_DIR

# Clone repository (or copy local files for testing)
echo "Setting up Ansible playbook..." | tee -a $LOG_FILE
if [[ -d ".git" ]]; then
    git pull >> $LOG_FILE 2>&1
else
    # For testing, copy local files
    if [[ -f "/tmp/${ARCHIVE_NAME}" ]]; then
        tar -xzf /tmp/${ARCHIVE_NAME} -C . >> $LOG_FILE 2>&1
    else
        echo "Repository URL not configured. Please set REPO_URL variable." | tee -a $LOG_FILE
        echo "For testing, place files in $INSTALL_DIR" | tee -a $LOG_FILE
    fi
fi

# Set proper permissions
chown -R root:root $INSTALL_DIR
chmod -R 755 $INSTALL_DIR

# Generate systemd service and timer files
echo "Setting up systemd service..." | tee -a $LOG_FILE

# Create service file
cat > /etc/systemd/system/${SERVICE_NAME}.service << EOF
[Unit]
Description=Ansible Pull for ${PROJECT_NAME}
After=network.target

[Service]
Type=oneshot
User=${ANSIBLE_PULL_USER}
Group=${ANSIBLE_PULL_USER}
WorkingDirectory=${ANSIBLE_PULL_CHECKOUT_DIR}
ExecStartPre=/bin/sleep \$((RANDOM % ${ANSIBLE_PULL_RANDOM_DELAY%min} * 60))
ExecStart=/usr/bin/ansible-pull -U ${REPO_URL} -i ${ANSIBLE_PULL_INVENTORY} ${ANSIBLE_PULL_PLAYBOOK}
TimeoutSec=1800
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Create timer file
# Convert interval to minutes for OnCalendar
INTERVAL_MINUTES=${ANSIBLE_PULL_INTERVAL%min}
DELAY_SECONDS=$((${ANSIBLE_PULL_RANDOM_DELAY%min} * 60))

cat > /etc/systemd/system/${SERVICE_NAME}.timer << EOF
[Unit]
Description=Run Ansible Pull every ${ANSIBLE_PULL_INTERVAL}
Requires=${SERVICE_NAME}.service

[Timer]
OnCalendar=*:0/${INTERVAL_MINUTES}
Persistent=true
RandomizedDelaySec=${DELAY_SECONDS}

[Install]
WantedBy=timers.target
EOF

# Reload systemd
systemctl daemon-reload

# Enable and start the timer
echo "Enabling Ansible pull timer..." | tee -a $LOG_FILE
systemctl enable ${SERVICE_NAME}.timer
systemctl start ${SERVICE_NAME}.timer

# Run initial optimization
echo "Running initial optimization..." | tee -a $LOG_FILE
ansible-playbook -i inventory/hosts.yml site.yml >> $LOG_FILE 2>&1

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

# Display status
echo "=== Setup Complete ===" | tee -a $LOG_FILE
echo "Installation directory: $INSTALL_DIR" | tee -a $LOG_FILE
echo "Service status:" | tee -a $LOG_FILE
systemctl status ${SERVICE_NAME}.timer --no-pager | tee -a $LOG_FILE

echo "Timer schedule:" | tee -a $LOG_FILE
systemctl list-timers ${SERVICE_NAME}.timer --no-pager | tee -a $LOG_FILE

echo "Setup completed at: $(date)" | tee -a $LOG_FILE

# Show next optimization run
echo ""
echo "Next optimization run:"
systemctl list-timers ${SERVICE_NAME}.timer --no-pager | grep ${SERVICE_NAME}

echo ""
echo "To manually run optimization:"
echo "  systemctl start ${SERVICE_NAME}.service"
echo ""
echo "To check logs:"
echo "  journalctl -u ${SERVICE_NAME}.service -f"
echo "  tail -f /var/log/${PROJECT_NAME}.log"
echo ""
echo "To stop automatic optimization:"
echo "  systemctl stop ${SERVICE_NAME}.timer"
echo "  systemctl disable ${SERVICE_NAME}.timer"