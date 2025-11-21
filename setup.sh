#!/bin/bash

# Azure Kinect Streaming System - Master Installation Script
# Version 2.0 - With Ubuntu 24.04 Support & Research Enhancements

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

clear

echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                                                      ║${NC}"
echo -e "${BLUE}║     Azure Kinect Streaming System Installer          ║${NC}"
echo -e "${BLUE}║     Version 2.0 - Ubuntu 24.04 Ready                 ║${NC}"
echo -e "${BLUE}║                                                      ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: This script must be run as root${NC}"
    echo "Please run: sudo ./setup.sh"
    exit 1
fi

# Load configuration
if [ ! -f config.env ]; then
    echo -e "${RED}Error: config.env not found${NC}"
    exit 1
fi

source config.env

echo -e "${BLUE}Installation Configuration:${NC}"
echo "  Install Directory: $INSTALL_DIR"
echo "  Service User: $SERVICE_USER"
echo "  Use Virtual Env: $USE_VENV"
echo "  Enable Xvfb: $ENABLE_XVFB"
echo "  Auto-accept EULA: $AUTO_ACCEPT_EULA"
echo "  Interactive Ports: $INTERACTIVE_PORTS"
echo ""

read -p "Continue with installation? [Y/n]: " response
if [[ "$response" =~ ^[Nn]$ ]]; then
    echo "Installation cancelled"
    exit 0
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Step 1: Hardware Detection${NC}"
echo -e "${BLUE}========================================${NC}"

bash scripts/detect_hardware.sh

echo ""
read -p "Continue? [Y/n]: " response
if [[ "$response" =~ ^[Nn]$ ]]; then exit 0; fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Step 2: Port Conflict Check${NC}"
echo -e "${BLUE}========================================${NC}"

bash scripts/check_ports.sh

# Reload config in case ports were changed
source config.env

echo ""
read -p "Continue? [Y/n]: " response
if [[ "$response" =~ ^[Nn]$ ]]; then exit 0; fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Step 3: Azure Kinect SDK${NC}"
echo -e "${BLUE}========================================${NC}"

if [ "$INSTALL_KINECT_SDK" = true ]; then
    bash scripts/install_kinect_sdk.sh
else
    echo "Skipped (INSTALL_KINECT_SDK=false)"
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Step 4: Python Dependencies${NC}"
echo -e "${BLUE}========================================${NC}"

if [ "$INSTALL_PYTHON_DEPS" = true ]; then
    bash scripts/install_python_deps.sh
else
    echo "Skipped (INSTALL_PYTHON_DEPS=false)"
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Step 5: MediaMTX Streaming Server${NC}"
echo -e "${BLUE}========================================${NC}"

if [ "$INSTALL_MEDIAMTX" = true ]; then
    bash scripts/install_mediamtx.sh
else
    echo "Skipped (INSTALL_MEDIAMTX=false)"
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Step 6: Xvfb (Depth Camera Fix)${NC}"
echo -e "${BLUE}========================================${NC}"

if [ "$INSTALL_XVFB" = true ]; then
    bash scripts/install_xvfb.sh
else
    echo "Skipped (INSTALL_XVFB=false)"
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Step 7: Permissions & User Setup${NC}"
echo -e "${BLUE}========================================${NC}"

bash scripts/setup_permissions.sh

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Step 8: Application Files${NC}"
echo -e "${BLUE}========================================${NC}"

echo "Copying application files..."

# Create directories
mkdir -p "$INSTALL_DIR"/{src,scripts,web,docs,firmware}
mkdir -p "$LOG_DIR"

# Copy source files
cp -r src/* "$INSTALL_DIR/src/"
cp -r web/* "$INSTALL_DIR/web/"
cp -r docs/* "$INSTALL_DIR/docs/" 2>/dev/null || true
cp config.env "$INSTALL_DIR/"

# Copy scripts
cp scripts/*.sh "$INSTALL_DIR/scripts/"
chmod +x "$INSTALL_DIR/scripts/"*.sh

echo -e "${GREEN}✓ Application files copied${NC}"

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Step 9: Systemd Services${NC}"
echo -e "${BLUE}========================================${NC}"

if [ "$CREATE_SYSTEMD_SERVICES" = true ]; then
    bash scripts/create_services.sh
else
    echo "Skipped (CREATE_SYSTEMD_SERVICES=false)"
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Step 10: Firmware Check${NC}"
echo -e "${BLUE}========================================${NC}"

if [ "$CHECK_FIRMWARE" = true ]; then
    bash scripts/update_firmware.sh || true
else
    echo "Skipped (CHECK_FIRMWARE=false)"
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Step 11: Installation Validation${NC}"
echo -e "${BLUE}========================================${NC}"

bash scripts/validate_install.sh

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                      ║${NC}"
    echo -e "${GREEN}║     Installation Completed Successfully! 🎉          ║${NC}"
    echo -e "${GREEN}║                                                      ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}Next Steps:${NC}"
    echo ""
    echo "1. Connect your Azure Kinect device(s)"
    echo ""
    echo "2. Start services:"
    echo "   ${YELLOW}sudo systemctl start kinect-xvfb kinect-streamer${NC}"
    echo ""
    echo "3. Enable auto-start on boot:"
    echo "   ${YELLOW}sudo systemctl enable kinect-xvfb kinect-streamer mediamtx${NC}"
    echo ""
    echo "4. Check status:"
    echo "   ${YELLOW}sudo systemctl status kinect-streamer${NC}"
    echo ""
    echo "5. View logs:"
    echo "   ${YELLOW}sudo journalctl -u kinect-streamer -f${NC}"
    echo ""
    echo "6. Access web dashboard:"
    SERVER_IP=$(hostname -I | awk '{print $1}')
    echo "   ${YELLOW}http://${SERVER_IP}:8085${NC}"
    echo ""
    echo "7. API endpoint:"
    echo "   ${YELLOW}http://${SERVER_IP}:${API_PORT}${NC}"
    echo ""
    echo -e "${BLUE}Documentation:${NC}"
    echo "  Installation Guide: ${INSTALL_DIR}/INSTALLATION_GUIDE.md"
    echo "  Depth Camera Fix:   ${INSTALL_DIR}/docs/DEPTH_ENGINE_FIX.md"
    echo "  Research Report:    ${INSTALL_DIR}/docs/RESEARCH_REPORT.md"
    echo "  Web Dashboard:      ${INSTALL_DIR}/web/README.md"
    echo ""
    echo -e "${YELLOW}Tip: Run validation anytime with:${NC}"
    echo "  ${INSTALL_DIR}/scripts/validate_install.sh"
    echo ""
else
    echo ""
    echo -e "${RED}Installation completed with errors${NC}"
    echo "Please review the output above and fix any issues"
    echo ""
    echo "Re-run validation:"
    echo "  sudo ${INSTALL_DIR}/scripts/validate_install.sh"
    exit 1
fi
