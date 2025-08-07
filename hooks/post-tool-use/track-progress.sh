#!/bin/bash
# AutoClaude Post-Tool-Use Hook
# Tracks progress and updates project state after tool usage

set -euo pipefail

# Read input from stdin
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.toolName')
TOOL_RESULT=$(echo "$INPUT" | jq -r '.result')
SESSION_ID=$(echo "$INPUT" | jq -r '.sessionId')
WORKING_DIR=$(echo "$INPUT" | jq -r '.workingDirectory')

# Log tool usage
echo "[$(date)] Tool used: $TOOL_NAME" >> .claude-code/logs/tool-usage.log

# Update session state
if [ -f ".claude-code/state/current.json" ]; then
    # Read current state
    CURRENT_STATE=$(cat .claude-code/state/current.json)
    
    # Extract current values
    COMPLETED_TASKS=$(echo "$CURRENT_STATE" | jq -r '.completedTasks // []')
    CONTEXT_USAGE=$(echo "$CURRENT_STATE" | jq -r '.contextUsage // 0')
    
    # Update based on tool usage
    case "$TOOL_NAME" in
        "write"|"edit")
            # File was created or modified
            echo "📝 File operation detected"
            ;;
        "bash"|"run_terminal_cmd")
            # Command was executed
            echo "🔧 Command execution detected"
            ;;
        "codebase_search")
            # Code was searched
            echo "🔍 Code search detected"
            ;;
        "web_search")
            # Web search performed
            echo "🌐 Web search detected"
            ;;
        *)
            echo "🛠️ Tool usage: $TOOL_NAME"
            ;;
    esac
    
    # Estimate context usage (rough calculation)
    NEW_CONTEXT_USAGE=$((CONTEXT_USAGE + 5))
    if [ $NEW_CONTEXT_USAGE -gt 100 ]; then
        NEW_CONTEXT_USAGE=100
    fi
    
    # Update state
    cat > .claude-code/state/current.json <<EOF
{
  "sessionId": "$SESSION_ID",
  "startTime": "$(echo "$CURRENT_STATE" | jq -r '.startTime')",
  "phase": "$(echo "$CURRENT_STATE" | jq -r '.phase')",
  "contextUsage": $NEW_CONTEXT_USAGE,
  "completedTasks": $COMPLETED_TASKS,
  "currentTask": "$(echo "$CURRENT_STATE" | jq -r '.currentTask')",
  "lastToolUsed": "$TOOL_NAME",
  "lastToolTime": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
fi

# Update CLAUDE.md if it exists
if [ -f "CLAUDE.md" ]; then
    # Extract current session count
    SESSION_COUNT=$(grep -o "Total Sessions: [0-9]*" CLAUDE.md | grep -o "[0-9]*" || echo "1")
    
    # Update context usage
    sed -i '' "s/Current Context Usage: [0-9]*%/Current Context Usage: ${NEW_CONTEXT_USAGE}%/g" CLAUDE.md
    
    # Update last modified date
    sed -i '' "s/Last Updated: [0-9-]*/Last Updated: $(date -u +%Y-%m-%d)/g" CLAUDE.md
    
    # Add tool usage to session history if section exists
    if grep -q "### Session $SESSION_COUNT" CLAUDE.md; then
        # Add tool usage to session history
        sed -i '' "/### Session $SESSION_COUNT/a\\
- **Tool Used**: $TOOL_NAME at $(date -u +%Y-%m-%dT%H:%M:%SZ)\\
" CLAUDE.md
    fi
fi

# Check for context compression trigger
if [ "${NEW_CONTEXT_USAGE:-0}" -gt 80 ]; then
    echo "⚠️ Context usage high (${NEW_CONTEXT_USAGE}%). Consider compression."
    
    # Create compression trigger file
    cat > .claude-code/state/compression-triggered.json <<EOF
{
  "triggered": true,
  "contextUsage": $NEW_CONTEXT_USAGE,
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "sessionId": "$SESSION_ID"
}
EOF
fi

# Return success
cat <<EOF
{
  "action": "continue",
  "context": "Tool usage tracked. Context usage: ${NEW_CONTEXT_USAGE}%"
}
EOF