#!/bin/bash

#############################################
# SSL Certificate Setup Script
# Run this after initial deployment to add HTTPS
#############################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}"
echo "=========================================="
echo "   SSL Certificate Setup"
echo "=========================================="
echo -e "${NC}"
echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    SUDO=""
else
    SUDO="sudo"
fi

# Check if Nginx is installed and running
if ! command -v nginx &> /dev/null; then
    echo -e "${RED}✗ Nginx is not installed${NC}"
    echo "Please install Nginx first and run the main setup.sh script"
    exit 1
fi

if ! $SUDO systemctl is-active --quiet nginx; then
    echo -e "${RED}✗ Nginx is not running${NC}"
    echo "Start Nginx with: sudo systemctl start nginx"
    exit 1
fi

echo -e "${GREEN}✓ Nginx is installed and running${NC}"
echo ""

# Get domain name
read -p "Enter your domain name: " DOMAIN_NAME

if [ -z "$DOMAIN_NAME" ]; then
    echo -e "${RED}✗ Domain name is required${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}Important checks before continuing:${NC}"
echo "1. Your domain $DOMAIN_NAME must point to this server's IP"
echo "2. Port 80 and 443 must be open in your firewall"
echo "3. Nginx must be configured for your domain"
echo ""

# Get server IP
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s icanhazip.com 2>/dev/null || echo "unknown")
echo "This server's public IP: $SERVER_IP"
echo ""

read -p "Have you confirmed your DNS is pointing here? (y/n): " dns_confirmed

if [ "$dns_confirmed" != "y" ] && [ "$dns_confirmed" != "Y" ]; then
    echo -e "${YELLOW}Please configure your DNS first, then run this script again${NC}"
    exit 0
fi

echo ""

# Check if certbot is installed
if ! command -v certbot &> /dev/null; then
    echo "Installing Certbot..."

    if [ -f /etc/debian_version ]; then
        $SUDO apt update
        $SUDO apt install -y certbot python3-certbot-nginx
    elif [ -f /etc/redhat-release ]; then
        $SUDO yum install -y certbot python3-certbot-nginx
    else
        echo -e "${RED}✗ Could not detect OS. Please install certbot manually${NC}"
        exit 1
    fi

    echo -e "${GREEN}✓ Certbot installed${NC}"
else
    echo -e "${GREEN}✓ Certbot is already installed${NC}"
fi

echo ""

# Get email for renewal notifications (optional)
read -p "Enter your email for renewal notifications (or press Enter to skip): " EMAIL

echo ""
echo "Obtaining SSL certificate from Let's Encrypt..."
echo ""

# Run certbot
if [ -z "$EMAIL" ]; then
    $SUDO certbot --nginx -d "$DOMAIN_NAME" --non-interactive --agree-tos --register-unsafely-without-email
else
    $SUDO certbot --nginx -d "$DOMAIN_NAME" --non-interactive --agree-tos --email "$EMAIL"
fi

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✓ SSL certificate installed successfully!${NC}"
    echo ""

    # Test auto-renewal
    echo "Testing certificate auto-renewal..."
    if $SUDO certbot renew --dry-run; then
        echo -e "${GREEN}✓ Auto-renewal test passed${NC}"
    else
        echo -e "${YELLOW}! Auto-renewal test failed. Check certbot configuration${NC}"
    fi

    echo ""
    echo -e "${GREEN}"
    echo "=========================================="
    echo "   ✅ SSL Setup Complete!"
    echo "=========================================="
    echo -e "${NC}"
    echo ""
    echo -e "Your site is now accessible at: ${GREEN}https://$DOMAIN_NAME${NC}"
    echo ""
    echo "Certificate information:"
    $SUDO certbot certificates | grep -A 5 "$DOMAIN_NAME" || echo "Run: sudo certbot certificates"
    echo ""
    echo "Certificates will auto-renew. Check renewal with:"
    echo "  sudo certbot renew --dry-run"
else
    echo ""
    echo -e "${RED}✗ SSL certificate installation failed${NC}"
    echo ""
    echo "Common issues:"
    echo "1. Domain not pointing to this server"
    echo "2. Ports 80/443 not open"
    echo "3. Nginx not configured correctly"
    echo ""
    echo "Check the error messages above and try again"
    exit 1
fi
