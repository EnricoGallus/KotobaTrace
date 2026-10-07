# Development Dockerfile for Dev Containers
ARG RUBY_VERSION=4.0.7
FROM ruby:${RUBY_VERSION}-slim

# Install system dependencies
RUN set -ex && \
    apt-get update -qq && \
    apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    curl \
    git \
    gnupg \
    libc6 \
    libjemalloc2 \
    libpq-dev \
    libvips \
    libyaml-dev \
    pkg-config \
    postgresql-client \
    python3 \
    wget \
    chromium \
    chromium-driver \
    mecab libmecab-dev mecab-naist-jdic \
    && rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Install Node.js from official distribution
ARG NODE_VERSION=24.21.0
RUN set -ex && \
    NODE_ARCH=$(uname -m | sed 's/x86_64/x64/; s/aarch64/arm64/') && \
    cd /tmp && \
    curl -fsSL https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${NODE_ARCH}.tar.gz -o node.tar.gz && \
    tar -xzf node.tar.gz -C /usr/local --strip-components=1 && \
    rm node.tar.gz && \
    node --version && \
    npm --version

# Install Yarn
ARG YARN_VERSION=1.22.22
RUN npm install -g yarn@${YARN_VERSION} && yarn --version

# Install Bundler and development tools
RUN gem install bundler --no-document && \
    gem install foreman --no-document

WORKDIR /workspace

ENV RAILS_ENV=development \
    BUNDLE_PATH=/usr/local/bundle \
    GEM_HOME=/usr/local/bundle \
    NODE_ENV=development

# Health check to prevent early exit
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD [ -d /workspace ] || exit 1
