#!/bin/bash

# Python Dependencies Installation with Virtual Environment Support

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

source "$(dirname "$0")/../config.env"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Installing Python Dependencies${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Detect Ubuntu version
UBUNTU_VERSION=$(lsb_release -rs)
echo "Ubuntu version: $UBUNTU_VERSION"

# Install Python3 and pip
echo "Installing Python3 and build tools..."
DEBIAN_FRONTEND=noninteractive apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    python3 \
    python3-pip \
    python3-dev \
    python3-venv \
    build-essential

# Check Python version
PYTHON_VERSION=$(python3 --version)
echo "Python: $PYTHON_VERSION"

# Create virtual environment if enabled
if [ "$USE_VENV" = true ]; then
    echo -e "\n${BLUE}Creating Python virtual environment...${NC}"
    
    if [ -d "$VENV_PATH" ]; then
        echo -e "${YELLOW}Virtual environment already exists at $VENV_PATH${NC}"
        read -p "Recreate virtual environment? [y/N]: " response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            rm -rf "$VENV_PATH"
        fi
    fi
    
    if [ ! -d "$VENV_PATH" ]; then
        python3 -m venv "$VENV_PATH"
        echo -e "${GREEN}✓ Virtual environment created at $VENV_PATH${NC}"
    fi
    
    # Activate virtual environment
    source "$VENV_PATH/bin/activate"
    
    # Upgrade pip in venv
    echo "Upgrading pip in virtual environment..."
    "$VENV_PATH/bin/pip" install --upgrade pip setuptools wheel
    
    PIP_CMD="$VENV_PATH/bin/pip"
    PYTHON_CMD="$VENV_PATH/bin/python3"
else
    echo -e "\n${YELLOW}Installing system-wide (not recommended for Ubuntu 24.04+)${NC}"
    
    # For Ubuntu 24.04+, we need to use --break-system-packages
    if [[ "$UBUNTU_VERSION" > "23.04" ]]; then
        echo -e "${YELLOW}Note: Using --break-system-packages for Ubuntu 24.04+${NC}"
        PIP_FLAGS="--break-system-packages"
    else
        PIP_FLAGS=""
    fi
    
    PIP_CMD="pip3"
    PYTHON_CMD="python3"
fi

# Install Python packages
echo -e "\n${BLUE}Installing Python packages...${NC}"

# Core dependencies
echo "Installing core packages..."
$PIP_CMD install \
    numpy \
    opencv-python \
    fastapi \
    uvicorn \
    python-multipart \
    pydantic

# Azure Kinect wrapper
echo "Installing pyk4a..."
$PIP_CMD install pyk4a

# FFmpeg Python wrapper
echo "Installing ffmpeg-python..."
$PIP_CMD install ffmpeg-python

# Additional utilities
echo "Installing utility packages..."
$PIP_CMD install \
    requests \
    python-dotenv \
    psutil

# Verify installations
echo -e "\n${BLUE}Verifying installations...${NC}"

$PYTHON_CMD -c "import numpy; print(f'  ✓ NumPy {numpy.__version__}')"
$PYTHON_CMD -c "import cv2; print(f'  ✓ OpenCV {cv2.__version__}')"
$PYTHON_CMD -c "import fastapi; print(f'  ✓ FastAPI {fastapi.__version__}')"
$PYTHON_CMD -c "import pyk4a; print('  ✓ pyk4a installed')" || echo -e "${YELLOW}  ⚠ pyk4a may need Azure Kinect SDK${NC}"

# Create activation helper
if [ "$USE_VENV" = true ]; then
    cat > "${INSTALL_DIR}/activate_venv.sh" << 'VENV_ACTIVATE'
#!/bin/bash
# Helper script to activate the virtual environment
source /opt/kinect-streaming/venv/bin/activate
echo "✓ Virtual environment activated"
echo "Python: $(which python3)"
echo "To deactivate, run: deactivate"
VENV_ACTIVATE
    
    chmod +x "${INSTALL_DIR}/activate_venv.sh"
    
    echo -e "\n${GREEN}✓ Virtual environment ready${NC}"
    echo "  Activate with: source ${INSTALL_DIR}/activate_venv.sh"
    echo "  Or directly: source $VENV_PATH/bin/activate"
fi

echo -e "\n${GREEN}✓ Python dependencies installed successfully!${NC}"

# Save Python configuration
cat > /tmp/python_config.env << PYTHON_ENV
USE_VENV=$USE_VENV
VENV_PATH=$VENV_PATH
PYTHON_CMD=$PYTHON_CMD
PIP_CMD=$PIP_CMD
PYTHON_ENV

echo -e "\nPython configuration saved to: /tmp/python_config.env"
