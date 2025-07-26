# Visitor Counter

A simple Go web application that tracks visitor counts with a beautiful UI. This project includes a complete CI/CD pipeline for deployment to Google Cloud Platform using GitHub Actions.

> **Note**: This project now uses a modern zero-downtime deployment system with GitHub Actions and Google Cloud Platform. See [ZERO_DOWNTIME_README.md](ZERO_DOWNTIME_README.md) for detailed information about the new deployment architecture.

## Features

- **Visitor Counter**: Tracks and displays visitor counts with timestamps
- **Beautiful UI**: Modern, responsive design with gradient backgrounds
- **Health Endpoint**: `/health` endpoint for monitoring
- **API Endpoints**: RESTful API for visit tracking and count retrieval
- **CI/CD Pipeline**: Automated testing, building, and deployment
- **Multi-Environment**: Development and production deployments
- **GCP Integration**: Deployed on Google Cloud Platform using free tier

## Architecture

- **Frontend**: HTML/CSS/JavaScript with modern UI
- **Backend**: Go HTTP server with in-memory storage
- **Infrastructure**: GCP Compute Engine (single e2-micro instance)
- **CI/CD**: GitHub Actions with Workload Identity Federation
- **Deployment**: Zero-downtime deployments with automatic rollback
- **Domains**: Cloudflare-managed domains for environment separation
- **Monitoring**: Built-in health checks, log rotation, and cost monitoring

## Quick Start

### Prerequisites

