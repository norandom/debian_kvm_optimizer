#!/bin/bash
# Interface Watchdog Script for Intel I219-LM
# Monitors ethernet interface for link state and tx queue lockups
# Detects IRQ storms and e1000e driver issues
# Usage: ./interface-watchdog.sh [interface_name]

INTERFACE="${1:-eno1}"
SLEEP_INTERVAL=30
LOG_FILE="/root/interface-watchdog.log"

# Function to log to both stdout and file
log_message() {
    local msg="$1"
    echo "$msg"
    echo "$msg" >> "$LOG_FILE"
}

log_message "Starting Intel I219-LM watchdog for $INTERFACE (checking every ${SLEEP_INTERVAL}s)"
log_message "$(date): Watchdog started - monitoring $INTERFACE for link state and tx queue lockups"

# Track previous stats for comparison
PREV_TX_BYTES=0
PREV_TX_PACKETS=0
PREV_IRQ16_COUNT=0

perform_interface_reset() {
    local reason="$1"
    log_message "$(date): ALERT - $reason - initiating interface reset"
    
    # Step 1: Check for Hardware Unit Hangs in dmesg
    HW_HANGS=$(dmesg | tail -50 | grep -c "Hardware Unit Hang" || echo "0")
    if [[ $HW_HANGS -gt 0 ]]; then
        log_message "$(date): WARNING - Detected $HW_HANGS Hardware Unit Hangs in recent dmesg"
    fi
    
    # Step 2: Bring interface down
    log_message "$(date): Step 1/3 - Bringing interface down"
    ip link set "$INTERFACE" down
    
    # Step 3: Disable hardware offloading (critical for I219-LM)
    log_message "$(date): Step 2/3 - Disabling hardware offloading"
    ethtool -K "$INTERFACE" tx off rx off tso off gso off gro off lro off ufo off txvlan off rxvlan off ntuple off 2>/dev/null || true
    
    # Step 4: Bring interface back up
    log_message "$(date): Step 3/3 - Bringing interface up"
    ip link set "$INTERFACE" up
    
    # Wait for link to establish
    sleep 5
    
    # Check result
    NEW_STATE=$(ip link show "$INTERFACE" | grep -o 'state [A-Z]*' | awk '{print $2}')
    if [[ "$NEW_STATE" == "UP" ]]; then
        log_message "$(date): SUCCESS - Interface $INTERFACE reset successfully (state: $NEW_STATE)"
    else
        log_message "$(date): FAILED - Interface $INTERFACE still down after reset (state: $NEW_STATE)"
    fi
}

while true; do
    # Check if interface exists
    if ! ip link show "$INTERFACE" &>/dev/null; then
        log_message "$(date): ERROR - Interface $INTERFACE not found!"
        sleep $SLEEP_INTERVAL
        continue
    fi
    
    # Get interface state
    LINK_STATE=$(ip link show "$INTERFACE" | grep -o 'state [A-Z]*' | awk '{print $2}')
    
    # Get current network statistics
    TX_BYTES=$(cat "/sys/class/net/$INTERFACE/statistics/tx_bytes" 2>/dev/null || echo "0")
    TX_PACKETS=$(cat "/sys/class/net/$INTERFACE/statistics/tx_packets" 2>/dev/null || echo "0")
    TX_ERRORS=$(cat "/sys/class/net/$INTERFACE/statistics/tx_errors" 2>/dev/null || echo "0")
    TX_DROPPED=$(cat "/sys/class/net/$INTERFACE/statistics/tx_dropped" 2>/dev/null || echo "0")
    
    # Check IRQ 16 count (common issue with I219-LM)
    IRQ16_COUNT=$(grep "^ *16:" /proc/interrupts | awk '{print $2}' | head -1 || echo "0")
    
    # Check for interface down
    if [[ "$LINK_STATE" != "UP" ]]; then
        perform_interface_reset "Interface $INTERFACE is $LINK_STATE"
        
    # Check for tx queue lockup (no tx activity but errors/drops increasing)
    elif [[ $TX_BYTES -eq $PREV_TX_BYTES ]] && [[ $TX_PACKETS -eq $PREV_TX_PACKETS ]] && [[ $TX_ERRORS -gt 0 || $TX_DROPPED -gt 0 ]]; then
        log_message "$(date): TX queue potentially locked - bytes: $TX_BYTES (no change), errors: $TX_ERRORS, dropped: $TX_DROPPED"
        perform_interface_reset "TX queue lockup detected"
        
    # Check for IRQ storm on IRQ 16 (massive increase)
    elif [[ $PREV_IRQ16_COUNT -gt 0 ]] && [[ $IRQ16_COUNT -gt $((PREV_IRQ16_COUNT + 50000)) ]]; then
        log_message "$(date): IRQ storm detected - IRQ 16 count jumped from $PREV_IRQ16_COUNT to $IRQ16_COUNT"
        perform_interface_reset "IRQ storm on IRQ 16"
        
    else
        log_message "$(date): Interface $INTERFACE healthy - state: $LINK_STATE, tx_bytes: $TX_BYTES, tx_errors: $TX_ERRORS, irq16: $IRQ16_COUNT"
    fi
    
    # Update previous values
    PREV_TX_BYTES=$TX_BYTES
    PREV_TX_PACKETS=$TX_PACKETS
    PREV_IRQ16_COUNT=$IRQ16_COUNT
    
    sleep $SLEEP_INTERVAL
done