#!/bin/bash

# Azure Kinect Streaming System - Interactive Installation Script
# Version 2.0 - Interactive Setup for Multiple Machines

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

clear

echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                                                          ║${NC}"
echo -e "${BLUE}║     Azure Kinect Streaming System - Interactive Setup    ║${NC}"
echo -e "${BLUE}║     Version 2.0 - Ubuntu 24.04 Ready                     ║${NC}"
echo -e "${BLUE}║                                                          ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: This script must be run as root${NC}"
    echo "Please run: sudo ./interactive_setup.sh"
    exit 1
fi

# Check if config.env exists, if not create from template
if [ ! -f config.env ]; then
    echo -e "${YELLOW}⚠ config.env not found. Creating from template...${NC}"
    # We'll create it during the interactive setup
fi

echo -e "${CYAN}This interactive setup will automatically detect your system${NC}"
echo -e "${CYAN}configuration and then let you review or customize it.${NC}"
echo ""
echo -e "${YELLOW}Press Enter to start auto-detection or Ctrl+C to cancel...${NC}"
read

# ============================================
# Phase 1: Auto-Detection
# ============================================
clear
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Phase 1: Auto-Detecting System Configuration${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${CYAN}Detecting system information...${NC}"
echo ""

# Network Detection
echo -e "${YELLOW}[1/6] Detecting network configuration...${NC}"
DETECTED_IP=$(hostname -I | awk '{print $1}')
DETECTED_API_PORT=8000
DETECTED_RTSP_PORT=8554
DETECTED_WEBRTC_PORT=8889
DETECTED_HLS_PORT=8890

# Check for port conflicts
if ss -tlnp | grep -q ":${DETECTED_API_PORT} "; then
    DETECTED_API_PORT=8001
fi
if ss -tlnp | grep -q ":${DETECTED_RTSP_PORT} "; then
    DETECTED_RTSP_PORT=8555
fi
if ss -tlnp | grep -q ":${DETECTED_WEBRTC_PORT} "; then
    DETECTED_WEBRTC_PORT=8890
fi
if ss -tlnp | grep -q ":${DETECTED_HLS_PORT} "; then
    DETECTED_HLS_PORT=8891
fi
echo -e "${GREEN}  ✓ Network configuration detected${NC}"

# Kinect Device Detection
echo -e "${YELLOW}[2/6] Detecting Azure Kinect devices...${NC}"
KINECT_COUNT=$(lsusb | grep -i "045e" | wc -l)
DETECTED_DEVICE_ID=0
if [ $KINECT_COUNT -gt 0 ]; then
    echo -e "${GREEN}  ✓ Found $KINECT_COUNT Azure Kinect USB device(s)${NC}"
else
    echo -e "${YELLOW}  ⚠ No Azure Kinect devices detected (will use device ID 0)${NC}"
fi

# Video Settings Detection
echo -e "${YELLOW}[3/6] Detecting video capabilities...${NC}"
DETECTED_RGB_RESOLUTION="1080p"
DETECTED_DEPTH_MODE="NFOV_UNBINNED"
DETECTED_FPS=30
echo -e "${GREEN}  ✓ Video settings configured${NC}"

# Streaming Settings Detection
echo -e "${YELLOW}[4/6] Detecting streaming preferences...${NC}"
DETECTED_STREAM_PRESET="ultrafast"
DETECTED_STREAM_BITRATE="4M"
DETECTED_ENABLE_RGB="Y"
DETECTED_ENABLE_DEPTH="Y"
DETECTED_ENABLE_IR="N"
DETECTED_ENABLE_AUDIO="Y"
echo -e "${GREEN}  ✓ Streaming settings configured${NC}"

# Installation Path Detection
echo -e "${YELLOW}[5/6] Detecting installation preferences...${NC}"
DETECTED_INSTALL_DIR="/opt/kinect-streaming"
DETECTED_USE_VENV=true
DETECTED_ENABLE_XVFB=true
DETECTED_CREATE_SERVICES=true
echo -e "${GREEN}  ✓ Installation preferences configured${NC}"

# Hardware Detection
echo -e "${YELLOW}[6/6] Detecting hardware capabilities...${NC}"
if [ -f scripts/detect_hardware.sh ]; then
    bash scripts/detect_hardware.sh > /tmp/hardware_detection_output.txt 2>&1 || true
    if grep -q "QuickSync\|vaapi\|nvenc" /tmp/hardware_detection_output.txt 2>/dev/null; then
        echo -e "${GREEN}  ✓ Hardware encoding available${NC}"
    else
        echo -e "${YELLOW}  ⚠ Hardware encoding not detected (will use software encoding)${NC}"
    fi
else
    echo -e "${YELLOW}  ⚠ Hardware detection script not found${NC}"
fi

echo ""
echo -e "${GREEN}✓ Auto-detection complete!${NC}"
sleep 2

# ============================================
# Phase 2: Display Detected Configuration
# ============================================
clear
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Phase 2: Detected Configuration${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${CYAN}Network Configuration:${NC}"
echo "  Server IP: ${DETECTED_IP}"
echo "  API Port: ${DETECTED_API_PORT}"
echo "  RTSP Port: ${DETECTED_RTSP_PORT}"
echo "  WebRTC Port: ${DETECTED_WEBRTC_PORT}"
echo "  HLS Port: ${DETECTED_HLS_PORT}"
echo ""

echo -e "${CYAN}Kinect Device Configuration:${NC}"
echo "  Devices Found: $KINECT_COUNT"
echo "  Device ID: ${DETECTED_DEVICE_ID}"
echo "  RGB Resolution: ${DETECTED_RGB_RESOLUTION}"
echo "  Depth Mode: ${DETECTED_DEPTH_MODE}"
echo "  FPS: ${DETECTED_FPS}"
echo ""

echo -e "${CYAN}Streaming Configuration:${NC}"
echo "  Preset: ${DETECTED_STREAM_PRESET}"
echo "  Bitrate: ${DETECTED_STREAM_BITRATE}"
echo "  RGB Stream: ${DETECTED_ENABLE_RGB}"
echo "  Depth Stream: ${DETECTED_ENABLE_DEPTH}"
echo "  IR Stream: ${DETECTED_ENABLE_IR}"
echo "  Audio Stream: ${DETECTED_ENABLE_AUDIO}"
echo ""

echo -e "${CYAN}Installation Settings:${NC}"
echo "  Install Directory: ${DETECTED_INSTALL_DIR}"
echo "  Use Virtual Env: ${DETECTED_USE_VENV}"
echo "  Enable Xvfb: ${DETECTED_ENABLE_XVFB}"
echo "  Create Services: ${DETECTED_CREATE_SERVICES}"
echo ""

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Choose an option:${NC}"
echo "  1) Use auto-detected configuration (recommended)"
echo "  2) Customize configuration manually"
echo ""
read -p "Enter choice [1]: " CONFIG_CHOICE
CONFIG_CHOICE=${CONFIG_CHOICE:-1}

if [ "$CONFIG_CHOICE" = "2" ]; then
    # ============================================
    # Phase 3: Manual Configuration
    # ============================================
    clear
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Phase 3: Manual Configuration${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Network Configuration
    echo -e "${CYAN}Network Configuration:${NC}"
    read -p "Server IP address [${DETECTED_IP}]: " SERVER_IP
    SERVER_IP=${SERVER_IP:-$DETECTED_IP}
    
    read -p "API Port [${DETECTED_API_PORT}]: " API_PORT
    API_PORT=${API_PORT:-$DETECTED_API_PORT}
    
    read -p "MediaMTX RTSP Port [${DETECTED_RTSP_PORT}]: " MEDIAMTX_RTSP_PORT
    MEDIAMTX_RTSP_PORT=${MEDIAMTX_RTSP_PORT:-$DETECTED_RTSP_PORT}
    
    read -p "MediaMTX WebRTC Port [${DETECTED_WEBRTC_PORT}]: " MEDIAMTX_WEBRTC_PORT
    MEDIAMTX_WEBRTC_PORT=${MEDIAMTX_WEBRTC_PORT:-$DETECTED_WEBRTC_PORT}
    
    read -p "MediaMTX HLS Port [${DETECTED_HLS_PORT}]: " MEDIAMTX_HLS_PORT
    MEDIAMTX_HLS_PORT=${MEDIAMTX_HLS_PORT:-$DETECTED_HLS_PORT}
    
    # Kinect Device Configuration
    echo ""
    echo -e "${CYAN}Kinect Device Configuration:${NC}"
    if [ $KINECT_COUNT -gt 0 ]; then
        echo -e "${GREEN}Found $KINECT_COUNT Azure Kinect USB device(s):${NC}"
        lsusb | grep -i "045e" | head -5
        echo ""
    fi
    
    read -p "Kinect Device ID (0 for first, 1 for second, etc.) [${DETECTED_DEVICE_ID}]: " KINECT_DEVICE_ID
    KINECT_DEVICE_ID=${KINECT_DEVICE_ID:-$DETECTED_DEVICE_ID}
    
    read -p "RGB Resolution (720p, 1080p, 1440p, 1536p, 2160p, 3072p) [${DETECTED_RGB_RESOLUTION}]: " KINECT_RGB_RESOLUTION
    KINECT_RGB_RESOLUTION=${KINECT_RGB_RESOLUTION:-$DETECTED_RGB_RESOLUTION}
    
    read -p "Depth Mode (NFOV_UNBINNED, NFOV_2X2BINNED, WFOV_UNBINNED, WFOV_2X2BINNED) [${DETECTED_DEPTH_MODE}]: " KINECT_DEPTH_MODE
    KINECT_DEPTH_MODE=${KINECT_DEPTH_MODE:-$DETECTED_DEPTH_MODE}
    
    read -p "FPS (5, 15, 30) [${DETECTED_FPS}]: " KINECT_FPS
    KINECT_FPS=${KINECT_FPS:-$DETECTED_FPS}
    
    # Streaming Configuration
    echo ""
    echo -e "${CYAN}Streaming Configuration:${NC}"
    read -p "Stream Preset (ultrafast, superfast, veryfast, faster, fast, medium) [${DETECTED_STREAM_PRESET}]: " STREAM_PRESET
    STREAM_PRESET=${STREAM_PRESET:-$DETECTED_STREAM_PRESET}
    
    read -p "Stream Bitrate (e.g., 2M, 4M, 6M, 8M) [${DETECTED_STREAM_BITRATE}]: " STREAM_BITRATE
    STREAM_BITRATE=${STREAM_BITRATE:-$DETECTED_STREAM_BITRATE}
    
    echo ""
    echo -e "${CYAN}Enable Streams:${NC}"
    read -p "Enable RGB stream? [${DETECTED_ENABLE_RGB}]: " ENABLE_RGB
    ENABLE_RGB=${ENABLE_RGB:-$DETECTED_ENABLE_RGB}
    
    read -p "Enable Depth stream? [${DETECTED_ENABLE_DEPTH}]: " ENABLE_DEPTH
    ENABLE_DEPTH=${ENABLE_DEPTH:-$DETECTED_ENABLE_DEPTH}
    
    read -p "Enable IR stream? [${DETECTED_ENABLE_IR}]: " ENABLE_IR
    ENABLE_IR=${ENABLE_IR:-$DETECTED_ENABLE_IR}
    
    read -p "Enable Audio stream? [${DETECTED_ENABLE_AUDIO}]: " ENABLE_AUDIO
    ENABLE_AUDIO=${ENABLE_AUDIO:-$DETECTED_ENABLE_AUDIO}
    
    # Installation Options
    echo ""
    echo -e "${CYAN}Installation Options:${NC}"
    read -p "Install directory [${DETECTED_INSTALL_DIR}]: " INSTALL_DIR
    INSTALL_DIR=${INSTALL_DIR:-$DETECTED_INSTALL_DIR}
    
    read -p "Use Python virtual environment? [Y/n]: " USE_VENV_RESPONSE
    USE_VENV_RESPONSE=${USE_VENV_RESPONSE:-Y}
    if [[ "$USE_VENV_RESPONSE" =~ ^[Yy]$ ]]; then
        USE_VENV=true
    else
        USE_VENV=false
    fi
    
    read -p "Enable Xvfb for headless depth camera? [Y/n]: " ENABLE_XVFB_RESPONSE
    ENABLE_XVFB_RESPONSE=${ENABLE_XVFB_RESPONSE:-Y}
    if [[ "$ENABLE_XVFB_RESPONSE" =~ ^[Yy]$ ]]; then
        ENABLE_XVFB=true
    else
        ENABLE_XVFB=false
    fi
    
    read -p "Create systemd services? [Y/n]: " CREATE_SERVICES_RESPONSE
    CREATE_SERVICES_RESPONSE=${CREATE_SERVICES_RESPONSE:-Y}
    if [[ "$CREATE_SERVICES_RESPONSE" =~ ^[Yy]$ ]]; then
        CREATE_SYSTEMD_SERVICES=true
    else
        CREATE_SYSTEMD_SERVICES=false
    fi
else
    # Use auto-detected values
    SERVER_IP=$DETECTED_IP
    API_PORT=$DETECTED_API_PORT
    MEDIAMTX_RTSP_PORT=$DETECTED_RTSP_PORT
    MEDIAMTX_WEBRTC_PORT=$DETECTED_WEBRTC_PORT
    MEDIAMTX_HLS_PORT=$DETECTED_HLS_PORT
    KINECT_DEVICE_ID=$DETECTED_DEVICE_ID
    KINECT_RGB_RESOLUTION=$DETECTED_RGB_RESOLUTION
    KINECT_DEPTH_MODE=$DETECTED_DEPTH_MODE
    KINECT_FPS=$DETECTED_FPS
    STREAM_PRESET=$DETECTED_STREAM_PRESET
    STREAM_BITRATE=$DETECTED_STREAM_BITRATE
    ENABLE_RGB=$DETECTED_ENABLE_RGB
    ENABLE_DEPTH=$DETECTED_ENABLE_DEPTH
    ENABLE_IR=$DETECTED_ENABLE_IR
    ENABLE_AUDIO=$DETECTED_ENABLE_AUDIO
    INSTALL_DIR=$DETECTED_INSTALL_DIR
    USE_VENV=$DETECTED_USE_VENV
    ENABLE_XVFB=$DETECTED_ENABLE_XVFB
    CREATE_SYSTEMD_SERVICES=$DETECTED_CREATE_SERVICES
fi

# ============================================
# Step 5: Review Configuration
# ============================================
clear
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Final Configuration Review${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# ============================================
# Step 5: Review Configuration
# ============================================
clear
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Step 5: Review Configuration${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${CYAN}Network Settings:${NC}"
echo "  Server IP: $SERVER_IP"
echo "  API Port: $API_PORT"
echo "  RTSP Port: $MEDIAMTX_RTSP_PORT"
echo "  WebRTC Port: $MEDIAMTX_WEBRTC_PORT"
echo "  HLS Port: $MEDIAMTX_HLS_PORT"
echo ""

echo -e "${CYAN}Kinect Settings:${NC}"
echo "  Device ID: $KINECT_DEVICE_ID"
echo "  RGB Resolution: $KINECT_RGB_RESOLUTION"
echo "  Depth Mode: $KINECT_DEPTH_MODE"
echo "  FPS: $KINECT_FPS"
echo ""

echo -e "${CYAN}Streaming Settings:${NC}"
echo "  Preset: $STREAM_PRESET"
echo "  Bitrate: $STREAM_BITRATE"
echo "  RGB: $ENABLE_RGB"
echo "  Depth: $ENABLE_DEPTH"
echo "  IR: $ENABLE_IR"
echo "  Audio: $ENABLE_AUDIO"
echo ""

echo -e "${CYAN}Installation Settings:${NC}"
echo "  Install Directory: $INSTALL_DIR"
echo "  Use Virtual Env: $USE_VENV"
echo "  Enable Xvfb: $ENABLE_XVFB"
echo "  Create Services: $CREATE_SYSTEMD_SERVICES"
echo ""

echo -e "${YELLOW}Review the configuration above.${NC}"
read -p "Proceed with installation? [Y/n]: " CONFIRM
if [[ "$CONFIRM" =~ ^[Nn]$ ]]; then
    echo "Installation cancelled."
    exit 0
fi

# ============================================
# Step 6: Create Configuration File
# ============================================
echo ""
echo -e "${BLUE}Creating configuration file...${NC}"

# Convert Y/N to true/false
if [[ "$ENABLE_RGB" =~ ^[Yy]$ ]]; then ENABLE_RGB_STREAM=true; else ENABLE_RGB_STREAM=false; fi
if [[ "$ENABLE_DEPTH" =~ ^[Yy]$ ]]; then ENABLE_DEPTH_STREAM=true; else ENABLE_DEPTH_STREAM=false; fi
if [[ "$ENABLE_IR" =~ ^[Yy]$ ]]; then ENABLE_IR_STREAM=true; else ENABLE_IR_STREAM=false; fi
if [[ "$ENABLE_AUDIO" =~ ^[Yy]$ ]]; then ENABLE_AUDIO_STREAM=true; else ENABLE_AUDIO_STREAM=false; fi

cat > config.env << CONFIG_FILE
# Kinect Streaming System Configuration
# Generated by interactive_setup.sh

# ============================================
# Server Configuration
# ============================================
SERVER_IP="$SERVER_IP"
API_PORT=$API_PORT
MEDIAMTX_RTSP_PORT=$MEDIAMTX_RTSP_PORT
MEDIAMTX_WEBRTC_PORT=$MEDIAMTX_WEBRTC_PORT
MEDIAMTX_HLS_PORT=$MEDIAMTX_HLS_PORT

# ============================================
# Kinect Device Configuration
# ============================================
KINECT_DEVICE_ID=$KINECT_DEVICE_ID
KINECT_RGB_RESOLUTION="$KINECT_RGB_RESOLUTION"
KINECT_DEPTH_MODE="$KINECT_DEPTH_MODE"
KINECT_FPS=$KINECT_FPS

# ============================================
# Streaming Configuration
# ============================================
STREAM_PRESET="$STREAM_PRESET"
STREAM_BITRATE="$STREAM_BITRATE"
ENABLE_RGB_STREAM=$ENABLE_RGB_STREAM
ENABLE_DEPTH_STREAM=$ENABLE_DEPTH_STREAM
ENABLE_IR_STREAM=$ENABLE_IR_STREAM
ENABLE_AUDIO_STREAM=$ENABLE_AUDIO_STREAM

# ============================================
# Hardware Encoding (auto-detected if empty)
# ============================================
HARDWARE_ENCODER=""

# ============================================
# Installation Paths
# ============================================
INSTALL_DIR="$INSTALL_DIR"
LOG_DIR="/var/log/kinect-streaming"
SERVICE_USER="kinect-streaming"
SERVICE_GROUP="kinect-streaming"

# ============================================
# Python Virtual Environment
# ============================================
USE_VENV=$USE_VENV
VENV_PATH="${INSTALL_DIR}/venv"

# ============================================
# Xvfb Configuration (for headless depth camera)
# ============================================
ENABLE_XVFB=$ENABLE_XVFB
XVFB_DISPLAY=":99"
XVFB_RESOLUTION="1920x1080x24"

# ============================================
# Ubuntu Version (auto-detected, but can override)
# ============================================
UBUNTU_VERSION=""

# ============================================
# Feature Flags
# ============================================
INSTALL_KINECT_SDK=true
INSTALL_MEDIAMTX=true
INSTALL_PYTHON_DEPS=true
INSTALL_XVFB=true
CREATE_SYSTEMD_SERVICES=$CREATE_SYSTEMD_SERVICES
SETUP_FIREWALL=false
AUTO_ACCEPT_EULA=true
CHECK_FIRMWARE=true
INTERACTIVE_PORTS=true

# ============================================
# Development Mode
# ============================================
DEV_MODE=false
CONFIG_FILE

echo -e "${GREEN}✓ Configuration file created${NC}"

# ============================================
# Step 7: Run Installation
# ============================================
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Starting Installation${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${CYAN}The installation will now proceed automatically.${NC}"
echo -e "${CYAN}This may take 10-15 minutes.${NC}"
echo ""
read -p "Press Enter to start installation..."

# Run the main setup script
bash setup.sh

# ============================================
# Installation Complete
# ============================================
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                          ║${NC}"
echo -e "${GREEN}║     Installation Complete! 🎉                             ║${NC}"
echo -e "${GREEN}║                                                          ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}Next Steps:${NC}"
echo ""
echo "1. Start services:"
echo "   ${YELLOW}sudo systemctl start kinect-xvfb kinect-streamer mediamtx${NC}"
echo ""
echo "2. Enable auto-start on boot:"
echo "   ${YELLOW}sudo systemctl enable kinect-xvfb kinect-streamer mediamtx${NC}"
echo ""
echo "3. Check status:"
echo "   ${YELLOW}sudo systemctl status kinect-streamer${NC}"
echo ""
echo "4. Access web dashboard:"
echo "   ${YELLOW}http://${SERVER_IP}:8085${NC}"
echo ""
echo "5. API endpoint:"
echo "   ${YELLOW}http://${SERVER_IP}:${API_PORT}${NC}"
echo ""
echo -e "${CYAN}Configuration saved to: config.env${NC}"
echo ""

