#!/bin/bash
# AutoClaude Post-Tool-Use Hook
# Tracks progress and updates project state

set -euo pipefail

# Read input from stdin
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.toolName')
TOOL_RESULT=$(echo "$INPUT" | jq -r '.result // empty')
SUCCESS=$(echo "$INPUT" | jq -r '.success // true')

# Log tool completion
echo "[$(date)] Tool $TOOL_NAME completed. Success: $SUCCESS" >> .claude-code/logs/tools.log

# Update state based on tool usage
case "$TOOL_NAME" in
    "Write"|"Edit"|"MultiEdit")
        # Track file modifications
        FILE_PATH=$(echo "$INPUT" | jq -r '.arguments.file_path // .arguments.path // empty')
        if [ -n "$FILE_PATH" ] && [ "$SUCCESS" = "true" ]; then
            echo "[$(date)] Modified: $FILE_PATH" >> .claude-code/logs/modifications.log
            
            # Update CLAUDE.md if it exists
            if [ -f "CLAUDE.md" ]; then
                # Add to modification tracking (simplified - would be more sophisticated in production)
                LAST_UPDATED=$(date -u +%Y-%m-%dT%H:%M:%SZ)
                sed -i '' "s/{{LAST_UPDATED}}/.*/$LAST_UPDATED/g" CLAUDE.md 2>/dev/null || true
            fi
        fi
        ;;
        
    "Bash")
        COMMAND=$(echo "$INPUT" | jq -r '.arguments.command // empty')
        
        # Check for specific command patterns
        if [[ "$COMMAND" == *"git commit"* ]] && [ "$SUCCESS" = "true" ]; then
            echo "[$(date)] Git commit executed" >> .claude-code/logs/git.log
            
            # Extract commit hash if available
            if [[ "$TOOL_RESULT" == *"[main"* ]] || [[ "$TOOL_RESULT" == *"[master"* ]]; then
                COMMIT_HASH=$(echo "$TOOL_RESULT" | grep -oE '\[[a-zA-Z]+ [a-f0-9]+\]' | grep -oE '[a-f0-9]+' | head -1)
                if [ -n "$COMMIT_HASH" ]; then
                    echo "[$(date)] Commit: $COMMIT_HASH" >> .claude-code/logs/commits.log
                fi
            fi
        fi
        
        # Track test executions
        if [[ "$COMMAND" == *"test"* ]] || [[ "$COMMAND" == *"pytest"* ]] || [[ "$COMMAND" == *"jest"* ]]; then
            echo "[$(date)] Test execution: $COMMAND" >> .claude-code/logs/tests.log
            echo "Result: $SUCCESS" >> .claude-code/logs/tests.log
        fi
        ;;
        
    "TodoWrite")
        # Update task tracking
        echo "[$(date)] Todo list updated" >> .claude-code/logs/tasks.log
        ;;
esac

# Check if we need to trigger auto-save or compression
if [ -f ".claude-code/state/current.json" ]; then
    CONTEXT_USAGE=$(jq -r '.contextUsage // 0' .claude-code/state/current.json)
    
    # Auto-save at 50% context usage
    if [ $CONTEXT_USAGE -gt 50000 ] && [ ! -f ".claude-code/state/autosaved-50" ]; then
        echo "[$(date)] Auto-saving at 50% context usage" >> .claude-code/logs/autosave.log
        touch .claude-code/state/autosaved-50
        
        # Trigger git commit if configured
        if [ "${AUTOCLAUDE_AUTO_COMMIT:-false}" = "true" ]; then
            git add -A 2>/dev/null || true
            git commit -m "Auto-save: 50% context usage reached" 2>/dev/null || true
        fi
    fi
fi

# Return success
cat <<EOF
{
  "action": "continue"
}
EOF