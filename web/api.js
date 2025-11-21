/**
 * API Client for Azure Kinect Streaming Backend
 */

class KinectAPI {
    constructor(baseURL, port = 8000) {
        this.baseURL = `http://${baseURL}:${port}`;
        this.timeout = 5000;
    }

    /**
     * Make HTTP request with timeout
     */
    async request(endpoint, options = {}) {
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), this.timeout);

        try {
            const response = await fetch(`${this.baseURL}${endpoint}`, {
                ...options,
                signal: controller.signal,
                headers: {
                    'Content-Type': 'application/json',
                    ...options.headers
                }
            });

            clearTimeout(timeoutId);

            if (!response.ok) {
                throw new Error(`HTTP ${response.status}: ${response.statusText}`);
            }

            return await response.json();
        } catch (error) {
            clearTimeout(timeoutId);
            if (error.name === 'AbortError') {
                throw new Error('Request timeout');
            }
            throw error;
        }
    }

    /**
     * Get API root information
     */
    async getInfo() {
        return this.request('/');
    }

    /**
     * Start streaming
     */
    async startStream() {
        return this.request('/stream/start', {
            method: 'POST'
        });
    }

    /**
     * Stop streaming
     */
    async stopStream() {
        return this.request('/stream/stop', {
            method: 'POST'
        });
    }

    /**
     * Get stream status
     */
    async getStatus() {
        return this.request('/stream/status');
    }

    /**
     * Health check
     */
    async healthCheck() {
        return this.request('/health');
    }

    /**
     * Test connection
     */
    async testConnection() {
        try {
            await this.healthCheck();
            return { success: true, online: true };
        } catch (error) {
            return { success: false, online: false, error: error.message };
        }
    }

    /**
     * Get stream URLs
     */
    getStreamURLs(rtspPort = 8554, hlsPort = 8888, webrtcPort = 8889) {
        const host = this.baseURL.replace(/^http:\/\//, '').split(':')[0];
        return {
            rgb: {
                rtsp: `rtsp://${host}:${rtspPort}/kinect_rgb`,
                hls: `http://${host}:${hlsPort}/kinect_rgb/index.m3u8`,
                webrtc: `http://${host}:${webrtcPort}/kinect_rgb`
            },
            depth: {
                rtsp: `rtsp://${host}:${rtspPort}/kinect_depth`,
                hls: `http://${host}:${hlsPort}/kinect_depth/index.m3u8`,
                webrtc: `http://${host}:${webrtcPort}/kinect_depth`
            },
            ir: {
                rtsp: `rtsp://${host}:${rtspPort}/kinect_ir`,
                hls: `http://${host}:${hlsPort}/kinect_ir/index.m3u8`,
                webrtc: `http://${host}:${webrtcPort}/kinect_ir`
            }
        };
    }
}

/**
 * Camera Manager - Handles multiple cameras
 */
class CameraManager {
    constructor() {
        this.cameras = this.loadCameras();
    }

    /**
     * Load cameras from localStorage
     */
    loadCameras() {
        const stored = localStorage.getItem('kinect_cameras');
        return stored ? JSON.parse(stored) : [];
    }

    /**
     * Save cameras to localStorage
     */
    saveCameras() {
        localStorage.setItem('kinect_cameras', JSON.stringify(this.cameras));
    }

    /**
     * Add a new camera
     */
    addCamera(camera) {
        const newCamera = {
            id: Date.now().toString(),
            ...camera,
            status: 'offline',
            streaming: false,
            recording: false,
            stats: {}
        };
        this.cameras.push(newCamera);
        this.saveCameras();
        return newCamera;
    }

    /**
     * Remove a camera
     */
    removeCamera(id) {
        this.cameras = this.cameras.filter(cam => cam.id !== id);
        this.saveCameras();
    }

    /**
     * Update camera
     */
    updateCamera(id, updates) {
        const camera = this.cameras.find(cam => cam.id === id);
        if (camera) {
            Object.assign(camera, updates);
            this.saveCameras();
        }
        return camera;
    }

    /**
     * Get camera by ID
     */
    getCamera(id) {
        return this.cameras.find(cam => cam.id === id);
    }

    /**
     * Get all cameras
     */
    getAllCameras() {
        return this.cameras;
    }

    /**
     * Get API client for camera
     */
    getAPI(id) {
        const camera = this.getCamera(id);
        if (!camera) return null;
        return new KinectAPI(camera.serverIP, camera.apiPort);
    }

    /**
     * Get stream URLs for camera
     */
    getStreamURLs(id) {
        const camera = this.getCamera(id);
        if (!camera) return null;

        const api = this.getAPI(id);
        return api.getStreamURLs(camera.rtspPort, camera.hlsPort, camera.hlsPort + 1);
    }

    /**
     * Check health of all cameras
     */
    async checkAllHealth() {
        const results = await Promise.allSettled(
            this.cameras.map(async (camera) => {
                const api = this.getAPI(camera.id);
                const result = await api.testConnection();
                return { id: camera.id, ...result };
            })
        );

        results.forEach((result, index) => {
            if (result.status === 'fulfilled') {
                this.updateCamera(this.cameras[index].id, {
                    status: result.value.online ? 'online' : 'offline'
                });
            } else {
                this.updateCamera(this.cameras[index].id, {
                    status: 'offline'
                });
            }
        });

        return results;
    }

    /**
     * Get statistics
     */
    getStatistics() {
        return {
            total: this.cameras.length,
            online: this.cameras.filter(c => c.status === 'online').length,
            streaming: this.cameras.filter(c => c.streaming).length,
            recording: this.cameras.filter(c => c.recording).length,
            servers: new Set(this.cameras.map(c => c.serverIP)).size
        };
    }
}
