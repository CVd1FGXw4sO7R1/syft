# Makefile for syft - Fork of anchore/syft

BINARY := syft
GO := go
GOFLAGS :=
BUILD_DIR := ./dist
CMD_DIR := ./cmd/syft

# Version information
VERSION ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
COMMIT ?= $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
BUILD_DATE ?= $(shell date -u +"%Y-%m-%dT%H:%M:%SZ")

LD_FLAGS := -ldflags "-X main.version=$(VERSION) -X main.commit=$(COMMIT) -X main.buildDate=$(BUILD_DATE)"

.DEFAULT_GOAL := dev

.PHONY: all
all: clean lint test build

.PHONY: build
build: ## Build the binary
	$(GO) build $(GOFLAGS) $(LD_FLAGS) -o $(BUILD_DIR)/$(BINARY) $(CMD_DIR)

.PHONY: run
run: ## Run the application
	$(GO) run $(CMD_DIR)/main.go

.PHONY: test
test: ## Run unit tests
	$(GO) test $(GOFLAGS) ./... -v -race -timeout 300s

.PHONY: test-unit
test-unit: ## Run unit tests only
	$(GO) test $(GOFLAGS) ./... -v -race -timeout 120s -short

.PHONY: test-integration
test-integration: ## Run integration tests
	$(GO) test $(GOFLAGS) ./... -v -race -timeout 300s -run Integration

.PHONY: lint
lint: ## Run linters
	$(GO) vet ./...
	which golangci-lint && golangci-lint run ./... || echo "golangci-lint not found, skipping"

.PHONY: fmt
fmt: ## Format code
	$(GO) fmt ./...

.PHONY: tidy
tidy: ## Tidy go modules
	$(GO) mod tidy

.PHONY: clean
clean: ## Remove build artifacts
	rm -rf $(BUILD_DIR)

.PHONY: install
install: build ## Install the binary to GOPATH/bin
	cp $(BUILD_DIR)/$(BINARY) $(GOPATH)/bin/$(BINARY)

.PHONY: snapshot
snapshot: ## Build a snapshot release with goreleaser
	goreleaser release --snapshot --clean --skip-publish

.PHONY: release
release: ## Build and publish a release with goreleaser
	goreleaser release --clean

.PHONY: bootstrap
bootstrap: ## Install required tools
	$(GO) install github.com/golangci/golangci-lint/cmd/golangci-lint@latest

# Quick dev target: build without race detector for faster iteration
.PHONY: dev
dev: ## Fast build for local development (no tests)
	$(GO) build $(GOFLAGS) $(LD_FLAGS) -o $(BUILD_DIR)/$(BINARY) $(CMD_DIR)
	@echo "Built $(BUILD_DIR)/$(BINARY) ($(VERSION))"

# Personal shortcut: run tests without -v for cleaner output during development
# Using -count=1 to disable test caching so results are always fresh
# Bumped timeout from 120s to 180s - some catalog tests were flaky on my machine
# Added -parallel 4 to speed things up a bit on my 8-core machine
# Bumped -parallel to 8 to better utilize all cores (was 4, but 8 is noticeably faster)
.PHONY: test-quiet
test-quiet: ## Run unit tests with minimal output
	$(GO) test $(GOFLAGS) ./... -race -timeout 180s -short -count=1 -parallel 8

.PHONY: help
help: ## Display this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'
