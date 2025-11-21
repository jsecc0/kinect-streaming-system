# Azure Kinect Streaming System

A comprehensive system for streaming RGB, Depth, IR, and Audio from Azure Kinect DK devices over RTSP/WebRTC for video conferencing, monitoring, and multi-camera setups.

## Features

- ✅ Stream RGB, Depth, IR, and Audio from Azure Kinect
- ✅ RTSP/WebRTC/HLS streaming support via MediaMTX
- ✅ REST API for control and monitoring
- ✅ Multi-camera support (distributed across servers)
- ✅ Systemd service integration for auto-start
- ✅ Real-time depth visualization
- ✅ Video conferencing compatible (Zoom, etc.)
- ✅ Web-based monitoring dashboard
- ✅ iOS mobile app support (coming soon)

## System Requirements

### Hardware
- Azure Kinect DK device(s)
- USB 3.0 port
- Ubuntu server (18.04, 20.04, 22.04, or 24.04)
- Recommended: 8GB+ RAM, 4+ CPU cores per Kinect

### Software
- Ubuntu Linux (headless server supported)
- Root/sudo access
- Internet connection for installation

## Quick Start

### Option 1: Interactive Setup (Recommended)

The easiest way to install and configure the system:

```bash
# Make script executable
chmod +x interactive_setup.sh

# Run interactive setup
sudo ./interactive_setup.sh
```

The interactive setup will:
- Guide you through all configuration options
- Auto-detect your server IP and connected devices
- Let you customize settings for your machine
- Run the complete installation automatically

See [INTERACTIVE_SETUP_GUIDE.md](INTERACTIVE_SETUP_GUIDE.md) for details.

### Option 2: Manual Setup

### 1. Download and Prepare

```bash
# Clone or download this repository
cd /home/your-user
git clone <repository-url> kinect-streaming-system
cd kinect-streaming-system

# Make scripts executable
chmod +x setup.sh uninstall.sh test_installation.sh interactive_setup.sh
chmod +x scripts/*.sh
```

### 2. Configure

Edit `config.env` to customize your installation:

```bash
nano config.env
```

Key settings to review:
- `SERVER_IP`: Set to your server's IP for remote access
- `KINECT_DEVICE_ID`: 0 for first Kinect, 1 for second, etc.
- `API_PORT`, `MEDIAMTX_RTSP_PORT`: Adjust if ports conflict
- Stream quality settings (resolution, FPS, bitrate)

### 3. Install

```bash
# Run the automated setup
sudo ./setup.sh
```

The installer will:
1. Install Azure Kinect SDK
2. Install Python dependencies
3. Install MediaMTX streaming server
4. Set up permissions and udev rules
5. Create systemd services
6. Configure firewall (if enabled)

**Installation time:** ~10-15 minutes

### 4. Test Installation

```bash
# Run the test suite
sudo ./test_installation.sh
```

### 5. Start Streaming

```bash
# Start the services
sudo systemctl start mediamtx
sudo systemctl start kinect-streamer

# Check status
sudo systemctl status kinect-streamer

# View logs
sudo journalctl -u kinect-streamer -f
```

### 6. Test Streams

```bash
# Start streaming via API
curl -X POST http://localhost:8000/stream/start

# Check status
curl http://localhost:8000/stream/status

# View stream with VLC or ffplay
ffplay rtsp://localhost:8554/kinect_rgb
ffplay rtsp://localhost:8554/kinect_depth
```

## API Documentation

### Base URL
```
http://SERVER_IP:8000
```

### Endpoints

#### GET `/`
Get service information
```json
{
  "service": "Azure Kinect Streaming Service",
  "version": "1.0.0",
  "device_id": 0,
  "status": "ready"
}
```

#### POST `/stream/start`
Start streaming from Kinect
```bash
curl -X POST http://localhost:8000/stream/start
```

Response:
```json
{
  "status": "started",
  "device_id": 0,
  "streams": {
    "rgb": "rtsp://SERVER_IP:8554/kinect_rgb",
    "depth": "rtsp://SERVER_IP:8554/kinect_depth"
  }
}
```

#### POST `/stream/stop`
Stop streaming
```bash
curl -X POST http://localhost:8000/stream/stop
```

#### GET `/stream/status`
Get streaming statistics
```bash
curl http://localhost:8000/stream/status
```

Response:
```json
{
  "streaming": true,
  "device_id": 0,
  "frames_captured": 1523,
  "frames_dropped": 0,
  "uptime_seconds": 50.8,
  "fps": 29.98,
  "streams_active": ["rgb", "depth"]
}
```

#### GET `/health`
Health check endpoint
```bash
curl http://localhost:8000/health
```

## Service Management

### Start/Stop Services

```bash
# Start services
sudo systemctl start mediamtx
sudo systemctl start kinect-streamer

# Stop services
sudo systemctl stop kinect-streamer
sudo systemctl stop mediamtx

# Restart services
sudo systemctl restart kinect-streamer

# Enable auto-start on boot
sudo systemctl enable kinect-streamer
sudo systemctl enable mediamtx
```

### View Logs

```bash
# Real-time logs
sudo journalctl -u kinect-streamer -f
sudo journalctl -u mediamtx -f

# Recent logs
sudo journalctl -u kinect-streamer -n 100

# All logs from today
sudo journalctl -u kinect-streamer --since today
```

## Multi-Server Setup

For distributed setup with multiple servers:

1. **Install on each server**
   ```bash
   # On Server A, B, C
   sudo ./setup.sh
   ```

2. **Configure unique device IDs**
   ```bash
   # On each server, edit config
   nano /opt/kinect-streaming/config/config.env
   # Set KINECT_DEVICE_ID appropriately (0, 1, 2, etc.)
   ```

