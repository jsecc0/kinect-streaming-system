#!/bin/bash

# Post-Installation Validation Script

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

source "$(dirname "$0")/../config.env"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Installation Validation${NC}"
echo -e "${BLUE}========================================${NC}\n"

ERRORS=0
WARNINGS=0

# Check Azure Kinect SDK
echo -e "${BLUE}Checking Azure Kinect SDK...${NC}"
if dpkg -l | grep -q libk4a1.4; then
    echo -e "  ${GREEN}✓ Azure Kinect SDK installed${NC}"
else
    echo -e "  ${RED}✗ Azure Kinect SDK not installed${NC}"
    ERRORS=$((ERRORS + 1))
fi

# Check MediaMTX
echo -e "\n${BLUE}Checking MediaMTX...${NC}"
if command -v mediamtx &> /dev/null; then
    echo -e "  ${GREEN}✓ MediaMTX installed${NC}"
    if systemctl is-active --quiet mediamtx; then
        echo -e "  ${GREEN}✓ MediaMTX service running${NC}"
    else
        echo -e "  ${YELLOW}⚠ MediaMTX service not running${NC}"
        WARNINGS=$((WARNINGS + 1))
    fi
else
    echo -e "  ${RED}✗ MediaMTX not installed${NC}"
    ERRORS=$((ERRORS + 1))
fi

# Check Python
echo -e "\n${BLUE}Checking Python environment...${NC}"
if [ "$USE_VENV" = true ]; then
    if [ -d "$VENV_PATH" ]; then
        echo -e "  ${GREEN}✓ Virtual environment exists${NC}"
        
        if [ -f "$VENV_PATH/bin/python3" ]; then
            VENV_PYTHON_VERSION=$("$VENV_PATH/bin/python3" --version)
            echo -e "  ${GREEN}✓ Python: $VENV_PYTHON_VERSION${NC}"
            
            # Check pyk4a in venv
            if "$VENV_PATH/bin/python3" -c "import pyk4a" 2>/dev/null; then
                echo -e "  ${GREEN}✓ pyk4a installed in venv${NC}"
            else
                echo -e "  ${RED}✗ pyk4a not found in venv${NC}"
                ERRORS=$((ERRORS + 1))
            fi
        else
            echo -e "  ${RED}✗ Python not found in venv${NC}"
            ERRORS=$((ERRORS + 1))
        fi
    else
        echo -e "  ${RED}✗ Virtual environment not found${NC}"
        ERRORS=$((ERRORS + 1))
    fi
else
    if command -v python3 &> /dev/null; then
        PYTHON_VERSION=$(python3 --version)
        echo -e "  ${GREEN}✓ Python: $PYTHON_VERSION${NC}"
    else
        echo -e "  ${RED}✗ Python3 not installed${NC}"
        ERRORS=$((ERRORS + 1))
    fi
fi

# Check Xvfb
if [ "$ENABLE_XVFB" = true ]; then
    echo -e "\n${BLUE}Checking Xvfb...${NC}"
    if command -v Xvfb &> /dev/null; then
        echo -e "  ${GREEN}✓ Xvfb installed${NC}"
        
        if systemctl is-active --quiet kinect-xvfb 2>/dev/null; then
            echo -e "  ${GREEN}✓ Xvfb service running${NC}"
        else
            echo -e "  ${YELLOW}⚠ Xvfb service not running (will start with kinect-streamer)${NC}"
        fi
    else
        echo -e "  ${RED}✗ Xvfb not installed${NC}"
        ERRORS=$((ERRORS + 1))
    fi
fi

# Check ports
echo -e "\n${BLUE}Checking port availability...${NC}"

check_port() {
    local port=$1
    local name=$2
    
    if ss -tlnp | grep -q ":$port "; then
        PROCESS=$(ss -tlnp | grep ":$port " | awk '{print $NF}' | head -1)
        
        # Check if it's our service
        if echo "$PROCESS" | grep -q "mediamtx\|kinect\|uvicorn"; then
            echo -e "  ${GREEN}✓ Port $port ($name) - Used by our service${NC}"
        else
            echo -e "  ${YELLOW}⚠ Port $port ($name) - In use by: $PROCESS${NC}"
            WARNINGS=$((WARNINGS + 1))
        fi
    else
        echo -e "  ${GREEN}✓ Port $port ($name) - Available${NC}"
    fi
}

