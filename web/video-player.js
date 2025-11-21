/**
 * Video Player Component with HLS and Recording Support
 */

class VideoPlayer {
    constructor(containerId, streamURL, options = {}) {
        this.containerId = containerId;
        this.streamURL = streamURL;
        this.options = {
            autoplay: true,
            muted: false,
            protocol: 'hls', // 'hls' or 'webrtc'
            ...options
        };

        this.video = null;
        this.hls = null;
        this.mediaRecorder = null;
        this.recordedChunks = [];
        this.isPlaying = false;
        this.isRecording = false;
        this.stats = {
            fps: 0,
            bitrate: 0,
            latency: 0
        };
    }

    /**
     * Initialize the video player
     */
    init() {
        const container = document.getElementById(this.containerId);
        if (!container) {
            console.error(`Container ${this.containerId} not found`);
            return false;
        }

        // Create video element
        this.video = document.createElement('video');
        this.video.className = 'camera-video';
        this.video.controls = false;
        this.video.muted = this.options.muted;
        this.video.playsInline = true;

        container.querySelector('.camera-video-container').appendChild(this.video);

        // Set up event listeners
        this.setupEventListeners();

        return true;
    }

    /**
     * Setup video event listeners
     */
    setupEventListeners() {
        this.video.addEventListener('loadedmetadata', () => {
            console.log('Video metadata loaded');
            this.updateStats();
        });

        this.video.addEventListener('play', () => {
            this.isPlaying = true;
            this.hideOverlay();
        });

        this.video.addEventListener('pause', () => {
            this.isPlaying = false;
        });

        this.video.addEventListener('error', (e) => {
            console.error('Video error:', e);
            this.showOverlay('Error loading stream');
        });
    }

    /**
     * Start playing the stream
     */
    async play() {
        if (!this.video) {
            console.error('Video element not initialized');
            return false;
        }

        try {
            this.showOverlay('Loading...');

            if (this.options.protocol === 'hls') {
                await this.playHLS();
            } else if (this.options.protocol === 'webrtc') {
                await this.playWebRTC();
            }

            return true;
        } catch (error) {
            console.error('Error playing stream:', error);
            this.showOverlay('Failed to load stream');
            return false;
        }
    }

    /**
     * Play HLS stream
     */
    async playHLS() {
        if (Hls.isSupported()) {
            this.hls = new Hls({
                enableWorker: true,
                lowLatencyMode: true,
                backBufferLength: 90
            });

            this.hls.loadSource(this.streamURL);
            this.hls.attachMedia(this.video);

            this.hls.on(Hls.Events.MANIFEST_PARSED, () => {
                this.video.play().catch(err => {
                    console.error('Play error:', err);
                    // Try with muted
                    this.video.muted = true;
                    this.video.play();
                });
            });

            this.hls.on(Hls.Events.ERROR, (event, data) => {
                console.error('HLS error:', data);
                if (data.fatal) {
                    switch (data.type) {
                        case Hls.ErrorTypes.NETWORK_ERROR:
                            console.log('Network error, trying to recover...');
                            this.hls.startLoad();
                            break;
                        case Hls.ErrorTypes.MEDIA_ERROR:
                            console.log('Media error, trying to recover...');
                            this.hls.recoverMediaError();
                            break;
                        default:
                            this.showOverlay('Fatal error loading stream');
                            break;
                    }
                }
            });
        } else if (this.video.canPlayType('application/vnd.apple.mpegurl')) {
            // Native HLS support (Safari)
            this.video.src = this.streamURL;
            await this.video.play();
        } else {
            throw new Error('HLS is not supported in this browser');
        }
    }

    /**
     * Play WebRTC stream (placeholder for future implementation)
     */
    async playWebRTC() {
        // WebRTC implementation would go here
        // This requires MediaMTX WebRTC API integration
        throw new Error('WebRTC not yet implemented');
    }

    /**
     * Stop the stream
     */
    stop() {
        if (this.hls) {
            this.hls.destroy();
            this.hls = null;
        }

        if (this.video) {
            this.video.pause();
            this.video.src = '';
            this.video.load();
        }

        this.isPlaying = false;
        this.showOverlay('Stream stopped');
    }

