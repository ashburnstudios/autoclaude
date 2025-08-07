# GitHub Integration with Cursor

This guide explains how to integrate GitHub Actions Claude feedback with your local Cursor development environment.

## Overview

Your GitHub Actions workflows (`claude-code-review.yml` and `claude.yml`) automatically trigger Claude Code reviews on pull requests. This guide shows you how to bring that feedback back into your local Cursor environment for seamless development.

## How It Works

### 1. GitHub → Claude Code (Automatic)
- **PR Creation**: When you create a PR, `claude-code-review.yml` automatically triggers Claude to review your code
- **@claude Mentions**: When you mention `@claude` in comments, `claude.yml` triggers Claude to respond
- **Feedback Location**: All feedback appears as comments on your GitHub PR

### 2. GitHub → Cursor (Manual/Integration)
- **Fetch Script**: Use `scripts/fetch-github-feedback.sh` to pull feedback into your local environment
- **Integration**: The script creates local files you can work with in Cursor
- **Workflow**: Review feedback → Make changes → Test → Push updates

## Setup

### 1. Install Dependencies

```bash
# Install jq for JSON processing (if not already installed)
brew install jq  # macOS
# or
sudo apt-get install jq  # Ubuntu/Debian
```

### 2. Configure GitHub Token

```bash
# Set your GitHub token (Personal Access Token with repo permissions)
export GITHUB_TOKEN="your-github-token-here"

# Or add to your shell profile
echo 'export GITHUB_TOKEN="your-github-token-here"' >> ~/.zshrc
source ~/.zshrc
```

### 3. Repository Configuration

The script automatically detects your repository from git remote, or you can set manually:

```bash
export REPO_OWNER="your-username"
export REPO_NAME="your-repo-name"
```

## Usage

### Basic Usage

```bash
# List recent PRs
./scripts/fetch-github-feedback.sh -l

# Fetch feedback for PR #123
./scripts/fetch-github-feedback.sh -p 123

# Get summary format
./scripts/fetch-github-feedback.sh -p 123 -f summary

# Save to custom file
./scripts/fetch-github-feedback.sh -p 123 -o my-feedback.md
```

### Complete Workflow

1. **Create a PR** with your changes
2. **Wait for Claude** to automatically review (or mention `@claude`)
3. **Fetch feedback** locally:
   ```bash
   ./scripts/fetch-github-feedback.sh -p <PR_NUMBER>
   ```
4. **Review feedback** in the generated files:
   - `github-feedback.md` - Detailed feedback
   - `cursor-feedback.md` - Integration guide
5. **Make changes** based on feedback
6. **Test locally** and push updates
7. **Re-fetch** if needed: `./scripts/fetch-github-feedback.sh -p <PR_NUMBER>`

## File Outputs

### github-feedback.md
Contains detailed feedback including:
- PR information (title, author, state, dates)
- Claude's automated review comments
- Review comments with file locations
- General comments from other users
- Review states and feedback

### cursor-feedback.md
Integration guide with:
- Quick action checklist
- Next steps for addressing feedback
- Workflow reminders

## Advanced Usage

### Custom Formats

```bash
# JSON format for programmatic processing
./scripts/fetch-github-feedback.sh -p 123 -f json

# Summary format for quick overview
./scripts/fetch-github-feedback.sh -p 123 -f summary

# Markdown format (default) for detailed review
./scripts/fetch-github-feedback.sh -p 123 -f markdown
```

### Environment Variables

```bash
# Set all variables for convenience
export GITHUB_TOKEN="your-token"
export REPO_OWNER="your-username"
export REPO_NAME="your-repo"
export PR_NUMBER="123"

# Then just run
./scripts/fetch-github-feedback.sh
```

## Integration with Cursor

### 1. Open Generated Files
```bash
# Open feedback in Cursor
cursor github-feedback.md
cursor cursor-feedback.md
```

