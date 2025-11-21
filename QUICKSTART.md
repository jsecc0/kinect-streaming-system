# Quick Start Guide

## Prerequisites
- Ubuntu server (18.04, 20.04, 22.04, or 24.04)
- Azure Kinect DK connected via USB 3.0
- Root/sudo access
- Internet connection

## 5-Minute Setup

### Step 1: Configure
```bash
cd kinect-streaming-system
nano config.env
```

**Important settings to update:**
```bash
SERVER_IP="192.168.1.100"  # Change to your server's IP
KINECT_DEVICE_ID=0         # 0 for first Kinect, 1 for second, etc.
```

### Step 2: Install
```bash
sudo ./setup.sh
```

Wait ~10-15 minutes for installation to complete.

### Step 3: Start
```bash
sudo systemctl start mediamtx
sudo systemctl start kinect-streamer
```

### Step 4: Test
```bash
# Start streaming
curl -X POST http://localhost:8000/stream/start

# Check status
curl http://localhost:8000/stream/status
```

### Step 5: View
```bash
# With VLC or ffplay
ffplay rtsp://localhost:8554/kinect_rgb
```

Or open in browser:
```
http://YOUR_SERVER_IP:8000/docs
```

## Common First-Time Issues

### "Device not found"
```bash
# Check if Kinect is connected
lsusb | grep 045e

# If found, reload rules and replug device
sudo udevadm control --reload-rules
```

### "Permission denied"
```bash
# Add your user to video group
sudo usermod -a -G video $USER

# Logout and login again
```

### "Service failed to start"
```bash
# Check logs
sudo journalctl -u kinect-streamer -n 50

# Test manually
cd /opt/kinect-streaming/src
python3 kinect_streamer.py
```

## Next Steps

1. **Configure for remote access**: Update firewall rules
2. **Set up multiple cameras**: Repeat on other servers
3. **Video conferencing**: Set up virtual camera (see README)
4. **Web dashboard**: Build custom monitoring interface
5. **Mobile app**: Deploy iOS app for remote control

## Getting Help

- Check logs: `sudo journalctl -u kinect-streamer -f`
- Run tests: `sudo ./test_installation.sh`
- Full documentation: See README.md
- API docs: `http://YOUR_SERVER_IP:8000/docs`

## Uninstall

```bash
sudo ./uninstall.sh
```
