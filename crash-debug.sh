#!/bin/bash
# Crash Debug Monitoring Script
# Monitors system for conditions that could lead to crashes
# Usage: ./crash-debug.sh

LOG_FILE="/var/log/crash-debug.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Ensure log file exists
touch "$LOG_FILE"

echo "[$TIMESTAMP] === CRASH DEBUG MONITOR START ===" >> "$LOG_FILE"

# 1. Check Intel I219-LM network interface status
echo "[$TIMESTAMP] Network Interface Status:" >> "$LOG_FILE"
if ip link show eno1 &>/dev/null; then
    LINK_STATUS=$(ip link show eno1 | grep -o 'state [A-Z]*' | awk '{print $2}')
    echo "[$TIMESTAMP] eno1 link state: $LINK_STATUS" >> "$LOG_FILE"
    
    # Check for Hardware Unit Hangs in recent dmesg
    RECENT_HANGS=$(dmesg | grep -c "Hardware Unit Hang" | tail -1)
    echo "[$TIMESTAMP] Hardware Unit Hangs detected: $RECENT_HANGS" >> "$LOG_FILE"
    
    # Network interface error counts
    RX_ERRORS=$(cat /sys/class/net/eno1/statistics/rx_errors 2>/dev/null || echo "0")
    TX_ERRORS=$(cat /sys/class/net/eno1/statistics/tx_errors 2>/dev/null || echo "0")
    echo "[$TIMESTAMP] eno1 RX errors: $RX_ERRORS, TX errors: $TX_ERRORS" >> "$LOG_FILE"
else
    echo "[$TIMESTAMP] ERROR: eno1 interface not found!" >> "$LOG_FILE"
fi

# 2. Check IRQ status and interrupt counts
echo "[$TIMESTAMP] IRQ Status:" >> "$LOG_FILE"
# Check if any IRQs are disabled
DISABLED_IRQS=$(grep "disabled" /proc/interrupts | wc -l)
echo "[$TIMESTAMP] Disabled IRQs: $DISABLED_IRQS" >> "$LOG_FILE"

# Check IRQ 16 specifically (was problematic)
IRQ16_COUNT=$(grep "^ *16:" /proc/interrupts | awk '{print $2}' | head -1)
echo "[$TIMESTAMP] IRQ 16 count: ${IRQ16_COUNT:-0}" >> "$LOG_FILE"

# Check for IRQ storms (>100k interrupts)
HIGH_IRQ=$(awk '$2 > 100000 {print $1 $2}' /proc/interrupts | wc -l)
echo "[$TIMESTAMP] High interrupt count IRQs (>100k): $HIGH_IRQ" >> "$LOG_FILE"

# 3. Memory pressure and swap usage
echo "[$TIMESTAMP] Memory Status:" >> "$LOG_FILE"
MEMORY_TOTAL=$(grep MemTotal /proc/meminfo | awk '{print $2}')
MEMORY_AVAILABLE=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
MEMORY_USED=$((MEMORY_TOTAL - MEMORY_AVAILABLE))
MEMORY_PCT=$((MEMORY_USED * 100 / MEMORY_TOTAL))

SWAP_TOTAL=$(grep SwapTotal /proc/meminfo | awk '{print $2}')
SWAP_FREE=$(grep SwapFree /proc/meminfo | awk '{print $2}')
SWAP_USED=$((SWAP_TOTAL - SWAP_FREE))

echo "[$TIMESTAMP] Memory usage: ${MEMORY_PCT}%, Swap used: ${SWAP_USED}KB" >> "$LOG_FILE"

# 4. System load and CPU utilization
echo "[$TIMESTAMP] System Load:" >> "$LOG_FILE"
LOAD_1MIN=$(cat /proc/loadavg | awk '{print $1}')
LOAD_5MIN=$(cat /proc/loadavg | awk '{print $2}')
LOAD_15MIN=$(cat /proc/loadavg | awk '{print $3}')
echo "[$TIMESTAMP] Load: 1min=$LOAD_1MIN, 5min=$LOAD_5MIN, 15min=$LOAD_15MIN" >> "$LOG_FILE"

