#!/bin/bash

# Install MediaMTX

set -e

source "$(dirname "$0")/../config.env"

echo "Installing MediaMTX..."

# Determine architecture
ARCH=$(uname -m)
case $ARCH in
    x86_64)
        MEDIAMTX_ARCH="amd64"
        ;;
    aarch64)
        MEDIAMTX_ARCH="arm64v8"
        ;;
    armv7l)
        MEDIAMTX_ARCH="armv7"
        ;;
    *)
        echo "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

echo "Detected architecture: $ARCH (MediaMTX: $MEDIAMTX_ARCH)"

# Get latest version
LATEST_VERSION=$(curl -s https://api.github.com/repos/bluenviron/mediamtx/releases/latest | grep '"tag_name"' | sed -E 's/.*"v([^"]+)".*/\1/')

if [ -z "$LATEST_VERSION" ]; then
    echo "⚠ Could not detect latest version, using v1.8.0"
    LATEST_VERSION="1.8.0"
fi

echo "Installing MediaMTX version: $LATEST_VERSION"

# Download MediaMTX
DOWNLOAD_URL="https://github.com/bluenviron/mediamtx/releases/download/v${LATEST_VERSION}/mediamtx_v${LATEST_VERSION}_linux_${MEDIAMTX_ARCH}.tar.gz"

cd /tmp
wget -q "$DOWNLOAD_URL" -O mediamtx.tar.gz

# Extract and install
tar -xzf mediamtx.tar.gz
mv mediamtx /usr/local/bin/
chmod +x /usr/local/bin/mediamtx

# Create MediaMTX config directory
mkdir -p /etc/mediamtx
mkdir -p /var/log/mediamtx

# Clean up
rm mediamtx.tar.gz

# Verify installation
if command -v mediamtx &> /dev/null; then
    echo "✓ MediaMTX installed successfully"
    mediamtx --version || true
else
    echo "✗ MediaMTX installation failed"
    exit 1
fi

echo "✓ MediaMTX installation complete"
