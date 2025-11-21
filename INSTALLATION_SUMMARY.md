# Installation Package Summary

## What's Included

This automated installation package contains everything needed to deploy Azure Kinect streaming infrastructure across your 3 SuperMicro servers.

### 📦 Package Contents

```
kinect-streaming-system/
├── 📄 README.md                    - Complete documentation
├── 📄 QUICKSTART.md                - 5-minute quick start guide
├── 📄 DEPLOYMENT_CHECKLIST.md      - Multi-server deployment guide
├── ⚙️  config.env                   - Configuration file (EDIT THIS!)
├── 🚀 setup.sh                     - Main installation script
├── 🧪 test_installation.sh         - Automated testing script
├── 🗑️  uninstall.sh                 - Clean removal script
│
├── 📁 scripts/                     - Installation modules
│   ├── install_kinect_sdk.sh      - Azure Kinect SDK installer
│   ├── install_python_deps.sh     - Python packages installer
│   ├── install_mediamtx.sh        - MediaMTX streaming server
│   ├── setup_permissions.sh       - USB device permissions
│   └── create_services.sh         - Systemd service creator
│
├── 📁 src/                         - Application code
│   └── kinect_streamer.py         - Main streaming service
│
├── 📁 services/                    - Service files (auto-generated)
└── 📁 web/                         - Web viewer (to be added)
```

## 🎯 What It Does

### Automated Installation
- ✅ Installs Azure Kinect SDK with proper version detection
- ✅ Installs Python 3 with all required packages (pyk4a, FastAPI, OpenCV)
- ✅ Installs MediaMTX streaming server (RTSP/WebRTC/HLS)
- ✅ Sets up USB device permissions and udev rules
- ✅ Creates systemd services for auto-start
- ✅ Configures firewall rules (optional)

### Streaming Capabilities
- 🎥 RGB stream (up to 4K resolution)
- 📊 Depth stream (with colorization)
- 🔦 IR stream
- 🎤 Audio stream (4-mic array)
- 🌐 Multiple protocols: RTSP, WebRTC, HLS

### Management Features
- 🔌 REST API for control
- 📈 Real-time statistics and monitoring
- 🔄 Auto-restart on failure
- 📝 Comprehensive logging
- 🔧 Easy configuration

## 🚀 Installation Steps

### 1. Before You Start

**Checklist:**
- [ ] Ubuntu server ready (18.04, 20.04, 22.04, or 24.04)
- [ ] Azure Kinect DK device(s)
- [ ] USB 3.0 ports available
- [ ] Root/sudo access
- [ ] Internet connection

### 2. Configure

```bash
cd kinect-streaming-system
nano config.env
```

**Must change:**
- `SERVER_IP` - Your server's IP address
- `KINECT_DEVICE_ID` - 0, 1, 2, etc. for each Kinect

**Optional:**
- Stream quality settings
- Port numbers
- Feature flags

### 3. Install

```bash
sudo ./setup.sh
```

**Time:** 10-15 minutes  
**Requires:** Internet connection

### 4. Test

```bash
sudo ./test_installation.sh
```

### 5. Deploy

```bash
sudo systemctl start mediamtx
sudo systemctl start kinect-streamer
```

## 📊 Your 3-Server Architecture

### Recommended Distribution

**Server A:** 2 Kinects (device IDs 0, 1)
**Server B:** 2 Kinects (device IDs 2, 3)  
**Server C:** 1 Kinect (device ID 4)

### Stream URLs

```
Server A:
  - rtsp://SERVER_A_IP:8554/kinect_rgb (device 0)
  - rtsp://SERVER_A_IP:8555/kinect_rgb (device 1)

Server B:
  - rtsp://SERVER_B_IP:8554/kinect_rgb (device 0)
  - rtsp://SERVER_B_IP:8555/kinect_rgb (device 1)

Server C:
  - rtsp://SERVER_C_IP:8554/kinect_rgb (device 0)
```

*Note: For multiple devices per server, you'll need to run multiple instances with different ports*

## 🔧 Command Reference

### Service Management
```bash
# Start
sudo systemctl start kinect-streamer

# Stop
sudo systemctl stop kinect-streamer

# Restart
sudo systemctl restart kinect-streamer

# Status
sudo systemctl status kinect-streamer

# Logs
sudo journalctl -u kinect-streamer -f
```

### API Commands
```bash
# Start streaming
curl -X POST http://localhost:8000/stream/start

# Stop streaming
curl -X POST http://localhost:8000/stream/stop

# Get status
curl http://localhost:8000/stream/status

# Health check
curl http://localhost:8000/health
```

### Testing Streams
```bash
# With ffplay
ffplay rtsp://localhost:8554/kinect_rgb

# With VLC
vlc rtsp://localhost:8554/kinect_rgb

# List available streams
curl http://localhost:8554/
```

## 📱 What's Next

### Phase 2: Central Management
- [ ] Central API server
- [ ] Multi-camera management
- [ ] Service discovery
- [ ] Load balancing

### Phase 3: User Interfaces
- [ ] Web monitoring dashboard
- [ ] iOS mobile app
- [ ] React Native cross-platform app
- [ ] Real-time control panel

