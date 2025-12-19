#!/bin/bash
# AutoClaude Interactive Menu System
# Main entry point for all AutoClaude operations

set -euo pipefail

# Colors for better UI
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# AutoClaude configuration file
AUTOCLAUDE_CONFIG="${HOME}/.autoclaude/config"
AUTOCLAUDE_PROJECTS="${HOME}/.autoclaude/projects"

# Create config directory if it doesn't exist
mkdir -p "${HOME}/.autoclaude"

# Banner
show_banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "     _         _         ____ _                 _"
    echo "    / \  _   _| |_ ___  / ___| | __ _ _   _  __| | ___"
    echo "   / _ \| | | | __/ _ \| |   | |/ _\` | | | |/ _\` |/ _ \\"
    echo "  / ___ \ |_| | || (_) | |___| | (_| | |_| | (_| |  __/"
    echo " /_/   \_\__,_|\__\___/ \____|_|\__,_|\__,_|\__,_|\___|"
    echo -e "${NC}"
    echo -e "${BLUE}Autonomous Claude Code System${NC}"
    echo -e "${YELLOW}========================================${NC}"
    echo ""
}

# Load or create configuration
load_config() {
    if [ -f "$AUTOCLAUDE_CONFIG" ]; then
        source "$AUTOCLAUDE_CONFIG"
    else
        # Create default config
        cat > "$AUTOCLAUDE_CONFIG" <<EOF
# AutoClaude Configuration
AUTOCLAUDE_WORKSPACE="${HOME}/autoclaude-projects"
AUTOCLAUDE_DEFAULT_RUNTIME="auto"  # auto, docker, or podman
AUTOCLAUDE_AUTO_COMMIT="true"
AUTOCLAUDE_USE_SANDBOX="true"
EOF
        source "$AUTOCLAUDE_CONFIG"
    fi
    
    # Export runtime preference if not auto
    if [ "${AUTOCLAUDE_DEFAULT_RUNTIME}" != "auto" ]; then
        export AUTOCLAUDE_CONTAINER_RUNTIME="${AUTOCLAUDE_DEFAULT_RUNTIME}"
    fi
}

# Save configuration
save_config() {
    cat > "$AUTOCLAUDE_CONFIG" <<EOF
# AutoClaude Configuration
AUTOCLAUDE_WORKSPACE="${AUTOCLAUDE_WORKSPACE}"
AUTOCLAUDE_DEFAULT_RUNTIME="${AUTOCLAUDE_DEFAULT_RUNTIME}"
AUTOCLAUDE_AUTO_COMMIT="${AUTOCLAUDE_AUTO_COMMIT}"
AUTOCLAUDE_USE_SANDBOX="${AUTOCLAUDE_USE_SANDBOX}"
EOF
}

# Per-project configuration file
PROJECT_CONFIG_FILE=".autoclaude.json"

# Get a value from project config (requires jq, falls back to grep)
get_project_config() {
    local key="$1"
    local config_file="${2:-$PROJECT_CONFIG_FILE}"

    if [ ! -f "$config_file" ]; then
        return 1
    fi

    if command -v jq &> /dev/null; then
        jq -r ".$key // empty" "$config_file" 2>/dev/null
    else
        # Fallback: simple grep for "key": "value" pattern
        grep -oP "\"$key\"[[:space:]]*:[[:space:]]*\"\\K[^\"]*" "$config_file" 2>/dev/null
    fi
}

# Set a value in project config
set_project_config() {
    local key="$1"
    local value="$2"
    local config_file="${3:-$PROJECT_CONFIG_FILE}"

    if command -v jq &> /dev/null; then
        if [ -f "$config_file" ]; then
            local tmp=$(mktemp)
            jq ".$key = \"$value\"" "$config_file" > "$tmp" && mv "$tmp" "$config_file"
        else
            echo "{\"$key\": \"$value\"}" | jq '.' > "$config_file"
        fi
    else
        # Fallback: simple JSON write (won't merge, just overwrites)
        if [ -f "$config_file" ]; then
            # Try to preserve existing values (basic approach)
            local existing=$(cat "$config_file" | tr -d '\n' | sed 's/}$//')
            if [ "$existing" = "{" ]; then
                echo "{\"$key\": \"$value\"}" > "$config_file"
            else
                echo "${existing}, \"$key\": \"$value\"}" > "$config_file"
            fi
        else
            echo "{\"$key\": \"$value\"}" > "$config_file"
        fi
    fi
}

