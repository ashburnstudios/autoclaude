#!/bin/bash

# Fetch GitHub PR feedback and integrate with local development
# This script helps bring GitHub Actions Claude feedback back to your local environment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
REPO_OWNER="${REPO_OWNER:-}"
REPO_NAME="${REPO_NAME:-}"
PR_NUMBER="${PR_NUMBER:-}"

# Function to show usage
show_usage() {
    echo -e "${BLUE}Usage:${NC}"
    echo "  $0 [options]"
    echo ""
    echo -e "${BLUE}Options:${NC}"
    echo "  --token TOKEN     GitHub token (or set GITHUB_TOKEN env var)"
    echo "  --owner OWNER     Repository owner (or set REPO_OWNER env var)"
    echo "  --repo REPO       Repository name (or set REPO_NAME env var)"
    echo "  --pr NUMBER       PR number to fetch feedback for"
    echo "  --list            List recent PRs"
    echo "  --format FORMAT   Output format: json, markdown, summary (default: markdown)"
    echo "  --output FILE     Output file (default: github-feedback.md)"
    echo "  --help            Show this help"
    echo ""
    echo -e "${BLUE}Examples:${NC}"
    echo "  $0 --pr 123                    # Fetch feedback for PR #123"
    echo "  $0 --list                        # List recent PRs"
    echo "  $0 --pr 123 --format summary         # Get summary of PR #123 feedback"
    echo "  $0 --pr 123 --output feedback.md     # Save feedback to feedback.md"
}

# Function to check dependencies
check_dependencies() {
    local missing_deps=()
    
    if ! command -v jq &> /dev/null; then
        missing_deps+=("jq")
    fi
    
    if ! command -v curl &> /dev/null; then
        missing_deps+=("curl")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        echo -e "${RED}Error: Missing dependencies:${NC} ${missing_deps[*]}"
        echo "Please install them and try again."
        exit 1
    fi
}

# Function to validate GitHub token
validate_token() {
    if [ -z "$GITHUB_TOKEN" ]; then
        echo -e "${RED}Error: GitHub token is required${NC}"
        echo "Set GITHUB_TOKEN environment variable or use --token option"
        exit 1
    fi
    
    # Test token
    local response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
        "https://api.github.com/user" 2>/dev/null)
    
    if echo "$response" | jq -e '.message' >/dev/null 2>&1; then
        echo -e "${RED}Error: Invalid GitHub token${NC}"
        exit 1
    fi
}

# Function to get repository info
get_repo_info() {
    if [ -z "$REPO_OWNER" ] || [ -z "$REPO_NAME" ]; then
        # Try to get from git remote
        local remote_url=$(git config --get remote.origin.url 2>/dev/null)
        if [ -n "$remote_url" ]; then
            if [[ "$remote_url" =~ github\.com[:/]([^/]+)/([^/]+) ]]; then
                REPO_OWNER="${BASH_REMATCH[1]}"
                REPO_NAME="${BASH_REMATCH[2]%.git}"
            fi
        fi
        
        if [ -z "$REPO_OWNER" ] || [ -z "$REPO_NAME" ]; then
            echo -e "${RED}Error: Repository owner and name are required${NC}"
            echo "Set REPO_OWNER and REPO_NAME environment variables or use --owner and --repo options"
            exit 1
        fi
    fi
}

# Function to list recent PRs
list_prs() {
    echo -e "${BLUE}Fetching recent pull requests...${NC}"
    
    local response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
        "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/pulls?state=all&per_page=10")
    
    echo -e "${GREEN}Recent Pull Requests:${NC}"
    echo "$response" | jq -r '.[] | "\(.number): \(.title) (\(.state)) - \(.user.login)"'
}

