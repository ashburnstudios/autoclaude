# AutoClaude Development Sandbox
FROM ubuntu:22.04

# Prevent interactive prompts during installation
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# Install base dependencies
RUN apt-get update && apt-get install -y \
    # Core utilities
    curl \
    wget \
    git \
    jq \
    zip \
    unzip \
    build-essential \
    software-properties-common \
    ca-certificates \
    gnupg \
    lsb-release \
    # Development tools
    vim \
    nano \
    tree \
    htop \
    # Network tools (restricted)
    dnsutils \
    netcat \
    # Process management
    supervisor \
    && rm -rf /var/lib/apt/lists/*

# Install Python and common tools
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js (LTS)
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install Go
RUN wget -q https://go.dev/dl/go1.21.5.linux-amd64.tar.gz \
    && tar -C /usr/local -xzf go1.21.5.linux-amd64.tar.gz \
    && rm go1.21.5.linux-amd64.tar.gz

# Install Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

# Install Docker CLI (for Docker-in-Docker scenarios)
RUN curl -fsSL https://get.docker.com | sh

# Install GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update \
    && apt-get install gh -y \
    && rm -rf /var/lib/apt/lists/*

# Set up environment variables
ENV PATH="/usr/local/go/bin:/root/.cargo/bin:${PATH}"
ENV PYTHONUNBUFFERED=1

# Create working directory
WORKDIR /workspace

# Create non-root user for better security
RUN useradd -m -s /bin/bash claude \
    && usermod -aG sudo claude \
    && echo "claude ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Install common Python packages
RUN pip3 install --no-cache-dir \
    requests \
    flask \
    fastapi \
    pytest \
    black \
    flake8 \
    mypy \
    pandas \
    numpy \
    matplotlib \
    jupyter

# Install common Node packages globally
RUN npm install -g \
    typescript \
    @types/node \
    eslint \
    prettier \
    jest \
    nodemon \
    pm2

# Set up resource limits
RUN echo "claude soft nproc 1024" >> /etc/security/limits.conf \
    && echo "claude hard nproc 2048" >> /etc/security/limits.conf \
    && echo "claude soft nofile 4096" >> /etc/security/limits.conf \
    && echo "claude hard nofile 8192" >> /etc/security/limits.conf

# Configure git
RUN git config --global user.name "Claude Code" \
    && git config --global user.email "claude@autoclaude.local" \
    && git config --global init.defaultBranch main

# Add sandbox marker
RUN echo "AUTOCLAUDE_SANDBOX=true" >> /etc/environment

# Switch to non-root user
USER claude
WORKDIR /home/claude/workspace

# Default command
CMD ["/bin/bash"]