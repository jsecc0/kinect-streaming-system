# Azure Kinect Streaming System - Installation Guide
## Version 2.0 - With Ubuntu 24.04 Support & Research Enhancements

**Updated:** November 19, 2025  
**Author:** Built for jsecco®

---

## 🎯 What's New in Version 2.0

### Bug Fixes (All Your Issues Resolved!)
✅ **Ubuntu 24.04 Support** - Auto-detects and handles libsoundio1, libgl1  
✅ **Python Virtual Environment** - PEP 668 compliant, isolated dependencies  
✅ **Depth Engine Error 204 Fix** - Automatic Xvfb setup for headless servers  
✅ **Port Conflict Detection** - Interactive port selection  
✅ **Non-Interactive EULA** - Auto-accepts Azure Kinect licenses  
✅ **Service User Fix** - Uses `kinect-streaming` to match directory  

### New Features (From Research)
✅ **Intel QuickSync Support** - Hardware-accelerated encoding detection  
✅ **Hardware Compatibility Checker** - Validates your system before install  
✅ **Firmware Update Helper** - Check and update camera firmware  
✅ **Post-Install Validation** - Comprehensive system checks  
✅ **Interactive Installer** - Smart port selection and configuration  

---

## 📋 System Requirements

### Minimum
- Ubuntu 20.04+ (22.04, 24.04 supported)
- 8GB RAM
- 1 USB 3.0 controller
- Python 3.8+

### Recommended (Your System ✓)
- Ubuntu 24.04 LTS
- 64GB RAM (you have this!)
- Intel Xeon E-2176G with QuickSync (you have this!)
- 2+ USB 3.0 controllers (you have this!)
- Gigabit Ethernet

---

## 🚀 Quick Start

### 1. Download and Extract
```bash
cd ~
wget https://your-download-link/kinect-streaming-system.tar.gz
tar -xzf kinect-streaming-system.tar.gz
cd kinect-streaming-system
```

### 2. Review Configuration (Optional)
```bash
nano config.env
```

Key settings:
- `USE_VENV=true` - Use virtual environment (recommended)
- `ENABLE_XVFB=true` - Fix depth camera (required for headless)
- `AUTO_ACCEPT_EULA=true` - Skip EULA prompts
- `INTERACTIVE_PORTS=true` - Choose ports if conflicts exist

### 3. Run Installation
```bash
sudo ./setup.sh
```

The installer will:
1. Detect your Ubuntu version (24.04)
2. Check hardware capabilities (QuickSync, RAM, USB)
3. Detect port conflicts and offer alternatives
4. Install all dependencies with proper fixes
5. Set up Xvfb for depth camera
6. Create systemd services
7. Validate installation

### 4. Start Services
```bash
# Enable auto-start on boot
sudo systemctl enable kinect-xvfb kinect-streamer mediamtx

# Start now
sudo systemctl start kinect-xvfb kinect-streamer mediamtx

# Check status
sudo systemctl status kinect-streamer
```

### 5. Access Dashboard
```
http://your-server-ip:8085
```

---

## 🔧 Installation Steps (Detailed)

### Pre-Installation

**1. Hardware Check**
```bash
./scripts/detect_hardware.sh
```

This checks:
- CPU (Intel QuickSync detection)
- RAM (minimum 8GB)
- GPU (NVIDIA/AMD)
- USB controllers
- Connected Kinects

**2. Port Check**
```bash
./scripts/check_ports.sh
```

If ports are in use, you'll be offered:
1. Auto-select next available ports
2. Manually specify ports
3. View conflicting services

### Main Installation

**Run the master installer:**
```bash
sudo ./setup.sh
```

This executes in order:
1. `detect_hardware.sh` - System capability check
2. `check_ports.sh` - Port conflict resolution
3. `install_kinect_sdk.sh` - Azure Kinect SDK + Ubuntu 24.04 fixes
4. `install_python_deps.sh` - Python venv + pyk4a
5. `install_mediamtx.sh` - Streaming server
6. `install_xvfb.sh` - X Virtual Framebuffer (depth camera fix)
7. `setup_permissions.sh` - User/group/permissions
8. `create_services.sh` - Systemd services with Xvfb
9. `validate_install.sh` - Post-install verification

