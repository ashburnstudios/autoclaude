#!/bin/bash
# AutoClaude Autonomous Launch Script
# Starts a fully autonomous Claude Code session

set -euo pipefail

# Check if project description is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 \"Project description\""
    echo "Example: $0 \"Build a REST API for task management with authentication\""
    exit 1
fi

PROJECT_DESCRIPTION="$1"
SESSION_ID="auto-$(date +%Y%m%d-%H%M%S)"

echo "🤖 AutoClaude Autonomous Mode"
echo "============================"
echo "Project: $PROJECT_DESCRIPTION"
echo "Session: $SESSION_ID"
echo ""

# Source environment variables if .env exists
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

# Verify required environment variables
if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
    echo "❌ ANTHROPIC_API_KEY not set. Please add it to .env file."
    exit 1
fi

# Export session ID for hooks
export SESSION_ID
export AUTOCLAUDE_MODE=autonomous

# Create initial CLAUDE.md with project mission
echo "Initializing project memory..."
cat > CLAUDE.md <<EOF
# Project: AutoClaude Generated Project

## Mission
$PROJECT_DESCRIPTION

## Architecture Decisions
To be determined based on requirements analysis.

## Implementation Progress

### Completed ✅
- [ ] Project initialization

### In Progress 🚧
- [ ] Requirements analysis
- [ ] Technology selection

### Planned 📋
- [ ] Architecture design
- [ ] Implementation
- [ ] Testing
- [ ] Documentation

## Context Compression Points
- Session started: $(date -u +%Y-%m-%dT%H:%M:%SZ)

## Auto-Generated Metadata
- Created: $(date -u +%Y-%m-%d)
- Last Updated: $(date -u +%Y-%m-%d)
- Total Sessions: 1
- Current Context Usage: 0%
EOF

# Create initial prompt that triggers autonomous behavior
AUTONOMOUS_PROMPT=$(cat <<'EOF'
You are now in autonomous mode. Your mission is to:

1. Analyze the project requirements
2. Research and select appropriate technologies (prefer stable, well-documented options)
3. Create a detailed implementation plan
4. Set up the project structure
5. Implement the solution incrementally
6. Write comprehensive tests
7. Document your decisions in CLAUDE.md
8. Commit progress to GitHub when appropriate

Project Description: PROJECT_DESCRIPTION_PLACEHOLDER

Please begin by:
1. Creating a detailed project plan
2. Researching the best technologies for this use case
3. Setting up the initial project structure

Remember to:
- Use the TodoWrite tool to track all tasks
- Prefer stable technologies (Go, Flask, Node.js with Express)
- Research official documentation before implementing
- Commit progress at meaningful milestones
- Update CLAUDE.md with architectural decisions
- Monitor context usage and prepare for handoff if needed

Begin autonomous development now.
EOF
)

# Replace placeholder with actual project description
AUTONOMOUS_PROMPT="${AUTONOMOUS_PROMPT//PROJECT_DESCRIPTION_PLACEHOLDER/$PROJECT_DESCRIPTION}"

# Launch Claude Code with autonomous prompt
echo "Launching Claude Code in autonomous mode..."
echo ""

# Check if we should use container sandbox
CONTAINER_RUNTIME=""
if [ "${AUTOCLAUDE_USE_SANDBOX:-true}" = "true" ]; then
    # Prefer Podman over Docker
    if command -v podman &> /dev/null; then
        CONTAINER_RUNTIME="podman"
        echo "🦭 Using Podman sandbox for execution"
    elif command -v docker &> /dev/null; then
        # Check if Docker daemon is actually running
        if docker info >/dev/null 2>&1; then
            CONTAINER_RUNTIME="docker"
            echo "🐳 Using Docker sandbox for execution"
        else
            echo "⚠️  Docker found but daemon not running"
            # Check again for Podman as fallback
            if command -v podman &> /dev/null; then
                CONTAINER_RUNTIME="podman"
                echo "🦭 Falling back to Podman sandbox"
            else
                echo "⚠️  No working container runtime found. Continuing without sandbox."
                CONTAINER_RUNTIME=""
            fi
        fi
    fi
    
    if [ -n "$CONTAINER_RUNTIME" ]; then
        # Start sandbox container
        cd docker
        
        if [ "$CONTAINER_RUNTIME" = "podman" ]; then
            # Use podman-compose if available
            if command -v podman-compose &> /dev/null; then
                podman-compose up -d autoclaude-sandbox
            else
                # Run with podman directly
                podman run -d \
                    --name autoclaude-dev \
                    --hostname autoclaude-sandbox \
                    -v "$(pwd)/../:/home/claude/autoclaude:ro" \
                    -v "autoclaude-workspace:/home/claude/workspace" \
                    -e "AUTOCLAUDE_SANDBOX=true" \
                    -e "SESSION_ID=$SESSION_ID" \
                    --rm \
                    autoclaude/sandbox:latest \
                    tail -f /dev/null
            fi
        else
            docker compose up -d autoclaude-sandbox
        fi
        
        cd ..
        
        # Wait for container to be ready
        sleep 2
        
        # Execute Claude Code with sandbox context
        SANDBOX_CONTEXT=" Use the container sandbox 'autoclaude-dev' for any code execution or testing."
    else
        SANDBOX_CONTEXT=""
    fi
else
    SANDBOX_CONTEXT=""
fi

# Create a wrapper script that will be used by Claude Code
cat > .claude-code/temp/autonomous-wrapper.sh <<EOF
#!/bin/bash
# This script ensures AutoClaude mode is maintained

export AUTOCLAUDE_MODE=autonomous
export SESSION_ID=$SESSION_ID

# Execute the original command
"\$@"
EOF
chmod +x .claude-code/temp/autonomous-wrapper.sh

# Launch Claude Code with the autonomous prompt
if [ "${AUTOCLAUDE_INTERACTIVE:-false}" = "true" ]; then
    # Interactive mode - allows human oversight
    claude --config-dir .claude-code/config \
           --continue \
           "${AUTONOMOUS_PROMPT}${SANDBOX_CONTEXT}"
else
    # Non-interactive mode - fully autonomous
    claude --config-dir .claude-code/config \
           --no-interactive \
           --max-tokens 100000 \
           "${AUTONOMOUS_PROMPT}${SANDBOX_CONTEXT}" \
           2>&1 | tee ".claude-code/logs/session-$SESSION_ID.log"
fi

# Session completed
echo ""
echo "✅ Autonomous session completed"
echo "Session ID: $SESSION_ID"
echo "Log file: .claude-code/logs/session-$SESSION_ID.log"

# Clean up container sandbox if used
if [ "${AUTOCLAUDE_USE_SANDBOX:-true}" = "true" ] && [ -n "$CONTAINER_RUNTIME" ]; then
    echo "Cleaning up container sandbox..."
    cd docker
    
    if [ "$CONTAINER_RUNTIME" = "podman" ]; then
        if command -v podman-compose &> /dev/null; then
            podman-compose down
        else
            podman stop autoclaude-dev 2>/dev/null || true
            podman rm autoclaude-dev 2>/dev/null || true
        fi
    else
        docker compose down
    fi
    
    cd ..
fi

# Show summary
echo ""
echo "📊 Session Summary:"
echo "=================="
if [ -f CLAUDE.md ]; then
    echo "Project status saved in CLAUDE.md"
    grep -A 5 "## Implementation Progress" CLAUDE.md || true
fi

if [ -f .claude-code/handoff/RESUME-*.md ]; then
    echo ""
    echo "📋 Handoff documentation created for session continuation"
fi

echo ""
echo "To continue this session later, run:"
echo "  claude --resume"