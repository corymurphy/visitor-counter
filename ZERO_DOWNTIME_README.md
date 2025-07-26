# Visitor Counter - Zero-Downtime Deployment

A modern, simple, and robust Continuous Deployment (CD) pipeline for your Go application on Google Compute Engine with zero-downtime deployments and Cloudflare domains.

## 🎯 Overview

This system provides:
- **Zero-Downtime Deployments**: Seamless updates with automatic rollback
- **Single Machine Architecture**: Cost-effective proof-of-concept setup
- **Environment Separation**: Development and production on separate domains
- **Cloudflare Integration**: Custom domains with SSL
- **Modern CI/CD**: GitHub Actions with Workload Identity Federation
- **No Ansible**: Simple, reliable deployment without complex configuration management

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   GitHub PR     │───▶│  GitHub Actions │───▶│  GCP Instance   │
│   (Labeled)     │    │                 │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                                       │
                                                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  Cloudflare     │◀───│   NGINX Proxy   │◀───│  Go Application │
│  DNS/SSL        │    │                 │    │  (Port 8080/1)  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

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
    ├── deploy.sh (zero-downtime deployment)
    ├── health-check.sh
    └── nginx/ (configs)
```

## 🚀 Quick Start

### 1. Set Up Infrastructure
```bash
# Run the setup script (one-time)
./scripts/setup-gcp-and-github.sh
```

This will:
- Create GCP infrastructure (VPC, firewall, compute instance)
- Set up Workload Identity for GitHub Actions
- Configure the server for zero-downtime deployments
- Display GitHub secrets to configure

### 2. Configure Cloudflare DNS
Point your domains to the instance IP:
- `visitor-counter.corymurphy.net` → Instance IP
- `visitor-counter.development.corymurphy.net` → Instance IP

### 3. Add GitHub Secrets
Add these secrets to your repository (Settings > Secrets and variables > Actions):
- `GCP_WORKLOAD_IDENTITY_PROVIDER`
- `GCP_SERVICE_ACCOUNT`
- `GCP_PROJECT_ID`
- `GCP_ZONE`
- `GCP_INSTANCE_NAME`

### 4. Test the Pipeline
1. Create a pull request
2. Add the `deploy development` label
3. Watch the deployment to `visitor-counter.development.corymurphy.net`

## 🔄 Deployment Process

### Zero-Downtime Strategy

1. **Backup Current Version**: Create backup of running binary
2. **Deploy New Version**: Copy new binary to environment directory
3. **Stop Service**: Gracefully stop the current service
4. **Start New Service**: Start service with new binary
5. **Health Check**: Verify new version is responding
6. **Rollback if Failed**: Automatically restore previous version

### Development Deployment
- **Trigger**: PR with `deploy development` label
- **URL**: `https://visitor-counter.development.corymurphy.net`
- **Port**: 8081
- **Version**: `dev-{PR_NUMBER}-{TIMESTAMP}`

### Production Deployment
- **Trigger**: Merge to main branch
- **URL**: `https://visitor-counter.corymurphy.net`
- **Port**: 8080
- **Version**: `v{RUN_NUMBER}`

## 📋 Configuration

### Environment Variables
| Variable | Default | Description |
|----------|---------|-------------|
| `PROJECT_ID` | `inbound-trilogy-449714-g7` | GCP Project ID |
| `REGION` | `us-central1` | GCP Region |
| `ZONE` | `us-central1-a` | GCP Zone |
| `INSTANCE_NAME` | `visitor-counter-app` | Compute instance name |
| `MACHINE_TYPE` | `e2-micro` | Instance machine type |
| `PROD_DOMAIN` | `visitor-counter.corymurphy.net` | Production domain |
| `DEV_DOMAIN` | `visitor-counter.development.corymurphy.net` | Development domain |

### Customization
Edit the setup scripts to modify:
- Instance configuration
- Domain names
- Port assignments
- Deployment strategies

## 🔧 Components

### 1. Server Setup (`scripts/setup-server.sh`)
- Installs NGINX, systemd, and required packages
- Creates environment-specific directories
- Configures systemd services for zero-downtime deployments
- Sets up NGINX reverse proxy with domain routing
- Creates health check and deployment scripts

### 2. GCP Infrastructure (`scripts/setup-gcp-and-github.sh`)
- Creates VPC network and firewall rules
- Sets up Workload Identity for GitHub Actions
- Creates compute instance with startup script
- Configures service accounts and IAM permissions

