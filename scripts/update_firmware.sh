#!/bin/bash

# Azure Kinect Firmware Update Helper

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

source "$(dirname "$0")/../config.env"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Azure Kinect Firmware Checker${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Check if AzureKinectFirmwareTool is available
if ! command -v AzureKinectFirmwareTool &> /dev/null; then
    echo -e "${RED}✗ AzureKinectFirmwareTool not found${NC}"
    echo "Installing firmware tool..."
    apt-get update -qq
    apt-get install -y k4a-tools
fi

# Check for connected devices
KINECT_COUNT=$(lsusb | grep -i "045e" | wc -l)
if [ $KINECT_COUNT -eq 0 ]; then
    echo -e "${RED}✗ No Azure Kinect devices detected${NC}"
    echo "Please connect your device and try again"
    exit 1
fi

echo -e "${GREEN}✓ Found $KINECT_COUNT Azure Kinect device(s)${NC}\n"

# List connected devices and their firmware
echo "Checking current firmware versions..."
echo ""

AzureKinectFirmwareTool -l || true

echo ""
echo -e "${BLUE}Firmware Information:${NC}"
echo "  Recommended versions:"
echo "    RGB:   1.6.110"
echo "    Depth: 1.6.80"
echo "    Audio: 1.6.14"
echo ""

# Check if firmware update is needed
if [ "$CHECK_FIRMWARE" = true ]; then
    echo "Do you want to check for firmware updates?"
    read -p "Check firmware? [y/N]: " response
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
        # Get firmware info
        FIRMWARE_INFO=$(AzureKinectFirmwareTool -q)
        
        # Parse firmware versions (this is simplified)
        echo ""
        echo "Current firmware status:"
        echo "$FIRMWARE_INFO"
        
        echo ""
        echo "Latest firmware file should be in ${INSTALL_DIR}/firmware/"
        echo "Download from: https://github.com/microsoft/Azure-Kinect-Sensor-SDK/releases"
        echo ""
        
        if [ -d "${INSTALL_DIR}/firmware" ]; then
            FW_FILES=$(find "${INSTALL_DIR}/firmware" -name "*.bin" 2>/dev/null)
            if [ ! -z "$FW_FILES" ]; then
                echo "Found firmware files:"
                echo "$FW_FILES"
                echo ""
                read -p "Update firmware with one of these files? [y/N]: " update_response
                
                if [[ "$update_response" =~ ^[Yy]$ ]]; then
                    echo "Available firmware files:"
                    select fw_file in $FW_FILES "Cancel"; do
                        if [ "$fw_file" = "Cancel" ]; then
                            echo "Firmware update cancelled"
                            break
                        elif [ ! -z "$fw_file" ]; then
                            echo ""
                            echo -e "${YELLOW}⚠ WARNING: Firmware update can take several minutes${NC}"
                            echo -e "${YELLOW}  Do not disconnect the device during update!${NC}"
                            echo ""
                            read -p "Proceed with firmware update? [y/N]: " confirm
                            
                            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                                echo "Updating firmware..."
                                AzureKinectFirmwareTool -u "$fw_file"
                                
                                if [ $? -eq 0 ]; then
                                    echo -e "${GREEN}✓ Firmware updated successfully!${NC}"
                                    echo "Please reconnect your device"
                                else
                                    echo -e "${RED}✗ Firmware update failed${NC}"
                                fi
                            fi
                            break
                        fi
                    done
                fi
            else
                echo -e "${YELLOW}No firmware files found in ${INSTALL_DIR}/firmware${NC}"
            fi
        fi
    fi
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Firmware Check Complete${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Manual firmware update:"
echo "  1. Download firmware from GitHub releases"
echo "  2. Place .bin file in ${INSTALL_DIR}/firmware/"
echo "  3. Run: AzureKinectFirmwareTool -u <firmware.bin>"
echo ""
echo "Check firmware:"
echo "  AzureKinectFirmwareTool -l"
