# Speed Test Application

Web-based network speed testing tool measuring ping, download, and upload speeds.

**Live Demo:** https://speedtest.selimsandal.com

## Features

- Ping/latency measurement (RTT averaging)
- Download speed test with parallel connections
- Upload speed test with parallel connections
- Real-time progress tracking
- Data usage reporting
- No external dependencies

## Quick Start

### Local Development

```bash
go run main.go
# Access at http://localhost:8080
```

### Production Deployment

```bash
git clone <repo-url>
cd cs468-speedtest
./setup.sh
```

The setup script installs dependencies, builds the application, configures systemd service, sets up Nginx reverse proxy, configures firewall, and optionally enables SSL/HTTPS.

## Requirements

- Go 1.22.2 or higher
- Linux VPS (Ubuntu/Debian/CentOS/RHEL) for production
- Domain name (for production with SSL)

## API Endpoints

- `GET /` - Web interface
- `GET /ping` - Latency measurement (returns timestamp)
- `GET /download?size=<bytes>` - Download test (default 100MB, max 2GB)
- `POST /upload` - Upload test
- `GET /health` - Health check

## Configuration

Edit `index.html` to modify test parameters:

```javascript
        const CONFIG = {
            PING_COUNT: 5,                    // Number of ping tests to average
            PARALLEL_CONNECTIONS: 8,          // Parallel connections for better saturation
            STREAM_SIZE: 1024 * 1024 * 1024,  // 1 GB continuous stream (will be aborted when stable)
            UPLOAD_BUFFER_SIZE: 50 * 1024 * 1024,  // 50 MB upload buffer per request
            MIN_TEST_DURATION: 2000,          // Minimum 2 seconds of testing
            MAX_TEST_DURATION: 20000,         // Maximum 20 seconds to prevent hanging
            STABILIZATION_WINDOW: 8,          // Number of measurements to check for stability
            STABILIZATION_THRESHOLD: 0.05,    // 5% coefficient of variation for stability
            MEASUREMENT_INTERVAL: 250         // Take speed measurement every 250ms
        };
```

## Technical Implementation

### Backend (Go)

- Standard `net/http` library
- Pre-generated random data buffer (1MB) for performance
- CORS middleware for cross-origin requests
- Streaming transfers with 256KB write buffer
- TCP optimizations: 1MB buffers, TCP_NODELAY enabled, keep-alive configured
- 30s read/write timeouts, 120s idle timeout

### Frontend (JavaScript)

- Vanilla JavaScript, zero dependencies
- 8 parallel connections for download/upload to saturate bandwidth
- `fetch` API with ReadableStream for downloads
- `XMLHttpRequest` for uploads (progress tracking)
- Throttled UI updates (100ms intervals)
- Responsive CSS Grid/Flexbox layout

### Speed Calculation

- Download/Upload: Total bits transferred / elapsed time (8 parallel connections)
- Ping: Average RTT over 5 samples
- Units: Mbps (Megabits per second)

## Manual Build

```bash
go build -o speedtest-server main.go
./speedtest-server
```

## Deployment Options

### Automated (Recommended)

```bash
./setup.sh
```

Configures:
- Go installation
- Nginx with unlimited upload/download
- Systemd service (auto-start on boot)
- Firewall (ports 80, 443, 8080)
- Optional SSL via Let's Encrypt
