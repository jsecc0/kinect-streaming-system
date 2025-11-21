#!/usr/bin/env python3

"""
Azure Kinect Streaming Service
Streams RGB, Depth, IR, and Audio from Azure Kinect to MediaMTX
"""

import asyncio
import os
import sys
import signal
import logging
from typing import Optional, Dict
from datetime import datetime

import cv2
import numpy as np
from fastapi import FastAPI, BackgroundTasks, HTTPException
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
import uvicorn

try:
    from pyk4a import PyK4A, Config, ColorResolution, DepthMode, FPS, WiredSyncMode
except ImportError:
    print("Error: pyk4a not installed. Run: pip install pyk4a")
    sys.exit(1)

# ============================================
# Configuration
# ============================================

# Load from environment or use defaults
DEVICE_ID = int(os.getenv('KINECT_DEVICE_ID', '0'))
API_PORT = int(os.getenv('API_PORT', '8000'))
SERVER_IP = os.getenv('SERVER_IP', '0.0.0.0')
MEDIAMTX_HOST = os.getenv('MEDIAMTX_HOST', 'localhost')
MEDIAMTX_PORT = int(os.getenv('MEDIAMTX_RTSP_PORT', '8554'))

# Stream settings
RGB_RESOLUTION = os.getenv('KINECT_RGB_RESOLUTION', '1080p')
DEPTH_MODE = os.getenv('KINECT_DEPTH_MODE', 'NFOV_UNBINNED')
CAMERA_FPS = int(os.getenv('KINECT_FPS', '30'))
STREAM_PRESET = os.getenv('STREAM_PRESET', 'ultrafast')
STREAM_BITRATE = os.getenv('STREAM_BITRATE', '4M')

# Feature flags
ENABLE_RGB = os.getenv('ENABLE_RGB_STREAM', 'true').lower() == 'true'
ENABLE_DEPTH = os.getenv('ENABLE_DEPTH_STREAM', 'true').lower() == 'true'
ENABLE_IR = os.getenv('ENABLE_IR_STREAM', 'false').lower() == 'true'
ENABLE_AUDIO = os.getenv('ENABLE_AUDIO_STREAM', 'true').lower() == 'true'

# ============================================
# Logging Setup
# ============================================

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# ============================================
# FastAPI Application
# ============================================

app = FastAPI(
    title="Azure Kinect Streaming Service",
    description="REST API for controlling Azure Kinect streaming",
    version="1.0.0"
)

# Enable CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ============================================
# Kinect Streamer Class
# ============================================

