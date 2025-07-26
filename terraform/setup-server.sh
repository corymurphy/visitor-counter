#!/bin/bash

# Setup script for zero-downtime visitor counter deployment
# This script configures a single machine to handle both development and production environments

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="visitor-counter"
PROD_DOMAIN="visitor-counter.corymurphy.net"
DEV_DOMAIN="visitor-counter.development.corymurphy.net"
PROD_PORT="8080"
DEV_PORT="8081"
NGINX_PORT="80"

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

print_step "Starting server setup for zero-downtime deployments..."

# Update system
print_status "Updating system packages..."
apt-get update
apt-get upgrade -y

# Install required packages
print_status "Installing required packages..."
apt-get install -y \
    nginx \
    curl \
    wget \
    unzip \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    net-tools \
    ufw \
    fail2ban \
    supervisor

# Configure firewall
print_status "Configuring firewall..."
ufw --force enable
ufw default deny incoming
ufw allow 22/tcp    # SSH
ufw allow 80/tcp    # HTTP
ufw allow 443/tcp   # HTTPS
ufw allow 8080/tcp  # Production app
ufw allow 8081/tcp  # Development app

# Create application directories
print_status "Creating application directories..."
mkdir -p /opt/${APP_NAME}/{production,development,shared/{nginx,systemd,logs}}
mkdir -p /var/log/${APP_NAME}/{production,development}
chmod 755 /opt/${APP_NAME}/{production,development}
chmod 755 /var/log/${APP_NAME}/{production,development}


cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
systemctl enable fail2ban
systemctl start fail2ban

echo 'APT::Periodic::Update-Package-Lists "1";' > /etc/apt/apt.conf.d/20auto-upgrades
echo 'APT::Periodic::Unattended-Upgrade "1";' >> /etc/apt/apt.conf.d/20auto-upgrades
systemctl enable unattended-upgrades
systemctl start unattended-upgrades

# Note: Systemd services will be created dynamically by the deploy script
print_status "Systemd services will be created during deployment for each environment."

# Create health check script
print_status "Creating health check script..."
cat > /opt/${APP_NAME}/shared/health-check.sh << 'EOF'
#!/bin/bash

ENVIRONMENT=$1
APP_NAME="visitor-counter"

case $ENVIRONMENT in
    "production")
        PORT="8080"
        ;;
    "development")
        PORT="8081"
        ;;
    *)
        echo "Invalid environment: $ENVIRONMENT"
        exit 1
        ;;
esac

# Function to check if the application is responding
check_health() {
    local retries=0
    local max_retries=3
    local retry_delay=2
    
    while [ $retries -lt $max_retries ]; do
        if curl -f -s "http://localhost:${PORT}/health" > /dev/null 2>&1; then
            echo "Health check passed for ${APP_NAME} ${ENVIRONMENT} on port ${PORT}"
            return 0
        else
            echo "Health check failed for ${APP_NAME} ${ENVIRONMENT} on port ${PORT} (attempt $((retries + 1))/${max_retries})"
            retries=$((retries + 1))
            if [ $retries -lt $max_retries ]; then
                sleep $retry_delay
            fi
        fi
    done
    
    echo "Health check failed after ${max_retries} attempts"
    return 1
}

# Check if the process is running
if ! pgrep -f "${APP_NAME}" > /dev/null; then
    echo "Application ${APP_NAME} ${ENVIRONMENT} is not running"
    exit 1
fi

# Check if the port is listening
if ! netstat -tlnp 2>/dev/null | grep -q ":${PORT} "; then
    echo "Application ${APP_NAME} ${ENVIRONMENT} is not listening on port ${PORT}"
    exit 1
fi

# Perform health check
check_health
EOF

chmod +x /opt/${APP_NAME}/shared/health-check.sh

# Create deployment script
print_status "Creating deployment script..."
cat > /opt/${APP_NAME}/shared/deploy.sh << 'EOF'
#!/bin/bash

# Zero-downtime deployment script for visitor counter

set -e

ENVIRONMENT=$1
VERSION=$2
BINARY_PATH=$3

APP_NAME="visitor-counter"
SERVICE_NAME="${APP_NAME}-${ENVIRONMENT}"
APP_DIR="/opt/${APP_NAME}/${ENVIRONMENT}"
BACKUP_DIR="${APP_DIR}/backups"
LOG_FILE="/var/log/${APP_NAME}/${ENVIRONMENT}/deploy.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

# Validate inputs
if [[ -z "$ENVIRONMENT" || -z "$VERSION" || -z "$BINARY_PATH" ]]; then
    print_error "Usage: $0 <environment> <version> <binary_path>"
    print_error "Example: $0 production v1.0.0 /tmp/visitor-counter"
    exit 1
fi

if [[ "$ENVIRONMENT" != "production" && "$ENVIRONMENT" != "development" ]]; then
    print_error "Environment must be 'production' or 'development'"
    exit 1
