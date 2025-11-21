/**
 * Main Application Logic
 */

// Global instances
let cameraManager;
let videoPlayers = {};
let settings = {};
let refreshInterval;

// Initialize app when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    initializeApp();
});

/**
 * Initialize the application
 */
function initializeApp() {
    // Load settings
    loadSettings();

    // Initialize camera manager
    cameraManager = new CameraManager();

    // Setup event listeners
    setupEventListeners();

    // Render cameras
    renderCameras();

    // Start auto-refresh if enabled
    if (settings.refreshInterval > 0) {
        startAutoRefresh();
    }

    // Check camera health
    checkAllCamerasHealth();

    console.log('Application initialized');
}

/**
 * Setup all event listeners
 */
function setupEventListeners() {
    // Header buttons
    document.getElementById('settingsBtn').addEventListener('click', () => {
        openModal('settingsModal');
    });

    document.getElementById('refreshBtn').addEventListener('click', () => {
        checkAllCamerasHealth();
        showToast('Refreshing camera status...', 'info');
    });

    // Toolbar buttons
    document.getElementById('addCameraBtn').addEventListener('click', () => {
        openModal('addCameraModal');
    });

    document.getElementById('layoutSelect').addEventListener('change', (e) => {
        changeLayout(e.target.value);
    });

    document.getElementById('startAllBtn').addEventListener('click', startAllStreams);
    document.getElementById('stopAllBtn').addEventListener('click', stopAllStreams);
    document.getElementById('toggleStatsBtn').addEventListener('click', toggleStats);
    document.getElementById('fullscreenBtn').addEventListener('click', toggleFullscreen);

    // Add camera form
    document.getElementById('addCameraForm').addEventListener('submit', handleAddCamera);

    // Settings
    document.getElementById('saveSettingsBtn').addEventListener('click', saveSettings);
    document.getElementById('clearDataBtn').addEventListener('click', clearAllData);
    document.getElementById('exportConfigBtn').addEventListener('click', exportConfig);
    document.getElementById('importConfigBtn').addEventListener('click', importConfig);

    // Tab switching
    document.querySelectorAll('.tab-btn').forEach(btn => {
        btn.addEventListener('click', () => switchTab(btn.dataset.tab));
    });

    // Close modals on background click
    document.querySelectorAll('.modal').forEach(modal => {
        modal.addEventListener('click', (e) => {
            if (e.target === modal) {
                closeModal(modal.id);
            }
        });
    });
}

/**
 * Render all cameras
 */
function renderCameras() {
    const cameras = cameraManager.getAllCameras();
    const grid = document.getElementById('cameraGrid');
    const emptyState = document.getElementById('emptyState');

    // Show/hide empty state
    if (cameras.length === 0) {
        grid.classList.add('hidden');
        emptyState.classList.remove('hidden');
        return;
    } else {
        grid.classList.remove('hidden');
        emptyState.classList.add('hidden');
    }

    // Clear existing
    grid.innerHTML = '';

    // Render each camera
    cameras.forEach(camera => {
        const card = createCameraCard(camera);
        grid.appendChild(card);
    });

    // Update stats
    updateStatusBar();
}

/**
 * Create camera card HTML
 */
