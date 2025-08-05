#!/bin/bash
# AutoClaude Session Start Hook
# Initializes the sandbox environment and project structure

set -euo pipefail

# Read input from stdin
INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.sessionId')
WORKING_DIR=$(echo "$INPUT" | jq -r '.workingDirectory')

# Log session start
echo "[$(date)] Session $SESSION_ID started in $WORKING_DIR" >> .claude-code/logs/sessions.log

# Check if this is a new project (no CLAUDE.md exists)
if [ ! -f "CLAUDE.md" ]; then
    echo "Initializing new AutoClaude project..."
    
    # Create project structure if needed
    mkdir -p .claude-code/{state,backups,temp}
    
    # Initialize CLAUDE.md from template
    if [ -f "templates/CLAUDE.md" ]; then
        cp templates/CLAUDE.md CLAUDE.md
        # Replace template variables with initial values
        sed -i '' "s/{{PROJECT_NAME}}/Unnamed Project/g" CLAUDE.md
        sed -i '' "s/{{CREATED_DATE}}/$(date -u +%Y-%m-%d)/g" CLAUDE.md
        sed -i '' "s/{{SESSION_COUNT}}/1/g" CLAUDE.md
        sed -i '' "s/{{CONTEXT_PERCENTAGE}}/0/g" CLAUDE.md
    fi
    
    # Create initial state file
    cat > .claude-code/state/current.json <<EOF
{
  "sessionId": "$SESSION_ID",
  "startTime": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "phase": "initialization",
  "contextUsage": 0,
  "completedTasks": [],
  "currentTask": null
}
EOF
fi

# Check container runtime availability (prefer Podman)
CONTAINER_RUNTIME=""
if command -v podman &> /dev/null; then
    CONTAINER_RUNTIME="podman"
    echo "Podman detected. Sandbox environment available (preferred)."
    # Podman doesn't need explicit network creation for default network
elif command -v docker &> /dev/null && docker info >/dev/null 2>&1; then
    CONTAINER_RUNTIME="docker"
    echo "Docker detected and running. Sandbox environment available."
    # Ensure sandbox network exists
    docker network create autoclaude-sandbox 2>/dev/null || true
else
    echo "Warning: No working container runtime found. Sandbox features will be limited."
    if command -v docker &> /dev/null; then
        echo "Docker is installed but daemon not running. Start Docker or install Podman."
    fi
fi

# Return success with context message
SANDBOX_STATUS="limited"
if [ -n "$CONTAINER_RUNTIME" ]; then
    SANDBOX_STATUS="available ($CONTAINER_RUNTIME)"
fi

cat <<EOF
{
  "action": "continue",
  "context": "AutoClaude initialized. Project structure ready. Sandbox environment: $SANDBOX_STATUS"
}
EOF