# Project management functions
list_projects() {
    if [ -f "$AUTOCLAUDE_PROJECTS" ]; then
        echo -e "${CYAN}Existing Projects:${NC}"
        echo "=================="
        local i=1
        while IFS='|' read -r name path description; do
            echo -e "${GREEN}$i)${NC} ${BOLD}$name${NC}"
            echo "   Path: $path"
            echo "   Description: $description"
            echo ""
            ((i++))
        done < "$AUTOCLAUDE_PROJECTS"
    else
        echo -e "${YELLOW}No existing projects found.${NC}"
    fi
}

# Add project to registry
register_project() {
    local name="$1"
    local path="$2"
    local description="$3"
    
    echo "${name}|${path}|${description}" >> "$AUTOCLAUDE_PROJECTS"
}

# Check if project name exists
project_exists() {
    local name="$1"
    if [ -f "$AUTOCLAUDE_PROJECTS" ]; then
        grep -q "^${name}|" "$AUTOCLAUDE_PROJECTS"
    else
        return 1
    fi
}

# Get project path by name
get_project_path() {
    local name="$1"
    if [ -f "$AUTOCLAUDE_PROJECTS" ]; then
        grep "^${name}|" "$AUTOCLAUDE_PROJECTS" | cut -d'|' -f2
    fi
}

# Main menu
main_menu() {
    while true; do
        show_banner
        echo -e "${CYAN}Main Menu:${NC}"
        echo "1) Start New Project"
        echo "2) Open Existing Project"
        echo "3) Setup AutoClaude"
        echo "4) Check System Status"
        echo "5) Configuration"
        echo "6) Help & Documentation"
        echo "0) Exit"
        echo ""
        read -p "Select an option: " choice
        
        case $choice in
            1) new_project_menu ;;
            2) existing_project_menu ;;
            3) setup_autoclaude ;;
            4) check_status ;;
            5) configuration_menu ;;
            6) help_menu ;;
            0) exit 0 ;;
            *) echo -e "${RED}Invalid option${NC}"; sleep 2 ;;
        esac
    done
}

# New project menu
new_project_menu() {
    show_banner
    echo -e "${CYAN}Create New Project${NC}"
    echo "=================="
    echo ""
    
    # Get project name
    read -p "Project name (alphanumeric, hyphens, underscores): " project_name
    
    # Validate project name
    if [[ ! "$project_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo -e "${RED}Invalid project name. Use only letters, numbers, hyphens, and underscores.${NC}"
        sleep 3
        return
    fi
    
    # Check if project already exists
    if project_exists "$project_name"; then
        echo -e "${RED}Project '$project_name' already exists!${NC}"
        sleep 3
        return
    fi
    
    # Get project description
    read -p "Project description: " project_description
    
    # Get workspace location
    echo ""
    echo "Where should the project be created?"
    echo "1) Default workspace ($AUTOCLAUDE_WORKSPACE)"
    echo "2) Current directory ($(pwd))"
    echo "3) Custom location"
    read -p "Select location (1-3): " location_choice
    
    case $location_choice in
        1)
            project_path="${AUTOCLAUDE_WORKSPACE}/${project_name}"
            mkdir -p "$AUTOCLAUDE_WORKSPACE"
            ;;
        2)
            project_path="$(pwd)/${project_name}"
            ;;
        3)
            read -p "Enter full path: " custom_path
            # Expand tilde if present
            custom_path="${custom_path/#\~/$HOME}"
            project_path="${custom_path}/${project_name}"
            ;;
        *)
            echo -e "${RED}Invalid choice${NC}"
            sleep 2
            return
            ;;
    esac
    
    # Create project directory
    if [ -d "$project_path" ]; then
        echo -e "${RED}Directory already exists: $project_path${NC}"
        read -p "Use existing directory? (y/n): " use_existing
        if [[ ! "$use_existing" =~ ^[Yy]$ ]]; then
            return
        fi
    else
        mkdir -p "$project_path"
    fi
    
    # Copy AutoClaude files from installation directory
    echo -e "${YELLOW}Setting up AutoClaude in project...${NC}"
    
    # Get the AutoClaude installation directory
    AUTOCLAUDE_INSTALL_DIR=""
    if [ -n "${AUTOCLAUDE_HOME:-}" ]; then
        AUTOCLAUDE_INSTALL_DIR="$AUTOCLAUDE_HOME"
    elif [ -d "$(dirname "$0")/hooks" ]; then
        AUTOCLAUDE_INSTALL_DIR="$(dirname "$0")"
    else
        # Try to find it from the wrapper
        if [ -f "/usr/local/bin/autoclaude" ]; then
            AUTOCLAUDE_INSTALL_DIR=$(grep "^AUTOCLAUDE_HOME=" /usr/local/bin/autoclaude | cut -d'"' -f2)
        fi
    fi
    
    if [ -z "$AUTOCLAUDE_INSTALL_DIR" ] || [ ! -d "$AUTOCLAUDE_INSTALL_DIR/hooks" ]; then
        echo -e "${RED}Cannot find AutoClaude installation files${NC}"
        echo "Please run from AutoClaude directory or set AUTOCLAUDE_HOME"
        return
    fi
    
    # Copy files from installation directory
    cp -r "$AUTOCLAUDE_INSTALL_DIR/hooks" "$project_path/"
    cp -r "$AUTOCLAUDE_INSTALL_DIR/docker" "$project_path/"
    cp -r "$AUTOCLAUDE_INSTALL_DIR/templates" "$project_path/"
    cp -r "$AUTOCLAUDE_INSTALL_DIR/scripts" "$project_path/"
    mkdir -p "$project_path/.claude-code"
    
    # Create project-specific CLAUDE.md
    cat > "$project_path/CLAUDE.md" <<EOF