function createCameraCard(camera) {
    const card = document.createElement('div');
    card.className = `camera-card ${camera.streaming ? 'streaming' : ''} ${camera.recording ? 'recording' : ''}`;
    card.id = `camera-${camera.id}`;

    const statusClass = camera.status === 'online' ? 'online' : 'offline';
    const streamingBadge = camera.streaming ? '<span class="status-badge streaming">Streaming</span>' : '';
    const recordingBadge = camera.recording ? '<span class="status-badge recording">Recording</span>' : '';

    card.innerHTML = `
        <div class="camera-header">
            <div class="camera-title">${camera.name}</div>
            <div class="camera-status">
                <span class="status-badge ${statusClass}">${camera.status}</span>
                ${streamingBadge}
                ${recordingBadge}
            </div>
        </div>

        <div class="camera-video-container">
            <div class="video-overlay">
                <div class="loading-spinner"></div>
                <p>Ready to stream</p>
            </div>
            <div class="video-stats hidden" id="stats-${camera.id}">
                FPS: <span id="fps-${camera.id}">0</span><br>
                Resolution: <span id="res-${camera.id}">N/A</span>
            </div>
        </div>

        <div class="camera-controls">
            <button class="btn btn-success" onclick="startStream('${camera.id}')">
                <i class="fas fa-play"></i> Start
            </button>
            <button class="btn btn-danger" onclick="stopStream('${camera.id}')">
                <i class="fas fa-stop"></i> Stop
            </button>
            <button class="btn btn-danger" id="rec-${camera.id}" onclick="toggleRecording('${camera.id}')">
                <i class="fas fa-circle"></i> Record
            </button>
        </div>

        <div class="camera-footer">
            <div class="stream-selector">
                <button class="stream-btn active" data-camera="${camera.id}" data-stream="rgb">RGB</button>
                <button class="stream-btn" data-camera="${camera.id}" data-stream="depth">Depth</button>
                <button class="stream-btn" data-camera="${camera.id}" data-stream="ir">IR</button>
            </div>
            <div class="camera-actions">
                <button class="icon-btn" onclick="toggleFullscreenCamera('${camera.id}')" title="Fullscreen">
                    <i class="fas fa-expand"></i>
                </button>
                <button class="icon-btn" onclick="editCamera('${camera.id}')" title="Edit">
                    <i class="fas fa-edit"></i>
                </button>
                <button class="icon-btn" onclick="deleteCamera('${camera.id}')" title="Delete">
                    <i class="fas fa-trash"></i>
                </button>
            </div>
        </div>
    `;

    // Setup stream selector
    card.querySelectorAll('.stream-btn').forEach(btn => {
        btn.addEventListener('click', () => {
            card.querySelectorAll('.stream-btn').forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
            
            const cameraId = btn.dataset.camera;
            const streamType = btn.dataset.stream;
            switchStreamType(cameraId, streamType);
        });
    });

    return card;
}

/**
 * Start stream for a camera
 */
async function startStream(cameraId) {
    const camera = cameraManager.getCamera(cameraId);
    if (!camera) return;

    try {
        showToast(`Starting stream for ${camera.name}...`, 'info');

        // Call API to start stream
        const api = cameraManager.getAPI(cameraId);
        await api.startStream();

        // Wait a bit for stream to be ready
        await new Promise(resolve => setTimeout(resolve, 2000));

        // Get active stream type
        const card = document.getElementById(`camera-${cameraId}`);
        const activeBtn = card.querySelector('.stream-btn.active');
        const streamType = activeBtn ? activeBtn.dataset.stream : 'rgb';

        // Get stream URL
        const urls = cameraManager.getStreamURLs(cameraId);
        const streamURL = urls[streamType][settings.streamProtocol || 'hls'];

        // Create video player
        const player = new VideoPlayer(`camera-${cameraId}`, streamURL, {
            protocol: settings.streamProtocol || 'hls',
            muted: false
        });

        player.init();
        await player.play();

        videoPlayers[cameraId] = player;

        // Update camera status
        cameraManager.updateCamera(cameraId, { streaming: true });
        renderCameras();

        // Update stats periodically
        setInterval(() => {
            if (player.isPlaying) {
                const stats = player.getStats();
                updateCameraStats(cameraId, stats);
            }
        }, 1000);

        showToast(`Stream started for ${camera.name}`, 'success');
    } catch (error) {
        console.error('Error starting stream:', error);
        showToast(`Failed to start stream: ${error.message}`, 'error');
    }
}

/**
 * Stop stream for a camera
 */
