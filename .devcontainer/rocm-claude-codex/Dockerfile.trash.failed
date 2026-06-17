FROM ghcr.io/quokka-astro/quokka-linux-amd64-rocm:development

ENV TARGETARCH="linux/amd64"

USER root

# Install baseline tools for interactive agentic coding, debugging, and PR workflows.
RUN zypper --non-interactive refresh && \
    zypper --non-interactive install -y --no-recommends \
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
        less \
        nano \
        nodejs \
        npm \
        openssh-clients \
        python3-h5py \
        python3-pip \
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
RUN pip3 install --break-system-packages pre-commit

# Install the GitHub CLI from GitHub's RPM repository.
RUN zypper --non-interactive addrepo https://cli.github.com/packages/rpm/gh-cli.repo gh-cli && \
    zypper --non-interactive --gpg-auto-import-keys refresh gh-cli && \
    zypper --non-interactive install -y gh && \
    zypper clean --all

# Create ubuntu user with passwordless sudo (mirrors the cuda-claude image convention).
RUN useradd -m -s /bin/bash ubuntu && \
    echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ubuntu && \
    chmod 0440 /etc/sudoers.d/ubuntu

RUN git lfs install --system

USER ubuntu
WORKDIR /home/ubuntu

# Install Claude Code CLI and Codex CLI for the default non-root user.
RUN curl -fsSL https://claude.ai/install.sh | bash && \
    npm install -g @openai/codex

ENV PATH="/home/ubuntu/.local/bin:/home/ubuntu/.claude/local:/home/ubuntu/superpowers/quokka/bin:${PATH}" \
    PIP_BREAK_SYSTEM_PACKAGES=1

CMD [ "/bin/bash" ]
