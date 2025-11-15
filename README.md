# Speed Test Application

Web-based network speed testing tool measuring ping, download, and upload speeds.

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
    PING_COUNT: 5,                    // Number of ping samples
    DOWNLOAD_SIZE: 50 * 1024 * 1024,  // 50MB
    UPLOAD_SIZE: 25 * 1024 * 1024,    // 25MB
    DOWNLOAD_DURATION: 10000,         // 10 seconds
    UPLOAD_DURATION: 10000            // 10 seconds
};
```

## Technical Implementation

### Backend (Go)

- Standard `net/http` library
- Pre-generated random data buffer (1MB) for performance
- CORS middleware for cross-origin requests
- Streaming transfers with 1MB chunks
- TCP optimizations: 1MB buffers, TCP_NODELAY enabled, keep-alive configured
- 30s read/write timeouts, 120s idle timeout

### Frontend (JavaScript)

- Vanilla JavaScript, zero dependencies
- 4 parallel connections for download/upload to saturate bandwidth
- `fetch` API with ReadableStream for downloads
- `XMLHttpRequest` for uploads (progress tracking)
- Throttled UI updates (100ms intervals)
- Responsive CSS Grid/Flexbox layout

### Speed Calculation

- Download/Upload: Total bits transferred / elapsed time (4 parallel connections)
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

### Manual Deployment

```bash
# Build
go build -o speedtest-server main.go

# Install systemd service
sudo cp speedtest.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable speedtest
sudo systemctl start speedtest

# Configure Nginx
sudo sed "s/DOMAIN_NAME/your-domain.com/g" nginx.conf.template > /etc/nginx/sites-available/speedtest
sudo ln -s /etc/nginx/sites-available/speedtest /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx

# Setup SSL
./setup-ssl.sh
```

### Alternative Scripts

- `./deploy.sh` - Interactive deployment menu
- `./setup-ssl.sh` - SSL/HTTPS setup only

## Service Management

```bash
# Status
sudo systemctl status speedtest

# Start/Stop/Restart
sudo systemctl start speedtest
sudo systemctl stop speedtest
sudo systemctl restart speedtest

# Logs
sudo journalctl -u speedtest -f
sudo journalctl -u speedtest -n 100
```

## Nginx Management

```bash
# Test configuration
sudo nginx -t

# Reload without downtime
sudo systemctl reload nginx

# Restart
sudo systemctl restart nginx
```

## Nginx Configuration

The template includes optimizations for accurate speed testing:

- `client_max_body_size 0` - Unlimited upload
- Extended timeouts (300s)
- Disabled buffering (`proxy_buffering off`, `proxy_request_buffering off`)
- Proxy to backend on port 8080

## Updating

```bash
git pull
go build -o speedtest-server main.go
sudo systemctl restart speedtest
```

## Troubleshooting

### Check Server Status

```bash
ps aux | grep speedtest-server
sudo ss -tlnp | grep 8080
curl http://localhost:8080/health
```

### View Logs

```bash
sudo journalctl -u speedtest -f
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
```

### Common Issues

Port in use:
```bash
sudo lsof -i :8080
sudo kill -9 <PID>
```

Permissions:
```bash
chmod +x speedtest-server setup.sh deploy.sh setup-ssl.sh
```

Firewall:
```bash
# Ubuntu/Debian
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 8080/tcp

# CentOS/RHEL
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --permanent --add-port=8080/tcp
sudo firewall-cmd --reload
```

DNS verification:
```bash
dig your-domain.com
```

SSL certificate issues:
```bash
sudo certbot --nginx -d your-domain.com --dry-run
```

## Performance Tuning

Edit `/etc/nginx/nginx.conf`:

```nginx
worker_processes auto;
worker_connections 4096;
keepalive_timeout 65;
```

Then restart: `sudo systemctl restart nginx`

## Security

- Use HTTPS in production (`./setup-ssl.sh`)
- Keep system updated: `sudo apt update && sudo apt upgrade`
- Install fail2ban: `sudo apt install fail2ban`
- Monitor logs for suspicious activity
- Configure firewall (UFW/firewalld)

## Testing Accuracy

For best results:
- Close bandwidth-intensive applications
- Run multiple tests and average results
- Test at different times
- Compare with other tools (speedtest.net, fast.com)
- Results vary based on network conditions

## Files

- `main.go` - Go backend server
- `index.html` - Frontend interface
- `setup.sh` - Automated deployment
- `deploy.sh` - Deployment menu
- `setup-ssl.sh` - SSL configuration
- `nginx.conf.template` - Nginx template
- `speedtest.service` - Systemd service
- `go.mod` - Go module definition
