FROM mcr.microsoft.com/vscode/devcontainers/universal:linux

# Install basic dependencies
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
    build-essential \
    inotify-tools \
    postgresql-client \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

USER vscode

# Install asdf and plugins
RUN git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.13.1 \
    && echo '. "$HOME/.asdf/asdf.sh"' >> ~/.bashrc \
    && echo '. "$HOME/.asdf/completions/asdf.bash"' >> ~/.bashrc \
    && . "$HOME/.asdf/asdf.sh" \
    && asdf plugin add erlang https://github.com/asdf-vm/asdf-erlang.git \
    && asdf plugin add elixir https://github.com/asdf-vm/asdf-elixir.git \
    && asdf plugin add python \
    && asdf plugin add nodejs https://github.com/asdf-vm/asdf-nodejs.git

# Copy tool-versions file
COPY --chown=vscode:vscode ../.tool-versions /workspaces/lux/.tool-versions

# Install versions from tool-versions
RUN . "$HOME/.asdf/asdf.sh" && cd /workspaces/lux && asdf install

WORKDIR /workspaces/lux 