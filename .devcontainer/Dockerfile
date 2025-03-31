FROM mcr.microsoft.com/devcontainers/base:ubuntu

# Install basic dependencies
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
    build-essential \
    inotify-tools \
    postgresql-client \
    git \
    curl \
    unzip \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && apt-get update \
    && apt-get install -y sudo \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

USER $USERNAME

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
COPY --chown=$USERNAME:$USERNAME .tool-versions /workspaces/lux/.tool-versions

# Install versions from tool-versions
RUN . "$HOME/.asdf/asdf.sh" && cd /workspaces/lux && asdf install

# Install hex, rebar, and phoenix
RUN . "$HOME/.asdf/asdf.sh" \
    && mix local.hex --force \
    && mix local.rebar --force \
    && mix archive.install hex phx_new --force

WORKDIR /workspaces/lux 