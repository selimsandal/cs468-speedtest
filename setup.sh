#!/bin/bash

#############################################
# Speed Test Server - Full Deployment Script
# Automated deployment for VPS/Cloud servers
#############################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo -e "${BLUE}"
echo "=========================================="
echo "   Speed Test Server - Auto Deployment"
echo "=========================================="
echo -e "${NC}"

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo -e "${YELLOW}Warning: Running as root${NC}"
    SUDO=""
else
    SUDO="sudo"
    echo -e "${YELLOW}Note: You may need to enter your password for sudo commands${NC}"
fi

echo ""

#############################################
# Step 1: Check Prerequisites
#############################################
echo -e "${BLUE}[1/7] Checking prerequisites...${NC}"

# Check if Go is installed
if ! command -v go &> /dev/null; then
    echo -e "${RED}✗ Go is not installed${NC}"
    echo ""
    echo "Installing Go..."

    # Detect OS
    if [ -f /etc/debian_version ]; then
        # Debian/Ubuntu
        $SUDO apt update
        $SUDO apt install -y golang-go
    elif [ -f /etc/redhat-release ]; then
        # CentOS/RHEL
        $SUDO yum install -y golang
    else
        echo -e "${RED}Please install Go manually: https://golang.org/doc/install${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}✓ Go is installed: $(go version)${NC}"

# Check if Nginx is installed
if ! command -v nginx &> /dev/null; then
    echo -e "${YELLOW}! Nginx is not installed${NC}"
    read -p "Do you want to install Nginx? (y/n): " install_nginx

    if [ "$install_nginx" = "y" ] || [ "$install_nginx" = "Y" ]; then
        echo "Installing Nginx..."
        if [ -f /etc/debian_version ]; then
            $SUDO apt update
            $SUDO apt install -y nginx
        elif [ -f /etc/redhat-release ]; then
            $SUDO yum install -y nginx
        fi
        echo -e "${GREEN}✓ Nginx installed${NC}"
    fi
fi

if command -v nginx &> /dev/null; then
    echo -e "${GREEN}✓ Nginx is installed${NC}"
    NGINX_INSTALLED=true
else
    echo -e "${YELLOW}! Nginx not installed - will run on port 8080 only${NC}"
    NGINX_INSTALLED=false
fi

echo ""

#############################################
# Step 2: Get Domain Name
#############################################
echo -e "${BLUE}[2/7] Domain Configuration${NC}"

read -p "Enter your domain name (e.g., speedtest.example.com): " DOMAIN_NAME

if [ -z "$DOMAIN_NAME" ]; then
    echo -e "${RED}✗ Domain name is required${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Domain set to: $DOMAIN_NAME${NC}"
echo ""

#############################################
# Step 3: Build the Application
#############################################
echo -e "${BLUE}[3/7] Building the application...${NC}"

cd "$SCRIPT_DIR"

# Build the server
go build -o speedtest-server main.go

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Build successful${NC}"
    chmod +x speedtest-server
else
    echo -e "${RED}✗ Build failed${NC}"
    exit 1
fi

echo ""

#############################################
# Step 4: Install Systemd Service
#############################################
echo -e "${BLUE}[4/7] Setting up systemd service...${NC}"

# Update service file with correct path
cat > /tmp/speedtest.service << EOF
[Unit]
Description=Speed Test Server
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$SCRIPT_DIR
ExecStart=$SCRIPT_DIR/speedtest-server
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Install service
$SUDO cp /tmp/speedtest.service /etc/systemd/system/
$SUDO systemctl daemon-reload
$SUDO systemctl enable speedtest
$SUDO systemctl restart speedtest

# Wait a moment for service to start
sleep 2

# Check if service is running
if $SUDO systemctl is-active --quiet speedtest; then
    echo -e "${GREEN}✓ Service started successfully${NC}"
else
    echo -e "${RED}✗ Service failed to start${NC}"
    echo "Check logs with: sudo journalctl -u speedtest -n 50"
    exit 1
fi

echo ""

#############################################
# Step 5: Configure Firewall
#############################################
echo -e "${BLUE}[5/7] Configuring firewall...${NC}"

# Check which firewall is in use
if command -v ufw &> /dev/null && $SUDO ufw status | grep -q "Status: active"; then
    echo "Configuring UFW..."
    $SUDO ufw allow 80/tcp
    $SUDO ufw allow 443/tcp
    $SUDO ufw allow 8080/tcp
    echo -e "${GREEN}✓ UFW configured${NC}"
elif command -v firewall-cmd &> /dev/null; then
    echo "Configuring firewalld..."
    $SUDO firewall-cmd --permanent --add-service=http
    $SUDO firewall-cmd --permanent --add-service=https
    $SUDO firewall-cmd --permanent --add-port=8080/tcp
    $SUDO firewall-cmd --reload
    echo -e "${GREEN}✓ Firewalld configured${NC}"
else
    echo -e "${YELLOW}! No firewall detected. Make sure ports 80, 443, and 8080 are open${NC}"
fi

echo ""