# Function to fetch PR feedback
fetch_pr_feedback() {
    local pr_number="$1"
    local format="${2:-markdown}"
    local output_file="${3:-github-feedback.md}"
    
    echo -e "${BLUE}Fetching feedback for PR #$pr_number...${NC}"
    
    # Get PR details
    local pr_response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
        "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/pulls/$pr_number")
    
    # Get PR comments
    local comments_response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
        "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/issues/$pr_number/comments")
    
    # Get PR review comments
    local review_comments_response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
        "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/pulls/$pr_number/comments")
    
    # Get PR reviews
    local reviews_response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
        "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/pulls/$pr_number/reviews")
    
    # Check for errors
    if echo "$pr_response" | jq -e '.message' >/dev/null 2>&1; then
        echo -e "${RED}Error: Could not fetch PR #$pr_number${NC}"
        echo "$pr_response" | jq -r '.message'
        exit 1
    fi
    
    # Process based on format
    case "$format" in
        "json")
            # Output raw JSON
            echo "$pr_response" | jq '. + {comments: '"$comments_response"', review_comments: '"$review_comments_response"', reviews: '"$reviews_response"'}' > "$output_file"
            echo -e "${GREEN}JSON feedback saved to $output_file${NC}"
            ;;
        "summary")
            # Create summary
            {
                echo "# PR #$pr_number Feedback Summary"
                echo ""
                echo "## PR Details"
                echo "- **Title:** $(echo "$pr_response" | jq -r '.title')"
                echo "- **Author:** $(echo "$pr_response" | jq -r '.user.login')"
                echo "- **State:** $(echo "$pr_response" | jq -r '.state')"
                echo "- **Created:** $(echo "$pr_response" | jq -r '.created_at')"
                echo "- **Updated:** $(echo "$pr_response" | jq -r '.updated_at')"
                echo ""
                echo "## Comments Count"
                echo "- **General Comments:** $(echo "$comments_response" | jq 'length')"
                echo "- **Review Comments:** $(echo "$review_comments_response" | jq 'length')"
                echo "- **Reviews:** $(echo "$reviews_response" | jq 'length')"
                echo ""
                echo "## Claude Feedback"
                echo "$comments_response" | jq -r '.[] | select(.user.login == "claude-code-action") | "- " + .body' | head -5
                echo ""
                echo "## Recent Comments"
                echo "$comments_response" | jq -r '.[] | "- **'$(echo "$comments_response" | jq -r '.[0].user.login')'**: '$(echo "$comments_response" | jq -r '.[0].body')'" | head -3
            } > "$output_file"
            echo -e "${GREEN}Summary saved to $output_file${NC}"
            ;;
        "markdown"|*)
            # Create detailed markdown
            {
                echo "# PR #$pr_number Feedback Report"
                echo ""
                echo "## PR Information"
                echo "- **Title:** $(echo "$pr_response" | jq -r '.title')"
                echo "- **Author:** $(echo "$pr_response" | jq -r '.user.login')"
                echo "- **State:** $(echo "$pr_response" | jq -r '.state')"
                echo "- **Created:** $(echo "$pr_response" | jq -r '.created_at')"
                echo "- **Updated:** $(echo "$pr_response" | jq -r '.updated_at')"
                echo "- **URL:** $(echo "$pr_response" | jq -r '.html_url')"
                echo ""
                echo "## Claude Code Review"
                echo ""
                echo "### Automated Review Comments"
                echo "$comments_response" | jq -r '.[] | select(.user.login == "claude-code-action") | "#### Comment by Claude\n\n" + .body + "\n\n---\n"' || echo "No Claude comments found"
                echo ""
                echo "### Review Comments"
                echo "$review_comments_response" | jq -r '.[] | "#### Review Comment\n\n**File:** " + .path + ":" + (.line|tostring) + "\n\n" + .body + "\n\n---\n"' || echo "No review comments found"
                echo ""
                echo "### Reviews"
                echo "$reviews_response" | jq -r '.[] | "#### Review by " + .user.login + "\n\n**State:** " + .state + "\n\n" + (.body // "No body") + "\n\n---\n"' || echo "No reviews found"
                echo ""
                echo "### General Comments"
                echo "$comments_response" | jq -r '.[] | select(.user.login != "claude-code-action") | "#### Comment by " + .user.login + "\n\n" + .body + "\n\n---\n"' || echo "No general comments found"
            } > "$output_file"
            echo -e "${GREEN}Detailed feedback saved to $output_file${NC}"
            ;;
    esac
}

# Function to integrate with Cursor
integrate_with_cursor() {
    local feedback_file="$1"
    
    echo -e "${BLUE}Integrating feedback with Cursor...${NC}"
    
    # Create a Cursor-friendly format
    local cursor_file="cursor-feedback.md"
    {
        echo "# Cursor Integration: GitHub PR Feedback"
        echo ""
        echo "## Quick Actions"
        echo "- [ ] Review feedback in $feedback_file"
        echo "- [ ] Address critical issues"
        echo "- [ ] Update local code based on feedback"
        echo "- [ ] Test changes locally"
        echo "- [ ] Push updates to PR"
        echo ""
        echo "## Integration Notes"
        echo "This feedback was automatically fetched from GitHub PR #$PR_NUMBER"
        echo "Use this information to improve your local development workflow."
        echo ""
        echo "## Next Steps"
        echo "1. Review the feedback in $feedback_file"
        echo "2. Make necessary changes to your code"
        echo "3. Test your changes"
        echo "4. Commit and push updates"
        echo "5. Re-run this script to get updated feedback"
    } > "$cursor_file"
    
    echo -e "${GREEN}Cursor integration file created: $cursor_file${NC}"
    echo -e "${YELLOW}Open $feedback_file to review the feedback${NC}"
}

# Main execution
main() {
    local format="markdown"
    local output_file="github-feedback.md"
    local list_mode=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --token)
                GITHUB_TOKEN="$2"
                shift 2
                ;;
            --owner)
                REPO_OWNER="$2"
                shift 2
                ;;
            --repo)
                REPO_NAME="$2"
                shift 2
                ;;
            --pr)
                PR_NUMBER="$2"
                shift 2
                ;;
            --list)
                list_mode=true
                shift
                ;;
            --format)
                format="$2"
                shift 2
                ;;
            --output)
                output_file="$2"
                shift 2
                ;;
            --help)
                show_usage
                exit 0
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Check dependencies
    check_dependencies
    
    # Validate token
    validate_token
    
    # Get repository info
    get_repo_info
    
    if [ "$list_mode" = true ]; then
        list_prs
        exit 0
    fi
    
    if [ -z "$PR_NUMBER" ]; then
        echo -e "${RED}Error: PR number is required${NC}"
        echo "Use --pr option or set PR_NUMBER environment variable"
        exit 1
    fi
    
    # Fetch feedback
    fetch_pr_feedback "$PR_NUMBER" "$format" "$output_file"
    
    # Integrate with Cursor
    integrate_with_cursor "$output_file"
    
    echo -e "${GREEN}✅ GitHub feedback integration complete!${NC}"
    echo -e "${YELLOW}📁 Files created:${NC}"
    echo "  - $output_file (feedback details)"
    echo "  - cursor-feedback.md (integration guide)"
}

# Run main function
main "$@" 