# Project: $project_name

## Mission
$project_description

## Project Information
- Created: $(date -u +%Y-%m-%d)
- AutoClaude Version: 1.0.0
- Location: $project_path

## Architecture Decisions
To be determined based on requirements analysis.

## Implementation Progress

### Completed ✅
- [ ] Project initialization

### In Progress 🚧
- [ ] Requirements analysis

### Planned 📋
- [ ] Technology selection
- [ ] Implementation
- [ ] Testing
- [ ] Documentation

## Auto-Generated Metadata
- Created: $(date -u +%Y-%m-%d)
- Last Updated: $(date -u +%Y-%m-%d)
- Total Sessions: 0
- Current Context Usage: 0%
EOF
    
    # Register project
    register_project "$project_name" "$project_path" "$project_description"
    
    echo -e "${GREEN}✅ Project created successfully!${NC}"
    echo "Location: $project_path"
    echo ""
    read -p "Launch project now? (y/n): " launch_now
    
    if [[ "$launch_now" =~ ^[Yy]$ ]]; then
        cd "$project_path"
        launch_project_menu "$project_name" "$project_path"
    fi
}

# Existing project menu
existing_project_menu() {
    show_banner
    echo -e "${CYAN}Open Existing Project${NC}"
    echo "====================="
    echo ""
    
    if [ ! -f "$AUTOCLAUDE_PROJECTS" ] || [ ! -s "$AUTOCLAUDE_PROJECTS" ]; then
        echo -e "${YELLOW}No projects found.${NC}"
        echo ""
        echo "Options:"
        echo "1) Import project from directory"
        echo "2) Return to main menu"
        read -p "Select option: " import_choice
        
        if [ "$import_choice" = "1" ]; then
            import_project
        fi
        return
    fi
    
    # List projects
    list_projects
    
    # Count projects
    local project_count=$(wc -l < "$AUTOCLAUDE_PROJECTS")
    
    echo "Select project (1-$project_count) or 0 to return: "
    read -p "> " project_choice
    
    if [ "$project_choice" = "0" ]; then
        return
    fi
    
    # Get selected project
    local selected_project=$(sed -n "${project_choice}p" "$AUTOCLAUDE_PROJECTS")
    if [ -z "$selected_project" ]; then
        echo -e "${RED}Invalid selection${NC}"
        sleep 2
        return
    fi
    
    local project_name=$(echo "$selected_project" | cut -d'|' -f1)
    local project_path=$(echo "$selected_project" | cut -d'|' -f2)
    
    if [ ! -d "$project_path" ]; then
        echo -e "${RED}Project directory not found: $project_path${NC}"
        read -p "Remove from list? (y/n): " remove_project
        if [[ "$remove_project" =~ ^[Yy]$ ]]; then
            grep -v "^${project_name}|" "$AUTOCLAUDE_PROJECTS" > "$AUTOCLAUDE_PROJECTS.tmp"
            mv "$AUTOCLAUDE_PROJECTS.tmp" "$AUTOCLAUDE_PROJECTS"
        fi
        return
    fi
    
    cd "$project_path"
    launch_project_menu "$project_name" "$project_path"
}

