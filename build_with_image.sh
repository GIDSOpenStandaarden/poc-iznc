#!/bin/bash
# Quick build script using pre-built Docker image

set -e

echo "Building POC IZNC Implementation Guide using Docker..."

# Configuration
IMAGE_NAME=${IMAGE_NAME:-ghcr.io/gidsopenstandaarden/poc-iznc:latest}

# Pull latest image
echo "Pulling Docker image: $IMAGE_NAME"
docker pull "$IMAGE_NAME" || echo "Note: Image not yet published, will need to build locally first"

# Create output directories
mkdir -p ./public ./output

# Run the build
echo "Running build in Docker container..."
docker run --rm -v "${PWD}:/src" "$IMAGE_NAME"

echo ""
echo "Build complete!"
echo "Opening Implementation Guide in browser..."
open public/index.html || xdg-open public/index.html || echo "Please open public/index.html manually"
