# Makefile for POC IZNC FHIR Implementation Guide
# This Makefile is designed to run INSIDE the Docker container

# Variables
FHIR := fhir
DOTNET_TOOLS := $(HOME)/.dotnet/tools

# Fetch version from sushi-config.yaml with error handling
export VERSION := $(shell grep '^version:' sushi-config.yaml | sed 's/version: //' | tr -d '[:space:]')
ifeq ($(VERSION),)
$(error "Could not extract version from sushi-config.yaml")
endif

# Export PATH with dotnet tools
export PATH := $(PATH):$(DOTNET_TOOLS)

# Default target
.PHONY: all
all: build

# Build target (runs inside Docker container)
.PHONY: build
build: install-dependencies build-ig
	@echo "Build complete!"

# Install FHIR dependencies
.PHONY: install-dependencies
install-dependencies:
	@echo "Installing dependencies from sushi-config.yaml..."
	@python3 scripts/get_dependencies.py | while read pkg; do \
		echo "Installing $$pkg..."; \
		fhir install $$pkg; \
		fhir extract-package $$pkg; \
		fhir inflate --package $$pkg; \
	done

# Build Implementation Guide using IG Publisher
.PHONY: build-ig
build-ig:
	@echo "Building POC IZNC Implementation Guide with version $(VERSION)..."
	@echo "Running SUSHI to compile FSH files..."
	@sushi .
	@echo "Generating PlantUML diagrams..."
	@if command -v plantuml >/dev/null 2>&1; then \
		mkdir -p ./input/images; \
		plantuml -o ../images/ -tsvg ./input/images-source/*.plantuml 2>/dev/null || true; \
	fi
	@echo "Running IG Publisher..."
	@java -jar /usr/local/publisher.jar -ig ig.ini
	@if [ ! -f ./output/package.tgz ]; then \
		echo "ERROR: Build did not create ./output/package.tgz"; \
		exit 1; \
	fi
	@echo "Copying package.tgz to: ./output/gids.poc.iznc-$(VERSION).tgz"
	@cp ./output/package.tgz ./output/gids.poc.iznc-$(VERSION).tgz
	@echo "Successfully created: ./output/gids.poc.iznc-$(VERSION).tgz"
	@echo "IG Publisher completed successfully"

# Convert JSON examples to FSH using GoFSH
.PHONY: update-examples
update-examples:
	@echo "Converting JSON examples to FSH..."
	@if ! command -v gofsh >/dev/null 2>&1; then \
		echo "Error: GoFSH not found. Install it with: npm install -g gofsh"; \
		exit 1; \
	fi
	@gofsh --useFHIRVersion=4.0.1 examples/ --out input/fsh/
	@echo "Examples converted successfully"

# Generate PlantUML diagrams
.PHONY: diagrams
diagrams:
	@echo "Generating PlantUML diagrams..."
	@if ! command -v plantuml >/dev/null 2>&1; then \
		echo "Error: plantuml not found. Please install it first."; \
		exit 1; \
	fi
	@mkdir -p ./input/images
	@plantuml -o ../images/ -tsvg ./input/images-source/*.plantuml
	@echo "Diagrams generated successfully in input/images/"

# Clean build artifacts
.PHONY: clean
clean:
	@echo "Cleaning build artifacts..."
	@rm -rf ./output/* ./public/* ./temp/* ./fsh-generated/*
	@echo "Clean complete"

# Deep clean including caches
.PHONY: clean-all
clean-all: clean
	@echo "Performing deep clean..."
	@rm -rf ./input-cache/*
	@echo "Deep clean complete"

# Validate FSH files
.PHONY: validate
validate:
	@echo "Validating FSH files with SUSHI..."
	@sushi . --snapshot
	@echo "Validation complete"

# Show version
.PHONY: version
version:
	@echo "POC IZNC Implementation Guide Version: $(VERSION)"

# Help target
.PHONY: help
help:
	@echo "POC IZNC FHIR Implementation Guide - Available Make Targets"
	@echo ""
	@echo "This Makefile is designed to run INSIDE the Docker container."
	@echo "For instructions on running from the host machine, see README.md"
	@echo ""
	@echo "Building:"
	@echo "  make build           - Build IG (calls install-dependencies and build-ig)"
	@echo "  make build-ig        - Build Implementation Guide and create installable package"
	@echo "                         Creates: ./output/gids.poc.iznc-$(VERSION).tgz"
	@echo "  make install-dependencies - Install FHIR dependencies"
	@echo ""
	@echo "Development:"
	@echo "  make update-examples - Convert JSON examples to FSH using GoFSH"
	@echo "  make diagrams        - Generate PlantUML diagrams"
	@echo "  make validate        - Validate FSH files with SUSHI"
	@echo ""
	@echo "Maintenance:"
	@echo "  make clean           - Clean build artifacts"
	@echo "  make clean-all       - Deep clean including caches"
	@echo "  make version         - Show current version from sushi-config.yaml"
	@echo ""
	@echo "Information:"
	@echo "  make help            - Show this help message"
	@echo ""
	@echo "Current version: $(VERSION)"
