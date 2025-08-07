#!/bin/bash
# AutoClaude Project Analysis Script
# Provides comprehensive analysis of project progress and metrics

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

echo -e "${CYAN}${BOLD}AutoClaude Project Analysis${NC}"
echo "=========================="
echo ""

# Check if we're in a project directory
if [ ! -f "CLAUDE.md" ]; then
    echo -e "${RED}❌ Not in an AutoClaude project directory${NC}"
    echo "Please run this script from a project directory with CLAUDE.md"
    exit 1
fi

# Extract project information from CLAUDE.md
PROJECT_NAME=$(grep "^# Project:" CLAUDE.md | sed 's/# Project: //')
MISSION=$(grep -A 1 "## 🎯 Mission" CLAUDE.md | tail -n 1 | sed 's/^[[:space:]]*//')
CREATED_DATE=$(grep "Created:" CLAUDE.md | head -n 1 | grep -o '[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}')
SESSION_COUNT=$(grep "Total Sessions:" CLAUDE.md | grep -o '[0-9]*')
CONTEXT_USAGE=$(grep "Current Context Usage:" CLAUDE.md | grep -o '[0-9]*%')

echo -e "${BOLD}Project Overview:${NC}"
echo "=================="
echo -e "Name: ${GREEN}$PROJECT_NAME${NC}"
echo -e "Mission: ${YELLOW}$MISSION${NC}"
echo -e "Created: ${BLUE}$CREATED_DATE${NC}"
echo -e "Sessions: ${CYAN}$SESSION_COUNT${NC}"
echo -e "Context Usage: ${YELLOW}$CONTEXT_USAGE${NC}"
echo ""

# Analyze project structure
echo -e "${BOLD}Project Structure Analysis:${NC}"
echo "=========================="

# Count files by type
echo -e "${CYAN}File Distribution:${NC}"
if [ -d . ]; then
    echo "📁 Directories: $(find . -type d -not -path './.git*' -not -path './node_modules*' | wc -l | tr -d ' ')"
    echo "📄 Total Files: $(find . -type f -not -path './.git*' -not -path './node_modules*' | wc -l | tr -d ' ')"
    
    # Language-specific counts
    if [ -f "$(find . -name "*.py" | head -n 1)" ]; then
        echo "🐍 Python Files: $(find . -name "*.py" | wc -l | tr -d ' ')"
    fi
    if [ -f "$(find . -name "*.js" | head -n 1)" ]; then
        echo "🟨 JavaScript Files: $(find . -name "*.js" | wc -l | tr -d ' ')"
    fi
    if [ -f "$(find . -name "*.go" | head -n 1)" ]; then
        echo "🔵 Go Files: $(find . -name "*.go" | wc -l | tr -d ' ')"
    fi
    if [ -f "$(find . -name "*.md" | head -n 1)" ]; then
        echo "📝 Markdown Files: $(find . -name "*.md" | wc -l | tr -d ' ')"
    fi
    if [ -f "$(find . -name "*.json" | head -n 1)" ]; then
        echo "📋 JSON Files: $(find . -name "*.json" | wc -l | tr -d ' ')"
    fi
fi
echo ""

# Git analysis
echo -e "${CYAN}Git Analysis:${NC}"
if [ -d .git ]; then
    echo "✅ Git repository initialized"
    BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
    echo "🌿 Current Branch: $BRANCH"
    
    # Count commits
    COMMIT_COUNT=$(git rev-list --count HEAD 2>/dev/null || echo "0")
    echo "📝 Total Commits: $COMMIT_COUNT"
    
    # Recent activity
    echo "🕒 Recent Activity:"
    git log --oneline -5 2>/dev/null || echo "No commits yet"
    
    # Check for uncommitted changes
    if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
        echo -e "⚠️  ${YELLOW}Uncommitted changes detected${NC}"
        git status --short
    else
        echo -e "✅ ${GREEN}Working directory clean${NC}"
    fi
else
    echo "❌ Git repository not initialized"
fi
echo ""

# Container runtime analysis
echo -e "${CYAN}Container Runtime:${NC}"
if command -v podman &> /dev/null; then
    echo "✅ Podman available"
    if podman ps | grep -q autoclaude; then
        echo "🟢 AutoClaude containers running"
    else
        echo "⚪ No AutoClaude containers running"
    fi
elif command -v docker &> /dev/null && docker info >/dev/null 2>&1; then
    echo "✅ Docker available and running"
    if docker ps | grep -q autoclaude; then
        echo "🟢 AutoClaude containers running"
    else
        echo "⚪ No AutoClaude containers running"
    fi
else
    echo "❌ No container runtime available"
fi
echo ""

# Progress analysis from CLAUDE.md
echo -e "${BOLD}Progress Analysis:${NC}"
echo "=================="

# Extract completed tasks
COMPLETED_COUNT=$(grep -c "✅" CLAUDE.md || echo "0")
IN_PROGRESS_COUNT=$(grep -c "🚧" CLAUDE.md || echo "0")
PLANNED_COUNT=$(grep -c "📋" CLAUDE.md || echo "0")