fi

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

print_status "Starting deployment for ${ENVIRONMENT} environment, version ${VERSION}"

# Check if service is currently running
if systemctl is-active --quiet "$SERVICE_NAME"; then
    print_status "Service $SERVICE_NAME is currently running"
    SERVICE_RUNNING=true
else
    print_status "Service $SERVICE_NAME is not running"
    SERVICE_RUNNING=false
fi

# Create backup of current binary
if [[ -f "${APP_DIR}/${APP_NAME}" ]]; then
    BACKUP_FILE="${BACKUP_DIR}/${APP_NAME}.backup.$(date +%Y%m%d_%H%M%S)"
    print_status "Creating backup: $BACKUP_FILE"
    cp "${APP_DIR}/${APP_NAME}" "$BACKUP_FILE"
fi

# Stop the service
if [[ "$SERVICE_RUNNING" == "true" ]]; then
    print_status "Stopping service $SERVICE_NAME"
    systemctl stop "$SERVICE_NAME"
    sleep 2
fi

# Copy new binary
print_status "Copying new binary to $APP_DIR"
cp "$BINARY_PATH" "${APP_DIR}/${APP_NAME}"
chmod +x "${APP_DIR}/${APP_NAME}"

# Start the service
print_status "Starting service $SERVICE_NAME"
systemctl start "$SERVICE_NAME"

# Wait for service to be ready
print_status "Waiting for service to be ready..."
sleep 5

# Perform health check
print_status "Performing health check..."
if /opt/${APP_NAME}/shared/health-check.sh "$ENVIRONMENT"; then
    print_status "Health check passed - deployment successful!"
    
    # Clean up old backups (keep last 5)
    cd "$BACKUP_DIR"
    ls -t | tail -n +6 | xargs -r rm -f
    
    print_status "Deployment completed successfully for ${ENVIRONMENT} environment, version ${VERSION}"
    exit 0
else
    print_error "Health check failed - rolling back deployment"
    
    # Rollback
    if [[ -f "$BACKUP_FILE" ]]; then
        print_status "Rolling back to previous version"
        systemctl stop "$SERVICE_NAME"
        cp "$BACKUP_FILE" "${APP_DIR}/${APP_NAME}"
        chmod +x "${APP_DIR}/${APP_NAME}"
        systemctl start "$SERVICE_NAME"
        
        if /opt/${APP_NAME}/shared/health-check.sh "$ENVIRONMENT"; then
            print_status "Rollback successful"
        else
            print_error "Rollback failed - manual intervention required"
        fi
    fi
    
    exit 1
fi
EOF

chmod +x /opt/${APP_NAME}/shared/deploy.sh

# Configure NGINX
print_status "Configuring NGINX..."

# Main NGINX configuration
cat > /etc/nginx/nginx.conf << EOF
user www-data;
worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

events {
    worker_connections 768;
}

http {
    sendfile on;
    tcp_nopush on;
    types_hash_max_size 2048;
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # Logging
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    # Gzip
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;

    # Include site configurations
    include /etc/nginx/sites-enabled/*;
}
EOF

# Remove default site
rm -f /etc/nginx/sites-enabled/default

# Note: Environment-specific nginx configurations will be created by the deploy script
print_status "Nginx base configuration completed. Environment-specific configs will be created during deployment."

# Configure logrotate
print_status "Configuring log rotation..."
cat > /etc/logrotate.d/${APP_NAME} << EOF
/var/log/${APP_NAME}/*/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 644 root root
    postrotate
        systemctl reload nginx
    endscript
}
EOF

# Start and enable services
print_status "Starting and enabling services..."
systemctl daemon-reload
systemctl enable nginx
systemctl start nginx

# Create initial placeholder binaries (will be replaced by deployments)
print_status "Creating placeholder binaries..."
touch /opt/${APP_NAME}/production/${APP_NAME}
touch /opt/${APP_NAME}/development/${APP_NAME}
chmod +x /opt/${APP_NAME}/production/${APP_NAME}
chmod +x /opt/${APP_NAME}/development/${APP_NAME}

print_status "Server setup completed successfully!"
print_status ""
print_status "Configuration Summary:"
print_status "  - Production: ${PROD_DOMAIN} -> localhost:${PROD_PORT}"
print_status "  - Development: ${DEV_DOMAIN} -> localhost:${DEV_PORT}"
print_status "  - App directories: /opt/${APP_NAME}/{production,development}"
print_status "  - Logs: /var/log/${APP_NAME}/{production,development}"
print_status "  - Services: ${APP_NAME}-production, ${APP_NAME}-development"
print_status ""
print_status "Next steps:"
print_status "  1. Configure Cloudflare DNS to point to this server's IP"
print_status "  2. Set up GitHub Actions workflow for deployments"
print_status "  3. Deploy your first application version" 