#!/bin/bash

# Setup Permissions for Azure Kinect

set -e

source "$(dirname "$0")/../config.env"

echo "Setting up permissions for Azure Kinect..."

# Create service user and group if they don't exist
if ! id "$SERVICE_USER" &>/dev/null; then
    echo "Creating service user: $SERVICE_USER"
    useradd -r -s /bin/false -U "$SERVICE_USER"
else
    echo "Service user already exists: $SERVICE_USER"
fi

# Add user to video and audio groups
usermod -a -G video "$SERVICE_USER"
usermod -a -G audio "$SERVICE_USER"
usermod -a -G plugdev "$SERVICE_USER"

# Create udev rules for Azure Kinect
echo "Creating udev rules..."
cat > /etc/udev/rules.d/99-k4a.rules << 'EOF'
# Azure Kinect DK udev rules
# Depth camera
SUBSYSTEM=="usb", ATTR{idVendor}=="045e", ATTR{idProduct}=="097a", MODE="0666", GROUP="plugdev"
SUBSYSTEM=="usb", ATTR{idVendor}=="045e", ATTR{idProduct}=="097b", MODE="0666", GROUP="plugdev"
SUBSYSTEM=="usb", ATTR{idVendor}=="045e", ATTR{idProduct}=="097c", MODE="0666", GROUP="plugdev"
SUBSYSTEM=="usb", ATTR{idVendor}=="045e", ATTR{idProduct}=="097d", MODE="0666", GROUP="plugdev"
SUBSYSTEM=="usb", ATTR{idVendor}=="045e", ATTR{idProduct}=="097e", MODE="0666", GROUP="plugdev"

# RGB camera
SUBSYSTEM=="usb", ATTR{idVendor}=="045e", ATTR{idProduct}=="097f", MODE="0666", GROUP="plugdev"

# Audio
SUBSYSTEM=="usb", ATTR{idVendor}=="045e", ATTR{idProduct}=="0980", MODE="0666", GROUP="plugdev"
EOF

# Reload udev rules
udevadm control --reload-rules
udevadm trigger

# Set permissions on installation directory
chown -R "$SERVICE_USER:$SERVICE_GROUP" "$INSTALL_DIR" 2>/dev/null || true
chown -R "$SERVICE_USER:$SERVICE_GROUP" "$LOG_DIR" 2>/dev/null || true

# Set permissions on device nodes if they exist
if [ -d /dev/bus/usb ]; then
    echo "Setting permissions on USB devices..."
    # Find and set permissions on Azure Kinect devices
    for device in /dev/bus/usb/*/*; do
        vendor=$(cat "$(dirname "$device")/$(basename "$device" | sed 's/^0*//')/idVendor" 2>/dev/null || echo "")
        if [ "$vendor" = "045e" ]; then
            chmod 0666 "$device"
        fi
    done
fi

echo "✓ Permissions setup complete"
echo ""
echo "User '$SERVICE_USER' has been configured with:"
echo "  - video group (camera access)"
echo "  - audio group (microphone access)"
echo "  - plugdev group (USB device access)"
echo ""
echo "If Azure Kinect is connected, you may need to replug it or reboot"
