#!/bin/bash

#############################################
# Quick Deploy Script
# For simple/manual deployment
# For full automated deployment, use setup.sh
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
echo "   Speed Test Server - Quick Deploy"
echo "=========================================="
echo -e "${NC}"
echo ""

# Check if Go is installed
if ! command -v go &> /dev/null; then
    echo -e "${RED}✗ Go is not installed${NC}"
    echo "Please install Go first: https://golang.org/doc/install"
    exit 1
fi

echo -e "${GREEN}✓ Go is installed: $(go version)${NC}"
echo ""

# Build the server
echo "Building the server..."
go build -o speedtest-server main.go

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Build successful${NC}"
    chmod +x speedtest-server
else
    echo -e "${RED}✗ Build failed${NC}"
    exit 1
fi

echo ""
echo "What would you like to do?"
echo ""
echo "1) Run server now (foreground)"
echo "2) Install as systemd service (manual setup)"
echo "3) Full automated setup with Nginx + SSL (recommended)"
echo "4) Just build (already done)"
echo ""
read -p "Enter your choice (1-4): " choice
echo ""

case $choice in
    1)
        echo "Starting server..."
        echo "Press Ctrl+C to stop"
        echo ""
        ./speedtest-server
        ;;
    2)
        # Check if running as root
        if [ "$EUID" -ne 0 ]; then
            SUDO="sudo"
        else
            SUDO=""
        fi

        echo "Installing as systemd service..."

        # Get current directory
        CURRENT_DIR=$(pwd)

        # Create service file
        cat > /tmp/speedtest.service << EOF
[Unit]
Description=Speed Test Server
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$CURRENT_DIR
ExecStart=$CURRENT_DIR/speedtest-server
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

        $SUDO cp /tmp/speedtest.service /etc/systemd/system/
        $SUDO systemctl daemon-reload
        $SUDO systemctl enable speedtest
        $SUDO systemctl start speedtest

        echo -e "${GREEN}✓ Service installed and started${NC}"
        echo ""

        sleep 2
        $SUDO systemctl status speedtest --no-pager

        echo ""
        echo "Access at: http://your-domain:8080"
        ;;
    3)
        echo -e "${BLUE}Running full automated setup...${NC}"
        echo ""
        exec ./setup.sh
        ;;
    4)
        echo -e "${GREEN}✓ Build complete!${NC}"
        echo "Run the server with: ./speedtest-server"
        ;;
    *)
        echo -e "${RED}Invalid choice${NC}"
        exit 1
        ;;
esac

echo ""