# 5. Thermal status
echo "[$TIMESTAMP] Thermal Status:" >> "$LOG_FILE"
if command -v sensors &>/dev/null; then
    CORE_TEMPS=$(sensors | grep "Core" | awk '{print $3}' | tr -d '+°C' | sort -n | tail -1)
    echo "[$TIMESTAMP] Highest core temp: ${CORE_TEMPS}°C" >> "$LOG_FILE"
else
    # Fallback to thermal zones
    for zone in /sys/class/thermal/thermal_zone*/temp; do
        if [[ -r "$zone" ]]; then
            TEMP=$(cat "$zone" 2>/dev/null)
            TEMP_C=$((TEMP / 1000))
            ZONE_NAME=$(basename $(dirname "$zone"))
            echo "[$TIMESTAMP] $ZONE_NAME: ${TEMP_C}°C" >> "$LOG_FILE"
        fi
    done
fi

# 6. Check for kernel errors/warnings in recent dmesg
echo "[$TIMESTAMP] Recent Kernel Messages:" >> "$LOG_FILE"
RECENT_ERRORS=$(dmesg | tail -50 | grep -i -E "error|warning|fail|panic|oops|bug|critical" | wc -l)
echo "[$TIMESTAMP] Recent kernel errors/warnings: $RECENT_ERRORS" >> "$LOG_FILE"

# Log specific concerning messages if found
if [[ $RECENT_ERRORS -gt 0 ]]; then
    dmesg | tail -50 | grep -i -E "error|warning|fail|panic|oops|bug|critical" | while read line; do
        echo "[$TIMESTAMP] KERNEL: $line" >> "$LOG_FILE"
    done
fi

# 7. VM status
echo "[$TIMESTAMP] VM Status:" >> "$LOG_FILE"
if command -v virsh &>/dev/null; then
    RUNNING_VMS=$(virsh list --state-running --name | wc -l)
    echo "[$TIMESTAMP] Running VMs: $RUNNING_VMS" >> "$LOG_FILE"
else
    echo "[$TIMESTAMP] libvirt not available" >> "$LOG_FILE"
fi

# 8. Connection tracking status
echo "[$TIMESTAMP] Connection Tracking:" >> "$LOG_FILE"
if [[ -f /proc/net/nf_conntrack ]]; then
    CONNTRACK_CURRENT=$(cat /proc/net/nf_conntrack | wc -l)
    CONNTRACK_MAX=$(cat /proc/sys/net/netfilter/nf_conntrack_max)
    CONNTRACK_PCT=$((CONNTRACK_CURRENT * 100 / CONNTRACK_MAX))
    echo "[$TIMESTAMP] Conntrack: $CONNTRACK_CURRENT/$CONNTRACK_MAX (${CONNTRACK_PCT}%)" >> "$LOG_FILE"
fi

# 9. Check for out of memory conditions
echo "[$TIMESTAMP] OOM Status:" >> "$LOG_FILE"
OOM_KILLS=$(dmesg | grep -c "Out of memory: Kill process" || echo "0")
echo "[$TIMESTAMP] Total OOM kills: $OOM_KILLS" >> "$LOG_FILE"

# 10. Check ethtool settings (ensure offloading still disabled)
echo "[$TIMESTAMP] Network Offloading Status:" >> "$LOG_FILE"
if command -v ethtool &>/dev/null && ip link show eno1 &>/dev/null; then
    TX_OFF=$(ethtool -k eno1 | grep "tx-checksumming" | grep -o "off\|on")
    RX_OFF=$(ethtool -k eno1 | grep "rx-checksumming" | grep -o "off\|on")
    TSO_OFF=$(ethtool -k eno1 | grep "tcp-segmentation-offload" | grep -o "off\|on")
    echo "[$TIMESTAMP] eno1 offloading - TX: $TX_OFF, RX: $RX_OFF, TSO: $TSO_OFF" >> "$LOG_FILE"
fi

echo "[$TIMESTAMP] === CRASH DEBUG MONITOR END ===" >> "$LOG_FILE"

# Log rotation - keep last 10000 lines
if [[ $(wc -l < "$LOG_FILE") -gt 10000 ]]; then
    tail -n 5000 "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
fi