# Project launch menu
launch_project_menu() {
    local project_name="$1"
    local project_path="$2"
    
    while true; do
        show_banner
        echo -e "${CYAN}Project: ${BOLD}$project_name${NC}"
        echo "Path: $project_path"
        echo "=================="
        echo ""
        echo "1) Launch Autonomous Development"
        echo "2) Resume Previous Session"
        echo "3) Interactive Claude Session"
        echo "4) View Project Status"
        echo "5) Run Tests"
        echo "6) Git Operations"
        echo "7) Container Management"
        echo "0) Return to Main Menu"
        echo ""
        read -p "Select action: " action
        
        case $action in
            1) launch_autonomous ;;
            2) resume_session ;;
            3) interactive_session ;;
            4) project_status ;;
            5) run_tests ;;
            6) git_menu ;;
            7) container_menu ;;
            0) cd - > /dev/null; return ;;
            *) echo -e "${RED}Invalid option${NC}"; sleep 2 ;;
        esac
    done
}

# Launch autonomous development
launch_autonomous() {
    echo ""
    read -p "Enter project mission/description: " mission
    
    if [ -z "$mission" ]; then
        echo -e "${RED}Mission description required${NC}"
        sleep 2
        return
    fi
    
    echo -e "${YELLOW}Launching autonomous development...${NC}"
    ./scripts/launch-autonomous.sh "$mission"
    
    echo ""
    read -p "Press Enter to continue..."
}

# Resume session
resume_session() {
    echo -e "${YELLOW}Resuming previous session...${NC}"
    claude --resume
    
    echo ""
    read -p "Press Enter to continue..."
}

# Interactive session
interactive_session() {
    echo -e "${YELLOW}Starting interactive Claude session...${NC}"
    claude --continue
    
    echo ""
    read -p "Press Enter to continue..."
}

