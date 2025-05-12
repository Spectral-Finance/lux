FROM mcr.microsoft.com/devcontainers/base:ubuntu

# Install system dependencies
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
    build-essential \
    autoconf \
    m4 \
    libncurses-dev \
    libssl-dev \
    libsctp-dev \
    inotify-tools \
    curl \
    git \
    unzip \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

# Switch to vscode user for asdf installation (comes with base image)
USER vscode

# Install asdf
RUN git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.14.0 \
    && echo '. "$HOME/.asdf/asdf.sh"' >> ~/.bashrc \
    && echo '. "$HOME/.asdf/completions/asdf.bash"' >> ~/.bashrc \
    && echo '. "$HOME/.asdf/asdf.sh"' >> ~/.zshrc \
    && echo '. "$HOME/.asdf/completions/asdf.bash"' >> ~/.zshrc

# Source asdf for the installation
SHELL ["/bin/bash", "-lc"]

# Install asdf plugins
RUN . $HOME/.asdf/asdf.sh \
    && asdf plugin add erlang \
    && asdf plugin add elixir \
    && asdf plugin add python \
    && asdf plugin add nodejs \
    && asdf plugin add poetry

WORKDIR /workspaces/lux 