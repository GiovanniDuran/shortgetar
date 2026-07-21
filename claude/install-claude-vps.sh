#!/bin/bash
#
# Claude Code + Hephaestus VPS Installer
# Install Claude Code CLI di user claude + Hephaestus Framework (Full Tools)
#
# Usage (jalankan sebagai root):
#   bash install-claude-vps.sh
#
# Atau one-liner:
#   curl -fsSL https://raw.githubusercontent.com/GiovanniDuran/shortgetar/refs/heads/main/claude/install-claude-vps.sh | bash
#
# Setelah install, jalankan dengan:
#   su claude
#   cd ~/Hephaestus
#   claude --dangerously-skip-permissions
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Config
CLAUDE_USER="claude"
CLAUDE_HOME="/home/claude"
CLAUDE_BIN_DIR="$CLAUDE_HOME/.local/bin"
HEPHAESTUS_DIR="$CLAUDE_HOME/Hephaestus"
HEPHAESTUS_ZIP_URL="https://orang2.xyz/tools/Hephaestustools.zip"

# Banner
echo -e "${CYAN}"
cat << 'EOF'
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║   ██╗  ██╗███████╗██████╗ ██╗  ██╗ █████╗ ███████╗████████║
║   ██║  ██║██╔════╝██╔══██╗██║  ██║██╔══██╗██╔════╝╚══██╔══║
║   ███████║█████╗  ██████╔╝███████║███████║█████╗     ██║  ║
║   ██╔══██║██╔══╝  ██╔═══╝ ██╔══██║██╔══██║██╔══╝     ██║  ║
║   ██║  ██║███████╗██║     ██║  ██║██║  ██║███████╗   ██║  ║
║   ╚═╝  ╚═╝╚══════╝╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝   ╚═╝  ║
║                                                           ║
║           Claude Code + Hephaestus VPS Installer          ║
║                    Full Tools Edition                     ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "Script harus dijalankan sebagai root!"
        echo "Jalankan: sudo bash install-claude-vps.sh"
        exit 1
    fi
    log_success "Running as root"
}

# Detect OS
check_os() {
    log_info "Detecting OS..."
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
        log_success "OS: $PRETTY_NAME"
    else
        log_error "Tidak dapat mendeteksi OS"
        exit 1
    fi
}

# Create user claude
create_claude_user() {
    log_info "Creating user claude..."

    if id "$CLAUDE_USER" &>/dev/null; then
        log_warn "User claude sudah ada"
    else
        useradd -m -s /bin/bash "$CLAUDE_USER"
        log_success "User claude created"
    fi

    # Add to sudo group
    usermod -aG sudo "$CLAUDE_USER" 2>/dev/null || usermod -aG wheel "$CLAUDE_USER" 2>/dev/null || true

    # Create directories
    mkdir -p "$CLAUDE_BIN_DIR"
    mkdir -p "$CLAUDE_HOME/.npm-global"
    chown -R "$CLAUDE_USER:$CLAUDE_USER" "$CLAUDE_HOME"

    log_success "User claude configured"
}

# Install dependencies
install_dependencies() {
    log_info "Installing dependencies..."

    case $OS in
        ubuntu|debian)
            apt-get update -qq
            apt-get install -y -qq curl wget git build-essential unzip jq sshpass netcat-openbsd nmap whois dnsutils
            ;;
        centos|rhel|fedora|rocky|almalinux)
            yum install -y curl wget git gcc-c++ make unzip jq sshpass nc nmap whois bind-utils
            ;;
        *)
            log_warn "OS tidak dikenal, pastikan curl, wget, git, unzip sudah terinstall"
            ;;
    esac

    log_success "Dependencies installed"
}

# Install Node.js
install_nodejs() {
    log_info "Checking Node.js..."

    if command -v node &>/dev/null; then
        NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
        if [ "$NODE_VERSION" -ge 18 ]; then
            log_success "Node.js $(node -v) sudah terinstall"
            return 0
        fi
    fi

    log_info "Installing Node.js 20.x..."

    case $OS in
        ubuntu|debian)
            curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
            apt-get install -y nodejs
            ;;
        centos|rhel|fedora|rocky|almalinux)
            curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
            yum install -y nodejs
            ;;
        *)
            # Install via nvm untuk user claude
            su - "$CLAUDE_USER" -c 'curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash'
            su - "$CLAUDE_USER" -c 'source ~/.nvm/nvm.sh && nvm install 20 && nvm use 20 && nvm alias default 20'
            ;;
    esac

    log_success "Node.js $(node -v) installed"
}