3. **Restart services**
   ```bash
   sudo systemctl restart kinect-streamer
   ```

4. **Access streams**
   - Server A: `rtsp://SERVER_A_IP:8554/kinect_rgb`
   - Server B: `rtsp://SERVER_B_IP:8554/kinect_rgb`
   - Server C: `rtsp://SERVER_C_IP:8554/kinect_rgb`

## Video Conferencing Integration

### Zoom/Teams/Google Meet

Use virtual camera with v4l2loopback:

```bash
# Install v4l2loopback
sudo apt-get install v4l2loopback-dkms

# Load module
sudo modprobe v4l2loopback devices=1 video_nr=10 \
  card_label="Azure Kinect" exclusive_caps=1

# Convert RTSP to virtual camera
ffmpeg -i rtsp://localhost:8554/kinect_rgb \
  -f v4l2 -pix_fmt yuv420p /dev/video10
```

Then select "Azure Kinect" in your video conferencing app.

### Self-Hosted Jitsi

MediaMTX supports WebRTC directly - configure Jitsi to use the WebRTC endpoint:
```
http://SERVER_IP:8889/kinect_rgb
```

## Web Viewer

Open the web viewer at:
```
file:///opt/kinect-streaming/web/viewer.html
```

Or serve via HTTP:
```bash
cd /opt/kinect-streaming/web
python3 -m http.server 8080
# Access: http://SERVER_IP:8080/viewer.html
```

## Troubleshooting

### Device Not Found

```bash
# Check if Kinect is connected
lsusb | grep 045e

# Check permissions
ls -l /dev/bus/usb/*/*

# Reload udev rules
sudo udevadm control --reload-rules
sudo udevadm trigger

# Replug device
```

### Service Won't Start

```bash
# Check detailed logs
sudo journalctl -u kinect-streamer -xe

# Test manually
cd /opt/kinect-streaming/src
python3 kinect_streamer.py

# Verify dependencies
python3 -c "import pyk4a; import fastapi; import cv2"
```

### Stream Not Working

```bash
# Test MediaMTX directly
curl http://localhost:8554/

# Check if FFmpeg is running
ps aux | grep ffmpeg

# Test with VLC
vlc rtsp://localhost:8554/kinect_rgb
```

### Performance Issues

```bash
# Lower resolution in config
KINECT_RGB_RESOLUTION="720p"  # Instead of 1080p

# Adjust FFmpeg preset
STREAM_PRESET="superfast"  # Instead of ultrafast

# Lower bitrate
STREAM_BITRATE="2M"  # Instead of 4M
```

## Advanced Configuration

### Custom Stream Names

Edit `/etc/mediamtx/mediamtx.yml`:
```yaml
paths:
  my_custom_stream:
    source: publisher
```

Update application to stream to custom name.

### Authentication

Add authentication to MediaMTX:
```yaml
paths:
  kinect_rgb:
    source: publisher
    publishUser: admin
    publishPass: password123
```

### Recording Streams

```bash
# Record RGB stream for 60 seconds
ffmpeg -i rtsp://localhost:8554/kinect_rgb \
  -c copy -t 60 recording.mp4
```

## Uninstallation

```bash
# Run the uninstall script
sudo ./uninstall.sh

# Follow prompts to remove components
```

## File Locations

- Installation: `/opt/kinect-streaming/`
- Configuration: `/opt/kinect-streaming/config/config.env`
- Logs: `/var/log/kinect-streaming/`
- Services: `/etc/systemd/system/kinect-streamer.service`
- MediaMTX config: `/etc/mediamtx/mediamtx.yml`
- udev rules: `/etc/udev/rules.d/99-k4a.rules`

## Architecture

```
┌─────────────────┐
│  Azure Kinect   │
└────────┬────────┘
         │ USB 3.0
┌────────▼────────────────────┐
│   kinect_streamer.py        │
│   - Captures RGB/Depth/IR   │
│   - REST API (FastAPI)      │
│   - FFmpeg encoding         │
└────────┬────────────────────┘
         │ RTSP (local)
┌────────▼────────────────────┐
│      MediaMTX               │
│   - RTSP server             │
│   - WebRTC server           │
│   - HLS server              │
└────────┬────────────────────┘
         │ Network
    ┌────┴─────┬─────────┬──────┐
    │          │         │      │
┌───▼──┐  ┌───▼──┐  ┌───▼──┐  ┌▼──┐
│ Web  │  │Mobile│  │ Zoom │  │VLC│
└──────┘  └──────┘  └──────┘  └───┘
```

## Command Line Options

### Setup Script

```bash
sudo ./setup.sh [OPTIONS]

Options:
  --skip-kinect         Skip Azure Kinect SDK installation
  --skip-mediamtx       Skip MediaMTX installation
  --skip-python         Skip Python dependencies
  --dev                 Development mode (no systemd services)
  --help                Show help
```

## Support & Development

### Check Versions

```bash
# Azure Kinect SDK
dpkg -l | grep k4a

# MediaMTX
mediamtx --version

# Python packages
pip3 list | grep -E "pyk4a|fastapi|opencv"
```

### Update Installation

```bash
# Pull latest changes
git pull

# Re-run setup (skips existing installations)
sudo ./setup.sh
```

## License

[Your License Here]

## Acknowledgments

- Azure Kinect SDK by Microsoft
- MediaMTX by BluenViron
- pyk4a Python wrapper

## Next Steps

See the project roadmap for upcoming features:
- [ ] Central API server for multi-camera management
- [ ] iOS mobile app
- [ ] Advanced web dashboard
- [ ] Mode switching (streaming ↔ body tracking)
- [ ] Cloud recording support
- [ ] AI-powered features (pose estimation, etc.)