check_port "$API_PORT" "API"
check_port "$MEDIAMTX_RTSP_PORT" "RTSP"
check_port "$MEDIAMTX_HLS_PORT" "HLS"
check_port "$MEDIAMTX_WEBRTC_PORT" "WebRTC"

# Check Kinect devices
echo -e "\n${BLUE}Checking Azure Kinect devices...${NC}"
KINECT_COUNT=$(lsusb | grep -i "045e" | wc -l)
if [ $KINECT_COUNT -gt 0 ]; then
    echo -e "  ${GREEN}✓ Found $KINECT_COUNT Azure Kinect USB device(s)${NC}"
else
    echo -e "  ${YELLOW}⚠ No Azure Kinect devices detected${NC}"
    echo "    Connect your device(s) before starting services"
    WARNINGS=$((WARNINGS + 1))
fi

# Check hardware encoding
if [ -f /tmp/hardware_detection.env ]; then
    source /tmp/hardware_detection.env
    
    echo -e "\n${BLUE}Checking hardware encoding...${NC}"
    if [ "$RECOMMENDED_ENCODER" != "none" ]; then
        echo -e "  ${GREEN}✓ Hardware encoder available: $RECOMMENDED_ENCODER${NC}"
    else
        echo -e "  ${YELLOW}⚠ No hardware encoder detected (will use software encoding)${NC}"
        WARNINGS=$((WARNINGS + 1))
    fi
fi

# Check systemd services
echo -e "\n${BLUE}Checking systemd services...${NC}"
if systemctl list-unit-files | grep -q kinect-streamer; then
    echo -e "  ${GREEN}✓ kinect-streamer service installed${NC}"
    
    if systemctl is-enabled --quiet kinect-streamer 2>/dev/null; then
        echo -e "  ${GREEN}✓ Service enabled for auto-start${NC}"
    else
        echo -e "  ${YELLOW}⚠ Service not enabled for auto-start${NC}"
        echo "    Enable with: sudo systemctl enable kinect-streamer"
    fi
else
    echo -e "  ${YELLOW}⚠ kinect-streamer service not created${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

# Check web dashboard
echo -e "\n${BLUE}Checking web dashboard...${NC}"
if [ -d "${INSTALL_DIR}/web" ]; then
    if [ -f "${INSTALL_DIR}/web/index.html" ]; then
        echo -e "  ${GREEN}✓ Web dashboard files present${NC}"
        
        # Check if files are not empty
        if [ -s "${INSTALL_DIR}/web/index.html" ]; then
            echo -e "  ${GREEN}✓ Dashboard files are not empty${NC}"
        else
            echo -e "  ${RED}✗ Dashboard files are empty${NC}"
            ERRORS=$((ERRORS + 1))
        fi
    else
        echo -e "  ${RED}✗ Dashboard index.html not found${NC}"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo -e "  ${RED}✗ Web dashboard directory not found${NC}"
    ERRORS=$((ERRORS + 1))
fi

# Check configuration
echo -e "\n${BLUE}Checking configuration...${NC}"
if [ -f "${INSTALL_DIR}/config.env" ]; then
    echo -e "  ${GREEN}✓ Configuration file exists${NC}"
else
    echo -e "  ${RED}✗ Configuration file not found${NC}"
    ERRORS=$((ERRORS + 1))
fi

# Summary
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}  Validation Summary${NC}"
echo -e "${BLUE}========================================${NC}\n"

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✓ Installation validation PASSED!${NC}"
    echo "  No errors or warnings detected"
    echo ""
    echo "Next steps:"
    echo "  1. Connect Azure Kinect device(s)"
    echo "  2. Start services: sudo systemctl start kinect-xvfb kinect-streamer"
    echo "  3. Check status: sudo systemctl status kinect-streamer"
    echo "  4. Access dashboard: http://$(hostname -I | awk '{print $1}'):8085"
    EXIT_CODE=0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠ Installation validation completed with warnings${NC}"
    echo "  Errors: $ERRORS"
    echo "  Warnings: $WARNINGS"
    echo ""
    echo "Review warnings above before starting services"
    EXIT_CODE=0
else
    echo -e "${RED}✗ Installation validation FAILED${NC}"
    echo "  Errors: $ERRORS"
    echo "  Warnings: $WARNINGS"
    echo ""
    echo "Please fix errors before starting services"
    EXIT_CODE=1
fi

exit $EXIT_CODE