1. **Google Cloud Platform Account**
   - Enable billing (required for Compute Engine)
   - Install [gcloud CLI](https://cloud.google.com/sdk/docs/install)

2. **GitHub Repository**
   - Fork or clone this repository
   - Enable GitHub Actions

3. **Local Development Tools**
   - Go 1.24 or later
   - Google Cloud SDK (gcloud)

### Setup Instructions

1. **Clone the repository**
   ```bash
   git clone https://github.com/your-username/visitor-counter.git
   cd visitor-counter
   ```

2. **Configure GCP**
   ```bash
   gcloud auth login
   gcloud config set project YOUR_PROJECT_ID
   ```

3. **Set Up Zero-Downtime Deployment**
   ```bash
   ./scripts/setup-gcp-and-github.sh
   ```
   This script will:
   - Create GCP infrastructure (VPC, firewall, compute instance)
   - Set up Workload Identity for GitHub Actions
   - Configure the server for zero-downtime deployments
   - Display required GitHub secrets

4. **Configure GitHub Secrets**
   Add the following secrets to your GitHub repository (Settings > Secrets and variables > Actions):
   - `GCP_WORKLOAD_IDENTITY_PROVIDER`: Output from setup script
   - `GCP_SERVICE_ACCOUNT`: Output from setup script
   - `INSTANCE_IP`: Instance IP address
   
   **Note**: No SSH keys needed! The deployment uses Workload Identity Federation for secure authentication and zero-downtime deployments.

5. **Create GitHub Environments**
   - Go to Settings > Environments
   - Create `development` environment
   - Create `production` environment

6. **Configure Cloudflare DNS**
   - Point `visitor-counter.corymurphy.net` to the instance IP
   - Point `visitor-counter.development.corymurphy.net` to the instance IP

7. **Test the Pipeline**
   - Create a pull request
   - Add the `deploy development` label
   - The application will be deployed to `visitor-counter.development.corymurphy.net`

## Local Development

### Run Locally
```bash
go run main.go
```
The application will be available at `http://localhost:8080`

### Build
```bash
make build
```

### Test
```bash
make test
```

### Lint
```bash
make lint
```

## API Endpoints

- `GET /` - Main page with visitor counter
- `POST /api/visit` - Increment visitor count
- `GET /api/count` - Get current visitor count
- `GET /health` - Health check endpoint

## CI/CD Pipeline

### Workflows

1. **CI Workflow** (`.github/workflows/ci.yml`)
   - Triggers on pull requests and pushes to main
   - Runs tests, linting, and security scans
   - Builds application and uploads artifacts
   - Uploads coverage reports

2. **Infrastructure Management** (`.github/workflows/infrastructure.yml`)
   - Manages Terraform infrastructure deployment
   - Handles initial server setup with Ansible
   - Can be triggered manually or on Terraform changes

3. **Development Deploy Workflow** (`.github/workflows/development-deploy.yml`)
   - Creates pre-releases for pull requests
   - Deploys to development environment when labeled
   - Uses Ansible for zero-downtime deployment

4. **Production Deploy Workflow** (`.github/workflows/production-deploy.yml`)
   - Triggers on merge to main
   - Creates production releases
   - Uses Ansible for zero-downtime deployment

### Deployment Process

The deployment uses zero-downtime strategy with automatic rollback:

1. **Development Deployment**
   - Triggered by PR with `deploy development` label
   - Deploys to `visitor-counter.development.corymurphy.net`
   - Uses port 8081 for development environment
   - Version format: `dev-{PR_NUMBER}-{TIMESTAMP}`

2. **Production Deployment**
   - Triggered by merge to main branch
   - Deploys to `visitor-counter.corymurphy.net`
   - Uses port 8080 for production environment
   - Version format: `v{RUN_NUMBER}`

3. **Zero-Downtime Strategy**
   - Creates backup of current version
   - Deploys new version to environment directory
   - Stops old service and starts new service
   - Performs health checks and rolls back if needed
   - Automatic rollback on deployment failure

## Infrastructure

### GCP Resources

- **Compute Engine Instance**: e2-micro (free tier eligible)
  - Single instance: `visitor-counter-app`
  - Production environment: Application on port 8080, nginx on port 80
  - Development environment: Application on port 8081, nginx on port 80
  - Both environments served via NGINX reverse proxy with domain-based routing

- **Networking**
  - VPC: `visitor-counter-vpc`
  - Subnet: `visitor-counter-subnet`
  - Firewall rules for HTTP, HTTPS, and SSH
  - UFW firewall configured for additional security

- **IAM**
  - Service account for deployments
  - Workload Identity for GitHub Actions

### Cost Optimization

- Uses single e2-micro instance (free tier eligible)
- Separate environments on different ports
- Minimal storage requirements
- Cost monitoring script included
- Image-based deployment reduces runtime costs

Monitor costs:
```bash
./scripts/monitor-costs.sh
```

## Security

- **Workload Identity Federation**: No static credentials stored
- **Service Account**: Minimal required permissions
- **Zero-Downtime Security**: Automatic rollback on deployment failures
- **Firewall Rules**: Restrictive network access
- **HTTPS**: Cloudflare SSL/TLS encryption

## Monitoring

### Health Checks
- Application health endpoint: `/health`
- Systemd service monitoring
- Zero-downtime deployment validation
- Nginx proxy health verification
- Multi-level health checks (process, port, HTTP, proxy)

### Logs
- Application logs: `journalctl -u visitor-counter.service`
- Nginx logs: `/var/log/nginx/visitor-counter_*.log`
- System logs: `journalctl -xe`
- Log rotation configured for all application logs



## Troubleshooting

### Common Issues

1. **Deployment Fails**
   - Check GitHub Actions logs
   - Verify SSH key configuration
   - Ensure instances are running

2. **Application Not Accessible**
   - Check firewall rules
   - Verify service is running: `systemctl status visitor-counter.service`
   - Check application logs

3. **Authentication Issues**
   - Verify Workload Identity configuration
   - Check service account permissions
   - Ensure GitHub secrets are correct

### Debug Commands

```bash
# Check instance status
gcloud compute instances list

# SSH into instance
gcloud compute ssh visitor-counter-app --zone=us-central1-a

# Check service status
systemctl status visitor-counter-production
systemctl status visitor-counter-development

# View application logs
tail -f /var/log/visitor-counter/production/app.log
tail -f /var/log/visitor-counter/development/app.log

# Test health endpoint
curl https://visitor-counter.corymurphy.net/health
curl https://visitor-counter.development.corymurphy.net/health

# View deployment logs
tail -f /var/log/visitor-counter/production/deploy.log
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Create a pull request
6. Add `deploy development` label to test deployment

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

For issues and questions:
1. Check the troubleshooting section
2. Review GitHub Actions logs
3. Open an issue on GitHub

## Roadmap

- [ ] Add persistent storage (database)
- [ ] Implement user authentication
- [ ] Add metrics and analytics
- [ ] Set up monitoring and alerting
- [ ] Implement blue-green deployments
- [ ] Multi-region deployment
- [ ] Load balancing for high availability
- [ ] Automated vulnerability scanning
