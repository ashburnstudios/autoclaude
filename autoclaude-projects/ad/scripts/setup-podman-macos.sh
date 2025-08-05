#!/bin/bash
# Podman Setup Script for macOS
# Initializes and configures Podman machine

set -euo pipefail

echo "🦭 Podman macOS Setup"
echo "===================="
echo ""

# Check if Podman is installed
if ! command -v podman &> /dev/null; then
    echo "❌ Podman not installed"
    echo ""
    echo "Install with Homebrew:"
    echo "  brew install podman"
    echo ""
    echo "Or download from: https://podman.io/getting-started/installation"
    exit 1
fi

echo "✅ Podman is installed"
echo "Version: $(podman --version)"
echo ""

# Check current machines
echo "Checking Podman machines..."
MACHINES=$(podman machine list --format "{{.Name}}" 2>/dev/null || true)

if [ -z "$MACHINES" ]; then
    echo "No Podman machines found. Creating default machine..."
    echo ""
    
    # Create a new machine with reasonable defaults
    echo "Creating Podman machine with:"
    echo "  - CPUs: 2"
    echo "  - Memory: 4GB"
    echo "  - Disk: 20GB"
    echo ""
    
    podman machine init --cpus 2 --memory 4096 --disk-size 20
    
    echo ""
    echo "✅ Podman machine created"
else
    echo "Existing machines found:"
    podman machine list
    echo ""
fi

# Check if any machine is running
RUNNING_MACHINES=$(podman machine list --format "{{.Name}}" --filter "State=running" 2>/dev/null || true)

if [ -z "$RUNNING_MACHINES" ]; then
    echo "Starting Podman machine..."
    
    # Get the default machine name
    DEFAULT_MACHINE=$(podman machine list --format "{{.Name}}" | head -1)
    
    if [ -n "$DEFAULT_MACHINE" ]; then
        podman machine start "$DEFAULT_MACHINE"
        echo "✅ Podman machine started"
    else
        echo "❌ No machine available to start"
        exit 1
    fi
else
    echo "✅ Podman machine is already running"
fi

echo ""
echo "Testing Podman connection..."
if podman system connection list &>/dev/null; then
    echo "✅ Podman connection successful"
    echo ""
    podman system connection list
else
    echo "❌ Failed to connect to Podman"
    exit 1
fi

echo ""
echo "Testing container functionality..."
if podman run --rm alpine echo "Podman works!" &>/dev/null; then
    echo "✅ Container test successful"
else
    echo "❌ Container test failed"
    exit 1
fi

# Optional: Set up Docker compatibility
echo ""
read -p "Create Docker compatibility alias? (y/n): " create_alias
if [[ "$create_alias" =~ ^[Yy]$ ]]; then
    # Add to shell profile
    SHELL_PROFILE=""
    if [ -n "$ZSH_VERSION" ]; then
        SHELL_PROFILE="$HOME/.zshrc"
    elif [ -n "$BASH_VERSION" ]; then
        SHELL_PROFILE="$HOME/.bashrc"
    fi
    
    if [ -n "$SHELL_PROFILE" ] && [ -f "$SHELL_PROFILE" ]; then
        if ! grep -q "alias docker=podman" "$SHELL_PROFILE"; then
            echo "" >> "$SHELL_PROFILE"
            echo "# Podman Docker compatibility" >> "$SHELL_PROFILE"
            echo "alias docker=podman" >> "$SHELL_PROFILE"
            echo "✅ Added docker alias to $SHELL_PROFILE"
            echo "   Run: source $SHELL_PROFILE"
        else
            echo "✅ Docker alias already exists"
        fi
    fi
fi

# Show resource usage
echo ""
echo "Podman Machine Resources:"
podman machine info

echo ""
echo "✅ Podman is ready for use!"
echo ""
echo "Useful commands:"
echo "  podman machine stop     # Stop the VM"
echo "  podman machine start    # Start the VM"
echo "  podman machine ssh      # SSH into the VM"
echo "  podman system prune -a  # Clean up unused data"
echo ""
echo "AutoClaude can now use Podman for sandboxing!"