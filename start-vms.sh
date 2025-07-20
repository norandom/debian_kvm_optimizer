#!/bin/bash
# VM Startup Script - Start all VMs in specified order
# Usage: ./start-vms.sh

# VM list (filer last as requested)
VMS=("genai" "bookstack" "devwrld" "gitea" "InfoSecSystem" "jupy" "k3s" "observe" "websrv" "work" "filer")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Starting VMs on server...${NC}"

# Function to start a VM
start_vm() {
    local vm_name=$1
    echo -e "${YELLOW}Starting VM: ${vm_name}${NC}"
    
    if virsh start ${vm_name} 2>/dev/null; then
        echo -e "${GREEN}✓ ${vm_name} started successfully${NC}"
        return 0
    else
        echo -e "${RED}✗ Failed to start ${vm_name}${NC}"
        return 1
    fi
}

# Start each VM
for vm in "${VMS[@]}"; do
    start_vm "$vm"
    # Small delay between starts to avoid overloading the host
    sleep 2
done

echo -e "${YELLOW}Checking VM status...${NC}"
virsh list --all

echo -e "${GREEN}VM startup script completed!${NC}"