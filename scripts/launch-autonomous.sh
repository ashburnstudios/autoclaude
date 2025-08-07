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

# Load authentication
SECRETS_FILE="$HOME/.autoclaude/secrets"
if [ -f "$SECRETS_FILE" ]; then
    # Check auth method
    if grep -q "AUTH_METHOD=claude_max" "$SECRETS_FILE"; then
        echo "✅ Using Claude Max authentication"
        # No API key needed!
    elif grep -q "AUTH_METHOD=api_key" "$SECRETS_FILE"; then
        # Load API key securely
        source "$SECRETS_FILE"
        export ANTHROPIC_API_KEY
    fi
else
    echo "⚠️  No authentication configured"
    echo ""
    echo "Please run: autoclaude-manage-secrets setup"
    echo ""
    echo "Options:"
    echo "1) Claude Max (recommended) - No API key needed"
    echo "2) API Key - For non-Claude Max users"
    exit 1
fi

# Source project .env if exists (for other variables)
if [ -f .env ]; then
    export $(grep -v '^#' .env | grep -v 'ANTHROPIC_API_KEY' | xargs)
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
You are now in autonomous mode with enhanced intelligence. Your mission is to:

## 🎯 Core Mission
1. **Analyze Requirements**: Deeply understand the project requirements and constraints
2. **Research & Select Technologies**: Choose optimal technologies based on stability, documentation, and LLM compatibility
3. **Create Detailed Plan**: Develop a comprehensive implementation roadmap
4. **Implement Incrementally**: Build the solution step-by-step with testing
5. **Document Decisions**: Maintain detailed architectural decisions in CLAUDE.md
6. **Commit Progress**: Save meaningful milestones to version control

## 🧠 Enhanced Decision Framework

### Technology Selection Criteria:
- **Stability First**: Prefer mature, well-documented technologies
- **LLM Compatibility**: Choose frameworks that work well with AI code generation
- **Community Support**: Prioritize active communities and good documentation
- **Performance**: Consider scalability and performance requirements
- **Security**: Implement security best practices from the start

### Recommended Technology Stack (by use case):
- **Web APIs**: Flask (Python), Express.js (Node.js), or Go with Gin
- **Frontend**: React with TypeScript, or vanilla JS for simple projects
- **Database**: SQLite for development, PostgreSQL for production
- **Authentication**: JWT tokens, OAuth2 for external auth
- **Testing**: pytest (Python), Jest (Node.js), or built-in testing
- **Documentation**: OpenAPI/Swagger for APIs, README.md for projects

### Research Protocol:
1. **Official Documentation**: Always start with official docs
2. **Best Practices**: Research industry standards and patterns
3. **Security Considerations**: Look for security guidelines
4. **Performance Patterns**: Find optimization strategies
5. **Testing Strategies**: Understand testing approaches

## 📋 Implementation Workflow

### Phase 1: Analysis & Planning (15 minutes)
- [ ] Analyze project requirements thoroughly
- [ ] Research appropriate technologies
- [ ] Create detailed project plan
- [ ] Set up project structure
- [ ] Initialize version control

### Phase 2: Core Implementation (45 minutes)
- [ ] Implement core functionality
- [ ] Add comprehensive tests
- [ ] Handle error cases
- [ ] Implement security measures
- [ ] Add logging and monitoring

### Phase 3: Polish & Documentation (15 minutes)
- [ ] Write comprehensive documentation
- [ ] Create usage examples
- [ ] Add deployment instructions
- [ ] Update CLAUDE.md with decisions
- [ ] Commit final version

## 🔧 Tool Usage Guidelines

### Always Use:
- **TodoWrite**: Track all tasks and progress
- **Codebase Search**: Find relevant patterns and examples
- **Web Search**: Research official documentation and best practices
- **File Operations**: Create and modify project files systematically

### Context Management:
- Monitor context usage continuously
- Prepare handoff documentation when approaching limits
- Use compression strategies to maintain session continuity
- Save critical decisions to CLAUDE.md

## 📝 Documentation Standards

### CLAUDE.md Updates:
- **Architecture Decisions**: Document technology choices and reasoning
- **Implementation Progress**: Track completed, in-progress, and planned tasks
- **Context Compression**: Note when sessions are compressed or handed off
- **Lessons Learned**: Record patterns and insights discovered

### Code Documentation:
- **README.md**: Comprehensive project overview
- **API Documentation**: OpenAPI specs for web services
- **Inline Comments**: Explain complex logic and decisions
- **Setup Instructions**: Clear installation and usage guides

## 🚀 Execution Protocol

Project Description: PROJECT_DESCRIPTION_PLACEHOLDER

**Begin autonomous development now with this enhanced framework.**

Remember:
- Think systematically and document your reasoning
- Research before implementing
- Test thoroughly at each step
- Commit progress at meaningful milestones
- Maintain high code quality and security standards
- Update CLAUDE.md with all architectural decisions

Start with Phase 1: Analysis & Planning
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
    # Check for explicit runtime preference
    if [ -n "${AUTOCLAUDE_CONTAINER_RUNTIME:-}" ]; then
        case "${AUTOCLAUDE_CONTAINER_RUNTIME}" in
            docker)
                if command -v docker &> /dev/null && docker info >/dev/null 2>&1; then
                    CONTAINER_RUNTIME="docker"
                    echo "🐳 Using Docker sandbox (forced by configuration)"
                else
                    echo "❌ Docker requested but not available or not running"
                    exit 1
                fi
                ;;
            podman)
                if command -v podman &> /dev/null; then
                    CONTAINER_RUNTIME="podman"
                    echo "🦭 Using Podman sandbox (forced by configuration)"
                else
                    echo "❌ Podman requested but not available"
                    exit 1
                fi
                ;;
            *)
                echo "❌ Invalid AUTOCLAUDE_CONTAINER_RUNTIME: ${AUTOCLAUDE_CONTAINER_RUNTIME}"
                echo "   Valid options: docker, podman"
                exit 1
                ;;
        esac
    else
        # Auto-detect: Check Docker first on macOS for better compatibility
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # On macOS, prefer Docker if it's running
            if command -v docker &> /dev/null && docker info >/dev/null 2>&1; then
                CONTAINER_RUNTIME="docker"
                echo "🐳 Using Docker sandbox for execution"
            elif command -v podman &> /dev/null && podman machine list --format "{{.State}}" | grep -q "running"; then
                CONTAINER_RUNTIME="podman"
                echo "🦭 Using Podman sandbox for execution"
            else
                echo "⚠️  No working container runtime found. Continuing without sandbox."
                CONTAINER_RUNTIME=""
            fi
        else
            # On Linux, prefer Podman
            if command -v podman &> /dev/null; then
                CONTAINER_RUNTIME="podman"
                echo "🦭 Using Podman sandbox for execution"
            elif command -v docker &> /dev/null && docker info >/dev/null 2>&1; then
                CONTAINER_RUNTIME="docker"
                echo "🐳 Using Docker sandbox for execution"
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
mkdir -p .claude-code/temp
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