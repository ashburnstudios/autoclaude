#!/bin/bash

# Setup script for GitHub integration with Cursor
# This script helps configure the GitHub feedback integration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔧 Setting up GitHub Integration with Cursor${NC}"
echo ""

# Check if we're in a git repository
if [ ! -d .git ]; then
    echo -e "${RED}Error: Not in a git repository${NC}"
    echo "Please run this script from your project root directory"
    exit 1
fi

# Check dependencies
echo -e "${BLUE}Checking dependencies...${NC}"
missing_deps=()

if ! command -v jq &> /dev/null; then
    missing_deps+=("jq")
fi

if ! command -v curl &> /dev/null; then
    missing_deps+=("curl")
fi

if [ ${#missing_deps[@]} -ne 0 ]; then
    echo -e "${YELLOW}Missing dependencies: ${missing_deps[*]}${NC}"
    echo ""
    echo "Please install them:"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "  brew install jq"
    else
        echo "  sudo apt-get install jq curl"
    fi
    echo ""
    read -p "Press Enter after installing dependencies..."
fi

# Get repository information
echo -e "${BLUE}Detecting repository information...${NC}"
remote_url=$(git config --get remote.origin.url)

if [ -n "$remote_url" ]; then
    if [[ "$remote_url" =~ github\.com[:/]([^/]+)/([^/]+) ]]; then
        REPO_OWNER="${BASH_REMATCH[1]}"
        REPO_NAME="${BASH_REMATCH[2]%.git}"
        echo -e "${GREEN}Detected repository: $REPO_OWNER/$REPO_NAME${NC}"
    else
        echo -e "${YELLOW}Could not parse GitHub URL from: $remote_url${NC}"
        read -p "Enter repository owner: " REPO_OWNER
        read -p "Enter repository name: " REPO_NAME
    fi
else
    echo -e "${YELLOW}No git remote found${NC}"
    read -p "Enter repository owner: " REPO_OWNER
    read -p "Enter repository name: " REPO_NAME
fi

# Check for existing GitHub token
if [ -n "$GITHUB_TOKEN" ]; then
    echo -e "${GREEN}GitHub token found in environment${NC}"
    echo "Testing token..."
    response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" "https://api.github.com/user" 2>/dev/null)
    if echo "$response" | jq -e '.message' >/dev/null 2>&1; then
        echo -e "${RED}Invalid GitHub token${NC}"
        GITHUB_TOKEN=""
    else
        echo -e "${GREEN}GitHub token is valid${NC}"
    fi
fi

# Get GitHub token if needed
if [ -z "$GITHUB_TOKEN" ]; then
    echo ""
    echo -e "${BLUE}GitHub Token Setup${NC}"
    echo "You need a GitHub Personal Access Token with 'repo' permissions."
    echo ""
    echo "To create a token:"
    echo "1. Go to https://github.com/settings/tokens"
    echo "2. Click 'Generate new token (classic)'"
    echo "3. Give it a name like 'Cursor Integration'"
    echo "4. Select 'repo' permissions"
    echo "5. Copy the token"
    echo ""
    read -p "Enter your GitHub token: " GITHUB_TOKEN
    
    # Test the token
    echo "Testing token..."
    response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" "https://api.github.com/user" 2>/dev/null)
    if echo "$response" | jq -e '.message' >/dev/null 2>&1; then
        echo -e "${RED}Invalid GitHub token. Please check and try again.${NC}"
        exit 1
    else
        echo -e "${GREEN}GitHub token is valid!${NC}"
    fi
fi

# Create environment file
echo ""
echo -e "${BLUE}Creating environment configuration...${NC}"

cat > .env.github << EOF
# GitHub Integration Configuration
GITHUB_TOKEN=$GITHUB_TOKEN
REPO_OWNER=$REPO_OWNER
REPO_NAME=$REPO_NAME

# Optional: Set default PR number for convenience
# PR_NUMBER=

# Optional: Set default output format (markdown, summary, json)
# FEEDBACK_FORMAT=markdown
EOF

echo -e "${GREEN}Created .env.github file${NC}"

# Create shell profile configuration
echo ""
echo -e "${BLUE}Setting up shell profile...${NC}"

shell_profile=""
if [[ "$SHELL" == *"zsh"* ]]; then
    shell_profile="$HOME/.zshrc"
elif [[ "$SHELL" == *"bash"* ]]; then
    shell_profile="$HOME/.bashrc"
else
    shell_profile="$HOME/.profile"
fi

# Add to shell profile
if [ -f "$shell_profile" ]; then
    if ! grep -q "GITHUB_TOKEN" "$shell_profile"; then
        echo "" >> "$shell_profile"
        echo "# GitHub Integration for Cursor" >> "$shell_profile"
        echo "export GITHUB_TOKEN=\"$GITHUB_TOKEN\"" >> "$shell_profile"
        echo "export REPO_OWNER=\"$REPO_OWNER\"" >> "$shell_profile"
        echo "export REPO_NAME=\"$REPO_NAME\"" >> "$shell_profile"
        echo -e "${GREEN}Added configuration to $shell_profile${NC}"
    else
        echo -e "${YELLOW}GitHub configuration already exists in $shell_profile${NC}"
    fi
fi

# Create convenience script
echo ""
echo -e "${BLUE}Creating convenience script...${NC}"

cat > scripts/review-pr.sh << 'EOF'
#!/bin/bash

# Convenience script for PR review workflow
# Usage: ./scripts/review-pr.sh <PR_NUMBER>

set -e

PR_NUMBER="$1"

if [ -z "$PR_NUMBER" ]; then
    echo "Usage: $0 <PR_NUMBER>"
    echo ""
    echo "Examples:"
    echo "  $0 123                    # Review PR #123"
    echo "  $0 123 -f summary         # Get summary of PR #123"
    echo "  $0 123 -o my-feedback.md  # Save to custom file"
    exit 1
fi

# Load environment if .env.github exists
if [ -f .env.github ]; then
    export $(cat .env.github | grep -v '^#' | xargs)
fi

# Run the fetch script
./scripts/fetch-github-feedback.sh -p "$PR_NUMBER" "$@"

echo ""
echo -e "\033[0;32m✅ PR feedback fetched successfully!\033[0m"
echo ""
echo "Next steps:"
echo "1. Review github-feedback.md"
echo "2. Make changes based on feedback"
echo "3. Test your changes"
echo "4. Commit and push updates"
echo "5. Run this script again to get updated feedback"
EOF

chmod +x scripts/review-pr.sh
echo -e "${GREEN}Created scripts/review-pr.sh${NC}"

# Test the setup
echo ""
echo -e "${BLUE}Testing setup...${NC}"

# Test GitHub API access
response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
    "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME" 2>/dev/null)

if echo "$response" | jq -e '.message' >/dev/null 2>&1; then
    echo -e "${RED}Error: Cannot access repository $REPO_OWNER/$REPO_NAME${NC}"
    echo "Please check your token permissions and repository name"
    exit 1
else
    echo -e "${GREEN}✅ Repository access confirmed${NC}"
fi

# Show usage examples
echo ""
echo -e "${GREEN}🎉 Setup complete!${NC}"
echo ""
echo -e "${BLUE}Usage Examples:${NC}"
echo ""
echo "1. List recent PRs:"
echo "   ./scripts/fetch-github-feedback.sh -l"
echo ""
echo "2. Review a specific PR:"
echo "   ./scripts/review-pr.sh 123"
echo ""
echo "3. Get summary format:"
echo "   ./scripts/review-pr.sh 123 -f summary"
echo ""
echo "4. Save to custom file:"
echo "   ./scripts/review-pr.sh 123 -o my-feedback.md"
echo ""
echo -e "${BLUE}Workflow:${NC}"
echo "1. Create a PR on GitHub"
echo "2. Wait for Claude to review (or mention @claude)"
echo "3. Run: ./scripts/review-pr.sh <PR_NUMBER>"
echo "4. Review feedback in generated files"
echo "5. Make changes and push updates"
echo "6. Re-run to get updated feedback"
echo ""
echo -e "${YELLOW}Note:${NC} You may need to restart your terminal or run 'source ~/.zshrc' to load the environment variables." 