class KinectStreamer:
    """Manages Azure Kinect device and streaming"""
    
    # Resolution mapping
    RESOLUTION_MAP = {
        '720p': ColorResolution.RES_720P,
        '1080p': ColorResolution.RES_1080P,
        '1440p': ColorResolution.RES_1440P,
        '1536p': ColorResolution.RES_1536P,
        '2160p': ColorResolution.RES_2160P,
        '3072p': ColorResolution.RES_3072P,
    }
    
    DEPTH_MODE_MAP = {
        'NFOV_UNBINNED': DepthMode.NFOV_UNBINNED,
        'NFOV_2X2BINNED': DepthMode.NFOV_2X2BINNED,
        'WFOV_UNBINNED': DepthMode.WFOV_UNBINNED,
        'WFOV_2X2BINNED': DepthMode.WFOV_2X2BINNED,
    }
    
    FPS_MAP = {
        5: FPS.FPS_5,
        15: FPS.FPS_15,
        30: FPS.FPS_30,
    }
    
    def __init__(self, device_id: int = 0):
        self.device_id = device_id
        self.k4a: Optional[PyK4A] = None
        self.streaming = False
        self.ffmpeg_processes: Dict[str, any] = {}
        self.stream_task: Optional[asyncio.Task] = None
        
        # Statistics
        self.frames_captured = 0
        self.frames_dropped = 0
        self.start_time: Optional[datetime] = None
        
    def initialize_kinect(self):
        """Initialize Azure Kinect device with configuration"""
        try:
            logger.info(f"Initializing Kinect device {self.device_id}...")
            
            # Build configuration
            config = Config(
                color_resolution=self.RESOLUTION_MAP.get(RGB_RESOLUTION, ColorResolution.RES_1080P),
                depth_mode=self.DEPTH_MODE_MAP.get(DEPTH_MODE, DepthMode.NFOV_UNBINNED),
                camera_fps=self.FPS_MAP.get(CAMERA_FPS, FPS.FPS_30),
                synchronized_images_only=True,
                wired_sync_mode=WiredSyncMode.STANDALONE,
            )
            
            self.k4a = PyK4A(device_id=self.device_id, config=config)
            self.k4a.start()
            
            # Get device info
            logger.info(f"✓ Kinect {self.device_id} initialized successfully")
            logger.info(f"  RGB Resolution: {RGB_RESOLUTION}")
            logger.info(f"  Depth Mode: {DEPTH_MODE}")
            logger.info(f"  FPS: {CAMERA_FPS}")
            
            return True
            
        except Exception as e:
            logger.error(f"Failed to initialize Kinect: {e}")
            return False
    
    def colorize_depth(self, depth_image: np.ndarray) -> np.ndarray:
        """Convert depth to colorized visualization"""
        # Normalize to 0-255 range
        depth_normalized = cv2.normalize(
            depth_image, 
            None, 
            0, 
            255, 
            cv2.NORM_MINMAX, 
            dtype=cv2.CV_8U
        )
        
        # Apply colormap
        depth_colored = cv2.applyColorMap(depth_normalized, cv2.COLORMAP_JET)
        
        return depth_colored
    
    def start_ffmpeg_stream(self, stream_name: str, width: int, height: int, fps: int = 30):
        """Start FFmpeg process to push stream to MediaMTX"""
        import subprocess
        
        rtsp_url = f"rtsp://{MEDIAMTX_HOST}:{MEDIAMTX_PORT}/{stream_name}"
        
        cmd = [
            'ffmpeg',
            '-f', 'rawvideo',
            '-pix_fmt', 'bgr24',
            '-s', f'{width}x{height}',
            '-r', str(fps),
            '-i', '-',  # stdin
            '-c:v', 'libx264',
            '-preset', STREAM_PRESET,
            '-tune', 'zerolatency',
            '-b:v', STREAM_BITRATE,
            '-f', 'rtsp',
            '-rtsp_transport', 'tcp',
            rtsp_url
        ]
        
        try:
            process = subprocess.Popen(
                cmd,
                stdin=subprocess.PIPE,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.PIPE
            )
            
            self.ffmpeg_processes[stream_name] = process
            logger.info(f"✓ Started stream: {stream_name} -> {rtsp_url}")
            return process
            
        except Exception as e:
            logger.error(f"Failed to start FFmpeg for {stream_name}: {e}")
            return None
    
    async def stream_loop(self):
        """Main streaming loop"""
        if not self.initialize_kinect():
            logger.error("Failed to initialize Kinect, cannot start streaming")
            return
        
        # Start FFmpeg processes for enabled streams
        processes = {}
        
        if ENABLE_RGB:
            # RGB dimensions depend on resolution
            rgb_w, rgb_h = self._get_rgb_dimensions()
            processes['rgb'] = self.start_ffmpeg_stream('kinect_rgb', rgb_w, rgb_h, CAMERA_FPS)
        
        if ENABLE_DEPTH:
            # Depth dimensions depend on mode
            depth_w, depth_h = self._get_depth_dimensions()
            processes['depth'] = self.start_ffmpeg_stream('kinect_depth', depth_w, depth_h, CAMERA_FPS)
        
        if ENABLE_IR:
            depth_w, depth_h = self._get_depth_dimensions()
            processes['ir'] = self.start_ffmpeg_stream('kinect_ir', depth_w, depth_h, CAMERA_FPS)
        
        self.streaming = True
        self.start_time = datetime.now()
        
        logger.info("✓ Streaming started")
        
        try:
            while self.streaming:
                try:
                    capture = self.k4a.get_capture()
                    
                    # RGB Stream
                    if ENABLE_RGB and capture.color is not None and processes.get('rgb'):
                        rgb_frame = capture.color[:, :, :3]  # BGRA to BGR
                        try:
                            processes['rgb'].stdin.write(rgb_frame.tobytes())
                        except BrokenPipeError:
                            logger.warning("RGB stream pipe broken, restarting...")
                            processes['rgb'] = self.start_ffmpeg_stream('kinect_rgb', *self._get_rgb_dimensions(), CAMERA_FPS)
                    
                    # Depth Stream
                    if ENABLE_DEPTH and capture.depth is not None and processes.get('depth'):
                        depth_colored = self.colorize_depth(capture.depth)
                        try:
                            processes['depth'].stdin.write(depth_colored.tobytes())
                        except BrokenPipeError:
                            logger.warning("Depth stream pipe broken, restarting...")
                            processes['depth'] = self.start_ffmpeg_stream('kinect_depth', *self._get_depth_dimensions(), CAMERA_FPS)
                    
                    # IR Stream
                    if ENABLE_IR and capture.ir is not None and processes.get('ir'):
                        # Convert IR to 8-bit for streaming
                        ir_normalized = cv2.normalize(capture.ir, None, 0, 255, cv2.NORM_MINMAX, dtype=cv2.CV_8U)
                        ir_colored = cv2.cvtColor(ir_normalized, cv2.COLOR_GRAY2BGR)
                        try:
                            processes['ir'].stdin.write(ir_colored.tobytes())
                        except BrokenPipeError:
                            logger.warning("IR stream pipe broken, restarting...")
                            processes['ir'] = self.start_ffmpeg_stream('kinect_ir', *self._get_depth_dimensions(), CAMERA_FPS)
                    
                    self.frames_captured += 1
                    
                    # Small async sleep to yield control
                    await asyncio.sleep(0.001)
                    
                except Exception as e:
                    logger.error(f"Error in capture loop: {e}")
                    self.frames_dropped += 1
                    await asyncio.sleep(0.1)
                    
        except Exception as e:
            logger.error(f"Streaming error: {e}")
        finally:
            self.stop_streaming()
    
    def stop_streaming(self):
        """Stop all streams and clean up"""
        logger.info("Stopping streaming...")
        self.streaming = False
        
        # Terminate FFmpeg processes
        for name, process in self.ffmpeg_processes.items():
            try:
                process.terminate()
                process.wait(timeout=5)
                logger.info(f"✓ Stopped stream: {name}")
            except Exception as e:
                logger.warning(f"Error stopping {name}: {e}")
                process.kill()
        
        self.ffmpeg_processes.clear()
        
        # Stop Kinect
        if self.k4a:
            try:
                self.k4a.stop()
                logger.info("✓ Kinect stopped")
            except Exception as e:
                logger.warning(f"Error stopping Kinect: {e}")
        
        logger.info("✓ Streaming stopped")
    
    def get_stats(self) -> dict:
        """Get streaming statistics"""
        uptime = None
        if self.start_time:
            uptime = (datetime.now() - self.start_time).total_seconds()
        
        fps = 0
        if uptime and uptime > 0:
            fps = self.frames_captured / uptime
        
        return {
            'streaming': self.streaming,
            'device_id': self.device_id,
            'frames_captured': self.frames_captured,
            'frames_dropped': self.frames_dropped,
            'uptime_seconds': uptime,
            'fps': round(fps, 2),
            'streams_active': list(self.ffmpeg_processes.keys())
        }
    
    def _get_rgb_dimensions(self):
        """Get RGB dimensions based on resolution setting"""
        dimensions = {
            '720p': (1280, 720),
            '1080p': (1920, 1080),
            '1440p': (2560, 1440),
            '1536p': (2048, 1536),
            '2160p': (3840, 2160),
            '3072p': (4096, 3072),
        }
        return dimensions.get(RGB_RESOLUTION, (1920, 1080))
    
    def _get_depth_dimensions(self):
        """Get depth dimensions based on depth mode"""
        dimensions = {
            'NFOV_UNBINNED': (640, 576),
            'NFOV_2X2BINNED': (320, 288),
            'WFOV_UNBINNED': (1024, 1024),
            'WFOV_2X2BINNED': (512, 512),
        }
        return dimensions.get(DEPTH_MODE, (640, 576))

