#!/bin/bash
# Check Podman installation and configuration

echo "🦭 Podman Configuration Check"
echo "============================"
echo ""

# Check if Podman is installed
if ! command -v podman &> /dev/null; then
    echo "❌ Podman is not installed"
    echo ""
    echo "To install Podman:"
    echo "  macOS:    brew install podman"
    echo "  Fedora:   sudo dnf install podman"
    echo "  Ubuntu:   sudo apt-get install podman"
    echo "  Arch:     sudo pacman -S podman"
    exit 1
fi

echo "✅ Podman is installed"
PODMAN_VERSION=$(podman --version | cut -d' ' -f3)
echo "   Version: $PODMAN_VERSION"
echo ""

# Check if running rootless
if podman info 2>/dev/null | grep -q "rootless: true"; then
    echo "✅ Running in rootless mode (recommended)"
else
    echo "⚠️  Running with root privileges"
fi
echo ""

# Check Podman machine status (macOS)
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "Podman Machine Status (macOS):"
    if podman machine list 2>/dev/null | grep -q "Currently running"; then
        echo "✅ Podman machine is running"
        podman machine list
    else
        echo "❌ Podman machine is not running"
        echo "   Run: podman machine start"
    fi
    echo ""
fi

# Check if podman-compose is available
echo "Checking for podman-compose:"
if command -v podman-compose &> /dev/null; then
    echo "✅ podman-compose is installed"
    COMPOSE_VERSION=$(podman-compose --version 2>/dev/null | cut -d' ' -f3)
    echo "   Version: $COMPOSE_VERSION"
else
    echo "⚠️  podman-compose not found (optional)"
    echo "   Install with: pip3 install podman-compose"
fi
echo ""

# Test Podman functionality
echo "Testing Podman functionality:"
if podman run --rm alpine echo "Hello from Podman" &>/dev/null; then
    echo "✅ Podman can run containers"
else
    echo "❌ Failed to run test container"
    echo "   This might be a permission or configuration issue"
fi

# Check if Docker CLI is aliased to Podman
echo ""
echo "Docker compatibility:"
if command -v docker &> /dev/null; then
    if docker --version 2>&1 | grep -q podman; then
        echo "✅ Docker commands are aliased to Podman"
    else
        echo "ℹ️  Docker is installed separately"
    fi
else
    echo "ℹ️  No docker command found"
    echo "   You can create an alias: alias docker=podman"
fi

# Check AutoClaude image
echo ""
echo "Checking for AutoClaude image:"
if podman images | grep -q "autoclaude/sandbox"; then
    echo "✅ AutoClaude sandbox image exists"
    podman images | grep autoclaude
else
    echo "ℹ️  AutoClaude sandbox image not built yet"
    echo "   Run ./scripts/setup.sh to build it"
fi

# Check storage
echo ""
echo "Storage information:"
podman system df 2>/dev/null || echo "Unable to get storage info"

# Final summary
echo ""
echo "Summary:"
echo "========"
if command -v podman &> /dev/null && \
   podman run --rm alpine echo "test" &>/dev/null; then
    echo "✅ Podman is properly configured for AutoClaude"
    echo ""
    echo "You can now use AutoClaude with Podman!"
else
    echo "❌ Some issues need to be resolved"
    echo ""
    echo "Please fix the issues above before using AutoClaude with Podman"
fi