# Project status
project_status() {
    show_banner
    echo -e "${CYAN}Project Status${NC}"
    echo "=============="
    echo ""
    
    # Git status
    if [ -d .git ]; then
        echo -e "${YELLOW}Git Status:${NC}"
        git status -s
        echo ""
        
        echo -e "${YELLOW}Recent Commits:${NC}"
        git log --oneline -5
        echo ""
    fi
    
    # Check for CLAUDE.md
    if [ -f CLAUDE.md ]; then
        echo -e "${YELLOW}Project Progress:${NC}"
        grep -A 10 "## Implementation Progress" CLAUDE.md || echo "No progress tracking found"
        echo ""
    fi
    
    # Check for logs
    if [ -d .claude-code/logs ]; then
        echo -e "${YELLOW}Recent Activity:${NC}"
        find .claude-code/logs -type f -name "*.log" -exec basename {} \; | head -5
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

# Run tests
run_tests() {
    show_banner
    echo -e "${CYAN}Run Tests${NC}"
    echo "========="
    echo ""

    local test_found=false
    local saved_cmd=$(get_project_config "testCommand")

    # Check for saved test command
    if [ -n "$saved_cmd" ]; then
        echo -e "${GREEN}Saved test command:${NC} $saved_cmd"
        echo ""
        echo "1) Run saved command"
        echo "2) Reconfigure"
        echo "0) Cancel"
        echo ""
        read -p "Select option: " saved_choice

        case $saved_choice in
            1)
                echo ""
                echo "Running: $saved_cmd"
                echo ""
                if eval "$saved_cmd"; then
                    echo ""
                    echo -e "${GREEN}Tests passed${NC}"
                else
                    echo ""
                    echo -e "${RED}Tests failed (exit code: $?)${NC}"
                fi
                echo ""
                read -p "Press Enter to continue..."
                return
                ;;
            2)
                # Fall through to detection
                echo ""
                ;;
            *)
                return
                ;;
        esac
    fi

    # Auto-detect and run appropriate test framework
    if [ -f "package.json" ]; then
        # Extract all test-related scripts from package.json
        local test_scripts=()
        while IFS= read -r script; do
            [ -n "$script" ] && test_scripts+=("$script")
        done < <(grep -oE '"test[^"]*"[[:space:]]*:' package.json | sed 's/"//g; s/[[:space:]]*:$//' | sort -u)

        if [ ${#test_scripts[@]} -gt 0 ]; then
            echo -e "${YELLOW}Detected: Node.js project${NC}"
            echo ""
            test_found=true

            if [ ${#test_scripts[@]} -eq 1 ]; then
                local cmd="npm run ${test_scripts[0]}"
                echo "Running: $cmd"
                echo ""
                set_project_config "testCommand" "$cmd"
                echo -e "${GREEN}Saved to .autoclaude.json${NC}"
                echo ""
                npm run "${test_scripts[0]}" || echo -e "${RED}Tests failed (exit code: $?)${NC}"
            else
                echo "Available test scripts:"
                local i=1
                for script in "${test_scripts[@]}"; do
                    echo "  $i) $script"
                    ((i++))
                done
                echo "  0) Cancel"
                echo ""
                read -p "Select test script to run: " script_choice

                if [ "$script_choice" = "0" ] || [ -z "$script_choice" ]; then
                    echo "Cancelled."
                elif [ "$script_choice" -ge 1 ] 2>/dev/null && [ "$script_choice" -le ${#test_scripts[@]} ]; then
                    local selected="${test_scripts[$((script_choice-1))]}"
                    local cmd="npm run $selected"
                    echo ""
                    echo "Running: $cmd"
                    echo ""
                    set_project_config "testCommand" "$cmd"
                    echo -e "${GREEN}Saved to .autoclaude.json${NC}"
                    echo ""
                    npm run "$selected" || echo -e "${RED}Tests failed (exit code: $?)${NC}"
                else
                    echo -e "${RED}Invalid selection${NC}"
                fi
            fi
        fi
    fi

    if [ -f "Cargo.toml" ] && ! $test_found; then
        echo -e "${YELLOW}Detected: Rust project${NC}"
        echo ""
        test_found=true
        set_project_config "testCommand" "cargo test"
        cargo test || echo -e "${RED}Tests failed (exit code: $?)${NC}"
    fi

    if [ -f "pyproject.toml" ] || [ -f "setup.py" ] || [ -f "pytest.ini" ] && ! $test_found; then
        echo -e "${YELLOW}Detected: Python project${NC}"
        echo ""
        test_found=true
        if command -v pytest &> /dev/null; then
            set_project_config "testCommand" "pytest"
            pytest || echo -e "${RED}Tests failed (exit code: $?)${NC}"
        elif command -v python3 &> /dev/null; then
            set_project_config "testCommand" "python3 -m pytest"
            python3 -m pytest || echo -e "${RED}Tests failed (exit code: $?)${NC}"
        else
            set_project_config "testCommand" "python -m pytest"
            python -m pytest || echo -e "${RED}Tests failed (exit code: $?)${NC}"
        fi
    fi

    if [ -f "Makefile" ] && grep -q "^test:" Makefile && ! $test_found; then
        echo -e "${YELLOW}Detected: Makefile with test target${NC}"
        echo ""
        test_found=true
        set_project_config "testCommand" "make test"
        make test || echo -e "${RED}Tests failed (exit code: $?)${NC}"
    fi

    if [ -f "go.mod" ] && ! $test_found; then
        echo -e "${YELLOW}Detected: Go project${NC}"
        echo ""
        test_found=true
        set_project_config "testCommand" "go test ./..."
        go test ./... || echo -e "${RED}Tests failed (exit code: $?)${NC}"
    fi

    if [ -f "build.gradle" ] || [ -f "build.gradle.kts" ] && ! $test_found; then
        echo -e "${YELLOW}Detected: Gradle project${NC}"
        echo ""
        test_found=true
        set_project_config "testCommand" "./gradlew test"
        ./gradlew test || echo -e "${RED}Tests failed (exit code: $?)${NC}"
    fi

    if [ -f "pom.xml" ] && ! $test_found; then
        echo -e "${YELLOW}Detected: Maven project${NC}"
        echo ""
        test_found=true
        set_project_config "testCommand" "mvn test"
        mvn test || echo -e "${RED}Tests failed (exit code: $?)${NC}"
    fi

    if ! $test_found; then
        echo -e "${YELLOW}No recognised test framework detected.${NC}"
        echo ""
        echo "Supported frameworks:"
        echo "  - Node.js (npm run test* via package.json)"
        echo "  - Rust (cargo test)"
        echo "  - Python (pytest)"
        echo "  - Go (go test)"
        echo "  - Make (make test)"
        echo "  - Gradle (./gradlew test)"
        echo "  - Maven (mvn test)"
        echo ""
        echo "You can manually configure a test command:"
        read -p "Enter test command (or press Enter to skip): " manual_cmd
        if [ -n "$manual_cmd" ]; then
            set_project_config "testCommand" "$manual_cmd"
            echo -e "${GREEN}Saved to .autoclaude.json${NC}"
            echo ""
            echo "Running: $manual_cmd"
            echo ""
            eval "$manual_cmd" || echo -e "${RED}Tests failed (exit code: $?)${NC}"
        fi
    fi

    echo ""
    read -p "Press Enter to continue..."
}

# Setup AutoClaude
setup_autoclaude() {
    show_banner
    echo -e "${CYAN}AutoClaude Setup${NC}"
    echo "================"
    echo ""
    
    # Check if in AutoClaude directory
    if [ -f scripts/setup.sh ]; then
        ./scripts/setup.sh
    else
        echo -e "${RED}Setup script not found. Are you in the AutoClaude directory?${NC}"
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

# Check system status
check_status() {
    show_banner
    echo -e "${CYAN}System Status${NC}"
    echo "============="
    echo ""
    
    # Check Claude Code
    if command -v claude &> /dev/null; then
        echo -e "${GREEN}✅ Claude Code installed${NC}"
    else
        echo -e "${RED}❌ Claude Code not found${NC}"
    fi
    
    # Check container runtime
    if command -v podman &> /dev/null; then
        echo -e "${GREEN}✅ Podman installed (preferred)${NC}"
    elif command -v docker &> /dev/null; then
        if docker info >/dev/null 2>&1; then
            echo -e "${GREEN}✅ Docker installed and running${NC}"
        else
            echo -e "${YELLOW}⚠️  Docker installed but daemon not running${NC}"
        fi
    else
        echo -e "${RED}❌ No container runtime found${NC}"
    fi
    
    # Check Git
    if command -v git &> /dev/null; then
        echo -e "${GREEN}✅ Git installed${NC}"
    else
        echo -e "${RED}❌ Git not found${NC}"
    fi
    
    # Check GitHub CLI
    if command -v gh &> /dev/null; then
        echo -e "${GREEN}✅ GitHub CLI installed${NC}"
    else
        echo -e "${YELLOW}⚠️  GitHub CLI not found (optional)${NC}"
    fi
    
    # Check environment variables
    echo ""
    echo -e "${YELLOW}Environment:${NC}"
    if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
        echo "✅ ANTHROPIC_API_KEY is set"
    else
        echo "❌ ANTHROPIC_API_KEY not set"
    fi
    
    if [ -n "${GITHUB_TOKEN:-}" ]; then
        echo "✅ GITHUB_TOKEN is set"
    else
        echo "⚠️  GITHUB_TOKEN not set (optional)"
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

# Configuration menu
configuration_menu() {
    while true; do
        show_banner
        echo -e "${CYAN}Configuration${NC}"
        echo "============="
        echo ""
        echo "Current Settings:"
        echo "1) Workspace: $AUTOCLAUDE_WORKSPACE"
        echo "2) Container Runtime: $AUTOCLAUDE_DEFAULT_RUNTIME"
        echo "3) Auto-commit: $AUTOCLAUDE_AUTO_COMMIT"
        echo "4) Use Sandbox: $AUTOCLAUDE_USE_SANDBOX"
        echo ""
        echo "5) Edit .env file"
        echo "6) Check Podman setup"
        echo "0) Return to Main Menu"
        echo ""
        read -p "Select option to change: " config_choice
        
        case $config_choice in
            1)
                read -p "New workspace path: " new_workspace
                AUTOCLAUDE_WORKSPACE="${new_workspace/#\~/$HOME}"
                save_config
                ;;
            2)
                echo "Select container runtime:"
                echo "1) Auto-detect (Docker on macOS, Podman on Linux)"
                echo "2) Always use Docker"
                echo "3) Always use Podman"
                read -p "Choice: " runtime_choice
                case $runtime_choice in
                    1) AUTOCLAUDE_DEFAULT_RUNTIME="auto" ;;
                    2) AUTOCLAUDE_DEFAULT_RUNTIME="docker" ;;
                    3) AUTOCLAUDE_DEFAULT_RUNTIME="podman" ;;
                esac
                save_config
                # Export for immediate use
                export AUTOCLAUDE_CONTAINER_RUNTIME="$AUTOCLAUDE_DEFAULT_RUNTIME"
                ;;
            3)
                if [ "$AUTOCLAUDE_AUTO_COMMIT" = "true" ]; then
                    AUTOCLAUDE_AUTO_COMMIT="false"
                else
                    AUTOCLAUDE_AUTO_COMMIT="true"
                fi
                save_config
                ;;
            4)
                if [ "$AUTOCLAUDE_USE_SANDBOX" = "true" ]; then
                    AUTOCLAUDE_USE_SANDBOX="false"
                else
                    AUTOCLAUDE_USE_SANDBOX="true"
                fi
                save_config
                ;;
            5)
                if [ -f .env ]; then
                    ${EDITOR:-nano} .env
                else
                    echo -e "${YELLOW}No .env file found in current directory${NC}"
                    sleep 2
                fi
                ;;
            6)
                if [ -f scripts/check-podman.sh ]; then
                    ./scripts/check-podman.sh
                    read -p "Press Enter to continue..."
                else
                    echo -e "${RED}check-podman.sh not found${NC}"
                    sleep 2
                fi
                ;;
            0) return ;;
            *) echo -e "${RED}Invalid option${NC}"; sleep 2 ;;
        esac
    done
}