async function stopStream(cameraId) {
    const camera = cameraManager.getCamera(cameraId);
    if (!camera) return;

    try {
        // Stop recording if active
        if (camera.recording) {
            toggleRecording(cameraId);
        }

        // Stop video player
        if (videoPlayers[cameraId]) {
            videoPlayers[cameraId].stop();
            videoPlayers[cameraId].destroy();
            delete videoPlayers[cameraId];
        }

        // Call API to stop stream
        const api = cameraManager.getAPI(cameraId);
        await api.stopStream();

        // Update camera status
        cameraManager.updateCamera(cameraId, { streaming: false });
        renderCameras();

        showToast(`Stream stopped for ${camera.name}`, 'info');
    } catch (error) {
        console.error('Error stopping stream:', error);
        showToast(`Failed to stop stream: ${error.message}`, 'error');
    }
}

/**
 * Toggle recording for a camera
 */
function toggleRecording(cameraId) {
    const camera = cameraManager.getCamera(cameraId);
    if (!camera) return;

    const player = videoPlayers[cameraId];
    if (!player) {
        showToast('Start streaming before recording', 'warning');
        return;
    }

    const recBtn = document.getElementById(`rec-${cameraId}`);

    if (!camera.recording) {
        // Start recording
        const quality = settings.recordingQuality || 'medium';
        if (player.startRecording(quality)) {
            cameraManager.updateCamera(cameraId, { recording: true });
            recBtn.innerHTML = '<i class="fas fa-stop-circle"></i> Stop Rec';
            recBtn.classList.remove('btn-danger');
            recBtn.classList.add('btn-warning');
            showToast(`Recording started for ${camera.name}`, 'success');
            renderCameras();
        }
    } else {
        // Stop recording
        if (player.stopRecording()) {
            cameraManager.updateCamera(cameraId, { recording: false });
            recBtn.innerHTML = '<i class="fas fa-circle"></i> Record';
            recBtn.classList.remove('btn-warning');
            recBtn.classList.add('btn-danger');
            showToast(`Recording saved for ${camera.name}`, 'success');
            renderCameras();
        }
    }
}

/**
 * Switch stream type (RGB, Depth, IR)
 */
async function switchStreamType(cameraId, streamType) {
    const camera = cameraManager.getCamera(cameraId);
    if (!camera || !camera.streaming) return;

    // Stop current stream
    await stopStream(cameraId);

    // Wait a bit
    await new Promise(resolve => setTimeout(resolve, 500));

    // Start new stream type
    await startStream(cameraId);
}

/**
 * Update camera statistics
 */
function updateCameraStats(cameraId, stats) {
    const fpsEl = document.getElementById(`fps-${cameraId}`);
    const resEl = document.getElementById(`res-${cameraId}`);

    if (fpsEl) fpsEl.textContent = stats.fps;
    if (resEl) resEl.textContent = stats.resolution;
}

/**
 * Start all streams
 */
async function startAllStreams() {
    const cameras = cameraManager.getAllCameras();
    for (const camera of cameras) {
        if (!camera.streaming) {
            await startStream(camera.id);
            await new Promise(resolve => setTimeout(resolve, 1000));
        }
    }
}

/**
 * Stop all streams
 */
async function stopAllStreams() {
    const cameras = cameraManager.getAllCameras();
    for (const camera of cameras) {
        if (camera.streaming) {
            await stopStream(camera.id);
        }
    }
}

/**
 * Handle add camera form submission
 */
function handleAddCamera(e) {
    e.preventDefault();

    const formData = {
        name: document.getElementById('cameraName').value,
        serverIP: document.getElementById('serverIP').value,
        apiPort: parseInt(document.getElementById('apiPort').value),
        rtspPort: parseInt(document.getElementById('rtspPort').value),
        hlsPort: parseInt(document.getElementById('hlsPort').value),
        deviceId: parseInt(document.getElementById('deviceId').value),
        enableRGB: document.getElementById('enableRGB').checked,
        enableDepth: document.getElementById('enableDepth').checked,
        enableIR: document.getElementById('enableIR').checked
    };

    cameraManager.addCamera(formData);
    renderCameras();
    closeModal('addCameraModal');
    showToast(`Camera "${formData.name}" added successfully`, 'success');

    // Reset form
    document.getElementById('addCameraForm').reset();
}

/**
 * Delete camera
 */
