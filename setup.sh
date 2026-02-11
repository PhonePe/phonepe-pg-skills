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

# Repository URL - Update this with your actual repository URL
REPO_URL="https://github.com/PhonePe/phonepe-pg-skills.git"
TEMP_CLONE_DIR=""

# Function to print colored output
print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
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
        read -p "Continue anyway? (y/n) " -n 1 -r
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
    
    # Check if phonepe-pg-skill directory exists in current location
    if [ -d "$SCRIPT_DIR/phonepe-pg-skill" ]; then
        print_info "Running from cloned repository"
        SKILLS_SOURCE_DIR="$SCRIPT_DIR/phonepe-pg-skill"
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
    
    # Create temporary directory
    TEMP_CLONE_DIR=$(mktemp -d)
    
    # Clone the repository
    if git clone "$REPO_URL" "$TEMP_CLONE_DIR" 2>/dev/null; then
        print_success "Repository cloned successfully"
        SKILLS_SOURCE_DIR="$TEMP_CLONE_DIR/phonepe-pg-skill"
        
        # Verify skills directory exists
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

# Cleanup temporary clone directory
cleanup_temp() {
    if [ -n "$TEMP_CLONE_DIR" ] && [ -d "$TEMP_CLONE_DIR" ]; then
        rm -rf "$TEMP_CLONE_DIR"
        print_info "Cleaned up temporary files"
    fi
}

# Setup type selection
select_setup_type() {
    echo ""
    echo "Select setup type:"
    echo "1) Use this repository (for new projects)"
    echo "2) Copy skills to an existing project"
    echo ""
    read -p "Enter choice (1 or 2): " setup_choice
    
    case $setup_choice in
        1)
            setup_new_project
            ;;
        2)
            setup_existing_project
            ;;
        *)
            print_error "Invalid choice. Exiting."
            exit 1
            ;;
    esac
}

# Setup for new project (using this repository)
setup_new_project() {
    echo ""
    read -p "Enter the directory path for your new project (or press Enter for current directory): " new_project_path
    
    if [ -z "$new_project_path" ]; then
        PROJECT_DIR="$(pwd)"
    else
        # Expand tilde to home directory
        new_project_path="${new_project_path/#\~/$HOME}"
        
        # Create directory if it doesn't exist
        if [ ! -d "$new_project_path" ]; then
            mkdir -p "$new_project_path"
            print_success "Created directory: $new_project_path"
        fi
        
        PROJECT_DIR="$new_project_path"
    fi
    
    # Copy skills to .github/skills
    mkdir -p "$PROJECT_DIR/.github/skills"
    cp -r "$SKILLS_SOURCE_DIR" "$PROJECT_DIR/.github/skills/"
    
    print_success "Skills installed at: $PROJECT_DIR/.github/skills/phonepe-pg-skill"
    print_success "Project directory: $PROJECT_DIR"
}

# Setup for existing project
setup_existing_project() {
    echo ""
    read -p "Enter the path to your existing project: " target_path
    
    # Expand tilde to home directory
    target_path="${target_path/#\~/$HOME}"
    
    if [ ! -d "$target_path" ]; then
        print_error "Directory does not exist: $target_path"
        exit 1
    fi
    
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
    
    # Create .github/skills directory if it doesn't exist
    mkdir -p "$target_path/.github/skills"
    
    # Copy the skills directory
    cp -r "$SKILLS_SOURCE_DIR" "$target_path/.github/skills/"
    print_success "Copied skills to: $target_path/.github/skills/phonepe-pg-skill"
    
    PROJECT_DIR="$target_path"
    print_success "Skills copied to project: $PROJECT_DIR"
}

# Create environment configuration template
create_env_template() {
    echo ""
    read -p "Create .env.template file with PhonePe configuration? (y/n) " -n 1 -r
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
        
        # Update .gitignore to exclude .env
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
    
    echo ""
    print_info "Next steps:"
    echo "  1. Copy .env.template to .env and add your PhonePe credentials"
    echo "  2. Start GitHub Copilot CLI: cd $PROJECT_DIR && copilot"
    echo "  3. Try: 'Help me integrate PhonePe payment gateway'"
    echo ""
    print_warning "Security Note: Never commit credentials to version control!"
    echo ""
    
    # Cleanup temporary clone if it was created
    cleanup_temp
}

# Trap to ensure cleanup happens on exit
trap cleanup_temp EXIT

# Run main function
main
