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

# Load environment configuration
load_environment_config() {
    local env="$1"
    local config_file="/opt/${APP_NAME}/shared/environments.conf"
    
    # If config file doesn't exist, use defaults
    if [[ ! -f "$config_file" ]]; then
        case "$env" in
            "production")
                PORT="8080"
                DOMAIN="visitor-counter-corymurphy.net"
                ;;
            "development")
                PORT="8081"
                DOMAIN="visitor-counter-development.corymurphy.net"
                ;;
            *)
                echo "Error: Unknown environment '$env'"
                echo "Supported environments: production, development"
                exit 1
                ;;
        esac
        return
    fi
    
    # Read configuration from file
    local in_section=false
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$line" ]] && continue
        
        # Check if we're entering the right section
        if [[ "$line" =~ ^\[${env}\]$ ]]; then
            in_section=true
            continue
        fi
        
        # If we're in the right section, parse the config
        if [[ "$in_section" == "true" ]]; then
            # Check if we've reached the next section
            if [[ "$line" =~ ^\[.*\]$ ]]; then
                break
            fi
            
            # Parse key=value pairs
            if [[ "$line" =~ ^([^=]+)=(.*)$ ]]; then
                local key="${BASH_REMATCH[1]}"
                local value="${BASH_REMATCH[2]}"
                
                case "$key" in
                    "port")
                        PORT="$value"
                        ;;
                    "domain")
                        DOMAIN="$value"
                        ;;
                esac
            fi
        fi
    done < "$config_file"
    
    # Validate that we found the environment
    if [[ -z "$PORT" || -z "$DOMAIN" ]]; then
        echo "Error: Could not find configuration for environment '$env'"
        exit 1
    fi
}

# Load configuration for the specified environment
load_environment_config "$ENVIRONMENT"

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

# Create directories if they don't exist
mkdir -p "$APP_DIR"
mkdir -p "$BACKUP_DIR"
mkdir -p "$(dirname "$LOG_FILE")"

print_status "Starting deployment for ${ENVIRONMENT} environment, version ${VERSION}"

# Configure nginx for this environment
configure_nginx() {
    print_status "Configuring nginx for ${ENVIRONMENT} environment..."
    
    # Create nginx site configuration
    cat > "/etc/nginx/sites-available/${APP_NAME}-${ENVIRONMENT}" << EOF
server {
    listen              443 ssl;
    server_name         ${DOMAIN};
    ssl_certificate     /etc/ssl/private/cloudflare.crt;
    ssl_certificate_key /etc/ssl/private/cloudflare.key;
    ssl_protocols       TLSv1.2 TLSv1.3;
    ssl_ciphers         HIGH:!aNULL:!MD5;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;

    # Logging
    access_log /var/log/nginx/${APP_NAME}-${ENVIRONMENT}_access.log;
    error_log /var/log/nginx/${APP_NAME}-${ENVIRONMENT}_error.log;

    # Health check endpoint
    location /health {
        proxy_pass http://127.0.0.1:${PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        proxy_connect_timeout 5s;
        proxy_send_timeout 5s;
        proxy_read_timeout 5s;
    }

    # Main application
    location / {
        proxy_pass http://127.0.0.1:${PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        proxy_buffering on;
        proxy_buffer_size 4k;
        proxy_buffers 8 4k;
        
        proxy_http_version 1.1;
        proxy_set_header Connection "";
    }
}
EOF

    # Enable the site
    ln -sf "/etc/nginx/sites-available/${APP_NAME}-${ENVIRONMENT}" "/etc/nginx/sites-enabled/"
    
    # Test nginx configuration
    if nginx -t; then
        print_status "Nginx configuration test passed"
        systemctl reload nginx
        print_status "Nginx configuration reloaded"
    else
        print_error "Nginx configuration test failed"
        exit 1
    fi
}

# Create systemd service for this environment
create_systemd_service() {
    print_status "Creating systemd service for ${ENVIRONMENT} environment..."
    
    cat > "/etc/systemd/system/${SERVICE_NAME}.service" << EOF
[Unit]
Description=Visitor Counter ${ENVIRONMENT} Service
After=network.target

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=${APP_DIR}
ExecStart=${APP_DIR}/${APP_NAME}
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=${SERVICE_NAME}

# Environment variables
Environment=PORT=${PORT}

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    print_status "Systemd service created and daemon reloaded"
}

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

# Configure nginx and create systemd service
configure_nginx
create_systemd_service

# Start the service
print_status "Starting service $SERVICE_NAME"
systemctl enable "$SERVICE_NAME"
systemctl start "$SERVICE_NAME"

# Wait for service to be ready
print_status "Waiting for service to be ready..."
sleep 5

# Perform health check
print_status "Performing health check..."
if curl -f -s "http://localhost:${PORT}/health" > /dev/null; then
    print_status "Health check passed - deployment successful!"
    
    # Clean up old backups (keep last 5)
    cd "$BACKUP_DIR"
    ls -t | tail -n +6 | xargs -r rm -f
    
    print_status "Deployment completed successfully for ${ENVIRONMENT} environment, version ${VERSION}"
    print_status "Service URL: http://localhost:${PORT}"
    print_status "Domain: ${DOMAIN}"
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
        
        if curl -f -s "http://localhost:${PORT}/health" > /dev/null; then
            print_status "Rollback successful"
        else
            print_error "Rollback failed - manual intervention required"
        fi
    fi
    
    exit 1
fi 