# Install Claude Code untuk user claude
install_claude_code() {
    log_info "Installing Claude Code CLI untuk user claude..."

    # Setup npm untuk user claude
    su - "$CLAUDE_USER" << 'EOFUSER'
# Setup npm global directory di home
mkdir -p ~/.npm-global
mkdir -p ~/.local/bin
npm config set prefix '~/.npm-global'

# Install claude-code
npm install -g @anthropic-ai/claude-code

# Link ke ~/.local/bin
ln -sf ~/.npm-global/bin/claude ~/.local/bin/claude 2>/dev/null || true
EOFUSER

    log_success "Claude Code CLI installed"
}

# Setup PATH di .bashrc
setup_bashrc() {
    log_info "Setting up .bashrc..."

    BASHRC="$CLAUDE_HOME/.bashrc"

    # Backup existing
    [ -f "$BASHRC" ] && cp "$BASHRC" "${BASHRC}.bak"

    # Add PATH entries jika belum ada
    grep -q "npm-global" "$BASHRC" 2>/dev/null || cat >> "$BASHRC" << 'BASHRC_CONTENT'

# ═══════════════════════════════════════════════════════════
# Claude Code + Hephaestus Environment
# ═══════════════════════════════════════════════════════════

# PATH
export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$PATH"

# Aliases
alias h='cd ~/Hephaestus'
alias c='claude --dangerously-skip-permissions'
alias hc='cd ~/Hephaestus && claude --dangerously-skip-permissions'
alias gs='gs-netcat'

# Hephaestus shortcuts
alias exp='cd ~/Hephaestus && claude --dangerously-skip-permissions -p "exp'
alias keren='cd ~/Hephaestus && claude --dangerously-skip-permissions -p "keren'

# Auto cd to Hephaestus on login
if [ -d "$HOME/Hephaestus" ]; then
    cd "$HOME/Hephaestus"
fi

# Welcome message
echo ""
echo -e "\033[0;36m╔═══════════════════════════════════════════════════════════╗\033[0m"
echo -e "\033[0;36m║          HEPHAESTUS OPERATIONAL FRAMEWORK                 ║\033[0m"
echo -e "\033[0;36m╚═══════════════════════════════════════════════════════════╝\033[0m"
echo ""
echo -e "  \033[0;32mQuick Start:\033[0m"
echo -e "    claude --dangerously-skip-permissions"
echo ""
echo -e "  \033[0;32mShortcuts:\033[0m"
echo -e "    hc  = cd Hephaestus + claude"
echo -e "    c   = claude --dangerously-skip-permissions"
echo ""
BASHRC_CONTENT

    chown "$CLAUDE_USER:$CLAUDE_USER" "$BASHRC"
    log_success ".bashrc configured"
}

