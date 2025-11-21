#!/bin/bash

# Hardware Detection Script for Azure Kinect System

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Hardware Detection${NC}"
echo -e "${BLUE}========================================${NC}\n"

# ============================================
# CPU Detection
# ============================================

echo -e "${BLUE}CPU Information:${NC}"
CPU_MODEL=$(cat /proc/cpuinfo | grep "model name" | head -1 | cut -d: -f2 | xargs)
CPU_CORES=$(nproc)
CPU_VENDOR=$(lscpu | grep "Vendor ID" | awk '{print $3}')

echo "  Model: $CPU_MODEL"
echo "  Cores: $CPU_CORES"
echo "  Vendor: $CPU_VENDOR"

# Check for Intel QuickSync
HAS_QUICKSYNC=false
if [[ "$CPU_VENDOR" == "GenuineIntel" ]]; then
    if lspci | grep -i "VGA.*Intel" > /dev/null 2>&1; then
        HAS_QUICKSYNC=true
        echo -e "  QuickSync: ${GREEN}✓ Available${NC}"
        
        # Get Intel GPU model
        INTEL_GPU=$(lspci | grep "VGA.*Intel" | cut -d: -f3 | xargs)
        echo "  Intel GPU: $INTEL_GPU"
    else
        echo -e "  QuickSync: ${YELLOW}✗ Not detected${NC}"
    fi
else
    echo -e "  QuickSync: ${YELLOW}✗ Not available (AMD CPU)${NC}"
fi

# ============================================
# GPU Detection
# ============================================

echo -e "\n${BLUE}GPU Information:${NC}"
HAS_NVIDIA=false
HAS_AMD=false

if lspci | grep -i "VGA.*NVIDIA" > /dev/null 2>&1; then
    HAS_NVIDIA=true
    NVIDIA_GPU=$(lspci | grep "VGA.*NVIDIA" | cut -d: -f3 | xargs)
    echo -e "  NVIDIA GPU: ${GREEN}✓ $NVIDIA_GPU${NC}"
    
    # Check for NVENC support
    if command -v nvidia-smi &> /dev/null; then
        echo "  nvidia-smi: ✓ Available"
    else
        echo -e "  nvidia-smi: ${YELLOW}✗ Not installed${NC}"
        echo "    Install: sudo apt install nvidia-utils"
    fi
elif lspci | grep -i "VGA.*AMD" > /dev/null 2>&1; then
    HAS_AMD=true
    AMD_GPU=$(lspci | grep "VGA.*AMD" | cut -d: -f3 | xargs)
    echo -e "  AMD GPU: ${GREEN}✓ $AMD_GPU${NC}"
else
    echo "  Dedicated GPU: ✗ Not detected"
fi

# ============================================
# Memory
# ============================================

echo -e "\n${BLUE}Memory:${NC}"
TOTAL_MEM=$(free -h | grep "Mem:" | awk '{print $2}')
AVAIL_MEM=$(free -h | grep "Mem:" | awk '{print $7}')
echo "  Total: $TOTAL_MEM"
echo "  Available: $AVAIL_MEM"

# Check if sufficient
TOTAL_MEM_GB=$(free -g | grep "Mem:" | awk '{print $2}')
if [ "$TOTAL_MEM_GB" -lt 8 ]; then
    echo -e "  ${YELLOW}⚠ Warning: Less than 8GB RAM detected${NC}"
    echo "    Recommended: 16GB+ for 5 cameras"
else
    echo -e "  ${GREEN}✓ Sufficient memory${NC}"
fi

# ============================================
# USB Controllers
# ============================================

echo -e "\n${BLUE}USB Controllers:${NC}"
USB_CONTROLLERS=$(lspci | grep -i "USB controller" | wc -l)
echo "  Total Controllers: $USB_CONTROLLERS"

if [ "$USB_CONTROLLERS" -lt 2 ]; then
    echo -e "  ${YELLOW}⚠ Warning: Only $USB_CONTROLLERS USB controller(s) detected${NC}"
    echo "    Recommended: 2+ controllers for 5 cameras"
else
    echo -e "  ${GREEN}✓ Multiple controllers available${NC}"
fi

# List USB 3.0 devices
echo -e "\n  Connected USB 3.0 devices:"
lsusb -t | grep "5000M" | head -5 || echo "    None detected"

