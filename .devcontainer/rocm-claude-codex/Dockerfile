FROM ghcr.io/quokka-astro/quokka-linux-amd64-rocm:development

ENV TARGETARCH="linux/amd64"

USER root

# Add Node.js repository (not in base image).
RUN zypper --non-interactive addrepo --refresh \
        https://download.opensuse.org/repositories/devel:/languages:/nodejs/openSUSE_Leap_15.6/devel:languages:nodejs.repo && \
    zypper --non-interactive --gpg-auto-import-keys refresh

# Install baseline tools for interactive agentic coding, debugging, and PR workflows.
RUN zypper --non-interactive install --no-recommends \
        bash-completion \
        ca-certificates \
        ccache \
        curl \
        fd \
        fzf \
        gdb \
        git \
        git-lfs \
        gpg2 \
        jq \
        nano \
        nodejs \
        npm \
        openssh-clients \
        ripgrep \
        ShellCheck \
        sudo \
        tmux \
        unzip \
        vim \
        wget \
        zip && \
    zypper clean --all

# Install pre-commit via pip (not in openSUSE repos).
RUN pip3 install pre-commit

# Install the GitHub CLI from GitHub's RPM repository.
RUN zypper --non-interactive addrepo --refresh https://cli.github.com/packages/rpm/gh-cli.repo && \
    zypper --non-interactive --gpg-auto-import-keys install gh && \
    zypper clean --all

# Create ubuntu user with passwordless sudo (mirrors the cuda-claude image convention).
RUN useradd -m -s /bin/bash ubuntu && \
    echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ubuntu && \
    chmod 0440 /etc/sudoers.d/ubuntu

RUN git lfs install --system

USER ubuntu
WORKDIR /home/ubuntu

# Configure npm to use a user-local prefix since we're not root.
ENV NPM_CONFIG_PREFIX="/home/ubuntu/.npm-global" \
    PATH="/home/ubuntu/.npm-global/bin:/home/ubuntu/.local/bin:/home/ubuntu/.claude/local:/home/ubuntu/superpowers/quokka/bin:${PATH}" \
    PIP_BREAK_SYSTEM_PACKAGES=1

# Install Claude Code CLI and Codex CLI for the default non-root user.
RUN curl -fsSL https://claude.ai/install.sh | bash && \
    npm install -g @openai/codex

CMD [ "/bin/bash" ]
