#!/bin/bash

# Test Kinect Streaming Installation

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [ -f "${SCRIPT_DIR}/config.env" ]; then
    source "${SCRIPT_DIR}/config.env"
fi

API_PORT="${API_PORT:-8000}"
MEDIAMTX_PORT="${MEDIAMTX_RTSP_PORT:-8554}"

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  Kinect Streaming System - Tests${NC}"
echo -e "${BLUE}======================================${NC}\n"

FAILED=0
PASSED=0

test_command() {
    local name=$1
    local cmd=$2
    
    echo -n "Testing $name... "
    if eval "$cmd" &> /dev/null; then
        echo -e "${GREEN}✓ PASS${NC}"
        ((PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}"
        ((FAILED++))
    fi
}

test_service() {
    local name=$1
    
    echo -n "Testing $name service... "
    if systemctl is-active --quiet "$name"; then
        echo -e "${GREEN}✓ RUNNING${NC}"
        ((PASSED++))
    else
        echo -e "${YELLOW}⚠ NOT RUNNING${NC}"
        echo "  Start with: sudo systemctl start $name"
    fi
}

test_api() {
    local endpoint=$1
    local expected=$2
    
    echo -n "Testing API endpoint $endpoint... "
    response=$(curl -s "http://localhost:${API_PORT}${endpoint}" 2>/dev/null || echo "")
    if [ -n "$response" ] && [[ "$response" == *"$expected"* ]]; then
        echo -e "${GREEN}✓ PASS${NC}"
        ((PASSED++))
    else
        echo -e "${RED}✗ FAIL${NC}"
        ((FAILED++))
    fi
}

# ============================================
# System Tests
# ============================================

echo -e "${BLUE}System Dependencies:${NC}"
test_command "Python3" "python3 --version"
test_command "pip3" "pip3 --version"
test_command "FFmpeg" "ffmpeg -version"
test_command "k4a-tools" "k4aviewer --version"
test_command "MediaMTX" "mediamtx --version"

# ============================================
# Python Package Tests
# ============================================

echo -e "\n${BLUE}Python Packages:${NC}"
test_command "pyk4a" "python3 -c 'import pyk4a'"
test_command "fastapi" "python3 -c 'import fastapi'"
test_command "uvicorn" "python3 -c 'import uvicorn'"
test_command "opencv" "python3 -c 'import cv2'"
test_command "numpy" "python3 -c 'import numpy'"

# ============================================
# File Tests
# ============================================

echo -e "\n${BLUE}Installation Files:${NC}"
test_command "Config file" "test -f ${INSTALL_DIR:-/opt/kinect-streaming}/config/config.env"
test_command "Application file" "test -f ${INSTALL_DIR:-/opt/kinect-streaming}/src/kinect_streamer.py"
test_command "MediaMTX config" "test -f /etc/mediamtx/mediamtx.yml"

# ============================================
# Service Tests
# ============================================

echo -e "\n${BLUE}Services:${NC}"
test_service "mediamtx"
test_service "kinect-streamer"

# ============================================
# API Tests (if service is running)
# ============================================

if systemctl is-active --quiet kinect-streamer; then
    echo -e "\n${BLUE}API Endpoints:${NC}"
    test_api "/" "Azure Kinect"
    test_api "/stream/status" "streaming"
    test_api "/health" "healthy"
fi

# ============================================
# Device Tests
# ============================================

echo -e "\n${BLUE}USB Devices:${NC}"
echo -n "Checking for Azure Kinect devices... "
kinect_count=$(lsusb | grep -c "045e" || echo "0")
if [ "$kinect_count" -gt 0 ]; then
    echo -e "${GREEN}✓ Found $kinect_count device(s)${NC}"
    ((PASSED++))
else
    echo -e "${YELLOW}⚠ No devices found${NC}"
    echo "  Make sure Azure Kinect is connected"
fi

# ============================================
# Permission Tests
# ============================================

echo -e "\n${BLUE}Permissions:${NC}"
echo -n "Checking udev rules... "
if [ -f /etc/udev/rules.d/99-k4a.rules ]; then
    echo -e "${GREEN}✓ PASS${NC}"
    ((PASSED++))
else
    echo -e "${RED}✗ FAIL${NC}"
    ((FAILED++))
fi

# ============================================
# Summary
# ============================================

echo -e "\n${BLUE}======================================${NC}"
echo -e "${BLUE}  Test Summary${NC}"
echo -e "${BLUE}======================================${NC}"
echo -e "Passed: ${GREEN}${PASSED}${NC}"
echo -e "Failed: ${RED}${FAILED}${NC}"

if [ $FAILED -eq 0 ]; then
    echo -e "\n${GREEN}✓ All tests passed!${NC}"
    exit 0
else
    echo -e "\n${YELLOW}⚠ Some tests failed${NC}"
    echo -e "Check the output above for details"
    exit 1
fi
