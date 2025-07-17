# KVM Host Optimization - Ansible Pull Workflow

Automated optimization for Debian Bookworm KVM virtualization hosts using Ansible pull methodology.

## Overview

This playbook optimizes the **host OS only** for running KVM virtual machines on Debian Bookworm. It focuses on system-level optimizations without touching VM configurations.

## Host System Specifications

- **OS**: Debian GNU/Linux 12 (bookworm)
- **CPU**: Intel i7-8700 (6 cores, 12 threads) with VT-x
- **Memory**: 125GB
- **Storage**: 
  - 2TB root (RAID)
  - 5.3TB /home (RAID) - 98% full
  - 938GB /virt (NVMe)

## Optimizations Applied

### System Optimization
- CPU frequency scaling (performance governor)
- Transparent huge pages configuration
- IRQ balancing and affinity optimization
- Tuned profile for virtualization hosts
- Unnecessary service cleanup
- System monitoring and alerting

### Performance Tuning
- Kernel parameter optimization for virtualization
- Network stack tuning
- I/O scheduler optimization per storage type
- Memory management tuning
- NUMA balancing disabled for VMs
- Huge pages configuration

### Storage Optimization
- SSD TRIM scheduling
- Mount options optimization (noatime, nodiratime)
- Storage device readahead tuning
- Filesystem cache pressure optimization
- Dirty page writeback tuning
- Automated cleanup and monitoring

### KSM Optimization
- Replaces broken ksmtuned service
- Aggressive memory deduplication for 12 VMs
- Adaptive scanning based on memory pressure
- Monitoring and auto-optimization every 5 minutes
- Cross-NUMA and zero-page merging enabled

### Network NAT Persistence
- Consolidates and persists existing NAT rules
- Port forwarding: SSH (2223), BitTorrent (51413, 6881-6889)
- DNS/DHCP leak prevention on external interface
- BBR congestion control and buffer optimization
- Automated rule persistence and monitoring

## Quick Start

1. **Run setup on host**:
```bash
ssh root@YOUR_HOST_IP
curl -O https://raw.githubusercontent.com/norandom/debian_kvm_optimizer/main/setup.sh
chmod +x setup.sh
./setup.sh
```

The setup script will:
- Prompt for your repository URL
- Install Ansible and required packages
- Set up the ansible-pull service to automatically pull from your repository
- Run the initial optimization

2. **Monitor**:
```bash
# Check service status
systemctl status ansible-pull.timer

# Watch logs
journalctl -u ansible-pull.service -f
tail -f /var/log/Debian_KVM_Optimization.log
```

## Architecture

```
├── site.yml                    # Main playbook
├── inventory/hosts.yml          # Host configuration
├── roles/
│   ├── host_system_optimization/
│   ├── host_performance_tuning/
│   ├── host_storage_optimization/
│   ├── ksm_optimization/        # KSM memory deduplication
│   └── network_nat_persistence/ # Network NAT and firewall
├── ansible-pull.service         # Systemd service
├── ansible-pull.timer          # Systemd timer (30min)
└── setup.sh                    # Installation script
```

## Ansible Pull Workflow

- Runs every 30 minutes via systemd timer
- Random delay (0-5 minutes) to prevent load spikes
- Autonomous configuration management
- Logs all changes and system metrics
- Alerts on storage usage >90%

## Key Features

- **Host-only optimization**: No VM configuration changes
- **Storage monitoring**: Critical alerts for 98% /home usage
- **Performance tuning**: Optimized for 12 concurrent VMs
- **KSM memory deduplication**: Replaces broken ksmtuned service
- **Network NAT persistence**: Consolidates and persists existing rules
- **Automated cleanup**: Weekly maintenance tasks
- **Health monitoring**: Storage, CPU, memory, KSM, and network metrics
- **Log management**: Rotation and retention policies

## Manual Operations

```bash
# Run optimization manually
systemctl start ansible-pull.service

# Run specific optimization
ansible-playbook -i inventory/hosts.yml site.yml --tags="storage"
ansible-playbook -i inventory/hosts.yml site.yml --tags="ksm"
ansible-playbook -i inventory/hosts.yml site.yml --tags="network"

# Check KSM status
/usr/local/bin/ksm-optimization.sh stats

# Check network NAT rules
iptables -t nat -L -n -v

# View recent optimizations
tail -50 /var/log/Debian_KVM_Optimization.log
tail -50 /var/log/ksm-optimization.log
tail -50 /var/log/network-setup.log
```

## Monitoring

- **Host metrics**: Every 5 minutes
- **Storage health**: Daily at 2 AM
- **KSM monitoring**: Every 5 minutes
- **Network monitoring**: Every 10 minutes
- **System cleanup**: Weekly on Sunday at 3 AM
- **Optimization logs**: `/var/log/Debian_KVM_Optimization.log`
- **Storage alerts**: `/var/log/host-monitor.log`
- **KSM metrics**: `/var/log/ksm-monitor.log`
- **Network status**: `/var/log/network-monitor.log`

## Customization

Edit `inventory/hosts.yml` to adjust:
- `optimization_level`: conservative, balanced, aggressive
- `cpu_governor`: performance, ondemand, powersave
- `swappiness`: 1-100 (default: 10)
- `usage_alert_threshold`: storage alert percentage

## Security

- Runs as root (required for system optimization)
- Configuration stored in `/opt/kvm-host-optimization`
- Logs rotated automatically
- No external dependencies beyond system packages