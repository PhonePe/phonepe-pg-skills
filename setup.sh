#!/bin/bash

# PhonePe Payment Gateway Skills - Setup Script
# This script automates the setup process described in README.md
# Can be run standalone via wget or from within the cloned repository
#
# Copyright 2026 PhonePe Private Limited
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e

echo "🚀 PhonePe Payment Gateway Skills - Setup Script"
echo "================================================="
echo ""

# Color codes for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Repository URL
REPO_URL="https://github.com/PhonePe/phonepe-pg-skills.git"
TEMP_CLONE_DIR=""
IS_CLONED=false
CLONED_REPO_DIR=""

# Function to print colored output
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_info()    { echo -e "${BLUE}ℹ${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
print_error()   { echo -e "${RED}✗${NC} $1"; }

# Read from /dev/tty so that `read` works both interactively and when
# the script is piped via: curl -fsSL ... | bash
tty_read() {
    local prompt="$1"
    local var_name="$2"
    local flags="${3:-}"   # optional flags, e.g. "-n 1"
    if [ -t 0 ]; then
        # stdin is a terminal — read normally
        # shellcheck disable=SC2229
        read $flags -p "$prompt" "$var_name"
    else
        # stdin is a pipe — read from /dev/tty so user input still works
        # shellcheck disable=SC2229
        read $flags -p "$prompt" "$var_name" </dev/tty
    fi
}

# Check if git is installed
check_git() {
    if ! command -v git &> /dev/null; then
        print_error "Git is not installed. Please install git first."
        exit 1
    fi
}

# Check if GitHub Copilot CLI is installed
check_copilot_cli() {
    if command -v copilot &> /dev/null; then
        print_success "GitHub Copilot CLI is installed"
        return 0
    else
        print_warning "GitHub Copilot CLI is not installed"
        echo ""
        echo "  Install with one of the following methods:"
        echo "  - macOS: brew install copilot-cli"
        echo "  - npm: npm install -g @githubnext/github-copilot-cli"
        echo "  - Or visit: https://docs.github.com/en/copilot/how-tos/set-up/install-copilot-cli"
        echo ""
        tty_read "Continue anyway? (y/n) " REPLY "-n 1"
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
        return 1
    fi
}

# Check if script is running from cloned repo or standalone
detect_script_location() {
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

    if [ -d "$SCRIPT_DIR/phonepe-pg-skill" ]; then
        print_info "Running from cloned repository"
        SKILLS_SOURCE_DIR="$SCRIPT_DIR/phonepe-pg-skill"
        CLONED_REPO_DIR="$SCRIPT_DIR"
        IS_CLONED=true
    else
        print_info "Running in standalone mode - will clone repository"
        IS_CLONED=false
    fi
}

# Clone the repository to a temporary location
clone_repository() {
    if [ "$IS_CLONED" = true ]; then
        return 0
    fi

    print_info "Cloning repository..."

    TEMP_CLONE_DIR=$(mktemp -d)

    if timeout 60 git clone "$REPO_URL" "$TEMP_CLONE_DIR"; then
        print_success "Repository cloned successfully"
        SKILLS_SOURCE_DIR="$TEMP_CLONE_DIR/phonepe-pg-skill"

        if [ ! -d "$SKILLS_SOURCE_DIR" ]; then
            print_error "Skills directory not found in cloned repository"
            cleanup_temp
            exit 1
        fi
    else
        print_error "Failed to clone repository from: $REPO_URL"
        print_info "Please check the repository URL or clone manually"
        cleanup_temp
        exit 1
    fi
}

# Cleanup temporary clone directory (standalone mode)
cleanup_temp() {
    if [ -n "$TEMP_CLONE_DIR" ] && [ -d "$TEMP_CLONE_DIR" ]; then
        rm -rf "$TEMP_CLONE_DIR"
        print_info "Cleaned up temporary files"
    fi
}

# Setup type selection with input validation loop
select_setup_type() {
    echo ""
    echo "Select setup type:"
    echo "1) Install skills into a new project directory"
    echo "2) Install skills into an existing project"
    echo ""

    while true; do
        tty_read "Enter choice (1 or 2): " setup_choice
        case $setup_choice in
            1) setup_new_project; break ;;
            2) setup_existing_project; break ;;
            *) print_error "Invalid choice. Please enter 1 or 2." ;;
        esac
    done
}

# Resolve and validate a target project path (must not be the source repo)
resolve_project_path() {
    local input_path="$1"
    local path

    # Expand tilde
    path="${input_path/#\~/$HOME}"

    # Must not be the cloned source repo itself
    if [ "$IS_CLONED" = true ] && [ "$(cd "$path" 2>/dev/null && pwd)" = "$CLONED_REPO_DIR" ]; then
        print_error "Cannot install into the source repository itself ($CLONED_REPO_DIR)."
        print_error "Please specify a different directory."
        return 1
    fi

    echo "$path"
}