    /**
     * Start recording
     */
    startRecording(quality = 'medium') {
        if (!this.video || !this.video.srcObject && !this.video.captureStream) {
            console.error('Cannot record: video not ready');
            return false;
        }

        try {
            // Get video stream
            const stream = this.video.captureStream ? 
                this.video.captureStream() : 
                this.video.mozCaptureStream();

            // Configure recorder based on quality
            const options = this.getRecorderOptions(quality);

            this.mediaRecorder = new MediaRecorder(stream, options);
            this.recordedChunks = [];

            this.mediaRecorder.ondataavailable = (event) => {
                if (event.data.size > 0) {
                    this.recordedChunks.push(event.data);
                }
            };

            this.mediaRecorder.onstop = () => {
                this.saveRecording();
            };

            this.mediaRecorder.start(1000); // Collect data every second
            this.isRecording = true;

            console.log('Recording started');
            return true;
        } catch (error) {
            console.error('Error starting recording:', error);
            return false;
        }
    }

    /**
     * Stop recording
     */
    stopRecording() {
        if (this.mediaRecorder && this.isRecording) {
            this.mediaRecorder.stop();
            this.isRecording = false;
            console.log('Recording stopped');
            return true;
        }
        return false;
    }

    /**
     * Save recording to file
     */
    saveRecording() {
        if (this.recordedChunks.length === 0) {
            console.warn('No recorded data to save');
            return;
        }

        const blob = new Blob(this.recordedChunks, {
            type: 'video/webm'
        });

        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `kinect_recording_${Date.now()}.webm`;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);

        this.recordedChunks = [];
        console.log('Recording saved');
    }

    /**
     * Get MediaRecorder options based on quality
     */
    getRecorderOptions(quality) {
        const options = {
            high: {
                videoBitsPerSecond: 8000000,
                mimeType: 'video/webm;codecs=vp9'
            },
            medium: {
                videoBitsPerSecond: 4000000,
                mimeType: 'video/webm;codecs=vp9'
            },
            low: {
                videoBitsPerSecond: 2000000,
                mimeType: 'video/webm;codecs=vp8'
            }
        };

        return options[quality] || options.medium;
    }

    /**
     * Update video statistics
     */
    updateStats() {
        if (!this.video) return;

        // Calculate FPS (simplified)
        let lastTime = performance.now();
        let frames = 0;

        const updateFPS = () => {
            frames++;
            const now = performance.now();
            const delta = now - lastTime;

            if (delta >= 1000) {
                this.stats.fps = Math.round(frames / (delta / 1000));
                frames = 0;
                lastTime = now;
            }

            if (this.isPlaying) {
                requestAnimationFrame(updateFPS);
            }
        };

        requestAnimationFrame(updateFPS);
    }

    /**
     * Get current stats
     */
    getStats() {
        return {
            ...this.stats,
            resolution: this.video ? `${this.video.videoWidth}x${this.video.videoHeight}` : 'N/A',
            isPlaying: this.isPlaying,
            isRecording: this.isRecording
        };
    }

    /**
     * Show loading overlay
     */
    showOverlay(message = '') {
        const container = document.getElementById(this.containerId);
        if (!container) return;

        const overlay = container.querySelector('.video-overlay');
        if (overlay) {
            overlay.classList.remove('hidden');
            if (message) {
                overlay.innerHTML = `<div class="loading-spinner"></div><p>${message}</p>`;
            } else {
                overlay.innerHTML = '<div class="loading-spinner"></div>';
            }
        }
    }

    /**
     * Hide overlay
     */
    hideOverlay() {
        const container = document.getElementById(this.containerId);
        if (!container) return;

        const overlay = container.querySelector('.video-overlay');
        if (overlay) {
            overlay.classList.add('hidden');
        }
    }

    /**
     * Toggle fullscreen
     */
    toggleFullscreen() {
        if (!this.video) return;

        if (!document.fullscreenElement) {
            this.video.requestFullscreen().catch(err => {
                console.error('Error entering fullscreen:', err);
            });
        } else {
            document.exitFullscreen();
        }
    }

    /**
     * Cleanup
     */
    destroy() {
        this.stop();
        if (this.video) {
            this.video.remove();
            this.video = null;
        }
    }
}
