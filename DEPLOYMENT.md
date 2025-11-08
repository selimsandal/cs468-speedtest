# VPS Deployment Guide

Deploy the Speed Test application on any VPS with one command!

## 🚀 Automated Deployment (Recommended)

The easiest way to deploy:

```bash
# Clone the repository
git clone <your-repo-url>
cd cs468-speedtest

# Run automated setup
./setup.sh
```

The script will automatically:
- ✅ Install dependencies (Go, Nginx, Certbot if needed)
- ✅ Build the application
- ✅ Set up systemd service (auto-start on boot)
- ✅ Configure firewall rules
- ✅ Set up Nginx reverse proxy with unlimited upload/download
- ✅ Optionally configure SSL/HTTPS with Let's Encrypt

### What You Need

1. A VPS (Ubuntu, Debian, CentOS, or RHEL)
2. A domain name pointing to your VPS IP
3. Root or sudo access

### During Setup

The script will ask for:
- Your domain name (e.g., `speedtest.example.com`)
- Whether to install Nginx (if not already installed)
- Whether to set up SSL/HTTPS (recommended)

### After Setup

Access your speed test at:
- Without SSL: `http://your-domain.com`
- With SSL: `https://your-domain.com`

---

## Alternative Deployment Methods

### Option 1: Quick Deploy Script

For simpler manual control:

```bash
./deploy.sh
```

Choose from:
1. Run server now (foreground)
2. Install as systemd service
3. Full automated setup (runs setup.sh)
4. Just build

### Option 2: Manual Step-by-Step

#### 1. Build the Application

```bash
cd /root/cs468-speedtest
go build -o speedtest-server main.go
chmod +x speedtest-server
```

#### 2. Test the Server

```bash
./speedtest-server
```

Press Ctrl+C to stop.

#### 3. Configure Firewall

```bash
# Ubuntu/Debian (UFW)
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 8080/tcp

# CentOS/RHEL (firewalld)
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --permanent --add-port=8080/tcp
sudo firewall-cmd --reload
```

#### 4. Install as Systemd Service

```bash
# The service file is pre-configured
sudo cp speedtest.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable speedtest
sudo systemctl start speedtest

# Check status
sudo systemctl status speedtest
```

#### 5. Set Up Nginx (Optional but Recommended)

```bash
# Install Nginx
sudo apt install nginx  # Ubuntu/Debian
# OR
sudo yum install nginx  # CentOS/RHEL

# Use the provided template
sudo sed "s/DOMAIN_NAME/your-domain.com/g" nginx.conf.template > /etc/nginx/sites-available/speedtest

# Enable the site
sudo ln -s /etc/nginx/sites-available/speedtest /etc/nginx/sites-enabled/

# Test and restart
sudo nginx -t
sudo systemctl restart nginx
```

#### 6. Add SSL/HTTPS (Optional but Recommended)

```bash
# Run the SSL setup script
./setup-ssl.sh

# Or manually:
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d your-domain.com
```

---

## Nginx Configuration Details

The Nginx configuration includes:

### No Upload/Download Limits
```nginx
client_max_body_size 0;  # Unlimited upload size
```

### Extended Timeouts
```nginx
client_body_timeout 300s;
proxy_connect_timeout 300s;
proxy_send_timeout 300s;
proxy_read_timeout 300s;
```

### Disabled Buffering
```nginx
proxy_buffering off;
proxy_request_buffering off;
```

This ensures accurate speed measurements without artificial limitations.

---

## Managing the Application

### Service Management

```bash
# Check status
sudo systemctl status speedtest

# Start service
sudo systemctl start speedtest

# Stop service
sudo systemctl stop speedtest

# Restart service
sudo systemctl restart speedtest

# View logs
sudo journalctl -u speedtest -f

# View recent logs
sudo journalctl -u speedtest -n 100
```

### Nginx Management

```bash
# Check status
sudo systemctl status nginx

# Restart Nginx
sudo systemctl restart nginx

# Test configuration
sudo nginx -t

# Reload configuration (no downtime)
sudo systemctl reload nginx
```

---

## Updating the Application

```bash
# Pull latest changes
git pull

# Rebuild
go build -o speedtest-server main.go

# Restart service
sudo systemctl restart speedtest
```

Or run `./deploy.sh` and choose option 2.