### Post-Installation

**1. Firmware Check** (Recommended)
```bash
./scripts/update_firmware.sh
```

Current versions:
- RGB: 1.6.110
- Depth: 1.6.80
- Audio: 1.6.14

**2. Validate Installation**
```bash
./scripts/validate_install.sh
```

Checks:
- All packages installed
- Services created
- Ports available
- Xvfb running
- Python environment
- Kinect devices detected

**3. Test Camera**
```bash
# Test with k4aviewer (requires display)
DISPLAY=:99 k4aviewer

# Or test streaming
sudo systemctl start kinect-streamer
curl http://localhost:8000/health
```

---

## 📁 Directory Structure

```
/opt/kinect-streaming/
├── config.env                 # Main configuration
├── src/
│   └── kinect_streamer.py     # Streaming application
├── scripts/
│   ├── start_xvfb.sh          # Start virtual display
│   ├── stop_xvfb.sh           # Stop virtual display
│   ├── check_xvfb.sh          # Check Xvfb status
│   └── activate_venv.sh       # Activate Python venv
├── venv/                      # Python virtual environment
├── web/                       # Web dashboard
└── docs/
    ├── DEPTH_ENGINE_FIX.md    # Error 204 solution
    ├── RESEARCH_REPORT.md     # Full research findings
    └── QUICKSYNC_GUIDE.md     # Hardware encoding guide
```

---

## ⚙️ Configuration

### config.env (Key Settings)

```bash
# Ports (auto-selected if conflicts)
API_PORT=8000
MEDIAMTX_HLS_PORT=8890  # Changed from 8888

# Virtual Environment
USE_VENV=true
VENV_PATH="/opt/kinect-streaming/venv"

# Xvfb (Depth Camera Fix)
ENABLE_XVFB=true
XVFB_DISPLAY=":99"

# Hardware Encoding (auto-detected)
HARDWARE_ENCODER="auto"  # quicksync, nvenc, vaapi, none

# Service User
SERVICE_USER="kinect-streaming"
SERVICE_GROUP="kinect-streaming"

# Auto-Installation
AUTO_ACCEPT_EULA=true
INTERACTIVE_PORTS=true
CHECK_FIRMWARE=true
```

---

## 🔍 Troubleshooting

### Depth Camera Error 204

**Symptom:** `Depth engine create and initialize failed with error code: 204`

**Solution:** Xvfb should be running automatically.

**Check:**
```bash
# Is Xvfb running?
ps aux | grep Xvfb

# Is DISPLAY set?
echo $DISPLAY

# Check service
sudo systemctl status kinect-xvfb
```

**Manual Fix:**
```bash
sudo systemctl start kinect-xvfb
export DISPLAY=:99
export LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu/libk4a1.4:$LD_LIBRARY_PATH
```

See: [DEPTH_ENGINE_FIX.md](docs/DEPTH_ENGINE_FIX.md)

### Port Already in Use

**Run port checker:**
```bash
./scripts/check_ports.sh
```

Select option 1 for auto-selection.

**Manual override:**
Edit `config.env` and change ports:
```bash
API_PORT=8001
MEDIAMTX_HLS_PORT=8891
```

### Python Import Error

**If using venv:**
```bash
source /opt/kinect-streaming/venv/bin/activate
python3 -c "import pyk4a"
```

**If system Python:**
```bash
pip3 list | grep pyk4a
```

### Service Won't Start

**Check logs:**
```bash
sudo journalctl -u kinect-streamer -n 50
sudo journalctl -u kinect-xvfb -n 50
```

**Common issues:**
1. Xvfb not running → `sudo systemctl start kinect-xvfb`
2. No Kinect connected → `lsusb | grep 045e`
3. Port in use → Run port checker
4. Permission denied → Check service user exists

---

## 📊 Hardware Encoding

### Intel QuickSync (Your System!)

**Auto-detected:** Yes, you have Intel Xeon E-2176G  
**Encoder:** h264_qsv  
**Benefit:** 5-10x better CPU efficiency

**Verify:**
```bash
ffmpeg -codecs 2>&1 | grep h264_qsv
```

