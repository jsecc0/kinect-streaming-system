# Multi-Server Deployment Checklist

This checklist guides you through deploying the Kinect streaming system across 3 servers.

## Pre-Deployment

### Hardware Inventory
- [ ] Server A ready (specs: _______)
- [ ] Server B ready (specs: _______)
- [ ] Server C ready (specs: _______)
- [ ] 5 Azure Kinect DK devices available
- [ ] USB 3.0 ports available on each server
- [ ] All servers on same network
- [ ] Network bandwidth verified (recommended: 10+ Mbps per camera)

### Network Planning
- [ ] Server A IP: ______________
- [ ] Server B IP: ______________
- [ ] Server C IP: ______________
- [ ] Network accessible from monitoring location
- [ ] Firewall rules planned

### Camera Distribution
Plan which Kinects go where:
- [ ] Server A: Kinect IDs 0, 1
- [ ] Server B: Kinect IDs 2, 3
- [ ] Server C: Kinect ID 4

(Or your custom distribution: ________________)

## Deployment Phase

### For Each Server (A, B, C):

#### 1. Initial Setup
- [ ] Ubuntu installed and updated
- [ ] SSH access configured
- [ ] Root/sudo access verified
- [ ] Repository copied to server

#### 2. Configuration
```bash
cd kinect-streaming-system
nano config.env
```

- [ ] Update `SERVER_IP` to server's IP
- [ ] Update `KINECT_DEVICE_ID` appropriately
  - Server A: devices 0, 1 (run installer twice or deploy 2 instances)
  - Server B: devices 2, 3
  - Server C: device 4
- [ ] Update ports if needed (avoid conflicts)
- [ ] Configure stream quality settings

#### 3. Installation
```bash
sudo ./setup.sh
```

- [ ] Installation completed successfully
- [ ] No errors in installation log
- [ ] Services created and enabled

#### 4. Connect Hardware
- [ ] Azure Kinect(s) connected to USB 3.0
- [ ] Device detected: `lsusb | grep 045e`
- [ ] Permissions correct: `ls -l /dev/bus/usb/*/*`

#### 5. Service Startup
```bash
sudo systemctl start mediamtx
sudo systemctl start kinect-streamer
```

- [ ] MediaMTX started: `sudo systemctl status mediamtx`
- [ ] Kinect Streamer started: `sudo systemctl status kinect-streamer`
- [ ] No errors in logs: `sudo journalctl -u kinect-streamer -n 20`

#### 6. Testing
```bash
sudo ./test_installation.sh
curl -X POST http://localhost:8000/stream/start
curl http://localhost:8000/stream/status
```

- [ ] All tests passed
- [ ] API responding
- [ ] Streams started successfully

#### 7. Stream Verification
```bash
ffplay rtsp://localhost:8554/kinect_rgb
```

- [ ] RGB stream working
- [ ] Depth stream working (if enabled)
- [ ] No frame drops
- [ ] Latency acceptable

## Post-Deployment

### Central Access Setup
- [ ] Document all stream URLs:
  ```
  Server A - Device 0: rtsp://SERVER_A_IP:8554/kinect_rgb_0
  Server A - Device 1: rtsp://SERVER_A_IP:8554/kinect_rgb_1
  Server B - Device 0: rtsp://SERVER_B_IP:8554/kinect_rgb
  ...
  ```

### Monitoring Setup
- [ ] Web dashboard deployed
- [ ] All streams accessible from dashboard
- [ ] Mobile app configured (if applicable)
- [ ] Alert system configured (if applicable)

### Documentation
- [ ] Network diagram created
- [ ] Server access credentials documented
- [ ] Stream URLs documented
- [ ] Troubleshooting guide created
- [ ] Maintenance schedule defined

### Security
- [ ] Firewall rules configured
- [ ] Authentication enabled on API (if needed)
- [ ] SSL/TLS configured (if needed)
- [ ] Access logs reviewed

### Performance Tuning
- [ ] CPU usage monitored
- [ ] Memory usage checked
- [ ] Network bandwidth measured
- [ ] Stream quality optimized
- [ ] Latency measured and acceptable

### Backup & Recovery
- [ ] Configuration files backed up
- [ ] Installation scripts backed up
- [ ] Recovery procedure documented
- [ ] Failover plan created (if needed)

## Validation Tests

### Individual Server Tests
For each server, verify:
- [ ] Service auto-starts on reboot
- [ ] Streams recover after network interruption
- [ ] API accessible remotely
- [ ] Logs rotating properly
- [ ] No memory leaks over 24 hours

### Multi-Server Integration Tests
- [ ] All 5 cameras accessible simultaneously
- [ ] Web dashboard shows all streams
- [ ] Switch between cameras seamlessly
- [ ] Recording works from any stream
- [ ] Mobile app can control any camera

### Load Tests
- [ ] All 5 streams running for 1 hour
- [ ] CPU/memory usage acceptable
- [ ] No frame drops under load
- [ ] Network bandwidth sufficient
- [ ] System stable over 24 hours

## Troubleshooting Reference

### Common Issues

**Service won't start:**
```bash
sudo journalctl -u kinect-streamer -xe
sudo systemctl reset-failed kinect-streamer
sudo systemctl start kinect-streamer
```

**Stream not accessible remotely:**
```bash
# Check firewall
sudo ufw status
sudo ufw allow 8554/tcp
```

**Poor stream quality:**
```bash
# Edit config
sudo nano /opt/kinect-streaming/config/config.env
# Increase STREAM_BITRATE
# Lower KINECT_RGB_RESOLUTION
sudo systemctl restart kinect-streamer
```

## Maintenance Schedule

### Daily
- [ ] Check service status: `sudo systemctl status kinect-streamer`
- [ ] Monitor disk space: `df -h`
- [ ] Review error logs: `sudo journalctl -u kinect-streamer -p err`

### Weekly
- [ ] Check for system updates: `sudo apt update && sudo apt list --upgradable`
- [ ] Review performance metrics
- [ ] Test stream quality

### Monthly
- [ ] Full system updates
- [ ] Backup configurations
- [ ] Test recovery procedures
- [ ] Review and clean logs

## Rollback Plan

If deployment fails:

1. **Stop services:**
   ```bash
   sudo systemctl stop kinect-streamer
   sudo systemctl stop mediamtx
   ```

2. **Uninstall:**
   ```bash
   sudo ./uninstall.sh
   ```

3. **Review logs:**
   ```bash
   sudo journalctl -u kinect-streamer -n 100 > deployment_error.log
   ```

4. **Report issues:**
   - Include deployment_error.log
   - Note server specs
   - Note Ubuntu version

## Sign-Off

### Server A
- [ ] Deployed by: _____________ Date: _______
- [ ] Tested by: _____________ Date: _______
- [ ] Status: _____ Operational / _____ Issues

### Server B
- [ ] Deployed by: _____________ Date: _______
- [ ] Tested by: _____________ Date: _______
- [ ] Status: _____ Operational / _____ Issues

### Server C
- [ ] Deployed by: _____________ Date: _______
- [ ] Tested by: _____________ Date: _______
- [ ] Status: _____ Operational / _____ Issues

### Final Approval
- [ ] All servers operational
- [ ] All streams verified
- [ ] Documentation complete
- [ ] Team trained on system

**Approved by:** _____________ 
**Date:** _______

## Next Phase: Central API & Web Dashboard

After successful deployment, proceed to:
1. Central API server setup (manage all 3 servers)
2. Web monitoring dashboard
3. iOS mobile app deployment
4. Advanced features (mode switching, recording, etc.)
