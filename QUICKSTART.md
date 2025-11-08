# Quick Start Guide

Get your speed test up and running in minutes!

## One-Command Deployment

```bash
./setup.sh
```

That's it! The script will guide you through the entire setup.

## What It Does

The automated setup script will:

1. ✅ Check and install Go (if needed)
2. ✅ Check and install Nginx (if you want)
3. ✅ Build the application
4. ✅ Set up systemd service (auto-start on boot)
5. ✅ Configure firewall (ports 80, 443, 8080)
6. ✅ Set up Nginx with unlimited upload/download
7. ✅ Optionally set up SSL/HTTPS with Let's Encrypt

## What You'll Be Asked

During setup, you'll need to provide:

1. **Your domain name** (e.g., `speedtest.example.com`)
2. **Install Nginx?** (recommended: yes)
3. **Setup SSL?** (recommended: yes if domain DNS is configured)

## Prerequisites

- A VPS running Ubuntu, Debian, CentOS, or RHEL
- Your domain pointing to your VPS IP address
- Root or sudo access

## After Deployment

Your speed test will be available at:
- `http://your-domain.com` (if no SSL)
- `https://your-domain.com` (if SSL configured)

## Deployment on Current Server

For this specific server with domain `speedtest.selimsandal.com`:

```bash
./setup.sh
```

When prompted:
- Domain name: `speedtest.selimsandal.com`
- Install Nginx: `y`
- Setup SSL: `y`

## Testing

After deployment, test your installation:

```bash
# Check if service is running
sudo systemctl status speedtest

# Test health endpoint
curl http://localhost:8080/health

# Test external access
curl http://speedtest.selimsandal.com/health
```

## Alternative: Manual Deploy

If you prefer manual control:

```bash
./deploy.sh
```

Then choose your preferred option from the menu.

## Need Help?

See the full documentation:
- **[DEPLOYMENT.md](DEPLOYMENT.md)** - Complete deployment guide
- **[README.md](README.md)** - Application documentation

## Troubleshooting

**Script fails:**
```bash
# Check logs
sudo journalctl -u speedtest -f

# Verify firewall
sudo ufw status
```

**Can't access from outside:**
- Verify DNS: `dig speedtest.selimsandal.com`
- Check firewall: `sudo ufw status`
- Test local: `curl http://localhost:8080/health`

**SSL fails:**
- Ensure DNS points to this server
- Verify ports 80/443 are open
- Run: `./setup-ssl.sh` to try again

## File Structure

```
cs468-speedtest/
├── main.go                  # Go backend server
├── index.html              # Frontend web interface
├── setup.sh                # Automated deployment script ⭐
├── deploy.sh               # Quick deployment with options
├── setup-ssl.sh            # SSL/HTTPS setup
├── nginx.conf.template     # Nginx configuration
├── speedtest.service       # Systemd service file
├── README.md               # Application documentation
├── DEPLOYMENT.md           # Detailed deployment guide
└── QUICKSTART.md           # This file
```

## Summary

**Clone and deploy in one command:**
```bash
git clone <your-repo>
cd cs468-speedtest
./setup.sh
```

That's all you need! 🚀
