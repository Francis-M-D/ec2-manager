#!/usr/bin/env bash

# ============================================================
# Ubuntu 22.04 (Jammy) Full-Stack Development Setup
# ============================================================
#
# Target:
#   Ubuntu 22.04 LTS (Jammy Jellyfish)
#   AWS EC2 / Ubuntu Server
#
# Installs:
#   - Git
#   - Python 3
#   - pip
#   - Python venv
#   - pipx
#   - Node.js 22
#   - npm
#   - npx
#   - .NET SDK 10
#   - Docker Engine
#   - Docker Compose
#   - Docker Buildx
#   - AWS CLI v2
#   - Common development tools
#
# Python dependency strategy:
#   - Keep Ubuntu system Python packages managed by apt
#   - Do NOT install application packages globally with pip
#   - Use virtual environments for boto3/FastAPI/etc.
#
# ============================================================

set -Eeuo pipefail

# ------------------------------------------------------------
# Colors
# ------------------------------------------------------------

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ------------------------------------------------------------
# Functions
# ------------------------------------------------------------

section() {
    echo
    echo "============================================================"
    echo "$1"
    echo "============================================================"
    echo
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# ------------------------------------------------------------
# Error handler
# ------------------------------------------------------------

trap 'error "Script failed at line $LINENO."' ERR

# ------------------------------------------------------------
# Root check
# ------------------------------------------------------------

if [ "$EUID" -eq 0 ]; then
    error "Do not run this script as root."
    echo
    echo "Run it as your normal Ubuntu user:"
    echo
    echo "    ./fsd_tools.sh"
    echo
    exit 1
fi

# ============================================================
# 1. VERIFY UBUNTU 22.04
# ============================================================

section "Checking Operating System"

if [ ! -f /etc/os-release ]; then
    error "Cannot determine operating system."
    exit 1
fi

source /etc/os-release

echo "Distribution : ${PRETTY_NAME}"
echo "Version      : ${VERSION_ID}"
echo "Codename     : ${VERSION_CODENAME}"

if [ "$ID" != "ubuntu" ]; then
    error "This script is designed for Ubuntu."
    exit 1
fi

if [ "$VERSION_ID" != "22.04" ]; then
    error "This script is specifically for Ubuntu 22.04 Jammy."
    echo "Detected: Ubuntu $VERSION_ID"
    exit 1
fi

success "Ubuntu 22.04 Jammy detected."

# ============================================================
# 2. UPDATE SYSTEM
# ============================================================

section "Updating Ubuntu"

sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

success "Ubuntu updated."

# ============================================================
# 3. COMMON DEVELOPMENT TOOLS
# ============================================================

section "Installing Common Development Tools"

sudo apt-get install -y \
    ca-certificates \
    curl \
    wget \
    gnupg \
    lsb-release \
    apt-transport-https \
    software-properties-common \
    unzip \
    zip \
    jq \
    tree \
    vim \
    nano \
    htop \
    net-tools \
    dnsutils \
    openssh-client \
    build-essential \
    pkg-config \
    make \
    gcc \
    g++ \
    git \
    rsync

success "Common development tools installed."

# ============================================================
# 4. PYTHON
# ============================================================

section "Installing Python"

sudo apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    python3-setuptools \
    python3-wheel

success "Python: $(python3 --version)"
success "pip: $(python3 -m pip --version)"

if python3 -m venv --help >/dev/null 2>&1; then
    success "Python venv is available."
else
    error "Python venv is not available."
    exit 1
fi

# ------------------------------------------------------------
# Python policy
# ------------------------------------------------------------

warning "Python application packages should be installed inside virtual environments."
info "Do not use 'sudo pip install ...' on this system."
info "Do not use global 'pip install ...' for project dependencies."

# ============================================================
# 5. PIPX
# ============================================================

section "Installing pipx"

sudo apt-get install -y pipx

pipx ensurepath >/dev/null 2>&1 || true

success "pipx: $(pipx --version)"

# ============================================================
# 6. NODE.JS 22
# ============================================================

section "Installing Node.js 22"

# Remove old NodeSource configuration if present

sudo rm -f /etc/apt/sources.list.d/nodesource.list
sudo rm -f /etc/apt/sources.list.d/nodesource.sources

curl -fsSL \
    https://deb.nodesource.com/setup_22.x \
    | sudo -E bash -

sudo apt-get install -y nodejs

success "Node.js: $(node --version)"
success "npm: $(npm --version)"
success "npx: $(npx --version)"

# ============================================================
# 7. MICROSOFT REPOSITORY
# ============================================================

section "Configuring Microsoft Repository"

MICROSOFT_PACKAGE="/tmp/packages-microsoft-prod.deb"

if [ ! -f /etc/apt/sources.list.d/microsoft-prod.list ]; then

    info "Installing Microsoft package repository..."

    wget -q \
        https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb \
        -O "$MICROSOFT_PACKAGE"

    sudo dpkg -i "$MICROSOFT_PACKAGE"

    rm -f "$MICROSOFT_PACKAGE"

    sudo apt-get update

    success "Microsoft repository configured."

else

    info "Microsoft repository already configured."

fi

# ============================================================
# 8. .NET SDK 10
# ============================================================

section "Installing .NET SDK 10"

if apt-cache show dotnet-sdk-10.0 >/dev/null 2>&1; then

    sudo apt-get install -y dotnet-sdk-10.0

    success ".NET SDK 10 installed."

else

    warning ".NET SDK 10 is not available through the configured repository."
    info "Using Microsoft's official dotnet-install script."

    DOTNET_DIR="$HOME/.dotnet"
    DOTNET_INSTALL_SCRIPT="/tmp/dotnet-install.sh"

    curl -fsSL \
        https://dot.net/v1/dotnet-install.sh \
        -o "$DOTNET_INSTALL_SCRIPT"

    chmod +x "$DOTNET_INSTALL_SCRIPT"

    "$DOTNET_INSTALL_SCRIPT" \
        --channel 10.0 \
        --install-dir "$DOTNET_DIR"

    rm -f "$DOTNET_INSTALL_SCRIPT"

    if ! grep -q 'DOTNET_ROOT="$HOME/.dotnet"' "$HOME/.bashrc" 2>/dev/null; then

        cat >> "$HOME/.bashrc" <<'EOF'

# .NET SDK
export DOTNET_ROOT="$HOME/.dotnet"
export PATH="$DOTNET_ROOT:$PATH"
EOF

    fi

    export DOTNET_ROOT="$HOME/.dotnet"
    export PATH="$DOTNET_ROOT:$PATH"

fi

success ".NET: $(dotnet --version)"

# ============================================================
# 9. DOCKER REPOSITORY
# ============================================================

section "Configuring Docker Repository"

sudo install -m 0755 -d /etc/apt/keyrings

if [ ! -f /etc/apt/keyrings/docker.asc ]; then

    sudo curl -fsSL \
        https://download.docker.com/linux/ubuntu/gpg \
        -o /etc/apt/keyrings/docker.asc

fi

sudo chmod a+r /etc/apt/keyrings/docker.asc

ARCH=$(dpkg --print-architecture)

echo \
"deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/ubuntu \
jammy stable" \
| sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

sudo apt-get update

success "Docker repository configured."

# ============================================================
# 10. DOCKER
# ============================================================

section "Installing Docker"

sudo apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

success "Docker: $(docker --version)"
success "Docker Compose: $(docker compose version)"
success "Docker Buildx: $(docker buildx version)"

# ============================================================
# 11. DOCKER USER CONFIGURATION
# ============================================================

section "Configuring Docker Permissions"

if ! getent group docker >/dev/null 2>&1; then
    sudo groupadd docker
fi

if id -nG "$USER" | grep -qw docker; then

    info "$USER is already in the docker group."

else

    sudo usermod -aG docker "$USER"

    success "Added $USER to docker group."

fi

sudo systemctl enable docker
sudo systemctl start docker

if sudo systemctl is-active --quiet docker; then
    success "Docker service is running."
else
    warning "Docker service could not be verified as running."
fi

# ============================================================
# 12. AWS CLI V2
# ============================================================

section "Installing AWS CLI v2"

if command -v aws >/dev/null 2>&1; then

    info "AWS CLI already installed."
    success "AWS CLI: $(aws --version)"

else

    ARCH=$(dpkg --print-architecture)

    case "$ARCH" in

        amd64)
            AWS_URL="https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"
            ;;

        arm64)
            AWS_URL="https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip"
            ;;

        *)
            error "Unsupported architecture: $ARCH"
            exit 1
            ;;

    esac

    TMP_DIR=$(mktemp -d)

    curl -fsSL \
        "$AWS_URL" \
        -o "$TMP_DIR/awscliv2.zip"

    unzip -q \
        "$TMP_DIR/awscliv2.zip" \
        -d "$TMP_DIR"

    sudo "$TMP_DIR/aws/install"

    rm -rf "$TMP_DIR"

    success "AWS CLI installed."

