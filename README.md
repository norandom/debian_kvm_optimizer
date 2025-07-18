# KVM Host Optimization - Ansible Pull Workflow

Automated optimization for Debian Bookworm KVM virtualization hosts using Ansible pull methodology.

>   Memory Optimization Results:
>
>  - Total allocated VM memory: 107GB across 12 VMs
>  - Actual memory used: 50GB
>  - Memory ballooning savings: ~57GB (53% efficiency)
>  - KSM deduplication: ~1.6GB additional savings
>  - Combined optimization: 58.6GB total memory saved
>
>  This demonstrates that KSM + Memory Ballooning provides container-like density while maintaining full VM security isolation - a compelling alternative to Docker for
>  mixed workload environments with Windows/Linux VMs.

## Overview

This playbook optimizes the **host OS only** for running KVM virtual machines on Debian Bookworm. It focuses on system-level optimizations without touching VM configurations.

## Host System Specifications

- **OS**: Debian GNU/Linux 12 (bookworm)
- **CPU**: Intel i7-8700 (6 cores, 12 threads) with VT-x
- **Memory**: 125GB
- **Storage**: 
  - 2TB root (RAID)
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
- Network stack tuning (incl. Intel power management)
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

### KSM & Memory Ballooning Optimization
- **KSM (Kernel Same-page Merging)**: Aggressive memory deduplication for 12+ VMs
- **Memory Ballooning**: Dynamic memory allocation; saving ~57GB (107GB allocated → 50GB used) (*Linux VMs only - not supported by Windows (Server)*)
- **Security-focused alternative to Docker**: Provides similar consolidation efficiency with better isolation
- **Mixed workload efficiency**: Windows/Linux VMs coexist with optimized resource sharing
- Replaces (broken) ksmtuned service with intelligent adaptive scanning
- Cross-NUMA and zero-page merging for maximum memory efficiency
- Monitoring and auto-optimization every 3-5 minutes

#### Why KSM+Ballooning vs Docker?
- **Better security isolation**: Full VM boundaries 
- **Mixed OS support**: Run Windows, Linux, different distros simultaneously  
- **Enterprise workloads**: Database VMs, legacy applications, compliance requirements
- **Memory efficiency**: ~1.6GB deduplicated via KSM + ~57GB saved via ballooning (107GB allocated, 50GB used)
- **Resource flexibility**: Dynamic CPU/memory allocation without container limitations

### Network NAT Persistence
- Consolidates and persists existing NAT rules (NAT for qemu-kvm guests)
- Port forwarding: SSH (2223), BitTorrent (51413, 6881-6889) etc.
- DNS/DHCP leak prevention on external interface (libvirt services)
- BBR congestion control and buffer optimization
- Automated rule persistence and monitoring

## Quick Start

**Fork and adapt** (!) - I don't maintain your systems. I maintain mine.
This is a Git-Ops style pull workflow (!).

1. **Run setup on host**:
```bash
ssh root@$MY_HOST_IP
curl -O https://raw.githubusercontent.com/norandom/debian_kvm_optimizer/main/setup.sh
chmod +x setup.sh
./setup.sh
```

The setup script will:
- Prompt for your repository URL *(!)*
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
- **Performance tuning**: Optimized for 12+ concurrent VMs
- **KSM memory deduplication**: Replaces ksmtuned service
- **Network NAT persistence**: Consolidates and persists existing Netfilter rules
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

# Check network NAT rules for the guest systems
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
- Commits are signed here