function deleteCamera(cameraId) {
    const camera = cameraManager.getCamera(cameraId);
    if (!camera) return;

    if (confirm(`Are you sure you want to delete "${camera.name}"?`)) {
        // Stop stream if active
        if (camera.streaming) {
            stopStream(cameraId);
        }

        cameraManager.removeCamera(cameraId);
        renderCameras();
        showToast(`Camera "${camera.name}" deleted`, 'info');
    }
}

/**
 * Check health of all cameras
 */
async function checkAllCamerasHealth() {
    const statusEl = document.getElementById('connectionStatus');
    statusEl.querySelector('.status-text').textContent = 'Checking...';

    await cameraManager.checkAllHealth();
    renderCameras();

    const stats = cameraManager.getStatistics();
    const allOnline = stats.online === stats.total && stats.total > 0;

    const indicator = statusEl.querySelector('.status-indicator');
    const text = statusEl.querySelector('.status-text');

    if (allOnline) {
        indicator.classList.add('connected');
        indicator.classList.remove('disconnected');
        text.textContent = 'All Online';
    } else if (stats.online > 0) {
        indicator.classList.remove('connected', 'disconnected');
        text.textContent = `${stats.online}/${stats.total} Online`;
    } else {
        indicator.classList.add('disconnected');
        indicator.classList.remove('connected');
        text.textContent = 'Offline';
    }
}

/**
 * Update status bar
 */
function updateStatusBar() {
    const stats = cameraManager.getStatistics();
    document.getElementById('totalCameras').textContent = stats.total;
    document.getElementById('streamingCount').textContent = stats.streaming;
    document.getElementById('recordingCount').textContent = stats.recording;
    document.getElementById('serversCount').textContent = stats.servers;
}

/**
 * Change grid layout
 */
function changeLayout(layout) {
    const grid = document.getElementById('cameraGrid');
    grid.className = `camera-grid ${layout}`;
}

/**
 * Toggle statistics overlay
 */
function toggleStats() {
    const cameras = cameraManager.getAllCameras();
    cameras.forEach(camera => {
        const stats = document.getElementById(`stats-${camera.id}`);
        if (stats) {
            stats.classList.toggle('hidden');
        }
    });
}

/**
 * Toggle fullscreen
 */
function toggleFullscreen() {
    if (!document.fullscreenElement) {
        document.documentElement.requestFullscreen();
    } else {
        document.exitFullscreen();
    }
}

/**
 * Toggle fullscreen for specific camera
 */
function toggleFullscreenCamera(cameraId) {
    const player = videoPlayers[cameraId];
    if (player) {
        player.toggleFullscreen();
    }
}

/**
 * Start auto-refresh
 */
function startAutoRefresh() {
    if (refreshInterval) {
        clearInterval(refreshInterval);
    }

    const interval = settings.refreshInterval || 5;
    refreshInterval = setInterval(() => {
        checkAllCamerasHealth();
    }, interval * 1000);
}

/**
 * Load settings from localStorage
 */
function loadSettings() {
    const stored = localStorage.getItem('kinect_settings');
    settings = stored ? JSON.parse(stored) : {
        refreshInterval: 5,
        autoReconnect: true,
        showNotifications: true,
        theme: 'dark',
        streamProtocol: 'hls',
        bufferSize: 3,
        autoStartStreams: false,
        recordingQuality: 'medium',
        recordingFormat: 'webm',
        autoSaveRecordings: true,
        maxRetries: 3,
        requestTimeout: 5000,
        debugMode: false
    };

    // Apply settings to UI
    applySettingsToUI();
}

/**
 * Apply settings to UI
 */
function applySettingsToUI() {
    Object.keys(settings).forEach(key => {
        const element = document.getElementById(key);
        if (element) {
            if (element.type === 'checkbox') {
                element.checked = settings[key];
            } else {
                element.value = settings[key];
            }
        }
    });
}

/**
 * Save settings
 */