# ============================================
# Global Streamer Instance
# ============================================

streamer = KinectStreamer(device_id=DEVICE_ID)

# ============================================
# API Endpoints
# ============================================

@app.get("/")
async def root():
    """API information"""
    return {
        "service": "Azure Kinect Streaming Service",
        "version": "1.0.0",
        "device_id": DEVICE_ID,
        "status": "ready"
    }

@app.post("/stream/start")
async def start_stream(background_tasks: BackgroundTasks):
    """Start streaming from Kinect"""
    if streamer.streaming:
        raise HTTPException(status_code=400, detail="Already streaming")
    
    # Start streaming in background
    streamer.stream_task = asyncio.create_task(streamer.stream_loop())
    
    # Build stream URLs
    streams = {}
    if ENABLE_RGB:
        streams['rgb'] = f"rtsp://{SERVER_IP}:{MEDIAMTX_PORT}/kinect_rgb"
    if ENABLE_DEPTH:
        streams['depth'] = f"rtsp://{SERVER_IP}:{MEDIAMTX_PORT}/kinect_depth"
    if ENABLE_IR:
        streams['ir'] = f"rtsp://{SERVER_IP}:{MEDIAMTX_PORT}/kinect_ir"
    
    return {
        "status": "started",
        "device_id": DEVICE_ID,
        "streams": streams
    }

@app.post("/stream/stop")
async def stop_stream():
    """Stop streaming"""
    if not streamer.streaming:
        raise HTTPException(status_code=400, detail="Not streaming")
    
    streamer.stop_streaming()
    
    if streamer.stream_task:
        streamer.stream_task.cancel()
        try:
            await streamer.stream_task
        except asyncio.CancelledError:
            pass
    
    return {"status": "stopped"}

@app.get("/stream/status")
async def get_status():
    """Get current streaming status"""
    return streamer.get_stats()

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "streaming": streamer.streaming
    }

# ============================================
# Signal Handling
# ============================================

def signal_handler(signum, frame):
    """Handle shutdown signals gracefully"""
    logger.info(f"Received signal {signum}, shutting down...")
    streamer.stop_streaming()
    sys.exit(0)

signal.signal(signal.SIGINT, signal_handler)
signal.signal(signal.SIGTERM, signal_handler)

# ============================================
# Main Entry Point
# ============================================

if __name__ == "__main__":
    logger.info("=" * 60)
    logger.info("Azure Kinect Streaming Service")
    logger.info("=" * 60)
    logger.info(f"Device ID: {DEVICE_ID}")
    logger.info(f"API Port: {API_PORT}")
    logger.info(f"MediaMTX: {MEDIAMTX_HOST}:{MEDIAMTX_PORT}")
    logger.info(f"RGB: {ENABLE_RGB}, Depth: {ENABLE_DEPTH}, IR: {ENABLE_IR}")
    logger.info("=" * 60)
    
    uvicorn.run(
        app,
        host=SERVER_IP,
        port=API_PORT,
        log_level="info"
    )