### Phase 4: Advanced Features
- [ ] Mode switching (streaming ↔ body tracking)
- [ ] Recording capabilities
- [ ] Cloud storage integration
- [ ] AI-powered features

### Phase 5: Video Conferencing
- [ ] Zoom integration (v4l2loopback)
- [ ] Self-hosted Jitsi setup
- [ ] WebRTC direct connections
- [ ] Virtual background support

## 🆘 Support Resources

### Documentation
- **README.md** - Complete documentation
- **QUICKSTART.md** - Quick reference
- **DEPLOYMENT_CHECKLIST.md** - Production deployment guide

### Troubleshooting
```bash
# Check logs
sudo journalctl -u kinect-streamer -n 100

# Test device
lsusb | grep 045e

# Test manually
cd /opt/kinect-streaming/src
python3 kinect_streamer.py

# Run diagnostics
sudo ./test_installation.sh
```

### Common Issues

**Device not found:**
```bash
sudo udevadm control --reload-rules
sudo udevadm trigger
# Replug device
```

**Permission denied:**
```bash
sudo usermod -a -G video kinect
sudo systemctl restart kinect-streamer
```

**Port already in use:**
```bash
# Edit config to use different port
sudo nano /opt/kinect-streaming/config/config.env
sudo systemctl restart kinect-streamer
```

## 📈 Performance Tuning

### For Best Results

**Single Kinect:**
- Resolution: 1080p @ 30fps
- Bitrate: 4M
- Preset: ultrafast

**Multiple Kinects (per server):**
- Resolution: 720p @ 30fps
- Bitrate: 2M
- Preset: superfast

**Adjust in `config.env`:**
```bash
KINECT_RGB_RESOLUTION="1080p"
KINECT_FPS=30
STREAM_BITRATE="4M"
STREAM_PRESET="ultrafast"
```

## 🎓 Learning Resources

### Azure Kinect
- [Official SDK Documentation](https://learn.microsoft.com/en-us/azure/kinect-dk/)
- [k4a-tools Guide](https://github.com/microsoft/Azure-Kinect-Sensor-SDK)

### MediaMTX
- [MediaMTX Documentation](https://github.com/bluenviron/mediamtx)
- [RTSP Streaming Guide](https://github.com/bluenviron/mediamtx/blob/main/README.md)

### FastAPI
- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [API Best Practices](https://fastapi.tiangolo.com/tutorial/)

## 🔐 Security Considerations

### Production Deployment
- [ ] Change default ports
- [ ] Enable API authentication
- [ ] Configure SSL/TLS
- [ ] Restrict network access
- [ ] Regular security updates
- [ ] Monitor access logs

### Firewall Configuration
```bash
sudo ufw allow 8000/tcp  # API
sudo ufw allow 8554/tcp  # RTSP
sudo ufw allow 8889/tcp  # WebRTC
sudo ufw enable
```

## 💡 Pro Tips

1. **Always test on one server first** before deploying to all 3
2. **Use unique device IDs** for each Kinect across all servers
3. **Monitor CPU/RAM** usage - each Kinect uses ~15-20% CPU
4. **USB 3.0 is mandatory** - USB 2.0 won't work
5. **Keep logs** - they're invaluable for troubleshooting
6. **Document your setup** - future you will thank present you
7. **Test recovery** - simulate failures and practice recovery

## 📞 Getting Help

### Before Asking for Help

1. Run diagnostics: `sudo ./test_installation.sh`
2. Check logs: `sudo journalctl -u kinect-streamer -n 100`
3. Review README.md troubleshooting section
4. Try manual startup: `python3 /opt/kinect-streaming/src/kinect_streamer.py`

### When Reporting Issues

Include:
- Ubuntu version: `lsb_release -a`
- Installation log: `/var/log/kinect-streaming/install_*.log`
- Service status: `sudo systemctl status kinect-streamer`
- Error logs: `sudo journalctl -u kinect-streamer -n 100`
- Device detection: `lsusb | grep 045e`

## ✅ Success Criteria

You'll know it's working when:
- ✅ Services start automatically: `systemctl status kinect-streamer`
- ✅ API responds: `curl http://localhost:8000/health`
- ✅ Streams are accessible: `ffplay rtsp://localhost:8554/kinect_rgb`
- ✅ No errors in logs: `journalctl -u kinect-streamer -p err`
- ✅ Tests pass: `./test_installation.sh`

## 🎉 You're Ready!

With this installation package, you can:
- ✅ Deploy streaming on 5 Azure Kinects across 3 servers
- ✅ Stream RGB, Depth, IR, and Audio
- ✅ Access streams via RTSP, WebRTC, or HLS
- ✅ Control everything via REST API
- ✅ Monitor with web dashboard (coming soon)
- ✅ Use for video conferencing
- ✅ Build custom applications

**Good luck with your deployment!** 🚀

---

*Package Version: 1.0.0*  
*Last Updated: 2024*  
*Compatible with: Ubuntu 18.04, 20.04, 22.04, 24.04*
