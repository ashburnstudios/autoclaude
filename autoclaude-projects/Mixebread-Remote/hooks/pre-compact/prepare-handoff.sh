#!/bin/bash
# AutoClaude Pre-Compact Hook
# Prepares for context compression and session handoff

set -euo pipefail

# Read input from stdin
INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.sessionId')

echo "[$(date)] Preparing for context compression in session $SESSION_ID" >> .claude-code/logs/compression.log

# Create handoff documentation
HANDOFF_FILE=".claude-code/handoff/RESUME-$(date +%Y%m%d-%H%M%S).md"
mkdir -p .claude-code/handoff

cat > "$HANDOFF_FILE" <<'EOF'
# AutoClaude Session Handoff

## Session Summary
- **Session ID**: {{SESSION_ID}}
- **Compression Time**: {{TIMESTAMP}}
- **Context Usage**: {{CONTEXT_USAGE}}%

## Current State

### Active Task
{{CURRENT_TASK}}

### Completed in This Session
{{COMPLETED_TASKS}}

### Key Decisions Made
{{KEY_DECISIONS}}

## Critical Context to Preserve

### Code Patterns Discovered
{{CODE_PATTERNS}}

### Dependencies Added
{{NEW_DEPENDENCIES}}

### Architecture Changes
{{ARCHITECTURE_CHANGES}}

## Resume Instructions

To continue this session:
```bash
claude --resume
# Or if using AutoClaude:
./scripts/resume-autonomous.sh
```

### Next Steps
1. {{NEXT_STEP_1}}
2. {{NEXT_STEP_2}}
3. {{NEXT_STEP_3}}

### Important Files Modified
{{MODIFIED_FILES}}

### Test Status
{{TEST_STATUS}}

## GitHub Sync Status
- **Last Commit**: {{LAST_COMMIT}}
- **Branch**: {{CURRENT_BRANCH}}
- **Uncommitted Changes**: {{UNCOMMITTED_CHANGES}}

## Notes for Next Session
{{HANDOFF_NOTES}}
EOF

# Fill in the template with actual data
if [ -f ".claude-code/state/current.json" ]; then
    # Get current state
    CONTEXT_USAGE=$(jq -r '.contextUsage // 0' .claude-code/state/current.json)
    CONTEXT_PERCENT=$((CONTEXT_USAGE * 100 / 100000)) # Assuming 100k token limit
    
    # Update template
    sed -i '' "s/{{SESSION_ID}}/$SESSION_ID/g" "$HANDOFF_FILE"
    sed -i '' "s/{{TIMESTAMP}}/$(date -u +%Y-%m-%dT%H:%M:%SZ)/g" "$HANDOFF_FILE"
    sed -i '' "s/{{CONTEXT_USAGE}}/$CONTEXT_PERCENT/g" "$HANDOFF_FILE"
fi

# Check git status
if command -v git &> /dev/null && [ -d ".git" ]; then
    GIT_STATUS=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "main")
    LAST_COMMIT=$(git log -1 --format="%h - %s" 2>/dev/null || echo "No commits yet")
    
    sed -i '' "s/{{UNCOMMITTED_CHANGES}}/$GIT_STATUS files/g" "$HANDOFF_FILE"
    sed -i '' "s/{{CURRENT_BRANCH}}/$CURRENT_BRANCH/g" "$HANDOFF_FILE"
    sed -i '' "s|{{LAST_COMMIT}}|$LAST_COMMIT|g" "$HANDOFF_FILE"
    
    # Auto-commit if configured and there are changes
    if [ "$GIT_STATUS" -gt 0 ] && [ "${AUTOCLAUDE_AUTO_COMMIT:-false}" = "true" ]; then
        echo "[$(date)] Auto-committing before compression" >> .claude-code/logs/git.log
        git add -A
        git commit -m "Auto-commit: Pre-compression checkpoint

Context usage: ${CONTEXT_PERCENT}%
Session: $SESSION_ID

🤖 Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>"
        
        # Push if remote is configured
        if git remote get-url origin &> /dev/null; then
            git push origin "$CURRENT_BRANCH" 2>/dev/null || \
                echo "[$(date)] Failed to push to remote" >> .claude-code/logs/git.log
        fi
    fi
fi

# Create a compressed context summary
if [ -f "CLAUDE.md" ]; then
    # Backup current CLAUDE.md
    cp CLAUDE.md ".claude-code/backups/CLAUDE-$(date +%Y%m%d-%H%M%S).md"
    
    # Add compression marker
    echo -e "\n## Context Compression Point\n- Time: $(date -u +%Y-%m-%dT%H:%M:%SZ)\n- Session: $SESSION_ID\n- Handoff: $HANDOFF_FILE" >> CLAUDE.md
fi

# Log successful preparation
echo "[$(date)] Handoff documentation created: $HANDOFF_FILE" >> .claude-code/logs/compression.log

# Return success with guidance
cat <<EOF
{
  "action": "continue",
  "context": "Context compression prepared. Handoff documentation saved to $HANDOFF_FILE. Ready to compress non-critical context while preserving essential information in CLAUDE.md."
}
EOF