### 3. GitHub Actions (`.github/workflows/deploy.yml`)
- Builds Go application
- Authenticates to GCP using Workload Identity
- Deploys to development or production environment
- Verifies deployment with health checks
- Creates GitHub releases for production deployments

### 4. Deployment Script (`/opt/visitor-counter/shared/deploy.sh`)
- Implements zero-downtime deployment strategy
- Creates backups before deployment
- Performs health checks after deployment
- Automatically rolls back on failure
- Manages service lifecycle

## 🛡️ Security Features

- **Workload Identity Federation**: No static credentials
- **Service Account**: Minimal required permissions
- **Firewall Rules**: Restrictive network access
- **UFW**: Additional host-level firewall
- **Fail2ban**: Intrusion prevention
- **HTTPS**: Cloudflare SSL/TLS

## 📊 Monitoring

### Health Checks
- Application health endpoint: `/health`
- Systemd service monitoring
- NGINX proxy health verification
- Automatic rollback on failure

### Logs
- Application logs: `/var/log/visitor-counter/{env}/app.log`
- Error logs: `/var/log/visitor-counter/{env}/error.log`
- Deployment logs: `/var/log/visitor-counter/{env}/deploy.log`
- NGINX logs: `/var/log/nginx/`

### Commands
```bash
# Check service status
systemctl status visitor-counter-production
systemctl status visitor-counter-development

# View application logs
tail -f /var/log/visitor-counter/production/app.log

# Check health
curl https://visitor-counter.corymurphy.net/health
curl https://visitor-counter.development.corymurphy.net/health

# View deployment logs
tail -f /var/log/visitor-counter/production/deploy.log
```

## 🔄 Workflow

### Development Workflow
1. Create feature branch
2. Make changes
3. Create pull request
4. Add `deploy development` label
5. GitHub Actions deploys to development environment
6. Test at `visitor-counter.development.corymurphy.net`
7. Merge to main for production deployment

### Production Workflow
1. Merge PR to main branch
2. GitHub Actions automatically deploys to production
3. Creates GitHub release with version tag
4. Application available at `visitor-counter.corymurphy.net`

## 🚨 Troubleshooting

### Common Issues

#### Deployment Fails
```bash
# Check deployment logs
tail -f /var/log/visitor-counter/production/deploy.log

# Check service status
systemctl status visitor-counter-production

# Manual rollback
sudo /opt/visitor-counter/shared/deploy.sh production v1.0.0 /path/to/backup
```

#### Application Not Responding
```bash
# Check if service is running
systemctl is-active visitor-counter-production

# Check if port is listening
netstat -tlnp | grep :8080

# Check application logs
journalctl -u visitor-counter-production -f
```

#### NGINX Issues
```bash
# Check NGINX status
systemctl status nginx

# Test NGINX configuration
nginx -t

# Check NGINX logs
tail -f /var/log/nginx/visitor-counter-production_error.log
```

### Debug Commands
```bash
# SSH into instance
gcloud compute ssh visitor-counter-app --zone=us-central1-a

# Check instance status
gcloud compute instances list

# View startup script logs
gcloud compute instances get-serial-port-output visitor-counter-app --zone=us-central1-a
```

## 💰 Cost Optimization

- **Single e2-micro instance**: Free tier eligible
- **Minimal storage**: 10GB boot disk
- **Efficient resource usage**: Both environments on one machine
- **No additional services**: Uses only Compute Engine

## 🔮 Future Enhancements

1. **Load Balancing**: Multiple instances for high availability
2. **Database Integration**: Persistent storage for visitor counts
3. **Monitoring**: Prometheus/Grafana integration
4. **Blue-Green Deployments**: More sophisticated zero-downtime strategy
5. **Auto-scaling**: Based on traffic patterns
6. **Multi-region**: Geographic distribution

## 📚 Resources

- [Google Cloud Compute Engine](https://cloud.google.com/compute)
- [GitHub Actions](https://docs.github.com/en/actions)
- [Workload Identity Federation](https://cloud.google.com/iam/docs/workload-identity-federation)
- [Cloudflare DNS](https://developers.cloudflare.com/dns/)
- [NGINX Documentation](https://nginx.org/en/docs/)

## 🆘 Support

For issues and questions:
1. Check the troubleshooting section above
2. Review GitHub Actions logs
3. Check GCP Cloud Logging
4. Open an issue on GitHub

---

**This system provides a modern, simple, and reliable deployment pipeline perfect for proof-of-concept projects and small to medium applications.** 