# Download dan install Hephaestus Tools dari GitHub
install_hephaestus() {
    log_info "Downloading Hephaestus Tools from GitHub..."

    # Remove existing if any
    if [ -d "$HEPHAESTUS_DIR" ]; then
        log_warn "Hephaestus directory exists, backing up..."
        mv "$HEPHAESTUS_DIR" "${HEPHAESTUS_DIR}.bak.$(date +%s)"
    fi

    # Create temp directory
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"

    # Download zip
    log_info "Downloading Hephaestustools.zip..."
    if ! curl -fsSL "$HEPHAESTUS_ZIP_URL" -o Hephaestustools.zip; then
        log_error "Failed to download Hephaestustools.zip"
        log_info "Trying alternative method with wget..."
        if ! wget -q "$HEPHAESTUS_ZIP_URL" -O Hephaestustools.zip; then
            log_error "Download failed. Check your internet connection."
            rm -rf "$TEMP_DIR"
            exit 1
        fi
    fi

    # Check file size
    FILE_SIZE=$(stat -c%s Hephaestustools.zip 2>/dev/null || stat -f%z Hephaestustools.zip 2>/dev/null)
    log_info "Downloaded: $(numfmt --to=iec-i --suffix=B $FILE_SIZE 2>/dev/null || echo "$FILE_SIZE bytes")"

    # Extract
    log_info "Extracting Hephaestus tools..."
    unzip -q Hephaestustools.zip

    # Find the extracted directory (could be Hephaestus or Hephaestustools)
    EXTRACTED_DIR=""
    for dir in Hephaestus Hephaestustools hephaestus; do
        if [ -d "$dir" ]; then
            EXTRACTED_DIR="$dir"
            break
        fi
    done

    # If no directory found, check if files are extracted directly
    if [ -z "$EXTRACTED_DIR" ]; then
        # Files might be extracted directly, create Hephaestus dir
        mkdir -p Hephaestus
        # Move all extracted content except the zip
        for item in *; do
            [ "$item" != "Hephaestustools.zip" ] && [ "$item" != "Hephaestus" ] && mv "$item" Hephaestus/ 2>/dev/null || true
        done
        EXTRACTED_DIR="Hephaestus"
    fi

    # Move to final location
    mv "$EXTRACTED_DIR" "$HEPHAESTUS_DIR"

    # Cleanup
    cd /
    rm -rf "$TEMP_DIR"

    # Create additional directories if not exist
    mkdir -p "$HEPHAESTUS_DIR"/{campaigns,.claude/memory}

    # Set ownership
    chown -R "$CLAUDE_USER:$CLAUDE_USER" "$HEPHAESTUS_DIR"

    # Make scripts executable
    find "$HEPHAESTUS_DIR" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
    find "$HEPHAESTUS_DIR" -name "*.py" -exec chmod +x {} \; 2>/dev/null || true

    # Count files
    TOTAL_FILES=$(find "$HEPHAESTUS_DIR" -type f | wc -l)
    log_success "Hephaestus installed: $TOTAL_FILES files"
}

# Create/update .claude settings
setup_claude_settings() {
    log_info "Setting up Claude settings..."

    mkdir -p "$HEPHAESTUS_DIR/.claude"

    # Create settings.json if not exists
    if [ ! -f "$HEPHAESTUS_DIR/.claude/settings.json" ]; then
        cat > "$HEPHAESTUS_DIR/.claude/settings.json" << 'SETTINGS'
{
  "permissions": {
    "allow": [
      "Bash(*)",
      "Read(*)",
      "Write(*)",
      "Edit(*)"
    ],
    "deny": []
  }
}
SETTINGS
    fi

    chown -R "$CLAUDE_USER:$CLAUDE_USER" "$HEPHAESTUS_DIR/.claude"
    log_success "Claude settings configured"
}

# Install additional tools (nuclei, gsocket, subfinder)
install_extra_tools() {
    log_info "Installing additional tools..."

    # GSocket
    if ! command -v gs-netcat &>/dev/null; then
        log_info "Installing GSocket..."
        curl -fsSL https://github.com/hackerschoice/gsocket/releases/latest/download/gs-netcat_linux-x86_64 \
            -o /usr/local/bin/gs-netcat 2>/dev/null && chmod +x /usr/local/bin/gs-netcat
        [ -f /usr/local/bin/gs-netcat ] && log_success "GSocket installed" || log_warn "GSocket installation failed"
    else
        log_success "GSocket already installed"
    fi

    # Nuclei
    if ! command -v nuclei &>/dev/null; then
        log_info "Installing Nuclei..."
        ARCH=$(uname -m)
        [ "$ARCH" = "x86_64" ] && ARCH="amd64"
        NUCLEI_URL="https://github.com/projectdiscovery/nuclei/releases/latest/download/nuclei_$(uname -s | tr '[:upper:]' '[:lower:]')_${ARCH}.zip"
        curl -fsSL "$NUCLEI_URL" -o /tmp/nuclei.zip 2>/dev/null && \
            unzip -o /tmp/nuclei.zip -d /usr/local/bin/ nuclei 2>/dev/null && \
            chmod +x /usr/local/bin/nuclei && rm -f /tmp/nuclei.zip
        [ -f /usr/local/bin/nuclei ] && log_success "Nuclei installed" || log_warn "Nuclei installation failed"
    else
        log_success "Nuclei already installed"
    fi

    # Subfinder
    if ! command -v subfinder &>/dev/null; then
        log_info "Installing Subfinder..."
        ARCH=$(uname -m)
        [ "$ARCH" = "x86_64" ] && ARCH="amd64"
        SUBFINDER_URL="https://github.com/projectdiscovery/subfinder/releases/latest/download/subfinder_$(uname -s | tr '[:upper:]' '[:lower:]')_${ARCH}.zip"
        curl -fsSL "$SUBFINDER_URL" -o /tmp/subfinder.zip 2>/dev/null && \
            unzip -o /tmp/subfinder.zip -d /usr/local/bin/ subfinder 2>/dev/null && \
            chmod +x /usr/local/bin/subfinder && rm -f /tmp/subfinder.zip
        [ -f /usr/local/bin/subfinder ] && log_success "Subfinder installed" || log_warn "Subfinder installation failed"
    else
        log_success "Subfinder already installed"
    fi

    # httpx
    if ! command -v httpx &>/dev/null; then
        log_info "Installing httpx..."
        ARCH=$(uname -m)
        [ "$ARCH" = "x86_64" ] && ARCH="amd64"
        HTTPX_URL="https://github.com/projectdiscovery/httpx/releases/latest/download/httpx_$(uname -s | tr '[:upper:]' '[:lower:]')_${ARCH}.zip"
        curl -fsSL "$HTTPX_URL" -o /tmp/httpx.zip 2>/dev/null && \
            unzip -o /tmp/httpx.zip -d /usr/local/bin/ httpx 2>/dev/null && \
            chmod +x /usr/local/bin/httpx && rm -f /tmp/httpx.zip
        [ -f /usr/local/bin/httpx ] && log_success "httpx installed" || log_warn "httpx installation failed"
    else
        log_success "httpx already installed"
    fi

    log_success "Extra tools installation completed"
}

