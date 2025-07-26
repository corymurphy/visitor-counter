.PHONY: help build test run clean deploy-infra destroy-infra monitor-costs setup-oidc

# Default target
help:
	@echo "Available commands:"
	@echo "  build         - Build the Go application"
	@echo "  test          - Run tests"
	@echo "  run           - Run the application locally"
	@echo "  clean         - Clean build artifacts"
	@echo "  deploy-infra  - Deploy infrastructure with Terraform"
	@echo "  destroy-infra - Destroy infrastructure with Terraform"
	@echo "  monitor-costs - Monitor GCP usage and costs"
	@echo "  setup-oidc    - Set up OpenID Connect authentication"

# Build the application
build:
	go build -o bin/visitor-counter .

# Run tests
test:
	go test -v ./...

# Run the application locally
run:
	go run main.go

# Clean build artifacts
clean:
	rm -rf bin/
	go clean

# Deploy infrastructure
deploy-infra:
	cd terraform && \
	terraform init && \
	terraform plan && \
	terraform apply -auto-approve

# Destroy infrastructure
destroy-infra:
	cd terraform && \
	terraform destroy -auto-approve

# Monitor costs and usage
monitor-costs:
	./scripts/monitor-costs.sh

# Set up OpenID Connect authentication
setup-oidc:
	./scripts/setup-oidc.sh

# Install dependencies
deps:
	go mod download
	go mod tidy

# Format code
fmt:
	go fmt ./...

# Lint code
lint:
	golangci-lint run

# Run with race detection
test-race:
	go test -race ./...

# Generate coverage report
test-coverage:
	go test -coverprofile=coverage.out ./...
	go tool cover -html=coverage.out -o coverage.html
	@echo "Coverage report generated: coverage.html" 

# 	ansible-playbook \
# 		-i ansible/inventory-prod.yml \
# 		ansible/setup.yml \
# 		-e "environment=production"

ansible-ping:
# 	ansible development -m ping -i ansible/inventory.yml
	ANSIBLE_CONFIG=./ansible ansible development -m ping --playbook-dir ./ansible

terraform-plan:
	terraform -chdir=terraform plan

terraform-apply:
	terraform -chdir=terraform apply -auto-approve

ansible-inventory:
	ansible-inventory --list -i gcp.yaml

check-dependencies:
	ansible-galaxy collection install google.cloud
	python3 -m pip show google-auth