# Check for Azure Kinect devices
KINECT_COUNT=$(lsusb | grep -i "045e" | wc -l)
if [ "$KINECT_COUNT" -gt 0 ]; then
    echo -e "\n  ${GREEN}✓ Azure Kinect devices detected: $KINECT_COUNT${NC}"
else
    echo -e "\n  ${YELLOW}⚠ No Azure Kinect devices detected${NC}"
    echo "    Connect your Kinect and run again"
fi

# ============================================
# Encoding Capabilities
# ============================================

echo -e "\n${BLUE}Hardware Encoding:${NC}"

RECOMMENDED_ENCODER="none"

# Check for QuickSync support in FFmpeg
if command -v ffmpeg &> /dev/null; then
    if $HAS_QUICKSYNC; then
        if ffmpeg -codecs 2>&1 | grep -q "h264_qsv"; then
            echo -e "  QuickSync (h264_qsv): ${GREEN}✓ Available${NC}"
            RECOMMENDED_ENCODER="quicksync"
        else
            echo -e "  QuickSync (h264_qsv): ${YELLOW}✗ FFmpeg not compiled with QSV${NC}"
            echo "    Install Intel Media SDK and rebuild FFmpeg"
        fi
    fi
    
    if $HAS_NVIDIA; then
        if ffmpeg -codecs 2>&1 | grep -q "h264_nvenc"; then
            echo -e "  NVENC (h264_nvenc): ${GREEN}✓ Available${NC}"
            if [ "$RECOMMENDED_ENCODER" == "none" ]; then
                RECOMMENDED_ENCODER="nvenc"
            fi
        else
            echo -e "  NVENC (h264_nvenc): ${YELLOW}✗ FFmpeg not compiled with NVENC${NC}"
        fi
    fi
    
    # Check for VAAPI (software fallback)
    if ffmpeg -codecs 2>&1 | grep -q "h264_vaapi"; then
        echo -e "  VAAPI (h264_vaapi): ${GREEN}✓ Available${NC}"
        if [ "$RECOMMENDED_ENCODER" == "none" ]; then
            RECOMMENDED_ENCODER="vaapi"
        fi
    fi
else
    echo -e "  ${RED}✗ FFmpeg not installed${NC}"
fi

# ============================================
# Xvfb Check
# ============================================

echo -e "\n${BLUE}X Virtual Framebuffer (Xvfb):${NC}"
if command -v Xvfb &> /dev/null; then
    echo -e "  ${GREEN}✓ Xvfb installed${NC}"
else
    echo -e "  ${YELLOW}✗ Xvfb not installed${NC}"
    echo "    Required for depth camera on headless servers"
    echo "    Will be installed during setup"
fi

# ============================================
# Summary & Recommendations
# ============================================

echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}  Recommendations${NC}"
echo -e "${BLUE}========================================${NC}\n"

if [ "$RECOMMENDED_ENCODER" != "none" ]; then
    echo -e "${GREEN}✓ Hardware encoding available: $RECOMMENDED_ENCODER${NC}"
    echo "  This will significantly reduce CPU usage"
else
    echo -e "${YELLOW}⚠ No hardware encoding available${NC}"
    echo "  Will use software encoding (higher CPU usage)"
fi

if [ "$USB_CONTROLLERS" -ge 2 ] && [ "$TOTAL_MEM_GB" -ge 16 ]; then
    echo -e "${GREEN}✓ System meets recommended specifications${NC}"
elif [ "$USB_CONTROLLERS" -ge 1 ] && [ "$TOTAL_MEM_GB" -ge 8 ]; then
    echo -e "${YELLOW}⚠ System meets minimum specifications${NC}"
    echo "  Consider upgrading for better performance"
else
    echo -e "${RED}✗ System below minimum specifications${NC}"
    echo "  Installation may fail or perform poorly"
fi

# Save detection results
cat > /tmp/hardware_detection.env << EOF
HAS_QUICKSYNC=$HAS_QUICKSYNC
HAS_NVIDIA=$HAS_NVIDIA
HAS_AMD=$HAS_AMD
RECOMMENDED_ENCODER=$RECOMMENDED_ENCODER
USB_CONTROLLERS=$USB_CONTROLLERS
TOTAL_MEM_GB=$TOTAL_MEM_GB
CPU_CORES=$CPU_CORES
KINECT_COUNT=$KINECT_COUNT
EOF

echo -e "\n${GREEN}✓ Hardware detection complete${NC}"
echo "Results saved to: /tmp/hardware_detection.env"
