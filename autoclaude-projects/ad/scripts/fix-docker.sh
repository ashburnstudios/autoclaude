#!/bin/bash
# Quick fix to force Docker usage

echo "🔧 Configuring AutoClaude to use Docker..."

# Set in config file
CONFIG_FILE="$HOME/.autoclaude/config"
if [ -f "$CONFIG_FILE" ]; then
    # Update existing config
    sed -i.bak 's/AUTOCLAUDE_DEFAULT_RUNTIME="auto"/AUTOCLAUDE_DEFAULT_RUNTIME="docker"/' "$CONFIG_FILE"
    echo "✅ Updated configuration file"
else
    # Create new config
    mkdir -p "$HOME/.autoclaude"
    cat > "$CONFIG_FILE" <<EOF
# AutoClaude Configuration
AUTOCLAUDE_WORKSPACE="${HOME}/autoclaude-projects"
AUTOCLAUDE_DEFAULT_RUNTIME="docker"
AUTOCLAUDE_AUTO_COMMIT="true"
AUTOCLAUDE_USE_SANDBOX="true"
EOF
    echo "✅ Created configuration file"
fi

# Export for current session
export AUTOCLAUDE_CONTAINER_RUNTIME=docker

echo ""
echo "✅ AutoClaude will now use Docker"
echo ""
echo "To make this permanent, add to your shell profile:"
echo "  export AUTOCLAUDE_CONTAINER_RUNTIME=docker"
echo ""
echo "You can now run autoclaude and it will use Docker!"