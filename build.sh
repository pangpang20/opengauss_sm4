#!/bin/bash
set -e

echo "Fetching latest OpenGauss version..."
OPENGAUSS_VERSION=$(curl -s https://api.github.com/repos/opengauss/opengauss/tags | grep -o '"name": ".*"' | head -n 1 | cut -d '"' -f 4)

if [ -z "$OPENGAUSS_VERSION" ]; then
    echo "Error: Failed to fetch OpenGauss version from GitHub API"
    exit 1
fi

echo "Building Docker image for OpenGauss version: $OPENGAUSS_VERSION"
docker build --build-arg OPENGAUSS_VERSION=$OPENGAUSS_VERSION -t sm4-ext:openGauss-$OPENGAUSS_VERSION -t sm4-ext:latest .