echo -e "${GREEN}✅ Completed Tasks: $COMPLETED_COUNT${NC}"
echo -e "${YELLOW}🚧 In Progress: $IN_PROGRESS_COUNT${NC}"
echo -e "${BLUE}📋 Planned: $PLANNED_COUNT${NC}"

# Calculate progress percentage
TOTAL_TASKS=$((COMPLETED_COUNT + IN_PROGRESS_COUNT + PLANNED_COUNT))
if [ $TOTAL_TASKS -gt 0 ]; then
    PROGRESS_PERCENT=$((COMPLETED_COUNT * 100 / TOTAL_TASKS))
    echo -e "${CYAN}📊 Overall Progress: ${PROGRESS_PERCENT}%${NC}"
else
    echo -e "${CYAN}📊 Overall Progress: 0%${NC}"
fi
echo ""

# Session analysis
echo -e "${BOLD}Session Analysis:${NC}"
echo "=================="

if [ -d .claude-code/logs ]; then
    LOG_COUNT=$(find .claude-code/logs -name "*.log" | wc -l | tr -d ' ')
    echo "📋 Log Files: $LOG_COUNT"
    
    # Show recent log files
    echo "🕒 Recent Logs:"
    find .claude-code/logs -name "*.log" -exec basename {} \; | tail -5
else
    echo "❌ No logs directory found"
fi

# State analysis
if [ -f .claude-code/state/current.json ]; then
    echo ""
    echo -e "${CYAN}Current Session State:${NC}"
    jq -r '. | "Phase: \(.phase)\nContext Usage: \(.contextUsage)%\nLast Tool: \(.lastToolUsed // "None")"' .claude-code/state/current.json 2>/dev/null || echo "Invalid state file"
fi

# Check for compression triggers
if [ -f .claude-code/state/compression-triggered.json ]; then
    echo ""
    echo -e "${YELLOW}⚠️  Context compression triggered${NC}"
    jq -r '. | "Usage: \(.contextUsage)%\nTime: \(.timestamp)"' .claude-code/state/compression-triggered.json
fi

# Code quality analysis
echo ""
echo -e "${BOLD}Code Quality Analysis:${NC}"
echo "========================"

# Check for common files
if [ -f "requirements.txt" ] || [ -f "package.json" ] || [ -f "go.mod" ]; then
    echo "✅ Dependencies file found"
else
    echo "⚠️  No dependencies file found"
fi

if [ -f "README.md" ]; then
    echo "✅ README.md found"
else
    echo "❌ README.md missing"
fi

if [ -f ".gitignore" ]; then
    echo "✅ .gitignore found"
else
    echo "⚠️  .gitignore missing"
fi

# Test files
TEST_FILES=$(find . -name "*test*" -o -name "*spec*" | grep -v node_modules | wc -l | tr -d ' ')
if [ $TEST_FILES -gt 0 ]; then
    echo "✅ Test files found: $TEST_FILES"
else
    echo "❌ No test files found"
fi

# Security analysis
echo ""
echo -e "${BOLD}Security Analysis:${NC}"
echo "=================="

# Check for common security issues
if find . -name "*.py" -exec grep -l "password.*=" {} \; 2>/dev/null | head -1; then
    echo -e "${RED}⚠️  Hardcoded passwords detected in Python files${NC}"
else
    echo "✅ No hardcoded passwords detected"
fi

if find . -name "*.js" -exec grep -l "password.*=" {} \; 2>/dev/null | head -1; then
    echo -e "${RED}⚠️  Hardcoded passwords detected in JavaScript files${NC}"
else
    echo "✅ No hardcoded passwords detected"
fi

# Check for .env files
if [ -f ".env" ]; then
    echo -e "${YELLOW}⚠️  .env file found (check if it's in .gitignore)${NC}"
else
    echo "✅ No .env file (good for security)"
fi

# Recommendations
echo ""
echo -e "${BOLD}Recommendations:${NC}"
echo "================"

if [ $COMPLETED_COUNT -eq 0 ]; then
    echo "🚀 Start implementing core functionality"
fi

if [ ! -f "README.md" ]; then
    echo "📝 Create a comprehensive README.md"
fi

if [ $TEST_FILES -eq 0 ]; then
    echo "🧪 Add test files for better code quality"
fi

if [ ! -f ".gitignore" ]; then
    echo "📋 Create a .gitignore file"
fi

if [ "${CONTEXT_USAGE%\%}" -gt 80 ]; then
    echo "🔄 Consider context compression or session handoff"
fi

echo ""
echo -e "${GREEN}✅ Analysis complete!${NC}"
echo ""
echo "To continue development:"
echo "  autoclaude                    # Open project menu"
echo "  ./scripts/launch-autonomous.sh # Start autonomous session"
echo "  claude --resume              # Resume previous session" 