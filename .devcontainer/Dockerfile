ARG RUBY_VERSION=4.0.7
FROM ghcr.io/rails/devcontainer/images/ruby:$RUBY_VERSION

RUN sudo apt-get update && \
    sudo apt-get install -y --no-install-recommends \
      libpq-dev \
      mecab \
      libmecab-dev \
      mecab-naist-jdic \
    && sudo rm -rf /var/lib/apt/lists/*

WORKDIR /workspace