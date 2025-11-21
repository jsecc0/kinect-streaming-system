# Azure Kinect Streaming Dashboard

A comprehensive web-based dashboard for monitoring and controlling multiple Azure Kinect cameras across distributed servers.

## Features

### 🎥 Multi-Camera Management
- Add/remove cameras dynamically
- Monitor 5+ cameras simultaneously
- Flexible grid layouts (1x1, 2x2, 3x2, custom)
- Real-time status indicators

### 📺 Stream Control
- Start/stop individual streams
- Switch between RGB, Depth, and IR views
- HLS streaming support (WebRTC coming soon)
- Low-latency playback

### 🎬 Recording
- Client-side recording (no server storage needed)
- Multiple quality presets
- Auto-save recordings
- WebM format support

### ⚙️ Settings & Configuration
- Server management
- Stream quality controls
- Recording preferences
- Theme customization
- Export/import configuration

### 📊 Monitoring
- Real-time FPS and resolution stats
- Connection health indicators
- Server status overview
- Auto-refresh capabilities

## Quick Start

### 1. Serve the Dashboard

**Option A: Simple HTTP Server**
```bash
cd /opt/kinect-streaming/web
python3 -m http.server 8080
```

Access at: `http://your-server-ip:8080`

**Option B: Nginx (Production)**
```bash
# Install nginx
sudo apt install nginx

# Copy files
sudo cp -r /opt/kinect-streaming/web/* /var/www/html/kinect/

# Configure nginx (see below)
```

**Option C: Apache**
```bash
sudo apt install apache2
sudo cp -r /opt/kinect-streaming/web/* /var/www/html/kinect/
```

### 2. Add Your First Camera

1. Open the dashboard in your browser
2. Click "Add Camera"
3. Fill in the details:
   - **Name**: Server A - Camera 1
   - **Server IP**: 192.168.1.100
   - **API Port**: 8000
   - **RTSP Port**: 8554
   - **HLS Port**: 8888
   - **Device ID**: 0
4. Click "Add Camera"

### 3. Start Streaming

1. Click "Start" on the camera card
2. Wait 2-3 seconds for stream initialization
3. Video will appear automatically
4. Use RGB/Depth/IR buttons to switch views

## Configuration

### Adding Multiple Cameras

For your 3-server, 5-camera setup:

```javascript
// Server A - 2 cameras
Camera 1: IP 192.168.1.100, Device ID 0
Camera 2: IP 192.168.1.100, Device ID 1 (if running second instance)

// Server B - 2 cameras
Camera 3: IP 192.168.1.101, Device ID 0
Camera 4: IP 192.168.1.101, Device ID 1

// Server C - 1 camera
Camera 5: IP 192.168.1.102, Device ID 0
```

### Settings Overview

**General:**
- Auto-refresh interval
- Auto-reconnect on disconnect
- Notifications
- Theme (dark/light)

**Streaming:**
- Protocol (HLS/WebRTC)
- Buffer size
- Auto-start streams

**Recording:**
- Quality (high/medium/low)
- Format (WebM/MP4)
- Auto-save

**Advanced:**
- Connection retries
- Request timeout
- Debug mode

## Features Guide

### Recording Streams

1. Start the stream
2. Click "Record" button
3. Recording indicator appears
4. Click "Stop Rec" when done
5. File automatically downloads

**Recording Quality:**
- **High**: 8 Mbps (best quality, large files)
- **Medium**: 4 Mbps (balanced)
- **Low**: 2 Mbps (smaller files)

### Stream Types

**RGB Stream:**
- Full color video
- Best for general monitoring
- Default view

**Depth Stream:**
- Colorized depth map
- Shows distance information
- Great for 3D visualization

**IR Stream:**
- Infrared view
- Works in darkness
- Shows heat signatures

### Grid Layouts

- **1x1**: Single camera (full screen)
- **2x2**: Four cameras
- **3x2**: Six cameras (default)
- **Custom**: Flexible arrangement

### Fullscreen Mode

- **Global**: Click fullscreen button (top-right)
- **Per-Camera**: Click expand icon on camera card

### Statistics Overlay

Click "Stats" button to show:
- FPS (frames per second)
- Resolution
- Real-time performance metrics

## Nginx Configuration

Create `/etc/nginx/sites-available/kinect`:

```nginx
server {
    listen 80;
    server_name your-domain.com;

    root /var/www/html/kinect;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }

    # CORS for API calls
    location /api {
        proxy_pass http://localhost:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }

    # HLS streaming
    location /hls {
        types {
            application/vnd.apple.mpegurl m3u8;
            video/mp2t ts;
        }
        add_header Cache-Control no-cache;
        add_header Access-Control-Allow-Origin *;
    }
}
```

Enable and restart:
```bash
sudo ln -s /etc/nginx/sites-available/kinect /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

## Troubleshooting

### Streams Won't Load

**Check MediaMTX is running:**
```bash
sudo systemctl status mediamtx
```

**Check ports are accessible:**
```bash
# From your workstation
curl http://server-ip:8888/kinect_rgb/index.m3u8
```

**Enable CORS on MediaMTX:**
Edit `/etc/mediamtx/mediamtx.yml`:
```yaml
# Add to each path
paths:
  kinect_rgb:
    source: publisher
    runOnPublish: 
    runOnPublishRestart: yes
```

### Cannot Add Camera

**Verify API is accessible:**
```bash
curl http://server-ip:8000/health
```

**Check firewall:**
```bash
sudo ufw allow 8000/tcp
sudo ufw allow 8888/tcp
```

### Recording Doesn't Work

**Browser Support:**
- Chrome/Edge: Full support
- Firefox: Full support
- Safari: Limited (WebM not supported)

**Alternative:**
Use screen recording or download stream directly:
```bash
ffmpeg -i http://server-ip:8888/kinect_rgb/index.m3u8 \
  -c copy -t 60 recording.mp4
```

### Poor Performance

**Reduce quality:**
1. Settings → Streaming
2. Increase buffer size
3. Or lower stream quality on server

**Optimize network:**
- Use wired connection
- Close other applications
- Check network bandwidth

## Browser Compatibility

| Browser | HLS | WebRTC | Recording |
|---------|-----|--------|-----------|
| Chrome  | ✅  | ✅     | ✅        |
| Firefox | ✅  | ✅     | ✅        |
| Safari  | ✅  | ✅     | ⚠️        |
| Edge    | ✅  | ✅     | ✅        |

⚠️ = Limited support (WebM recording not available)

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `Space` | Start/Stop selected camera |
| `R` | Toggle recording |
| `F` | Toggle fullscreen |
| `S` | Toggle stats |
| `1-5` | Switch to camera 1-5 |
| `Escape` | Close modal/Exit fullscreen |

## Mobile Support

The dashboard is responsive and works on tablets/phones:
- Optimized touch controls
- Adaptive grid layout
- Mobile-friendly interface

**Recommended:** Use tablet or desktop for best experience

## Data Storage

All configuration is stored in browser localStorage:
- Camera configurations
- Settings
- Preferences

**Export your config regularly!**
- Settings → Advanced → Export Config

## Security Notes

**Production Deployment:**
1. Use HTTPS (Let's Encrypt)
2. Add authentication (nginx basic auth or OAuth)
3. Restrict access by IP
4. Use VPN for remote access

**Example nginx auth:**
```bash
# Create password file
sudo htpasswd -c /etc/nginx/.htpasswd admin

# Add to nginx config
location / {
    auth_basic "Kinect Dashboard";
    auth_basic_user_file /etc/nginx/.htpasswd;
}
```

## Performance Tips

1. **Limit concurrent streams**
   - Start only needed cameras
   - Stop when not in use

2. **Optimize settings**
   - Use HLS (better compatibility)
   - Increase buffer for stability
   - Lower quality if needed

3. **Network optimization**
   - Use gigabit switches
   - Separate VLAN for video
   - QoS for priority traffic

## Next Steps

- [ ] Add custom layouts
- [ ] Configure auto-start
- [ ] Set up notifications
- [ ] Create recording schedule
- [ ] Build iOS mobile app

## Support

- **Test connection**: Settings → Advanced → Debug Mode
- **Export logs**: Browser DevTools → Console
- **Config backup**: Settings → Export Config

## Files Overview

```
web/
├── index.html        - Main dashboard
├── style.css         - Styling
├── app.js            - Main application logic
├── api.js            - API client
├── video-player.js   - Video player component
└── README.md         - This file
```

## Credits

- **HLS.js**: https://github.com/video-dev/hls.js/
- **Font Awesome**: https://fontawesome.com/
- **MediaMTX**: https://github.com/bluenviron/mediamtx

---

**Version**: 1.0.0  
**Last Updated**: 2024  
**License**: MIT