# Help menu
help_menu() {
    show_banner
    echo -e "${CYAN}Help & Documentation${NC}"
    echo "==================="
    echo ""
    echo "1) View README"
    echo "2) View Podman Guide"
    echo "3) View Contributing Guide"
    echo "4) Launch Documentation Server"
    echo "5) About AutoClaude"
    echo "0) Return to Main Menu"
    echo ""
    read -p "Select option: " help_choice
    
    case $help_choice in
        1)
            if [ -f README.md ]; then
                less README.md
            else
                echo -e "${RED}README.md not found${NC}"
                sleep 2
            fi
            ;;
        2)
            if [ -f docs/PODMAN.md ]; then
                less docs/PODMAN.md
            else
                echo -e "${RED}Podman guide not found${NC}"
                sleep 2
            fi
            ;;
        3)
            if [ -f docs/CONTRIBUTING.md ]; then
                less docs/CONTRIBUTING.md
            else
                echo -e "${RED}Contributing guide not found${NC}"
                sleep 2
            fi
            ;;
        4)
            echo -e "${YELLOW}Starting documentation server...${NC}"
            echo "Documentation will be available at http://localhost:8080"
            python3 -m http.server 8080 --directory docs
            ;;
        5)
            show_banner
            echo "AutoClaude - Autonomous Claude Code System"
            echo "Version 1.0.0"
            echo ""
            echo "An autonomous development system that enables Claude Code"
            echo "to operate independently with minimal human intervention."
            echo ""
            echo "Repository: https://github.com/Jobikinobi/hole-foundation-autoclaude"
            echo ""
            read -p "Press Enter to continue..."
            ;;
        0) return ;;
        *) echo -e "${RED}Invalid option${NC}"; sleep 2 ;;
    esac
}

