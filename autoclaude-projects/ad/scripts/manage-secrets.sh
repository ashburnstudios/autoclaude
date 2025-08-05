#!/bin/bash
# Secure secrets management for AutoClaude

set -euo pipefail

SECRETS_FILE="$HOME/.autoclaude/secrets"
SECRETS_ENCRYPTED="$HOME/.autoclaude/secrets.enc"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "🔐 AutoClaude Secrets Management"
echo "==============================="
echo ""

# Create config directory
mkdir -p "$HOME/.autoclaude"

# Function to securely read password
read_secret() {
    local prompt="$1"
    local var_name="$2"
    
    echo -n "$prompt"
    read -s value
    echo ""
    
    eval "$var_name='$value'"
}

# Check if using Claude Max
check_claude_max() {
    echo "Authentication Method:"
    echo "1) Claude Max (recommended - no API key needed)"
    echo "2) API Key"
    read -p "Select method (1-2): " auth_method
    
    if [ "$auth_method" = "1" ]; then
        echo ""
        echo -e "${GREEN}✅ Using Claude Max authentication${NC}"
        echo ""
        echo "Make sure you're logged into Claude Code:"
        echo "  claude auth login"
        echo ""
        
        # Create config marking Claude Max usage
        cat > "$SECRETS_FILE" <<EOF
# AutoClaude Authentication
AUTH_METHOD=claude_max
# No API key needed with Claude Max!
EOF
        
        echo -e "${GREEN}✅ Configuration saved${NC}"
        echo ""
        echo "You can now use AutoClaude without an API key!"
        return 0
    fi
    
    return 1
}

# Main menu
case "${1:-}" in
    "setup")
        if check_claude_max; then
            exit 0
        fi
        
        # API Key setup
        echo ""
        echo -e "${YELLOW}⚠️  API Key Setup${NC}"
        echo "Your API key will be stored securely in your home directory"
        echo ""
        
        read_secret "Enter your Anthropic API key: " api_key
        
        if [ -z "$api_key" ]; then
            echo -e "${RED}❌ No API key provided${NC}"
            exit 1
        fi
        
        # Store securely with restricted permissions
        cat > "$SECRETS_FILE" <<EOF
# AutoClaude Authentication
AUTH_METHOD=api_key
ANTHROPIC_API_KEY="$api_key"
EOF
        
        # Restrict permissions
        chmod 600 "$SECRETS_FILE"
        
        echo -e "${GREEN}✅ API key stored securely${NC}"
        echo ""
        echo "Location: $SECRETS_FILE"
        echo "Permissions: 600 (only you can read)"
        ;;
        
    "show")
        if [ ! -f "$SECRETS_FILE" ]; then
            echo -e "${RED}❌ No secrets configured${NC}"
            echo "Run: $0 setup"
            exit 1
        fi
        
        echo "Current configuration:"
        echo "===================="
        grep -E "^AUTH_METHOD=" "$SECRETS_FILE" || echo "AUTH_METHOD not set"
        
        if grep -q "AUTH_METHOD=api_key" "$SECRETS_FILE"; then
            echo "API Key: [HIDDEN]"
            echo ""
            echo "To view: cat $SECRETS_FILE"
        else
            echo "Using Claude Max (no API key)"
        fi
        ;;
        
    "remove")
        if [ -f "$SECRETS_FILE" ]; then
            rm -f "$SECRETS_FILE"
            echo -e "${GREEN}✅ Secrets removed${NC}"
        else
            echo "No secrets to remove"
        fi
        ;;
        
    "check")
        if [ ! -f "$SECRETS_FILE" ]; then
            echo -e "${RED}❌ Not configured${NC}"
            exit 1
        fi
        
        if grep -q "AUTH_METHOD=claude_max" "$SECRETS_FILE"; then
            # Check if Claude Code is authenticated
            if claude auth status &>/dev/null; then
                echo -e "${GREEN}✅ Claude Max authentication working${NC}"
            else
                echo -e "${RED}❌ Claude Code not authenticated${NC}"
                echo "Run: claude auth login"
                exit 1
            fi
        elif grep -q "ANTHROPIC_API_KEY=" "$SECRETS_FILE"; then
            echo -e "${GREEN}✅ API key configured${NC}"
        else
            echo -e "${RED}❌ No authentication method configured${NC}"
            exit 1
        fi
        ;;
        
    *)
        echo "Usage: $0 {setup|show|remove|check}"
        echo ""
        echo "Commands:"
        echo "  setup  - Configure authentication (Claude Max or API key)"
        echo "  show   - Show current configuration"
        echo "  remove - Remove stored secrets"
        echo "  check  - Verify authentication is working"
        echo ""
        echo "Examples:"
        echo "  $0 setup   # Interactive setup"
        echo "  $0 check   # Verify configuration"
        ;;
esac