FROM ubuntu:24.10

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV ASDF_DIR=/root/.asdf
ENV PATH="${ASDF_DIR}/bin:${ASDF_DIR}/shims:${PATH}"
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV ELIXIR_ERL_OPTIONS="+fnu"

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    autoconf \
    m4 \
    libncurses-dev \
    libwxgtk3.2-dev \
    libwxgtk-webview3.2-dev \
    libgl1-mesa-dev \
    libglu1-mesa-dev \
    libpng-dev \
    libssh-dev \
    unixodbc-dev \
    xsltproc \
    fop \
    libxml2-utils \
    openjdk-17-jdk \
    libffi-dev \
    libsqlite3-dev \
    libbz2-dev \
    libreadline-dev \
    liblzma-dev \
    git \
    curl \
    wget \
    unzip \
    vim \
    locales \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Configure locale
RUN locale-gen en_US.UTF-8

# Install asdf
RUN git clone https://github.com/asdf-vm/asdf.git ${ASDF_DIR} --branch v0.13.1 \
    && echo '. ${ASDF_DIR}/asdf.sh' >> /root/.bashrc \
    && echo '. ${ASDF_DIR}/completions/asdf.bash' >> /root/.bashrc

# Set up shell for asdf
RUN echo '. ${ASDF_DIR}/asdf.sh' >> /root/.bashrc \
    && echo '. ${ASDF_DIR}/completions/asdf.bash' >> /root/.bashrc

# Install asdf plugins
RUN . ${ASDF_DIR}/asdf.sh \
    && asdf plugin add erlang https://github.com/asdf-vm/asdf-erlang.git \
    && asdf plugin add elixir https://github.com/asdf-vm/asdf-elixir.git \
    && asdf plugin add nodejs https://github.com/asdf-vm/asdf-nodejs.git \
    && asdf plugin add python https://github.com/danhper/asdf-python.git \
    && asdf plugin add poetry https://github.com/asdf-community/asdf-poetry.git

# Create root directory
WORKDIR /workspace

# Clone the repository
RUN git clone https://github.com/Spectral-Finance/lux .

# Install tools with asdf
RUN . ${ASDF_DIR}/asdf.sh && asdf install

# Change to the lux subdirectory
WORKDIR /workspace/lux

# Install Elixir dependencies
RUN . ${ASDF_DIR}/asdf.sh \
    && mix local.hex --force \
    && mix local.rebar --force \
    && mix deps.get \
    && mix setup

# Install required Python packages for testing - core packages first
RUN . ${ASDF_DIR}/asdf.sh \
    && python -m pip install setuptools==68.0.0 \
    && python -m pip install web3==6.15.1 \
    && python -m pip install nltk==3.9.1 \
    && python -m pip install erlport==0.6 \
    && python -m pip install hyperliquid-python-sdk==0.9.0 \
    && python -m pip install pytest==7.4.0 pytest-cov==4.1.0

# Install eth-tester with compatible dependencies
RUN . ${ASDF_DIR}/asdf.sh \
    && python -m pip install mypy-extensions==0.4.3 \
    && python -m pip install eth-tester[py-evm]==0.9.0b1

# Install development tools with compatible versions
RUN . ${ASDF_DIR}/asdf.sh \
    && python -m pip install black==23.7.0 isort==5.12.0 mypy==1.5.1

# Set the default command
CMD ["/bin/bash"]
