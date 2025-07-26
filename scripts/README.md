# Deployment Scripts

This directory contains the deployment scripts for the visitor-counter application.

## Files

- `deploy.sh` - Main deployment script that handles zero-downtime deployments
- `environments.conf` - Configuration file defining environments and their settings
- `setup-server.sh` - Initial server setup script (run once)

## Adding New Environments

To add a new environment (e.g., staging), follow these steps:

### 1. Update `environments.conf`

Add a new section to the configuration file:

```ini
[staging]
port=8082
domain=visitor-counter.staging.corymurphy.net
description=Staging environment
```

### 2. Update DNS

Point the new domain to your server IP address in Cloudflare or your DNS provider.

### 3. Deploy

The deployment script will automatically:
- Create the nginx configuration for the new environment
- Create a systemd service for the new environment
- Deploy the application to the new environment

### Example Usage

```bash
# Deploy to staging
sudo /opt/visitor-counter/shared/deploy.sh staging v1.0.0 /tmp/visitor-counter-v1.0.0
```

## Environment Configuration

Each environment can have the following settings:

- `port` - The port the application will run on
- `domain` - The domain name for the environment
- `description` - Human-readable description (optional)

## Supported Environments

Currently supported:
- `production` - Production environment (port 8080)
- `development` - Development environment (port 8081)

## Deployment Process

The deployment script performs the following steps:

1. **Validation** - Validates the environment and inputs
2. **Backup** - Creates a backup of the current binary
3. **Stop Service** - Stops the current service
4. **Update Binary** - Copies the new binary to the application directory
5. **Configure Nginx** - Creates/updates nginx configuration for the environment
6. **Create Systemd Service** - Creates/updates the systemd service
7. **Start Service** - Starts the service with the new binary
8. **Health Check** - Verifies the deployment was successful
9. **Rollback** - If health check fails, rolls back to the previous version

## Logs

Deployment logs are written to:
- `/var/log/visitor-counter/{environment}/deploy.log`

Application logs are available via:
- `journalctl -u visitor-counter-{environment}` 