---

## Troubleshooting

### Check if Server is Running

```bash
# Check process
ps aux | grep speedtest-server

# Check if port is listening
sudo netstat -tlnp | grep 8080
# OR
sudo ss -tlnp | grep 8080
```

### Test Connectivity

```bash
# Local test
curl http://localhost:8080/health

# Remote test
curl http://your-domain.com/health
```

### View Logs

```bash
# Service logs
sudo journalctl -u speedtest -f

# Nginx access logs
sudo tail -f /var/log/nginx/access.log

# Nginx error logs
sudo tail -f /var/log/nginx/error.log
```

### Common Issues

**Port already in use:**
```bash
# Find what's using port 8080
sudo lsof -i :8080

# Kill the process
sudo kill -9 <PID>
```

**Permission denied:**
```bash
chmod +x speedtest-server
chmod +x setup.sh
chmod +x deploy.sh
chmod +x setup-ssl.sh
```

**Cannot connect from outside:**
- Check firewall rules: `sudo ufw status` or `sudo firewall-cmd --list-all`
- Verify DNS points to your VPS IP: `dig your-domain.com`
- Check cloud provider security groups (AWS, GCP, etc.)

**Nginx configuration test fails:**
```bash
# Test and see errors
sudo nginx -t

# Check syntax
sudo nginx -T
```

**SSL certificate fails:**
- Ensure DNS points to your server
- Verify ports 80 and 443 are open
- Check domain ownership
- Try: `sudo certbot --nginx -d your-domain.com --dry-run`

---

## Deployment Files

The repository includes these deployment files:

- **`setup.sh`** - Full automated deployment script (recommended)
- **`deploy.sh`** - Quick deployment with options
- **`setup-ssl.sh`** - SSL/HTTPS setup script
- **`nginx.conf.template`** - Nginx configuration template
- **`speedtest.service`** - Systemd service file
- **`DEPLOYMENT.md`** - This file

---

## Security Best Practices

1. **Use HTTPS** in production (run `./setup-ssl.sh`)
2. **Keep system updated**:
   ```bash
   sudo apt update && sudo apt upgrade  # Ubuntu/Debian
   sudo yum update                      # CentOS/RHEL
   ```
3. **Set up fail2ban** to block malicious IPs:
   ```bash
   sudo apt install fail2ban
   ```
4. **Monitor logs** regularly for suspicious activity
5. **Use a firewall** (UFW or firewalld)
6. **Set up monitoring** (UptimeRobot, Prometheus, etc.)

---

## Performance Tuning

For high-traffic deployments, edit `/etc/nginx/nginx.conf`:

```nginx
worker_processes auto;
worker_connections 4096;

# In http block:
keepalive_timeout 65;
```

Restart Nginx: `sudo systemctl restart nginx`

---

## Cloud Provider Specific Notes

### AWS EC2
- Open ports in Security Group: 80, 443, 8080
- Consider using Elastic IP for static IP
- Use Route53 for DNS management

### Google Cloud Platform
- Configure firewall rules in VPC
- Use Cloud DNS for domain management
- Consider using Cloud Load Balancer for high traffic

### DigitalOcean
- Configure firewall in Droplet settings
- Use floating IP for static IP
- DigitalOcean DNS is free and easy to use

### Azure
- Configure Network Security Group rules
- Use Azure DNS for domain management
- Consider Application Gateway for SSL termination

---

## Migration Guide

To move your deployment to another VPS:

```bash
# On new VPS:
git clone <your-repo-url>
cd cs468-speedtest
./setup.sh
```

That's it! The script handles everything automatically.

---

## Support

If you encounter issues:

1. Check the logs: `sudo journalctl -u speedtest -f`
2. Test connectivity: `curl http://localhost:8080/health`
3. Verify firewall: `sudo ufw status` or `sudo firewall-cmd --list-all`
4. Check Nginx: `sudo nginx -t`
5. Review this documentation for troubleshooting steps

---

## Summary

**Fastest deployment:**
```bash
git clone <repo>
cd cs468-speedtest
./setup.sh
```

**Manual deployment:**
```bash
./deploy.sh  # Choose option 3 for full setup
```

**SSL setup (after deployment):**
```bash
./setup-ssl.sh
```

Your speed test will be live at your domain! 🚀
