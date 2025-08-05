#!/bin/bash
# AutoClaude Pre-Tool-Use Hook
# Validates tool usage for safety and tracks operations

set -euo pipefail

# Read input from stdin
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.toolName')
TOOL_ARGS=$(echo "$INPUT" | jq -r '.arguments')

# Log tool usage attempt
echo "[$(date)] Attempting to use tool: $TOOL_NAME" >> .claude-code/logs/tools.log

# Safety checks for specific tools
case "$TOOL_NAME" in
    "Bash")
        COMMAND=$(echo "$TOOL_ARGS" | jq -r '.command // empty')
        
        # Block dangerous commands
        DANGEROUS_PATTERNS=(
            "rm -rf /"
            "format"
            "dd if=/dev/zero"
            ":(){ :|:& };:"
            "> /dev/sda"
            "chmod -R 777 /"
        )
        
        for pattern in "${DANGEROUS_PATTERNS[@]}"; do
            if [[ "$COMMAND" == *"$pattern"* ]]; then
                echo "[$(date)] BLOCKED dangerous command: $COMMAND" >> .claude-code/logs/security.log
                cat <<EOF
{
  "action": "block",
  "message": "Command blocked for safety: contains dangerous pattern '$pattern'"
}
EOF
                exit 0
            fi
        done
        
        # Warn about potentially risky commands
        RISKY_PATTERNS=("sudo" "rm -rf" "chmod 777" "curl | bash" "wget | sh")
        for pattern in "${RISKY_PATTERNS[@]}"; do
            if [[ "$COMMAND" == *"$pattern"* ]]; then
                echo "[$(date)] WARNING risky command: $COMMAND" >> .claude-code/logs/security.log
            fi
        done
        ;;
        
    "Write"|"Edit"|"MultiEdit")
        FILE_PATH=$(echo "$TOOL_ARGS" | jq -r '.file_path // .path // empty')
        
        # Ensure we're not modifying system files
        PROTECTED_PATHS=("/etc" "/usr" "/bin" "/sbin" "/System" "/Library")
        for protected in "${PROTECTED_PATHS[@]}"; do
            if [[ "$FILE_PATH" == "$protected"* ]]; then
                cat <<EOF
{
  "action": "block",
  "message": "Cannot modify system files in $protected"
}
EOF
                exit 0
            fi
        done
        ;;
esac

# Track context usage if available
if [ -f ".claude-code/state/current.json" ]; then
    # This is a simplified tracking - in production, you'd calculate actual token usage
    CURRENT_USAGE=$(jq -r '.contextUsage // 0' .claude-code/state/current.json)
    NEW_USAGE=$((CURRENT_USAGE + 100)) # Rough estimate
    
    # Update state file
    jq ".contextUsage = $NEW_USAGE" .claude-code/state/current.json > .claude-code/state/current.json.tmp
    mv .claude-code/state/current.json.tmp .claude-code/state/current.json
    
    # Warn if approaching context limit
    if [ $NEW_USAGE -gt 75000 ]; then
        echo "[$(date)] WARNING: Context usage at $NEW_USAGE tokens" >> .claude-code/logs/context.log
    fi
fi

# Allow the tool to proceed
cat <<EOF
{
  "action": "continue"
}
EOF