# Print summary
print_summary() {
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}                  INSTALLATION COMPLETE!                    ${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${CYAN}User:${NC}        claude"
    echo -e "  ${CYAN}Home:${NC}        /home/claude"
    echo -e "  ${CYAN}Claude CLI:${NC}  /home/claude/.local/bin/claude"
    echo -e "  ${CYAN}Hephaestus:${NC}  /home/claude/Hephaestus"
    echo ""
    echo -e "  ${CYAN}Installed Tools:${NC}"
    echo -e "    Node.js:    $(node -v 2>/dev/null || echo 'N/A')"
    echo -e "    npm:        $(npm -v 2>/dev/null || echo 'N/A')"
    echo -e "    GSocket:    $(which gs-netcat 2>/dev/null || echo 'N/A')"
    echo -e "    Nuclei:     $(which nuclei 2>/dev/null || echo 'N/A')"
    echo -e "    Subfinder:  $(which subfinder 2>/dev/null || echo 'N/A')"
    echo -e "    httpx:      $(which httpx 2>/dev/null || echo 'N/A')"
    echo -e "    nmap:       $(which nmap 2>/dev/null || echo 'N/A')"
    echo ""
    HEPH_FILES=$(find "$HEPHAESTUS_DIR" -type f 2>/dev/null | wc -l)
    echo -e "  ${CYAN}Hephaestus Files:${NC} $HEPH_FILES files"
    echo ""
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}                       NEXT STEPS                           ${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${GREEN}Step 1:${NC} Masuk ke user claude"
    echo -e "          ${CYAN}su claude${NC}"
    echo ""
    echo -e "  ${GREEN}Step 2:${NC} Login ke akun Claude (sekali saja)"
    echo -e "          ${CYAN}claude auth login${NC}"
    echo -e "          (Ikuti instruksi untuk authenticate)"
    echo ""
    echo -e "  ${GREEN}Step 3:${NC} Jalankan Claude + Hephaestus"
    echo -e "          ${CYAN}cd ~/Hephaestus${NC}"
    echo -e "          ${CYAN}claude --dangerously-skip-permissions${NC}"
    echo ""
    echo -e "  ${GREEN}Shortcut:${NC}"
    echo -e "          ${CYAN}hc${NC}  = cd Hephaestus + jalankan claude"
    echo -e "          ${CYAN}c${NC}   = claude --dangerously-skip-permissions"
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
}

# Main
main() {
    echo ""
    log_info "Starting Hephaestus + Claude Code installation..."
    echo ""

    check_root
    check_os
    create_claude_user
    install_dependencies
    install_nodejs
    install_claude_code
    setup_bashrc
    install_hephaestus
    setup_claude_settings
    install_extra_tools
    print_summary
}

main "$@"