function saveSettings() {
    // Read from UI
    settings = {
        refreshInterval: parseInt(document.getElementById('refreshInterval').value),
        autoReconnect: document.getElementById('autoReconnect').checked,
        showNotifications: document.getElementById('showNotifications').checked,
        theme: document.getElementById('theme').value,
        streamProtocol: document.getElementById('streamProtocol').value,
        bufferSize: parseInt(document.getElementById('bufferSize').value),
        autoStartStreams: document.getElementById('autoStartStreams').checked,
        recordingQuality: document.getElementById('recordingQuality').value,
        recordingFormat: document.getElementById('recordingFormat').value,
        autoSaveRecordings: document.getElementById('autoSaveRecordings').checked,
        maxRetries: parseInt(document.getElementById('maxRetries').value),
        requestTimeout: parseInt(document.getElementById('requestTimeout').value),
        debugMode: document.getElementById('debugMode').checked
    };

    // Save to localStorage
    localStorage.setItem('kinect_settings', JSON.stringify(settings));

    // Restart auto-refresh if needed
    if (settings.refreshInterval > 0) {
        startAutoRefresh();
    }

    closeModal('settingsModal');
    showToast('Settings saved successfully', 'success');
}

/**
 * Clear all data
 */
function clearAllData() {
    if (confirm('This will delete all cameras and settings. Are you sure?')) {
        localStorage.clear();
        location.reload();
    }
}

/**
 * Export configuration
 */
function exportConfig() {
    const config = {
        cameras: cameraManager.getAllCameras(),
        settings: settings
    };

    const blob = new Blob([JSON.stringify(config, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `kinect_config_${Date.now()}.json`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);

    showToast('Configuration exported', 'success');
}

/**
 * Import configuration
 */
function importConfig() {
    const input = document.createElement('input');
    input.type = 'file';
    input.accept = '.json';

    input.onchange = (e) => {
        const file = e.target.files[0];
        if (!file) return;

        const reader = new FileReader();
        reader.onload = (event) => {
            try {
                const config = JSON.parse(event.target.result);
                
                // Validate config
                if (!config.cameras || !config.settings) {
                    throw new Error('Invalid configuration file');
                }

                // Import data
                localStorage.setItem('kinect_cameras', JSON.stringify(config.cameras));
                localStorage.setItem('kinect_settings', JSON.stringify(config.settings));

                showToast('Configuration imported successfully', 'success');
                setTimeout(() => location.reload(), 1000);
            } catch (error) {
                showToast(`Import failed: ${error.message}`, 'error');
            }
        };

        reader.readAsText(file);
    };

    input.click();
}

/**
 * Modal functions
 */
function openModal(modalId) {
    const modal = document.getElementById(modalId);
    if (modal) {
        modal.classList.add('active');
    }
}

function closeModal(modalId) {
    const modal = document.getElementById(modalId);
    if (modal) {
        modal.classList.remove('active');
    }
}

/**
 * Tab switching
 */
function switchTab(tabId) {
    // Hide all tabs
    document.querySelectorAll('.tab-content').forEach(tab => {
        tab.classList.remove('active');
    });
    document.querySelectorAll('.tab-btn').forEach(btn => {
        btn.classList.remove('active');
    });

    // Show selected tab
    document.getElementById(`${tabId}-tab`).classList.add('active');
    document.querySelector(`[data-tab="${tabId}"]`).classList.add('active');
}

/**
 * Toast notifications
 */
function showToast(message, type = 'info') {
    if (!settings.showNotifications) return;

    const container = document.getElementById('toastContainer');
    const toast = document.createElement('div');
    toast.className = `toast ${type}`;

    const icons = {
        success: 'fa-check-circle',
        error: 'fa-exclamation-circle',
        warning: 'fa-exclamation-triangle',
        info: 'fa-info-circle'
    };

    toast.innerHTML = `
        <i class="fas ${icons[type]}"></i>
        <div class="toast-message">${message}</div>
        <button class="toast-close" onclick="this.parentElement.remove()">
            <i class="fas fa-times"></i>
        </button>
    `;

    container.appendChild(toast);

    // Auto-remove after 5 seconds
    setTimeout(() => {
        toast.remove();
    }, 5000);
}