# Git operations menu
git_menu() {
    while true; do
        show_banner
        echo -e "${CYAN}Git Operations${NC}"
        echo "=============="
        echo ""
        
        # Show current branch and status
        if [ -d .git ]; then
            echo "Branch: $(git branch --show-current)"
            echo "Status: $(git status -s | wc -l) changes"
            echo ""
        fi
        
        echo "1) View Status"
        echo "2) Commit Changes"
        echo "3) Push to Remote"
        echo "4) Pull from Remote"
        echo "5) Create New Branch"
        echo "6) View Log"
        echo "0) Return"
        echo ""
        read -p "Select action: " git_action
        
        case $git_action in
            1) git status; read -p "Press Enter..." ;;
            2) 
                git add -A
                read -p "Commit message: " commit_msg
                git commit -m "$commit_msg

🤖 Generated with AutoClaude
Co-Authored-By: Claude <noreply@anthropic.com>"
                read -p "Press Enter..."
                ;;
            3) git push; read -p "Press Enter..." ;;
            4) git pull; read -p "Press Enter..." ;;
            5)
                read -p "Branch name: " branch_name
                git checkout -b "$branch_name"
                ;;
            6) git log --oneline -20; read -p "Press Enter..." ;;
            0) return ;;
            *) echo -e "${RED}Invalid option${NC}"; sleep 2 ;;
        esac
    done
}

