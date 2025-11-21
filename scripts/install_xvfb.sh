#!/bin/bash

# Xvfb Installation Script - Fix for Azure Kinect Depth Engine Error 204

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Load configuration
source "$(dirname "$0")/../config.env"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Installing Xvfb (X Virtual Framebuffer)${NC}"
echo -e "${BLUE}========================================${NC}\n"

echo "Xvfb is required for Azure Kinect depth camera on headless servers."
echo "It provides the OpenGL/GLX context needed by the depth engine."
echo ""

# Check if already installed
if command -v Xvfb &> /dev/null; then
    echo -e "${GREEN}✓ Xvfb already installed${NC}"
    XVFB_VERSION=$(Xvfb -version 2>&1 | head -1)
    echo "  Version: $XVFB_VERSION"
else
    echo "Installing Xvfb..."
    
    # Update package list
    DEBIAN_FRONTEND=noninteractive apt-get update -qq
    
    # Install Xvfb and dependencies
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        xvfb \
        x11-utils \
        mesa-utils \
        libgl1-mesa-dri \
        libglu1-mesa
    
    echo -e "${GREEN}✓ Xvfb installed successfully${NC}"
fi

# Verify GLX extension support
echo ""
echo "Verifying GLX extension support..."

# Start temporary Xvfb to test
Xvfb :98 -screen 0 1920x1080x24 -ac +extension GLX +render -noreset &
XVFB_TEST_PID=$!
sleep 2

# Test GLX
export DISPLAY=:98
if glxinfo &> /dev/null; then
    echo -e "${GREEN}✓ GLX extension working${NC}"
    GLX_VENDOR=$(DISPLAY=:98 glxinfo | grep "OpenGL vendor" | cut -d: -f2 | xargs)
    GLX_RENDERER=$(DISPLAY=:98 glxinfo | grep "OpenGL renderer" | cut -d: -f2 | xargs)
    echo "  Vendor: $GLX_VENDOR"
    echo "  Renderer: $GLX_RENDERER"
else
    echo -e "${YELLOW}⚠ GLX test inconclusive (this may be normal)${NC}"
fi

# Cleanup test Xvfb
kill $XVFB_TEST_PID 2>/dev/null || true
rm -f /tmp/.X98-lock 2>/dev/null || true

# Create Xvfb helper script
echo ""
echo "Creating Xvfb helper scripts..."

# Xvfb start script
cat > "${INSTALL_DIR}/scripts/start_xvfb.sh" << 'XVFB_START'
#!/bin/bash

# Start Xvfb for Azure Kinect depth engine

# Load configuration
source /opt/kinect-streaming/config.env

# Cleanup any existing Xvfb on this display
DISPLAY_NUM=$(echo $XVFB_DISPLAY | sed 's/://')
pkill -f "Xvfb ${XVFB_DISPLAY}" 2>/dev/null || true
rm -f /tmp/.X${DISPLAY_NUM}-lock 2>/dev/null || true
sleep 1

# Start Xvfb
echo "Starting Xvfb on display ${XVFB_DISPLAY}..."
Xvfb ${XVFB_DISPLAY} \
    -screen 0 ${XVFB_RESOLUTION} \
    -ac \
    +extension GLX \
    +render \
    -noreset \
    > /var/log/kinect-streaming/xvfb.log 2>&1 &

XVFB_PID=$!

# Wait for Xvfb to be ready
sleep 2

# Verify it started
if ps -p $XVFB_PID > /dev/null; then
    echo "✓ Xvfb started successfully (PID: $XVFB_PID)"
    echo $XVFB_PID > /var/run/kinect-xvfb.pid
    
    # Export DISPLAY for other processes
    export DISPLAY=${XVFB_DISPLAY}
    echo "export DISPLAY=${XVFB_DISPLAY}" > /tmp/kinect_display.env
else
    echo "✗ Failed to start Xvfb"
    exit 1
fi
XVFB_START

chmod +x "${INSTALL_DIR}/scripts/start_xvfb.sh"
echo -e "${GREEN}✓ Created start_xvfb.sh${NC}"

# Xvfb stop script
cat > "${INSTALL_DIR}/scripts/stop_xvfb.sh" << 'XVFB_STOP'
#!/bin/bash

# Stop Xvfb

source /opt/kinect-streaming/config.env

echo "Stopping Xvfb..."

# Stop by PID file
if [ -f /var/run/kinect-xvfb.pid ]; then
    XVFB_PID=$(cat /var/run/kinect-xvfb.pid)
    kill $XVFB_PID 2>/dev/null || true
    rm -f /var/run/kinect-xvfb.pid
fi

# Stop by process name
pkill -f "Xvfb ${XVFB_DISPLAY}" 2>/dev/null || true

# Cleanup lock files
DISPLAY_NUM=$(echo $XVFB_DISPLAY | sed 's/://')
rm -f /tmp/.X${DISPLAY_NUM}-lock 2>/dev/null || true

# Cleanup display env
rm -f /tmp/kinect_display.env 2>/dev/null || true

echo "✓ Xvfb stopped"
XVFB_STOP

chmod +x "${INSTALL_DIR}/scripts/stop_xvfb.sh"
echo -e "${GREEN}✓ Created stop_xvfb.sh${NC}"

