# Interactive Setup Guide

## Quick Start

Run the interactive setup script to configure and install the Azure Kinect Streaming System:

```bash
sudo ./interactive_setup.sh
```

## What the Interactive Setup Does

The interactive setup script guides you through:

1. **Network Configuration**
   - Server IP address (auto-detected)
   - API port (default: 8000)
   - RTSP port (default: 8554)
   - WebRTC port (default: 8889)
   - HLS port (default: 8890)

2. **Kinect Device Configuration**
   - Device ID (0, 1, 2, etc. for multiple cameras)
   - RGB resolution (720p, 1080p, 1440p, etc.)
   - Depth mode (NFOV_UNBINNED, WFOV_UNBINNED, etc.)
   - FPS (5, 15, 30)

3. **Streaming Configuration**
   - Stream preset (ultrafast, superfast, etc.)
   - Bitrate (2M, 4M, 6M, etc.)
   - Enable/disable RGB, Depth, IR, Audio streams

4. **Installation Options**
   - Install directory
   - Python virtual environment
   - Xvfb for headless servers
   - Systemd services

5. **Review & Confirm**
   - Review all settings
   - Confirm before installation

6. **Automatic Installation**
   - Runs all installation steps
   - Creates configuration file
   - Sets up services

## Features

- ✅ **Auto-detection**: Automatically detects server IP and connected Kinect devices
- ✅ **Smart Defaults**: Provides sensible defaults for all settings
- ✅ **Validation**: Shows detected devices and validates configuration
- ✅ **Review Step**: Lets you review everything before installation
- ✅ **Error-Free**: Uses all the fixed installation scripts

## Example Session

```
$ sudo ./interactive_setup.sh

╔══════════════════════════════════════════════════════════╗
║                                                          ║
║     Azure Kinect Streaming System - Interactive Setup    ║
║     Version 2.0 - Ubuntu 24.04 Ready                     ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝

Step 1: Network Configuration
Detected IP address: 192.168.1.100
Enter server IP address [192.168.1.100]: [Enter]
...

Step 2: Kinect Device Configuration
✓ Found 5 Azure Kinect USB device(s)
Enter Kinect Device ID [0]: [Enter]
...

[Review configuration]

Proceed with installation? [Y/n]: y

[Installation proceeds automatically]
```

## After Installation

The script will show you:

1. How to start services
2. How to enable auto-start
3. How to check status
4. Web dashboard URL
5. API endpoint URL

## Manual Configuration

If you prefer to configure manually, edit `config.env` and run:

```bash
sudo ./setup.sh
```

## Troubleshooting

### Port Conflicts

If you get port conflicts during setup, the script will:
- Detect the conflict
- Offer alternative ports
- Let you choose manually

### Multiple Machines

For multiple machines:
1. Run `interactive_setup.sh` on each machine
2. Use different Device IDs (0, 1, 2, etc.)
3. Use different ports if needed
4. Configure unique server IPs

### Network Issues

If the auto-detected IP is wrong:
- Enter the correct IP manually
- Use `ip addr` or `ifconfig` to find your IP
- Use the IP that other devices can reach

## Configuration File

The interactive setup creates `config.env` with all your settings. You can edit it later if needed:

```bash
nano config.env
```

Then restart services:

```bash
sudo systemctl restart kinect-streamer
```