# Setup for new project
setup_new_project() {
    echo ""

    if [ "$IS_CLONED" = true ]; then
        print_warning "You are running from the cloned repository ($(basename "$CLONED_REPO_DIR"))."
        print_warning "Skills must be installed into a separate project directory."
        echo ""
    fi

    while true; do
        if [ "$IS_CLONED" = true ]; then
            tty_read "Enter the directory path for your project: " new_project_path
        else
            tty_read "Enter the directory path for your new project (or press Enter for current directory): " new_project_path
        fi

        if [ -z "$new_project_path" ] && [ "$IS_CLONED" = false ]; then
            PROJECT_DIR="$(pwd)"
            break
        elif [ -z "$new_project_path" ]; then
            print_error "Path is required. Please enter a project directory."
            continue
        else
            resolved=$(resolve_project_path "$new_project_path") || continue

            if [ ! -d "$resolved" ]; then
                mkdir -p "$resolved"
                print_success "Created directory: $resolved"
            fi
            PROJECT_DIR="$resolved"
            break
        fi
    done

    DEST_DIR="$PROJECT_DIR/.github/skills/phonepe-pg-skill"
    mkdir -p "$DEST_DIR"
    cp -r "$SKILLS_SOURCE_DIR/." "$DEST_DIR/"
    print_success "Skills installed at: $DEST_DIR"
}

# Setup for existing project
setup_existing_project() {
    echo ""

    while true; do
        tty_read "Enter the path to your existing project: " target_path

        if [ -z "$target_path" ]; then
            print_error "Path is required."
            continue
        fi

        resolved=$(resolve_project_path "$target_path") || continue

        if [ ! -d "$resolved" ]; then
            print_error "Directory does not exist: $resolved"
            continue
        fi

        PROJECT_DIR="$resolved"
        break
    done

    DEST_DIR="$PROJECT_DIR/.github/skills/phonepe-pg-skill"
    mkdir -p "$DEST_DIR"
    cp -r "$SKILLS_SOURCE_DIR/." "$DEST_DIR/"
    print_success "Skills installed at: $DEST_DIR"
}

# Create environment configuration template
create_env_template() {
    echo ""
    tty_read "Create .env.template file with PhonePe configuration? (y/n) " REPLY "-n 1"
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        ENV_TEMPLATE="$PROJECT_DIR/.env.template"

        cat > "$ENV_TEMPLATE" << 'EOF'
# PhonePe Payment Gateway Configuration
# Copy this file to .env and fill in your credentials
# ⚠️ NEVER commit .env file to version control

# Environment (sandbox or production)
PHONEPE_ENV=sandbox

# API Credentials
PHONEPE_CLIENT_ID=your_client_id
PHONEPE_CLIENT_SECRET=your_client_secret
PHONEPE_CLIENT_VERSION=your_client_version
PHONEPE_MERCHANT_ID=your_merchant_id

# Callback URLs
PHONEPE_REDIRECT_URL=https://yourdomain.com/payment/callback
EOF

        print_success "Created .env.template at: $ENV_TEMPLATE"

        if [ -f "$PROJECT_DIR/.gitignore" ]; then
            if ! grep -q "^\.env$" "$PROJECT_DIR/.gitignore"; then
                echo ".env" >> "$PROJECT_DIR/.gitignore"
                print_success "Added .env to .gitignore"
            fi
        else
            echo ".env" > "$PROJECT_DIR/.gitignore"
            print_success "Created .gitignore with .env entry"
        fi
    fi
}

# Verify skills installation
verify_skills() {
    echo ""
    print_info "To verify skills are loaded, run the following commands:"
    echo ""
    echo "  cd $PROJECT_DIR"
    echo "  copilot"
    echo ""
    echo "Then in Copilot CLI:"
    echo "  /skills list"
    echo ""
    echo "You should see 'phonepe-pg-skill' in the list."
    echo "If not, try: /skills reload"
}

# Suggest cleanup of the cloned source repo (we cannot delete it while running from it)
suggest_cloned_repo_cleanup() {
    if [ "$IS_CLONED" = true ]; then
        echo ""
        print_info "The cloned source repository is no longer needed."
        print_info "You can delete it by running:"
        echo ""
        echo "  rm -rf \"$CLONED_REPO_DIR\""
        echo ""
    fi
}

# Trap ensures temp dir is always removed on exit (standalone mode)
trap cleanup_temp EXIT

# Main execution
main() {
    check_git
    check_copilot_cli
    detect_script_location
    clone_repository
    select_setup_type
    create_env_template

    echo ""
    echo "================================================="
    print_success "Setup completed successfully!"
    echo ""

    verify_skills
    suggest_cloned_repo_cleanup

    echo ""
    print_info "Next steps:"
    echo "  1. Copy .env.template to .env and add your PhonePe credentials"
    echo "  2. Start GitHub Copilot CLI: cd $PROJECT_DIR && copilot"
    echo "  3. Try: 'Help me integrate PhonePe payment gateway'"
    echo ""
    print_warning "Security Note: Never commit credentials to version control!"
    echo ""
}

main
