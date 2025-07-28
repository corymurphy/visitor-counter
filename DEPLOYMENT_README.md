# Deployment Details

This document provides detailed information about the deployment strategy used in the Visitor Counter application.

## Deployment Architecture

### Single Machine Layout
```
/opt/visitor-counter/
├── production/
│   ├── visitor-counter (binary)
│   ├── backups/
│   └── logs/
├── development/
│   ├── visitor-counter (binary)
│   ├── backups/
│   └── logs/
└── shared/
    ├── deploy.sh (deployment script)
    ├── health-check.sh
    └── nginx/ (configs)
```

### Deployment Strategy

1. **Backup Current Version**: Create backup of running binary
2. **Deploy New Version**: Copy new binary to environment directory
3. **Stop Service**: Stop the current service
4. **Start New Service**: Start service with new binary
5. **Health Check**: Verify new version is responding
6. **Rollback if Failed**: Automatically restore previous version

## Deployment Script Details

The deployment script (`/opt/visitor-counter/shared/deploy.sh`) implements:

- **Environment Management**: Separate directories for production/development
- **Service Lifecycle**: systemd service management
- **Health Verification**: Multiple health check levels
- **Automatic Rollback**: Restore previous version on failure
- **Logging**: Comprehensive deployment logging

## Environment Configuration

### Development Environment
- **Port**: 8081
- **Domain**: `visitor-counter.development.corymurphy.net`
- **Service**: `visitor-counter-development`
- **Version Format**: `dev-{PR_NUMBER}-{TIMESTAMP}`

### Production Environment
- **Port**: 8080
- **Domain**: `visitor-counter.corymurphy.net`
- **Service**: `visitor-counter-production`
- **Version Format**: `v{RUN_NUMBER}`

## NGINX Configuration

NGINX acts as a reverse proxy with domain-based routing:

```nginx
# Production
server {
    listen 80;
    server_name visitor-counter.corymurphy.net;
    location / {
        proxy_pass http://localhost:8080;
    }
}

# Development
server {
    listen 80;
    server_name visitor-counter.development.corymurphy.net;
    location / {
        proxy_pass http://localhost:8081;
    }
}
```

## Health Check Implementation

The deployment includes multiple health check levels:

1. **Process Check**: Verify service is running
2. **Port Check**: Confirm application is listening
3. **HTTP Check**: Test `/health` endpoint
4. **Proxy Check**: Verify NGINX routing

## Troubleshooting Deployment Issues

### Common Problems

**Deployment Fails**
```bash
# Check deployment logs
tail -f /var/log/visitor-counter/production/deploy.log

# Manual rollback
sudo /opt/visitor-counter/shared/deploy.sh production v1.0.0 /path/to/backup
```

**Application Not Responding**
```bash
# Check service status
systemctl is-active visitor-counter-production

# Check if port is listening
netstat -tlnp | grep :8080

# Check application logs
journalctl -u visitor-counter-production -f
```

**NGINX Issues**
```bash
# Check NGINX status
systemctl status nginx

# Test NGINX configuration
nginx -t

# Check NGINX logs
tail -f /var/log/nginx/visitor-counter-production_error.log
```

## Security Features

- **Workload Identity Federation**: No static credentials
- **Service Account**: Minimal required permissions
- **Firewall Rules**: Restrictive network access
- **UFW**: Additional host-level firewall
- **HTTPS**: Cloudflare SSL/TLS

## Cost Optimization

- **Single e2-micro instance**: Free tier eligible
- **Minimal storage**: 10GB boot disk
- **Efficient resource usage**: Both environments on one machine
- **No additional services**: Uses only Compute Engine 