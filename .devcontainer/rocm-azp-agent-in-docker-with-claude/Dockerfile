# Use the AMD ROCm image as the base image
FROM ghcr.io/quokka-astro/quokka-linux-amd64-rocm:development
ENV TARGETARCH="linux/amd64"

USER root

# Install baseline tools for interactive agentic coding, debugging, and PR workflows.
# busybox-less conflicts with the full less package; remove it first.
RUN zypper --non-interactive refresh && \
    zypper --non-interactive update && \
    zypper --non-interactive remove busybox-less || true && \
    zypper --non-interactive install \
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
        libicu-devel \
        lldb \
        nano \
        ninja \
        nodejs20 \
        npm20 \
        openssh \
        python311 \
        python311-pip \
        python311-devel \
        python311-setuptools \
        python311-wheel \
        ripgrep \
        ShellCheck \
        sudo \
        tar \
        gzip \
        tmux \
        unzip \
        vim \
        wget \
        which \
        zip && \
    zypper clean --all

# Set Python 3.11 as the default python3
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1 && \
    update-alternatives --install /usr/bin/pip3 pip3 /usr/bin/pip3.11 1

# Install Python packages
RUN python3 -m pip install --upgrade pip && \
    python3 -m pip install h5py cached-property numpy matplotlib pre-commit

# Install Azure CLI for openSUSE
RUN rpm --import https://packages.microsoft.com/keys/microsoft.asc && \
    zypper --non-interactive addrepo \
        --name 'Azure CLI' \
        --check https://packages.microsoft.com/yumrepos/azure-cli \
        azure-cli && \
    zypper --non-interactive install azure-cli && \
    zypper clean --all

# Install the GitHub CLI by downloading the RPM directly from GitHub Releases.
RUN GH_VERSION=$(curl -fsSL https://api.github.com/repos/cli/cli/releases/latest | jq -r '.tag_name' | sed 's/^v//') && \
    curl -fsSLo /tmp/gh.rpm "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_amd64.rpm" && \
    rpm -ivh /tmp/gh.rpm && \
    rm /tmp/gh.rpm

# Initialize git-lfs system-wide, create fd alias, and install codex globally.
RUN git lfs install --system && \
    ln -sf /usr/bin/fd /usr/local/bin/fd && \
    npm install -g @openai/codex

# Create agent user with sudo access
WORKDIR /azp/

RUN groupadd agent && \
    useradd -m -d /home/agent -s /bin/bash -g agent agent && \
    usermod -a -G users agent && \
    echo "agent ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/agent && \
    chmod 0440 /etc/sudoers.d/agent && \
    chown -R agent:agent /azp /home/agent

# Switch to agent user and install Claude CLI.
USER agent
WORKDIR /home/agent

RUN curl -fsSL https://claude.ai/install.sh | bash

ENV PATH="/home/agent/.local/bin:/home/agent/.claude/local:/home/agent/superpowers/quokka/bin:${PATH}" \
    PIP_BREAK_SYSTEM_PACKAGES=1

CMD [ "/bin/bash" ]
