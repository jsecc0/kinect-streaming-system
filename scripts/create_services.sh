#!/bin/bash

# Create Systemd Services with Xvfb and Hardware Encoding Support

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

source "$(dirname "$0")/../config.env"

# Load hardware detection if available
if [ -f /tmp/hardware_detection.env ]; then
    source /tmp/hardware_detection.env
fi

# Load Python config if available
if [ -f /tmp/python_config.env ]; then
    source /tmp/python_config.env
fi

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Creating Systemd Services${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Determine Python command
if [ "$USE_VENV" = true ] && [ -f "$VENV_PATH/bin/python3" ]; then
    PYTHON_EXEC="$VENV_PATH/bin/python3"
    echo "Using virtual environment Python: $PYTHON_EXEC"
else
    PYTHON_EXEC=$(which python3)
    echo "Using system Python: $PYTHON_EXEC"
fi

# Determine hardware encoder
if [ ! -z "$HARDWARE_ENCODER" ] && [ "$HARDWARE_ENCODER" != "auto" ]; then
    ENCODER="$HARDWARE_ENCODER"
elif [ ! -z "$RECOMMENDED_ENCODER" ] && [ "$RECOMMENDED_ENCODER" != "none" ]; then
    ENCODER="$RECOMMENDED_ENCODER"
else
    ENCODER="none"
fi

echo "Hardware encoder: $ENCODER"

# Create Xvfb service (if enabled)
if [ "$ENABLE_XVFB" = true ]; then
    echo -e "\n${BLUE}Creating Xvfb service...${NC}"
    
    cat > /etc/systemd/system/kinect-xvfb.service << XVFB_SERVICE
[Unit]
Description=X Virtual Framebuffer for Azure Kinect Depth Engine
Documentation=https://www.x.org/releases/X11R7.6/doc/man/man1/Xvfb.1.xhtml
After=network.target
Before=kinect-streamer.service

[Service]
Type=simple
User=root
Environment="DISPLAY=${XVFB_DISPLAY}"
ExecStart=/usr/bin/Xvfb ${XVFB_DISPLAY} -screen 0 ${XVFB_RESOLUTION} -ac +extension GLX +render -noreset
ExecStop=/usr/bin/pkill -f "Xvfb ${XVFB_DISPLAY}"
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal

# Performance tuning
Nice=-10
IOSchedulingClass=realtime
IOSchedulingPriority=0

[Install]
WantedBy=multi-user.target
XVFB_SERVICE

    echo -e "${GREEN}✓ Xvfb service created${NC}"
fi

# Create kinect-streamer service
echo -e "\n${BLUE}Creating kinect-streamer service...${NC}"

# Build environment variables
ENV_VARS="Environment=\"LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu/libk4a1.4:\$LD_LIBRARY_PATH\""

if [ "$ENABLE_XVFB" = true ]; then
    ENV_VARS="${ENV_VARS}
Environment=\"DISPLAY=${XVFB_DISPLAY}\""
fi

# Add hardware encoder if available
if [ "$ENCODER" != "none" ]; then
    ENV_VARS="${ENV_VARS}
Environment=\"KINECT_ENCODER=$ENCODER\""
fi

cat > /etc/systemd/system/kinect-streamer.service << KINECT_SERVICE
[Unit]
Description=Azure Kinect Streaming Service
Documentation=file://${INSTALL_DIR}/README.md
After=network.target mediamtx.service
$([ "$ENABLE_XVFB" = true ] && echo "After=kinect-xvfb.service")
$([ "$ENABLE_XVFB" = true ] && echo "Requires=kinect-xvfb.service")
Wants=mediamtx.service

[Service]
Type=simple
User=${SERVICE_USER}
Group=${SERVICE_GROUP}
WorkingDirectory=${INSTALL_DIR}

# Environment
$ENV_VARS
Environment="PYTHONUNBUFFERED=1"
Environment="API_PORT=${API_PORT}"
Environment="KINECT_DEVICE_ID=${KINECT_DEVICE_ID}"

# Start command
ExecStart=${PYTHON_EXEC} ${INSTALL_DIR}/src/kinect_streamer.py

# Restart policy
Restart=on-failure
RestartSec=10
StartLimitInterval=200
StartLimitBurst=5

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=kinect-streamer

# Security hardening
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=${INSTALL_DIR} ${LOG_DIR}

# Resource limits
LimitNOFILE=4096
LimitNPROC=512

# Performance tuning
Nice=-5
CPUSchedulingPolicy=fifo
CPUSchedulingPriority=50

[Install]
WantedBy=multi-user.target
KINECT_SERVICE

echo -e "${GREEN}✓ kinect-streamer service created${NC}"

# Reload systemd
echo -e "\n${BLUE}Reloading systemd...${NC}"
systemctl daemon-reload
echo -e "${GREEN}✓ Systemd reloaded${NC}"

# Display service information
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}  Services Created${NC}"
echo -e "${BLUE}========================================${NC}\n"

if [ "$ENABLE_XVFB" = true ]; then
    echo "Xvfb Service:"
    echo "  Status: systemctl status kinect-xvfb"
    echo "  Start:  systemctl start kinect-xvfb"
    echo "  Enable: systemctl enable kinect-xvfb"
    echo ""
fi

echo "Kinect Streamer Service:"
echo "  Status: systemctl status kinect-streamer"
echo "  Start:  systemctl start kinect-streamer"
echo "  Enable: systemctl enable kinect-streamer"
echo "  Logs:   journalctl -u kinect-streamer -f"
echo ""

echo -e "${YELLOW}Note: Enable services to start on boot:${NC}"
if [ "$ENABLE_XVFB" = true ]; then
    echo "  sudo systemctl enable kinect-xvfb"
fi
echo "  sudo systemctl enable kinect-streamer"

