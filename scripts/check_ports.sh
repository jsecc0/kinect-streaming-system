#!/bin/bash

# Port Conflict Checker and Interactive Port Selection

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Load configuration
source "$(dirname "$0")/../config.env"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Port Conflict Detection${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Ports to check
declare -A PORTS=(
    ["API_PORT"]=$API_PORT
    ["MEDIAMTX_RTSP_PORT"]=$MEDIAMTX_RTSP_PORT
    ["MEDIAMTX_WEBRTC_PORT"]=$MEDIAMTX_WEBRTC_PORT
    ["MEDIAMTX_HLS_PORT"]=$MEDIAMTX_HLS_PORT
)

declare -A PORT_CONFLICTS=()
declare -A PORT_PROCESSES=()

# Function to check if port is in use
check_port() {
    local port=$1
    if ss -tlnp | grep -q ":$port "; then
        return 0  # Port is in use
    else
        return 1  # Port is available
    fi
}

# Function to get process using port
get_port_process() {
    local port=$1
    ss -tlnp | grep ":$port " | awk '{print $NF}' | head -1
}

# Function to find next available port
find_available_port() {
    local start_port=$1
    local port=$start_port
    
    while check_port $port; do
        ((port++))
        if [ $port -gt 65535 ]; then
            echo "ERROR: No available ports found"
            return 1
        fi
    done
    
    echo $port
}

# Check all configured ports
echo "Checking configured ports..."
echo ""

HAS_CONFLICTS=false

for port_name in "${!PORTS[@]}"; do
    port=${PORTS[$port_name]}
    
    printf "  %-25s " "$port_name ($port):"
    
    if check_port $port; then
        HAS_CONFLICTS=true
        process=$(get_port_process $port)
        PORT_CONFLICTS[$port_name]=$port
        PORT_PROCESSES[$port_name]=$process
        echo -e "${RED}✗ IN USE${NC} - $process"
    else
        echo -e "${GREEN}✓ Available${NC}"
    fi
done

# If no conflicts, we're done
if [ "$HAS_CONFLICTS" = false ]; then
    echo -e "\n${GREEN}✓ All ports are available!${NC}"
    exit 0
fi

# Handle conflicts
echo -e "\n${YELLOW}⚠ Port conflicts detected${NC}\n"

if [ "$INTERACTIVE_PORTS" = true ]; then
    echo "Would you like to automatically select alternative ports?"
    echo -e "${YELLOW}Options:${NC}"
    echo "  1) Auto-select next available ports (recommended)"
    echo "  2) Manually specify ports"
    echo "  3) Show conflicting services and exit"
    echo ""
    read -p "Select option [1-3]: " choice
    
    case $choice in
        1)
            # Auto-select next available ports
            echo -e "\n${BLUE}Auto-selecting available ports...${NC}\n"
            
            for port_name in "${!PORT_CONFLICTS[@]}"; do
                original_port=${PORT_CONFLICTS[$port_name]}
                new_port=$(find_available_port $original_port)
                
                echo -e "  $port_name: $original_port → ${GREEN}$new_port${NC}"
                
                # Update config.env
                sed -i "s/^${port_name}=.*/${port_name}=${new_port}/" "$(dirname "$0")/../config.env"
            done
            
            echo -e "\n${GREEN}✓ Configuration updated with available ports${NC}"
            echo "Updated config.env saved"
            ;;
            
        2)
            # Manual port specification
            echo -e "\n${BLUE}Manual port configuration:${NC}\n"
            
            for port_name in "${!PORT_CONFLICTS[@]}"; do
                original_port=${PORT_CONFLICTS[$port_name]}
                
                while true; do
                    read -p "Enter new port for $port_name [$original_port]: " new_port
                    
                    # Use original if empty
                    if [ -z "$new_port" ]; then
                        new_port=$original_port
                    fi
                    
                    # Validate port number
                    if ! [[ "$new_port" =~ ^[0-9]+$ ]] || [ "$new_port" -lt 1024 ] || [ "$new_port" -gt 65535 ]; then
                        echo -e "${RED}Invalid port number. Use 1024-65535${NC}"
                        continue
                    fi
                    
                    # Check if available
                    if check_port $new_port && [ "$new_port" != "$original_port" ]; then
                        echo -e "${RED}Port $new_port is already in use. Try another.${NC}"
                        continue
                    fi
                    
                    # Update config
                    sed -i "s/^${port_name}=.*/${port_name}=${new_port}/" "$(dirname "$0")/../config.env"
                    echo -e "${GREEN}✓ $port_name set to $new_port${NC}"
                    break
                done
            done
            
            echo -e "\n${GREEN}✓ Manual configuration complete${NC}"
            ;;
            
        3)
            # Show details and exit
            echo -e "\n${BLUE}Conflicting services:${NC}\n"
            
            for port_name in "${!PORT_CONFLICTS[@]}"; do
                port=${PORT_CONFLICTS[$port_name]}
                process=${PORT_PROCESSES[$port_name]}
                
                echo "  Port $port ($port_name):"
                echo "    Process: $process"
                
                # Try to get more details
                pid=$(ss -tlnp | grep ":$port " | awk -F'pid=' '{print $2}' | awk -F',' '{print $1}' | head -1)
                if [ ! -z "$pid" ]; then
                    cmdline=$(ps -p $pid -o cmd --no-headers 2>/dev/null || echo "Unknown")
                    echo "    PID: $pid"
                    echo "    Command: $cmdline"
                fi
                echo ""
            done
            
            echo "To resolve conflicts:"
            echo "  1. Stop the conflicting services"
            echo "  2. Edit config.env to use different ports"
            echo "  3. Run this script again"
            echo ""
            exit 1
            ;;
            
        *)
            echo -e "${RED}Invalid option${NC}"
            exit 1
            ;;
    esac
else
    # Non-interactive mode - auto-select
    echo "Auto-selecting next available ports..."
    
    for port_name in "${!PORT_CONFLICTS[@]}"; do
        original_port=${PORT_CONFLICTS[$port_name]}
        new_port=$(find_available_port $original_port)
        
        echo "  $port_name: $original_port → $new_port"
        sed -i "s/^${port_name}=.*/${port_name}=${new_port}/" "$(dirname "$0")/../config.env"
    done
    
    echo -e "${GREEN}✓ Ports automatically updated${NC}"
fi

# Reload config
source "$(dirname "$0")/../config.env"

# Display final configuration
echo -e "\n${BLUE}Final Port Configuration:${NC}"
echo "  API Port:        $API_PORT"
echo "  RTSP Port:       $MEDIAMTX_RTSP_PORT"
echo "  WebRTC Port:     $MEDIAMTX_WEBRTC_PORT"
echo "  HLS Port:        $MEDIAMTX_HLS_PORT"
echo ""

# Save port configuration
cat > /tmp/port_config.env << EOF
API_PORT=$API_PORT
MEDIAMTX_RTSP_PORT=$MEDIAMTX_RTSP_PORT
MEDIAMTX_WEBRTC_PORT=$MEDIAMTX_WEBRTC_PORT
MEDIAMTX_HLS_PORT=$MEDIAMTX_HLS_PORT
EOF

echo -e "${GREEN}✓ Port configuration saved${NC}"
