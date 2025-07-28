# Visitor Counter

A simple Go web application that tracks visitor counts with a modern web interface. Deployed to Google Cloud Platform using GitHub Actions. See [DEPLOYMENT_README.md](DEPLOYMENT_README.md) for detailed information about the deployment architecture.

## What This App Does

The Visitor Counter is a lightweight web application that:

- **Tracks Visitors**: Counts and displays the number of visitors to the website
- **Provides API**: RESTful endpoints for incrementing and retrieving visitor counts
- **Health Monitoring**: Includes a `/health` endpoint for monitoring
- **Modern UI**: Clean, responsive web interface built with HTML/CSS/JavaScript

### API Endpoints
- `GET /` - Main page with visitor counter
- `POST /api/visit` - Increment visitor count
- `GET /api/count` - Get current visitor count
- `GET /health` - Health check endpoint

### Local Development
```bash
go run main.go  # Runs on http://localhost:8080
make build      # Build binary
make test       # Run tests
```

## Infrastructure Provisioning

The infrastructure is provisioned using Terraform and managed through GitHub Actions:

### GCP Resources
- **Compute Engine**: Single e2-micro instance (free tier eligible)
- **Networking**: Custom VPC with firewall rules for HTTP, HTTPS, and SSH
- **IAM**: Service account with minimal permissions for deployments
- **Workload Identity**: Secure authentication for GitHub Actions

### Infrastructure Setup
The infrastructure is created using:
- **Terraform** (`terraform/` directory): Defines VPC, firewall, compute instance
- **Setup Scripts** (`scripts/` directory): Server configuration and deployment scripts
- **GitHub Actions**: Automated infrastructure deployment workflow

### Architecture
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

## Deployment Pipeline

The deployment pipeline uses GitHub Actions for automated deployments:

### Development Deployment
- **Trigger**: Pull request with `deploy development` label
- **Environment**: `visitor-counter.development.corymurphy.net`
- **Process**: 
  1. Build Go application
  2. Deploy to development environment (port 8081)
  3. Run health checks
  4. Comment on PR with deployment URL

### Production Deployment
- **Trigger**: Merge to main branch
- **Environment**: `visitor-counter.corymurphy.net`
- **Process**:
  1. Build Go application
  2. Deploy to production environment (port 8080)
  3. Create GitHub release
  4. Run health checks

### Deployment Strategy
1. **Backup** current version
2. **Deploy** new version to environment directory
3. **Stop** old service and **start** new service
4. **Health check** new version
5. **Rollback** automatically if health check fails

### Key Features
- **Automatic Rollback**: Failed deployments automatically restore previous version
- **Health Monitoring**: Built-in health checks ensure application availability
- **Environment Separation**: Development and production on separate domains
- **Cost Optimized**: Uses single e2-micro instance for both environments

## Quick Setup

1. **Fork/Clone** this repository
2. **Configure** GitHub secrets for GCP authentication
3. **Run** infrastructure setup script: `./scripts/setup-gcp-and-github.sh`
4. **Point** Cloudflare DNS to the instance IP
5. **Create** a pull request with `deploy development` label to test

## Monitoring & Troubleshooting

### Health Checks
```bash
curl https://visitor-counter.corymurphy.net/health
curl https://visitor-counter.development.corymurphy.net/health
```

### Service Status
```bash
gcloud compute ssh visitor-counter-app --zone=us-central1-a
systemctl status visitor-counter-production
systemctl status visitor-counter-development
```

### Logs
```bash
tail -f /var/log/visitor-counter/production/app.log
tail -f /var/log/visitor-counter/development/app.log
```

## Future Enhancements

- Cloudflare Mutual TLS
- GCP Load Blanancer and Autoscaling
- Automated Credential Rotation