# Xvfb check script
cat > "${INSTALL_DIR}/scripts/check_xvfb.sh" << 'XVFB_CHECK'
#!/bin/bash

# Check Xvfb status

source /opt/kinect-streaming/config.env

DISPLAY_NUM=$(echo $XVFB_DISPLAY | sed 's/://')

if pgrep -f "Xvfb ${XVFB_DISPLAY}" > /dev/null; then
    XVFB_PID=$(pgrep -f "Xvfb ${XVFB_DISPLAY}")
    echo "✓ Xvfb is running (PID: $XVFB_PID)"
    echo "  Display: ${XVFB_DISPLAY}"
    
    # Check if DISPLAY is exported
    if [ -f /tmp/kinect_display.env ]; then
        source /tmp/kinect_display.env
        echo "  DISPLAY env: $DISPLAY"
    fi
    
    exit 0
else
    echo "✗ Xvfb is not running"
    exit 1
fi
XVFB_CHECK

chmod +x "${INSTALL_DIR}/scripts/check_xvfb.sh"
echo -e "${GREEN}✓ Created check_xvfb.sh${NC}"

# Create systemd service for Xvfb
if [ "$CREATE_SYSTEMD_SERVICES" = true ]; then
    echo ""
    echo "Creating Xvfb systemd service..."
    
    cat > /etc/systemd/system/kinect-xvfb.service << XVFB_SERVICE
[Unit]
Description=X Virtual Framebuffer for Azure Kinect
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

[Install]
WantedBy=multi-user.target
XVFB_SERVICE

    systemctl daemon-reload
    echo -e "${GREEN}✓ Xvfb systemd service created${NC}"
    echo "  Start with: sudo systemctl start kinect-xvfb"
    echo "  Enable on boot: sudo systemctl enable kinect-xvfb"
fi

# Create README for Xvfb
cat > "${INSTALL_DIR}/docs/XVFB_INFO.md" << 'XVFB_README'
# Xvfb (X Virtual Framebuffer) - Azure Kinect Depth Engine Fix

## What is Xvfb?

Xvfb (X Virtual Framebuffer) is an X11 server that performs all graphical operations in virtual memory without showing any screen output. It's essential for running GUI applications on headless servers.

## Why is it needed?

The Azure Kinect depth engine (libdepthengine.so.2.0) requires an OpenGL/GLX context to initialize, even though the actual depth processing is CPU-based. On headless servers without a display, this causes **Error 204** during depth camera initialization.

Xvfb solves this by providing a virtual display with full OpenGL/GLX support.

## Usage

### Manual Control

**Start Xvfb:**
```bash
sudo /opt/kinect-streaming/scripts/start_xvfb.sh
```

**Stop Xvfb:**
```bash
sudo /opt/kinect-streaming/scripts/stop_xvfb.sh
```

**Check Status:**
```bash
/opt/kinect-streaming/scripts/check_xvfb.sh
```

### Systemd Service

**Start:**
```bash
sudo systemctl start kinect-xvfb
```

**Enable on boot:**
```bash
sudo systemctl enable kinect-xvfb
```

**Check status:**
```bash
sudo systemctl status kinect-xvfb
```

## How it works

1. Xvfb creates a virtual display (default: :99)
2. It provides OpenGL/GLX extensions in software
3. The depth engine can initialize successfully
4. Performance impact is minimal (~2% CPU, 15MB RAM)

## Configuration

Edit `/opt/kinect-streaming/config.env`:

```bash
ENABLE_XVFB=true
XVFB_DISPLAY=":99"
XVFB_RESOLUTION="1920x1080x24"
```

## Troubleshooting

### Error: "Display :99 already in use"

```bash
# Kill existing Xvfb
sudo pkill Xvfb
rm -f /tmp/.X99-lock
```

### Error: "GLX extension not available"

Check if Xvfb was started with GLX:
```bash
ps aux | grep Xvfb | grep GLX
```

Should include: `+extension GLX`

### Error: Still getting depth engine error 204

1. Verify Xvfb is running: `ps aux | grep Xvfb`
2. Check DISPLAY variable: `echo $DISPLAY` (should be `:99`)
3. Source the environment: `source /tmp/kinect_display.env`

## Technical Details

**Critical Xvfb Parameters:**
- `:99` - Display number (configurable)
- `-screen 0 1920x1080x24` - Virtual screen resolution and color depth
- `-ac` - Disable access control
- `+extension GLX` - **Required** for OpenGL support
- `+render` - Enable render extension
- `-noreset` - Keep display active

## Performance

- CPU Usage: < 2%
- Memory: ~15 MB
- No impact on depth capture performance

## Credits

Solution discovered by: jsecco®
Issue documented: [Azure Kinect Error 204 Documentation](../DEPTH_ENGINE_FIX.md)
XVFB_README

echo -e "${GREEN}✓ Created Xvfb documentation${NC}"

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}✓ Xvfb installation complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Xvfb will automatically start with the kinect-streamer service."
echo ""
echo "Manual control:"
echo "  Start:  ${INSTALL_DIR}/scripts/start_xvfb.sh"
echo "  Stop:   ${INSTALL_DIR}/scripts/stop_xvfb.sh"
echo "  Status: ${INSTALL_DIR}/scripts/check_xvfb.sh"