**Manual enable:**
```bash
# In config.env
HARDWARE_ENCODER="quicksync"
```

### Performance Comparison

| Method | CPU Usage | Quality | Latency |
|--------|-----------|---------|---------|
| Software (libx264) | 60-80% | High | Normal |
| QuickSync (h264_qsv) | 10-15% | High | Lower |
| NVENC (h264_nvenc) | 5-10% | High | Lowest |

---

## 🧪 Testing

### Test 1: Hardware Detection
```bash
./scripts/detect_hardware.sh
```

Expected output:
- ✓ Intel QuickSync available
- ✓ 64GB RAM
- ✓ 2 USB controllers

### Test 2: SDK Installation
```bash
dpkg -l | grep libk4a
lsusb | grep 045e
```

### Test 3: Depth Camera (with Xvfb)
```bash
sudo systemctl start kinect-xvfb
export DISPLAY=:99
k4aviewer
```

### Test 4: API Health Check
```bash
curl http://localhost:8000/health
```

Expected: `{"status":"ok"}`

### Test 5: Stream URLs
```bash
# RGB stream
curl -I http://localhost:8890/kinect_rgb/index.m3u8

# Depth stream
curl -I http://localhost:8890/kinect_depth/index.m3u8
```

---

## 🎓 Advanced Usage

### Multiple Cameras

Edit `config.env` for each camera:
```bash
KINECT_DEVICE_ID=0  # First camera
# Or KINECT_DEVICE_ID=1 for second camera
```

### Camera Synchronization (Hardware)

Connect cameras with 3.5mm sync cables:
- Master camera: Out port → Subordinate In port
- Daisy-chain for >2 cameras

Update `kinect_streamer.py`:
```python
master_config = Config(wired_sync_mode=WiredSyncMode.MASTER)
subordinate_config = Config(
    wired_sync_mode=WiredSyncMode.SUBORDINATE,
    subordinate_delay_off_master_usec=160
)
```

### Custom Encoding Settings

```bash
# In kinect_streamer.py or via environment
STREAM_PRESET="veryfast"  # ultrafast, superfast, veryfast, faster
STREAM_BITRATE="6M"       # 2M, 4M, 6M, 8M
```

---

## 📚 Documentation

- [DEPTH_ENGINE_FIX.md](docs/DEPTH_ENGINE_FIX.md) - Error 204 solution (your fix!)
- [RESEARCH_REPORT.md](docs/RESEARCH_REPORT.md) - Full research findings
- [QUICKSTART.md](QUICKSTART.md) - Quick reference
- [Web Dashboard README](web/README.md) - Dashboard features

---

## 🆘 Support

### Check System Status
```bash
# All services
sudo systemctl status kinect-xvfb kinect-streamer mediamtx

# Logs
sudo journalctl -u kinect-streamer -f

# Hardware
./scripts/detect_hardware.sh

# Validation
./scripts/validate_install.sh
```

### Common Commands

```bash
# Start everything
sudo systemctl start kinect-xvfb kinect-streamer mediamtx

# Stop everything
sudo systemctl stop kinect-streamer kinect-xvfb

# Restart after config change
sudo systemctl restart kinect-streamer

# Enable auto-start
sudo systemctl enable kinect-xvfb kinect-streamer mediamtx

# View real-time logs
sudo journalctl -u kinect-streamer -f
```

---

## ✅ Verification Checklist

After installation, verify:

- [ ] `dpkg -l | grep libk4a` shows version 1.4.2
- [ ] `lsusb | grep 045e` shows Kinect devices
- [ ] `systemctl status kinect-xvfb` shows active (running)
- [ ] `systemctl status kinect-streamer` shows active (running)
- [ ] `curl http://localhost:8000/health` returns `{"status":"ok"}`
- [ ] Web dashboard loads at `http://server-ip:8085`
- [ ] No port conflicts (`ss -tlnp | grep 8000`)
- [ ] Virtual environment exists at `/opt/kinect-streaming/venv`
- [ ] `ps aux | grep Xvfb` shows Xvfb running on :99

---

**Installation complete! Your 5-camera Azure Kinect streaming system is ready.** 🎉

**Next:** Configure multiple cameras and test synchronization!
