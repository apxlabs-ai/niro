# syntax=docker/dockerfile:1
#
# Niro runner image for GitHub Actions and self-hosted CI.
#
# This image is intentionally a broad CI toolbox. It provides Niro, common
# build/runtime tools, browsers, GitHub CLI, Docker client/Compose, and coding
# agent CLIs. It does not run the GitHub Actions runner daemon itself.
# In GitHub Actions, use it as a job container or as the base for a self-hosted
# runner image.

FROM ubuntu:24.04

ARG TARGETARCH
ARG NIRO_VERSION
ARG CLAUDE_CODE_VERSION=latest
ARG CODEX_CLI_VERSION=latest

COPY docker/runner/scripts/collect-debug-artifacts.sh /usr/local/bin/niro-collect-debug-artifacts
COPY docker/runner/scripts/run-niro.sh /usr/local/bin/run-niro

ENV DEBIAN_FRONTEND=noninteractive \
    NIRO_INSTALL_DIR=/usr/local/bin \
    PIP_BREAK_SYSTEM_PACKAGES=1

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
      bash \
      ca-certificates \
      chromium \
      chromium-driver \
      curl \
      dnsutils \
      git \
      gnupg \
      jq \
      make \
      netcat-openbsd \
      openssh-client \
      postgresql-client \
      python3 \
      python3-pip \
      python3-venv \
      redis-tools \
      rsync \
      shellcheck \
      sudo \
      tar \
      unzip \
      wget \
      xz-utils \
      zip \
    && rm -rf /var/lib/apt/lists/*

RUN chmod 0755 /usr/local/bin/niro-collect-debug-artifacts /usr/local/bin/run-niro

# Install Docker client + Compose plugin. A Docker daemon is not included; this
# works when the host exposes Docker or a self-hosted runner provides it.
RUN install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
      | gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
    && chmod a+r /etc/apt/keyrings/docker.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu noble stable" \
      > /etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends docker-ce-cli docker-compose-plugin \
    && rm -rf /var/lib/apt/lists/*

# Install GitHub CLI.
RUN install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      -o /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js and common JS package managers from NodeSource.
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && npm install -g pnpm yarn \
    && npm cache clean --force \
    && rm -rf /var/lib/apt/lists/*

# Install Go from upstream tarballs so the image is not tied to Ubuntu's lagging
# Go version.
RUN case "${TARGETARCH:-$(dpkg --print-architecture)}" in \
      amd64) GOARCH=amd64 ;; \
      arm64) GOARCH=arm64 ;; \
      *) echo "unsupported TARGETARCH=${TARGETARCH}" >&2; exit 1 ;; \
    esac \
    && GO_VERSION="$(curl -fsSL https://go.dev/VERSION?m=text | head -n1)" \
    && curl -fsSL "https://go.dev/dl/${GO_VERSION}.linux-${GOARCH}.tar.gz" -o /tmp/go.tgz \
    && rm -rf /usr/local/go \
    && tar -C /usr/local -xzf /tmp/go.tgz \
    && rm /tmp/go.tgz

ENV PATH="/usr/local/go/bin:${PATH}"

# Install Niro from the released binary. NIRO_VERSION must be the same release
# tag used for the published image, for example "v0.1.32".
RUN if [[ ! "${NIRO_VERSION}" =~ ^v[0-9]+[.][0-9]+[.][0-9]+ ]]; then \
      echo "NIRO_VERSION must be a release tag like v0.1.32" >&2; \
      exit 1; \
    fi \
    && curl -fsSL https://raw.githubusercontent.com/apxlabs-ai/niro/main/install.sh \
      | NIRO_VERSION="${NIRO_VERSION}" NIRO_INSTALL_DIR=/usr/local/bin sh \
    && niro version

# Install supported coding agent CLIs. Runtime agent selection and secrets still
# come from the CI environment.
RUN npm install -g "@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}" "@openai/codex@${CODEX_CLI_VERSION}" \
    && claude --version \
    && codex --version \
    && gh extension install github/gh-copilot \
    && gh extension list | grep -q "github/gh-copilot"

WORKDIR /workspace

CMD ["/bin/bash"]