#############################################
# Step 6: Configure Nginx (if installed)
#############################################
if [ "$NGINX_INSTALLED" = true ]; then
    echo -e "${BLUE}[6/7] Configuring Nginx...${NC}"

    # Create Nginx config from template
    sed "s/DOMAIN_NAME/$DOMAIN_NAME/g" "$SCRIPT_DIR/nginx.conf.template" > /tmp/speedtest-nginx.conf

    # Install Nginx config
    if [ -d /etc/nginx/sites-available ]; then
        # Debian/Ubuntu style
        $SUDO cp /tmp/speedtest-nginx.conf /etc/nginx/sites-available/speedtest
        $SUDO ln -sf /etc/nginx/sites-available/speedtest /etc/nginx/sites-enabled/

        # Remove default site if it exists
        if [ -f /etc/nginx/sites-enabled/default ]; then
            read -p "Remove default Nginx site? (y/n): " remove_default
            if [ "$remove_default" = "y" ] || [ "$remove_default" = "Y" ]; then
                $SUDO rm -f /etc/nginx/sites-enabled/default
            fi
        fi
    else
        # CentOS/RHEL style
        $SUDO cp /tmp/speedtest-nginx.conf /etc/nginx/conf.d/speedtest.conf
    fi

    # Test Nginx configuration
    if $SUDO nginx -t; then
        echo -e "${GREEN}✓ Nginx configuration is valid${NC}"
        $SUDO systemctl restart nginx
        echo -e "${GREEN}✓ Nginx restarted${NC}"
        NGINX_CONFIGURED=true
    else
        echo -e "${RED}✗ Nginx configuration test failed${NC}"
        exit 1
    fi
else
    echo -e "${BLUE}[6/7] Skipping Nginx configuration (not installed)${NC}"
    NGINX_CONFIGURED=false
fi

echo ""

#############################################
# Step 7: SSL Setup (Optional)
#############################################
if [ "$NGINX_CONFIGURED" = true ]; then
    echo -e "${BLUE}[7/7] SSL Certificate Setup${NC}"

    read -p "Do you want to set up SSL with Let's Encrypt? (y/n): " setup_ssl

    if [ "$setup_ssl" = "y" ] || [ "$setup_ssl" = "Y" ]; then
        # Check if certbot is installed
        if ! command -v certbot &> /dev/null; then
            echo "Installing Certbot..."
            if [ -f /etc/debian_version ]; then
                $SUDO apt update
                $SUDO apt install -y certbot python3-certbot-nginx
            elif [ -f /etc/redhat-release ]; then
                $SUDO yum install -y certbot python3-certbot-nginx
            fi
        fi

        echo ""
        echo -e "${YELLOW}Important: Make sure $DOMAIN_NAME points to this server's IP${NC}"
        read -p "Press Enter to continue with SSL setup..."

        # Run certbot
        $SUDO certbot --nginx -d "$DOMAIN_NAME" --non-interactive --agree-tos --register-unsafely-without-email || {
            echo -e "${YELLOW}! SSL setup failed. You can run it manually later:${NC}"
            echo "  sudo certbot --nginx -d $DOMAIN_NAME"
        }

        # Test auto-renewal
        $SUDO certbot renew --dry-run || echo -e "${YELLOW}! Certificate auto-renewal test failed${NC}"

        echo -e "${GREEN}✓ SSL setup complete${NC}"
    else
        echo -e "${YELLOW}! Skipping SSL setup${NC}"
        echo "You can set it up later with: sudo certbot --nginx -d $DOMAIN_NAME"
    fi
else
    echo -e "${BLUE}[7/7] Skipping SSL setup (Nginx not configured)${NC}"
fi

echo ""

#############################################
# Deployment Complete
#############################################
echo -e "${GREEN}"
echo "=========================================="
echo "   🎉 Deployment Complete!"
echo "=========================================="
echo -e "${NC}"
echo ""
echo "Your Speed Test server is now running!"
echo ""

if [ "$NGINX_CONFIGURED" = true ]; then
    if [ "$setup_ssl" = "y" ] || [ "$setup_ssl" = "Y" ]; then
        echo -e "${GREEN}✓ Access your site at: https://$DOMAIN_NAME${NC}"
    else
        echo -e "${GREEN}✓ Access your site at: http://$DOMAIN_NAME${NC}"
    fi
else
    echo -e "${GREEN}✓ Access your site at: http://$DOMAIN_NAME:8080${NC}"
fi

echo ""
echo "Useful commands:"
echo "  sudo systemctl status speedtest    # Check service status"
echo "  sudo systemctl restart speedtest   # Restart service"
echo "  sudo journalctl -u speedtest -f    # View logs"

if [ "$NGINX_CONFIGURED" = true ]; then
    echo "  sudo systemctl restart nginx       # Restart Nginx"
    echo "  sudo nginx -t                      # Test Nginx config"
fi

echo ""
echo -e "${BLUE}=========================================="
echo "Testing server..."
echo -e "==========================================${NC}"

# Test local connectivity
sleep 2
if curl -s http://localhost:8080/health > /dev/null; then
    echo -e "${GREEN}✓ Server is responding locally${NC}"
else
    echo -e "${RED}✗ Server health check failed${NC}"
fi

# Show service status
echo ""
$SUDO systemctl status speedtest --no-pager -l

echo ""
echo -e "${GREEN}Setup complete! 🚀${NC}"