fi

success "AWS CLI: $(aws --version)"

# ============================================================
# 13. PYTHON PROJECT HELPER
# ============================================================

section "Creating Python Project Helper"

mkdir -p "$HOME/.local/bin"

cat > "$HOME/.local/bin/setup-python-project" <<'EOF'
#!/usr/bin/env bash

set -Eeuo pipefail

PROJECT_DIR="${1:-.}"

mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

echo "[INFO] Project directory: $(pwd)"

if [ ! -d ".venv" ]; then

    echo "[INFO] Creating Python virtual environment..."

    python3 -m venv .venv

else

    echo "[INFO] Existing .venv found."

fi

source .venv/bin/activate

echo "[INFO] Upgrading pip..."

python -m pip install --upgrade pip setuptools wheel

echo
echo "============================================================"
echo "Python environment ready"
echo "============================================================"
echo

echo "Virtual environment:"
echo "    $(which python)"

echo
echo "Python version:"
python --version

echo
echo "pip version:"
python -m pip --version

echo
echo "To activate it later:"
echo
echo "    source .venv/bin/activate"
echo

if [ -f "requirements.txt" ]; then

    echo "requirements.txt detected."
    echo

    read -r -p "Install requirements.txt now? [y/N]: " INSTALL_REQUIREMENTS

    if [[ "$INSTALL_REQUIREMENTS" =~ ^[Yy]$ ]]; then

        python -m pip install -r requirements.txt

        echo
        echo "[OK] Python dependencies installed."

    fi

