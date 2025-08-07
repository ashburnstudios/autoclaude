# GitHub + Cursor Integration Summary

## What You Have Now

✅ **GitHub Actions Workflows** (already set up):
- `claude-code-review.yml` - Automatically reviews PRs
- `claude.yml` - Responds to `@claude` mentions

✅ **New Integration Tools** (just created):
- `scripts/fetch-github-feedback.sh` - Pulls feedback to local
- `scripts/setup-github-integration.sh` - Easy setup
- `scripts/review-pr.sh` - Convenience wrapper

## How to Use It

### 1. First-Time Setup
```bash
# Run the setup script
./scripts/setup-github-integration.sh

# Follow the prompts to configure:
# - GitHub token
# - Repository info
# - Environment variables
```

### 2. Your Workflow
```bash
# 1. Create a PR on GitHub
# 2. Wait for Claude to review (or mention @claude)
# 3. Fetch feedback locally:
./scripts/review-pr.sh <PR_NUMBER>

# 4. Review the generated files:
# - github-feedback.md (detailed feedback)
# - cursor-feedback.md (integration guide)

# 5. Make changes based on feedback
# 6. Test and push updates
# 7. Re-fetch if needed: ./scripts/review-pr.sh <PR_NUMBER>
```

### 3. Quick Examples
```bash
# List recent PRs
./scripts/fetch-github-feedback.sh -l

# Get detailed feedback for PR #42
./scripts/review-pr.sh 42

# Get summary format
./scripts/review-pr.sh 42 -f summary

# Save to custom file
./scripts/review-pr.sh 42 -o my-feedback.md
```

## What This Solves

**Before**: GitHub → Claude Code (one-way)
**After**: GitHub → Claude Code → Local Cursor (two-way)

- ✅ Fetch Claude's PR feedback locally
- ✅ Work with feedback in Cursor
- ✅ Use Cursor's AI to address issues
- ✅ Track progress locally
- ✅ Iterate quickly

## Files Created

- `github-feedback.md` - Detailed PR feedback
- `cursor-feedback.md` - Integration guide
- `.env.github` - Configuration
- `scripts/review-pr.sh` - Convenience script

## Next Steps

1. **Run setup**: `./scripts/setup-github-integration.sh`
2. **Create a test PR** on GitHub
3. **Fetch feedback**: `./scripts/review-pr.sh <PR_NUMBER>`
4. **Review in Cursor** and make improvements
5. **Push updates** and repeat

## Troubleshooting

- **Token issues**: Check GitHub token permissions
- **Repository not found**: Verify repo owner/name
- **No feedback**: Check if Claude actually reviewed the PR
- **Script errors**: Install `jq` with `brew install jq`

## Integration with AutoClaude

This works perfectly with your existing AutoClaude setup:

1. **AutoClaude** creates projects → GitHub
2. **GitHub Actions** trigger Claude reviews
3. **Fetch script** brings feedback to Cursor
4. **Cursor** helps you improve the code
5. **Push updates** and repeat

The complete cycle: AutoClaude → GitHub → Claude Review → Local Feedback → Cursor Development → Improved Code 