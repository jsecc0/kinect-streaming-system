#!/bin/bash

# Azure Kinect SDK Installation Script with Ubuntu 24.04 Support

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Load configuration
source "$(dirname "$0")/../config.env"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Installing Azure Kinect SDK${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Detect Ubuntu version if not set
if [ -z "$UBUNTU_VERSION" ]; then
    UBUNTU_VERSION=$(lsb_release -rs)
    echo "Detected Ubuntu version: $UBUNTU_VERSION"
else
    echo "Using configured Ubuntu version: $UBUNTU_VERSION"
fi

# Auto-accept EULA if configured
if [ "$AUTO_ACCEPT_EULA" = true ]; then
    echo "Auto-accepting Azure Kinect SDK EULA..."
    echo 'libk4a1.4 libk4a1.4/accepted-eula-hash string 0f5d5c5de396e4fee4c0753a21fee0c1ed726cf0316204edda484f08cb266d76' | debconf-set-selections
    echo 'libk4abt1.1 libk4abt1.1/accepted-eula-hash string 03a13b63730639eeb6626d24fd45cf25131ee8e8e0df3f1b63f552269b176e38' | debconf-set-selections
    echo -e "${GREEN}✓ EULA pre-accepted${NC}"
fi

# Download and install Azure Kinect SDK packages directly (bypassing repository issues)
echo "Downloading Azure Kinect SDK packages directly from Microsoft..."
cd /tmp

# Define package versions and URLs (using Ubuntu 18.04 packages which work on 24.04)
K4A_VERSION="1.4.2"
BASE_URL="https://packages.microsoft.com/ubuntu/18.04/prod/pool/main"

# Package URLs (corrected paths based on actual repository structure)
LIBK4A_URL="${BASE_URL}/libk/libk4a1.4/libk4a1.4_${K4A_VERSION}_amd64.deb"
LIBK4A_DEV_URL="${BASE_URL}/libk/libk4a1.4-dev/libk4a1.4-dev_${K4A_VERSION}_amd64.deb"
K4A_TOOLS_URL="${BASE_URL}/k/k4a-tools/k4a-tools_${K4A_VERSION}_amd64.deb"

# Download packages
echo "  Downloading libk4a1.4..."
wget -q "${LIBK4A_URL}" -O libk4a1.4_${K4A_VERSION}_amd64.deb || {
    echo -e "${RED}✗ Failed to download libk4a1.4${NC}"
    exit 1
}

echo "  Downloading libk4a1.4-dev..."
wget -q "${LIBK4A_DEV_URL}" -O libk4a1.4-dev_${K4A_VERSION}_amd64.deb || {
    echo -e "${RED}✗ Failed to download libk4a1.4-dev${NC}"
    exit 1
}

echo "  Downloading k4a-tools..."
wget -q "${K4A_TOOLS_URL}" -O k4a-tools_${K4A_VERSION}_amd64.deb || {
    echo -e "${RED}✗ Failed to download k4a-tools${NC}"
    exit 1
}

echo -e "${GREEN}✓ All packages downloaded${NC}"

# Handle libsoundio1 for Ubuntu 24.04
if [[ "$UBUNTU_VERSION" == "24.04" ]]; then
    echo -e "${BLUE}Handling Ubuntu 24.04 specific dependencies...${NC}"
    
    # Check if libsoundio1 is available
    if ! apt-cache show libsoundio1 &> /dev/null; then
        echo "libsoundio1 not available in Ubuntu 24.04 repositories"
        echo "Downloading from Ubuntu 22.04 (Jammy) repository..."
        
        wget -q http://archive.ubuntu.com/ubuntu/pool/universe/libs/libsoundio/libsoundio1_1.1.0-1_amd64.deb
        
        if [ -f libsoundio1_1.1.0-1_amd64.deb ]; then
            dpkg -i libsoundio1_1.1.0-1_amd64.deb || true
            apt-get install -f -y  # Fix any dependency issues
            rm -f libsoundio1_1.1.0-1_amd64.deb
            echo -e "${GREEN}✓ libsoundio1 installed from Ubuntu 22.04${NC}"
        else
            echo -e "${RED}✗ Failed to download libsoundio1${NC}"
            exit 1
        fi
    fi
    
    # Install libgl1 (replaces libgl1-mesa-glx in Ubuntu 24.04)
    LIBGL_PACKAGE="libgl1"
else
    # Use libgl1-mesa-glx for older Ubuntu versions
    LIBGL_PACKAGE="libgl1-mesa-glx"
fi

# Install dependencies
echo "Installing dependencies..."
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    libusb-1.0-0 \
    ${LIBGL_PACKAGE} \
    libjpeg-turbo8

# Install libsoundio1 if not already installed (for Ubuntu < 24.04)
if [[ "$UBUNTU_VERSION" != "24.04" ]]; then
    if ! dpkg -l | grep -q libsoundio1; then
        DEBIAN_FRONTEND=noninteractive apt-get install -y libsoundio1
    fi
fi

# Install Azure Kinect Sensor SDK packages
echo "Installing Azure Kinect Sensor SDK packages..."
cd /tmp

# Install packages in order (dependencies first)
echo "  Installing libk4a1.4 (runtime library)..."
DEBIAN_FRONTEND=noninteractive dpkg -i libk4a1.4_${K4A_VERSION}_amd64.deb || true
apt-get install -f -y  # Fix any dependency issues

echo "  Installing libk4a1.4-dev (development headers)..."
DEBIAN_FRONTEND=noninteractive dpkg -i libk4a1.4-dev_${K4A_VERSION}_amd64.deb || true
apt-get install -f -y  # Fix any dependency issues

echo "  Installing k4a-tools..."
DEBIAN_FRONTEND=noninteractive dpkg -i k4a-tools_${K4A_VERSION}_amd64.deb || true
apt-get install -f -y  # Fix any dependency issues

# Clean up downloaded packages
rm -f libk4a1.4_${K4A_VERSION}_amd64.deb libk4a1.4-dev_${K4A_VERSION}_amd64.deb k4a-tools_${K4A_VERSION}_amd64.deb

# Verify installation
if dpkg -l | grep -q libk4a1.4; then
    echo -e "${GREEN}✓ Azure Kinect SDK installed successfully${NC}"
    
    # Show installed version
    INSTALLED_VERSION=$(dpkg -l | grep libk4a1.4 | awk '{print $3}')
    echo "  Version: $INSTALLED_VERSION"
    
    # Check depth engine library
    if [ -f /usr/lib/x86_64-linux-gnu/libk4a1.4/libdepthengine.so.2.0 ]; then
        DEPTH_SIZE=$(stat -c%s /usr/lib/x86_64-linux-gnu/libk4a1.4/libdepthengine.so.2.0)
        DEPTH_SIZE_MB=$((DEPTH_SIZE / 1024 / 1024))
        echo "  Depth engine: ${DEPTH_SIZE_MB}MB"
        
        # Verify it's not corrupted (should be ~3.8MB)
        if [ $DEPTH_SIZE_MB -lt 2 ]; then
            echo -e "${RED}  ⚠ Warning: Depth engine library seems corrupted${NC}"
        else
            echo -e "${GREEN}  ✓ Depth engine library intact${NC}"
        fi
    fi
else
    echo -e "${RED}✗ SDK installation failed${NC}"
    exit 1
fi

# Set up udev rules for USB permissions
echo "Setting up USB permissions..."
cat > /etc/udev/rules.d/99-k4a.rules << 'UDEV_RULES'
# Azure Kinect DK USB rules
# Allows non-root users to access Azure Kinect devices
SUBSYSTEM=="usb", ATTRS{idVendor}=="045e", ATTRS{idProduct}=="097a", MODE="0666", GROUP="plugdev"
SUBSYSTEM=="usb", ATTRS{idVendor}=="045e", ATTRS{idProduct}=="097b", MODE="0666", GROUP="plugdev"
SUBSYSTEM=="usb", ATTRS{idVendor}=="045e", ATTRS{idProduct}=="097c", MODE="0666", GROUP="plugdev"
SUBSYSTEM=="usb", ATTRS{idVendor}=="045e", ATTRS{idProduct}=="097d", MODE="0666", GROUP="plugdev"
SUBSYSTEM=="usb", ATTRS{idVendor}=="045e", ATTRS{idProduct}=="097e", MODE="0666", GROUP="plugdev"
UDEV_RULES

udevadm control --reload-rules
udevadm trigger

echo -e "${GREEN}✓ USB permissions configured${NC}"

# Set up library path
echo "Configuring library path..."
if ! grep -q "/usr/lib/x86_64-linux-gnu/libk4a1.4" /etc/ld.so.conf.d/k4a.conf 2>/dev/null; then
    echo "/usr/lib/x86_64-linux-gnu/libk4a1.4" > /etc/ld.so.conf.d/k4a.conf
    ldconfig
    echo -e "${GREEN}✓ Library path configured${NC}"
fi

# Check for connected Kinect devices
echo ""
echo "Checking for connected Azure Kinect devices..."
KINECT_COUNT=$(lsusb | grep -i "045e" | wc -l)
if [ $KINECT_COUNT -gt 0 ]; then
    echo -e "${GREEN}✓ Found $KINECT_COUNT Azure Kinect USB device(s)${NC}"
    lsusb | grep -i "045e" | while read line; do
        echo "  $line"
    done
else
    echo -e "${YELLOW}⚠ No Azure Kinect devices detected${NC}"
    echo "  Connect your device and run 'lsusb | grep 045e' to verify"
fi

echo ""
echo -e "${GREEN}✓ Azure Kinect SDK installation complete!${NC}"
echo ""
echo "Next steps:"
echo "  1. Connect your Azure Kinect device"
echo "  2. Verify connection: lsusb | grep 045e"
echo "  3. Update firmware (if needed): scripts/update_firmware.sh"
echo "  4. Continue installation: ./setup.sh"