fi
EOF

chmod +x "$HOME/.local/bin/setup-python-project"

if ! grep -qF 'export PATH="$HOME/.local/bin:$PATH"' "$HOME/.bashrc" 2>/dev/null; then

    cat >> "$HOME/.bashrc" <<'EOF'

export PATH="$HOME/.local/bin:$PATH"
EOF

fi

export PATH="$HOME/.local/bin:$PATH"

success "setup-python-project command created."

# ============================================================
# 14. PYTHON BOTO3 TEST PROJECT
# ============================================================

section "Creating AWS Python Environment"

AWS_PYTHON_DIR="$HOME/aws-python"

if [ ! -d "$AWS_PYTHON_DIR/.venv" ]; then

    info "Creating AWS Python virtual environment..."

    mkdir -p "$AWS_PYTHON_DIR"

    python3 -m venv "$AWS_PYTHON_DIR/.venv"

fi

"$AWS_PYTHON_DIR/.venv/bin/python" -m pip install --upgrade pip

"$AWS_PYTHON_DIR/.venv/bin/python" -m pip install boto3

success "Boto3 installed inside:"
echo "    $AWS_PYTHON_DIR/.venv"

# Test boto3 import without requiring AWS credentials

"$AWS_PYTHON_DIR/.venv/bin/python" -c \
    "import boto3; print('Boto3:', boto3.__version__)"

