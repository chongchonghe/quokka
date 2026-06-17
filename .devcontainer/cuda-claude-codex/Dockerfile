FROM ghcr.io/quokka-astro/quokka-linux-amd64-cuda:development

ENV TARGETARCH="linux/amd64" \
    DEBIAN_FRONTEND=noninteractive \
    NVIDIA_VISIBLE_DEVICES=all \
    NVIDIA_DRIVER_CAPABILITIES=compute,utility

USER root

# Refresh the inherited Kitware apt key before any apt update.
RUN rm -f /usr/share/keyrings/kitware-archive-keyring.gpg && \
    curl -fsSL https://apt.kitware.com/keys/kitware-archive-latest.asc | gpg --dearmor -o /usr/share/keyrings/kitware-archive-keyring.gpg

# Install baseline tools for interactive agentic coding, debugging, and PR workflows.
RUN apt-get update -qq && \
    apt-get install -y -qq --no-install-recommends \
        apt-transport-https \
        bash-completion \
        ca-certificates \
        ccache \
        curl \
        fd-find \
        fzf \
        gdb \
        git \
        git-lfs \
        gnupg \
        jq \
        less \
        lldb \
        nano \
        nodejs \
        npm \
        openssh-client \
        pre-commit \
        python3-h5py \
        python3-pip \
        python3-venv \
        ripgrep \
        shellcheck \
        sudo \
        tmux \
        unzip \
        vim \
        wget \
        zip && \
    rm -rf /var/lib/apt/lists/*

# Install the GitHub CLI from GitHub's apt repository.
RUN mkdir -p -m 0755 /etc/apt/keyrings && \
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/etc/apt/keyrings/githubcli-archive-keyring.gpg && \
    chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list && \
    apt-get update -qq && \
    apt-get install -y -qq --no-install-recommends gh && \
    rm -rf /var/lib/apt/lists/*

# Keep the image usable for devcontainer shells and one-off package installs.
RUN git lfs install --system && \
    ln -sf /usr/bin/fdfind /usr/local/bin/fd && \
    usermod -aG sudo ubuntu && \
    echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ubuntu && \
    chmod 0440 /etc/sudoers.d/ubuntu

USER ubuntu
WORKDIR /home/ubuntu

# Install Claude CLI for the default non-root user.
RUN curl -fsSL https://claude.ai/install.sh | bash && \
    npm install -g @openai/codex

ENV PATH="/home/ubuntu/.local/bin:/home/ubuntu/.claude/local:/home/ubuntu/superpowers/quokka/bin:${PATH}" \
    PIP_BREAK_SYSTEM_PACKAGES=1

CMD [ "/bin/bash" ]