### 2. Use Cursor's AI Features
- **Ask about feedback**: "What are the main issues identified in this PR feedback?"
- **Generate fixes**: "Create fixes for the security issues mentioned in the feedback"
- **Review changes**: "Review my changes against the original feedback"

### 3. Workflow Integration
```bash
# Create a workflow script
cat > scripts/review-workflow.sh << 'EOF'
#!/bin/bash
PR_NUMBER=$1
if [ -z "$PR_NUMBER" ]; then
    echo "Usage: $0 <PR_NUMBER>"
    exit 1
fi

# Fetch latest feedback
./scripts/fetch-github-feedback.sh -p $PR_NUMBER

# Open in Cursor
cursor github-feedback.md cursor-feedback.md

echo "Review feedback and make changes, then run:"
echo "git add . && git commit -m 'Address PR feedback' && git push"
EOF

chmod +x scripts/review-workflow.sh
```

## Troubleshooting

### Common Issues

1. **Invalid GitHub Token**
   ```bash
   # Test your token
   curl -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user
   ```

2. **Repository Not Found**
   ```bash
   # Check your git remote
   git remote -v
   
   # Set repository manually
   export REPO_OWNER="your-username"
   export REPO_NAME="your-repo-name"
   ```

3. **PR Not Found**
   ```bash
   # List recent PRs to find the correct number
   ./scripts/fetch-github-feedback.sh -l
   ```

### Debug Mode

```bash
# Enable debug output
set -x
./scripts/fetch-github-feedback.sh -p 123
set +x
```

## Best Practices

### 1. Regular Feedback Checks
```bash
# Check feedback after each push
git push origin feature-branch
./scripts/fetch-github-feedback.sh -p <PR_NUMBER>
```

### 2. Address Feedback Incrementally
- Review feedback in `github-feedback.md`
- Make changes to address issues
- Test locally
- Commit and push updates
- Re-fetch for updated feedback

### 3. Use Cursor's AI for Implementation
- Ask Cursor to help implement suggested fixes
- Use Cursor to review your changes against the feedback
- Generate tests for new code based on feedback

### 4. Track Progress
```bash
# Create a progress tracking file
echo "# PR Feedback Progress" > feedback-progress.md
echo "- [ ] Review initial feedback" >> feedback-progress.md
echo "- [ ] Address critical issues" >> feedback-progress.md
echo "- [ ] Add tests" >> feedback-progress.md
echo "- [ ] Final review" >> feedback-progress.md
```

## Examples

### Example 1: First-Time Setup
```bash
# 1. Set up environment
export GITHUB_TOKEN="ghp_..."
export REPO_OWNER="johndoe"
export REPO_NAME="my-project"

# 2. Create a PR and get feedback
# (Create PR on GitHub, wait for Claude review)

# 3. Fetch feedback
./scripts/fetch-github-feedback.sh -p 42

# 4. Review in Cursor
cursor github-feedback.md
```

### Example 2: Iterative Development
```bash
# 1. Make changes based on feedback
# (Edit files in Cursor)

# 2. Test changes
npm test

# 3. Commit and push
git add .
git commit -m "Address Claude feedback"
git push

# 4. Get updated feedback
./scripts/fetch-github-feedback.sh -p 42 -f summary
```

### Example 3: Team Collaboration
```bash
# 1. Fetch feedback for team review
./scripts/fetch-github-feedback.sh -p 42 -o team-review.md

# 2. Share with team
# (Share team-review.md with your team)

# 3. Address team feedback
# (Make changes, then re-fetch)
./scripts/fetch-github-feedback.sh -p 42
```

## Integration with AutoClaude

This GitHub integration works seamlessly with your AutoClaude setup:

1. **AutoClaude** creates projects and pushes to GitHub
2. **GitHub Actions** automatically review with Claude
3. **Fetch script** brings feedback back to Cursor
4. **Cursor** helps you address feedback and improve code

The complete workflow: AutoClaude → GitHub → Claude Review → Local Feedback → Cursor Development → Improved Code 