# ============================================================
# 15. FINAL VERIFICATION
# ============================================================

section "Installation Verification"

echo "Git:"
git --version

echo
echo "Python:"
python3 --version

echo
echo "pip:"
python3 -m pip --version

echo
echo "venv:"
python3 -m venv --help >/dev/null && echo "available"

echo
echo "pipx:"
pipx --version

echo
echo "Node.js:"
node --version

echo
echo "npm:"
npm --version

echo
echo "npx:"
npx --version

echo
echo ".NET:"
dotnet --version

echo
echo "Docker:"
docker --version

echo
echo "Docker Compose:"
docker compose version

echo
echo "Docker Buildx:"
docker buildx version

echo
echo "AWS CLI:"
aws --version

echo
echo "Boto3:"
"$HOME/aws-python/.venv/bin/python" -c \
    "import boto3; print(boto3.__version__)"

echo
echo "jq:"
jq --version

# ============================================================
# 16. COMPLETION
# ============================================================

section "SETUP COMPLETE"

echo -e "${GREEN}Ubuntu 22.04 full-stack environment is ready.${NC}"
echo

echo "Installed:"
echo
echo "  Git"
echo "  Python 3"
echo "  pip"
echo "  Python venv"
echo "  pipx"
echo "  Node.js 22"
echo "  npm"
echo "  npx"
echo "  .NET SDK 10"
echo "  Docker"
echo "  Docker Compose"
echo "  Docker Buildx"
echo "  AWS CLI v2"
echo "  Boto3 (isolated virtual environment)"
echo "  Build tools"
echo "  Development utilities"
echo

echo "============================================================"
echo "IMPORTANT: DOCKER"
echo "============================================================"
echo

echo "Your user was added to the docker group."

echo
echo "For the permission change to take effect, either:"
echo
echo "  1. Log out and log back in"
echo "  2. SSH into the server again"
echo "  3. Or run:"
echo
echo "       newgrp docker"
echo

echo "Then test:"
echo
echo "    docker run hello-world"
echo

echo "============================================================"
echo "PYTHON / FASTAPI / BOTO3"
echo "============================================================"
echo

echo "Create a Python project:"
echo
echo "    mkdir my-project"
echo "    cd my-project"
echo "    setup-python-project"
echo

echo "Activate the environment:"
echo
echo "    source .venv/bin/activate"
echo

echo "Install application dependencies:"
echo
echo "    pip install fastapi uvicorn boto3"
echo

echo "Or use requirements.txt:"
echo
echo "    pip install -r requirements.txt"
echo

echo "For AWS Python development, an isolated Boto3 environment"
echo "has already been created at:"
echo
echo "    ~/aws-python/.venv"
echo

echo "Activate it with:"
echo
echo "    source ~/aws-python/.venv/bin/activate"
echo

echo "============================================================"
echo "REACT / TAILWIND"
echo "============================================================"
echo

echo "Go to your frontend:"
echo
echo "    cd frontend"
echo "    npm install"
echo "    npm run dev"
echo

echo "============================================================"
echo ".NET"
echo "============================================================"
echo

echo "Check:"
echo
echo "    dotnet --version"
echo

echo "Build:"
echo
echo "    dotnet restore"
echo "    dotnet build"
echo "    dotnet run"
echo

echo "============================================================"
echo "AWS"
echo "============================================================"
echo

echo "Check AWS CLI:"
echo
echo "    aws --version"
echo

echo "Configure credentials if required:"
echo
echo "    aws configure"
echo

echo "Check the current AWS identity:"
echo
echo "    aws sts get-caller-identity"
echo

echo "Using Boto3:"
echo
echo "    source ~/aws-python/.venv/bin/activate"
echo
echo "    python -c \"import boto3; print(boto3.client('sts').get_caller_identity()['Arn'])\""
echo

echo "============================================================"
echo "DONE"
echo "============================================================"
