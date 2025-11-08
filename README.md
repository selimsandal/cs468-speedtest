# Speed Test Application

A web-based speed testing tool that measures network performance including ping/latency, download speed, and upload speed.

## Features

- **Ping/Latency Test**: Measures round-trip time (RTT) to the server by averaging multiple ping requests
- **Download Speed Test**: Measures download speed by fetching data from the server
- **Upload Speed Test**: Measures upload speed by sending data to the server
- **Data Usage Tracking**: Reports the exact amount of data downloaded and uploaded during tests
- **Real-time Progress**: Visual progress bars and live speed updates during testing
- **Responsive UI**: Clean, modern interface that works on all devices

## Quick Deployment

### VPS/Production (Automated)

Deploy to any VPS with one command:

```bash
git clone <your-repo-url>
cd cs468-speedtest
./setup.sh
```

The script automatically sets up everything including Nginx, SSL, and firewall. See **[QUICKSTART.md](QUICKSTART.md)** for details.

### Local Development

```bash
go run main.go
# Then open: http://localhost:8080
```

## System Requirements

- Go 1.22.2 or higher
- Modern web browser (Chrome, Firefox, Safari, Edge)
- Network connection
- For production: Linux VPS (Ubuntu/Debian/CentOS/RHEL)

## Installation and Setup

### 1. Build the Server

```bash
go build -o speedtest-server main.go
```

### 2. Run the Server

```bash
./speedtest-server
```

Or run directly without building:

```bash
go run main.go
```

The server will start on port 8080 by default.

### 3. Access the Application

Open your web browser and navigate to:

```
http://localhost:8080
```

## Usage

1. The server URL field is auto-detected based on the current domain
2. Click the "Start Test" button to begin the speed test
3. The test will run in three phases:
   - **Ping Test**: Measures latency by sending 5 ping requests
   - **Download Test**: Downloads 50 MB of data to measure download speed
   - **Upload Test**: Uploads 25 MB of data to measure upload speed
4. Results are displayed in real-time and summarized at the end

## API Endpoints

The backend provides the following REST API endpoints:

- `GET /` - Serves the frontend HTML interface
- `GET /ping` - Returns a timestamp for latency measurement
- `GET /download?size=<bytes>` - Generates random data for download testing (default: 50MB, max: 100MB)
- `POST /upload` - Receives data for upload testing
- `GET /health` - Health check endpoint

## Configuration

You can modify the following parameters in `index.html` if needed:

```javascript
const CONFIG = {
    PING_COUNT: 5,                    // Number of ping tests to average
    DOWNLOAD_SIZE: 50 * 1024 * 1024,  // 50 MB download
    UPLOAD_SIZE: 25 * 1024 * 1024,    // 25 MB upload
    DOWNLOAD_DURATION: 10000,         // Target 10 seconds for download
    UPLOAD_DURATION: 10000            // Target 10 seconds for upload
};
```

## Technical Details

### Backend (Go)

- Uses standard `net/http` library
- Generates cryptographically random data for downloads
- Implements CORS middleware for cross-origin requests
- Efficient streaming for large data transfers
- Memory-efficient chunked data generation (64KB chunks)

### Frontend (JavaScript)

- Vanilla JavaScript (no external dependencies)
- Uses `fetch` API for ping and download tests
- Uses `XMLHttpRequest` for upload tests (for progress tracking)
- Real-time speed calculations and progress updates
- Responsive design with CSS Grid and Flexbox

### Speed Calculation

- **Download Speed**: Measured by dividing total bits received by elapsed time
- **Upload Speed**: Measured by dividing total bits sent by elapsed time
- **Ping/Latency**: Calculated as the average RTT of multiple ping requests
- All speeds are reported in Mbps (Megabits per second)

## Deployment

### Local Development

See instructions above for running locally.

### VPS/Production Deployment

For detailed VPS deployment instructions (including systemd service, Nginx reverse proxy, SSL setup, etc.), see:

**[DEPLOYMENT.md](DEPLOYMENT.md)**

Quick VPS setup:
```bash
# Build
go build -o speedtest-server main.go

# Run directly on port 8080
./speedtest-server

# Access at: http://your-domain.com:8080
```

For production use with your domain (e.g., `speedtest.selimsandal.com`):
- Set up systemd service for auto-restart
- Configure Nginx reverse proxy for standard HTTP/HTTPS ports
- Add SSL certificate with Let's Encrypt

See DEPLOYMENT.md for complete instructions.

## Notes

- The server limits download size to a maximum of 100MB to prevent abuse
- Data is generated randomly and is not cached to ensure accurate measurements
- CORS is enabled to allow testing from different origins
- The application does not require any external libraries or dependencies for core functionality

## Testing Accuracy

For best results:
- Close other applications using network bandwidth
- Run multiple tests and compare results
- Test at different times of day
- Compare results with other speed test tools (speedtest.net, fast.com) from nearby servers
- Results should be similar but may vary slightly due to network conditions

## Troubleshooting

**Cannot connect to server:**
- Verify the server is running
- Check that port 8080 is not blocked by firewall
- Ensure the server URL is correct

**Tests are slow or timeout:**
- Check your network connection
- Verify server has sufficient bandwidth
- Try reducing test data sizes in the configuration

**Inaccurate results:**
- Close bandwidth-intensive applications
- Run multiple tests for consistency
- Check for network congestion
- Verify server is not under heavy load
