.PHONY: help build test run clean deploy-infra destroy-infra monitor-costs

help:
	@echo "Available commands:"
	@echo "  build         - Build the Go application"
	@echo "  test          - Run tests"
	@echo "  run           - Run the application locally"
	@echo "  clean         - Clean build artifacts"
	@echo "  deploy-infra  - Deploy infrastructure with Terraform"
	@echo "  destroy-infra - Destroy infrastructure with Terraform"
	@echo "  monitor-costs - Monitor GCP usage and costs"

build:
	go build -o bin/visitor-counter .

test:
	go test -v ./...

run:
	go run main.go

clean:
	rm -rf bin/
	go clean

deploy-infra:
	cd terraform && \
	terraform init && \
	terraform plan && \
	terraform apply -auto-approve

destroy-infra:
	cd terraform && \
	terraform destroy -auto-approve

monitor-costs:
	./scripts/monitor-costs.sh

deps:
	go mod tidy

fmt:
	go fmt ./...

lint:
	golangci-lint run

test-race:
	go test -race ./...

test-coverage:
	go test -coverprofile=coverage.out ./...
	go tool cover -html=coverage.out -o coverage.html
	@echo "Coverage report generated: coverage.html" 
