#!/bin/bash

# Uninstall Kinect Streaming System

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [ -f "${SCRIPT_DIR}/config.env" ]; then
    source "${SCRIPT_DIR}/config.env"
fi

INSTALL_DIR="${INSTALL_DIR:-/opt/kinect-streaming}"
LOG_DIR="${LOG_DIR:-/var/log/kinect-streaming}"
SERVICE_USER="${SERVICE_USER:-kinect}"

echo -e "${YELLOW}This will remove the Kinect Streaming System${NC}"
echo -e "${YELLOW}Installation directory: $INSTALL_DIR${NC}"
echo ""
read -p "Are you sure you want to continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Uninstall cancelled"
    exit 0
fi

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run as root (use sudo)${NC}"
    exit 1
fi

echo -e "${YELLOW}Stopping services...${NC}"
systemctl stop kinect-streamer.service 2>/dev/null || true
systemctl stop mediamtx.service 2>/dev/null || true

echo -e "${YELLOW}Disabling services...${NC}"
systemctl disable kinect-streamer.service 2>/dev/null || true
systemctl disable mediamtx.service 2>/dev/null || true

echo -e "${YELLOW}Removing service files...${NC}"
rm -f /etc/systemd/system/kinect-streamer.service
rm -f /etc/systemd/system/mediamtx.service
systemctl daemon-reload

echo -e "${YELLOW}Removing installation directory...${NC}"
rm -rf "$INSTALL_DIR"

echo -e "${YELLOW}Removing log directory...${NC}"
rm -rf "$LOG_DIR"
rm -rf /var/log/mediamtx

echo -e "${YELLOW}Removing MediaMTX...${NC}"
rm -f /usr/local/bin/mediamtx
rm -rf /etc/mediamtx

read -p "Remove Azure Kinect SDK? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Removing Azure Kinect SDK...${NC}"
    apt-get remove -y libk4a1.4 libk4a1.4-dev k4a-tools 2>/dev/null || true
fi

read -p "Remove Python packages? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Removing Python packages...${NC}"
    pip3 uninstall -y pyk4a fastapi uvicorn opencv-python numpy 2>/dev/null || true
fi

read -p "Remove service user '$SERVICE_USER'? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Removing service user...${NC}"
    userdel -r "$SERVICE_USER" 2>/dev/null || true
fi

echo -e "${YELLOW}Removing udev rules...${NC}"
rm -f /etc/udev/rules.d/99-k4a.rules
udevadm control --reload-rules

echo -e "\n${GREEN}✓ Uninstall complete!${NC}"
echo -e "Note: Some dependencies (FFmpeg, Python3) were not removed as they may be used by other applications"