# Container management menu
container_menu() {
    while true; do
        show_banner
        echo -e "${CYAN}Container Management${NC}"
        echo "==================="
        echo ""
        
        local runtime=""
        if command -v podman &> /dev/null; then
            runtime="podman"
        elif command -v docker &> /dev/null && docker info >/dev/null 2>&1; then
            runtime="docker"
        else
            echo -e "${RED}No working container runtime found${NC}"
            if command -v docker &> /dev/null; then
                echo -e "${YELLOW}Docker is installed but daemon not running${NC}"
                echo "Start Docker or install Podman"
            fi
            read -p "Press Enter to continue..."
            return
        fi
        
        echo "Runtime: $runtime"
        echo ""
        echo "1) List Containers"
        echo "2) Start Sandbox"
        echo "3) Stop Sandbox"
        echo "4) View Logs"
        echo "5) Shell into Container"
        echo "6) Build Image"
        echo "0) Return"
        echo ""
        read -p "Select action: " container_action
        
        case $container_action in
            1) $runtime ps -a | grep autoclaude || echo "No AutoClaude containers"; read -p "Press Enter..." ;;
            2) 
                cd docker
                if [ "$runtime" = "podman" ] && command -v podman-compose &> /dev/null; then
                    podman-compose up -d autoclaude-sandbox
                else
                    $runtime compose up -d autoclaude-sandbox
                fi
                cd ..
                read -p "Press Enter..."
                ;;
            3)
                cd docker
                if [ "$runtime" = "podman" ] && command -v podman-compose &> /dev/null; then
                    podman-compose down
                else
                    $runtime compose down
                fi
                cd ..
                read -p "Press Enter..."
                ;;
            4) $runtime logs autoclaude-dev 2>/dev/null || echo "Container not running"; read -p "Press Enter..." ;;
            5) $runtime exec -it autoclaude-dev bash 2>/dev/null || echo "Container not running"; ;;
            6)
                cd docker
                $runtime build -t autoclaude/sandbox:latest .
                cd ..
                read -p "Press Enter..."
                ;;
            0) return ;;
            *) echo -e "${RED}Invalid option${NC}"; sleep 2 ;;
        esac
    done
}

# Import existing project
import_project() {
    show_banner
    echo -e "${CYAN}Import Existing Project${NC}"
    echo "====================="
    echo ""
    
    read -p "Project directory path: " import_path
    import_path="${import_path/#\~/$HOME}"
    
    if [ ! -d "$import_path" ]; then
        echo -e "${RED}Directory not found: $import_path${NC}"
        sleep 3
        return
    fi
    
    # Get project name from directory
    project_name=$(basename "$import_path")
    read -p "Project name [$project_name]: " custom_name
    if [ -n "$custom_name" ]; then
        project_name="$custom_name"
    fi
    
    # Check if already registered
    if project_exists "$project_name"; then
        echo -e "${RED}Project name already exists${NC}"
        sleep 3
        return
    fi
    
    read -p "Project description: " project_description
    
    # Check if AutoClaude files exist
    if [ ! -d "$import_path/hooks" ] || [ ! -d "$import_path/scripts" ]; then
        echo -e "${YELLOW}AutoClaude files not found. Setting up...${NC}"
        cp -r hooks "$import_path/"
        cp -r docker "$import_path/"
        cp -r templates "$import_path/"
        cp -r scripts "$import_path/"
        mkdir -p "$import_path/.claude-code"
    fi
    
    # Register project
    register_project "$project_name" "$import_path" "$project_description"
    
    echo -e "${GREEN}✅ Project imported successfully!${NC}"
    sleep 2
}

# Main execution
load_config
main_menu