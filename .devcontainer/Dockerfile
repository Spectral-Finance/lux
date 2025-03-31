FROM mcr.microsoft.com/vscode/devcontainers/universal:linux

# Install basic dependencies
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
    build-essential \
    inotify-tools \
    postgresql-client \
    erlang \
    elixir \
    python3 \
    python3-pip \
    nodejs \
    npm \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

# Install Phoenix
RUN mix local.hex --force && \
    mix local.rebar --force && \
    mix archive.install hex phx_new --force

WORKDIR /workspaces/lux 