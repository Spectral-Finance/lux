# ███████╗██████╗ ███████╗ ██████╗████████╗██████╗  █████╗ ██╗     
# ██╔════╝██╔══██╗██╔════╝██╔════╝╚══██╔══╝██╔══██╗██╔══██╗██║     
# ███████╗██████╔╝█████╗  ██║        ██║   ██████╔╝███████║██║     
# ╚════██║██╔═══╝ ██╔══╝  ██║        ██║   ██╔══██╗██╔══██║██║     
# ███████║██║     ███████╗╚██████╗   ██║   ██║  ██║██║  ██║███████╗
# ╚══════╝╚═╝     ╚══════╝ ╚═════╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝
#
# Lux Framework - https://github.com/Spectral-Finance/lux/

SHELL := /bin/bash

# Color definitions using tput
CYAN := $$(tput setaf 6)
BOLD := $$(tput bold)
RESET := $$(tput sgr0)
DIM := $$(tput dim)
RED := $$(tput setaf 1)
GREEN := $$(tput setaf 2)
YELLOW := $$(tput setaf 3)
BLUE := $$(tput setaf 4)
MAGENTA := $$(tput setaf 5)
WHITE := $$(tput setaf 7)

.PHONY: help setup setup-asdf setup-deps setup-mac setup-linux setup-shell test show-logo

define LOGO
		     ██╗      ██╗   ██╗██╗  ██╗
		     ██║      ██║   ██║╚██╗██╔╝
		     ██║      ██║   ██║ ╚███╔╝ 
		     ██║      ██║   ██║ ██╔██╗ 
		     ███████╗ ╚██████╔╝██╔╝ ██╗
		     ╚══════╝  ╚═════╝ ╚═╝  ╚═╝
    ,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
    ,,,,,,,,,,,,,,,,,,,,,,,,,,,,,@@@,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
    ,,,,,,,,,,,,,,,,,,,,,,,,,,,/@,@@@%,,,,,,,,,,,,,,,,,,,,,,,,,,,
    ,,,,,,,,,,,,,,,,,,,,,,,,,,@,,,@@@@@,,,,,,,,,,,,,,,,,,,,,,,,,,
    ,,,,,,,,,,,,,,,,,,,,,,,,*%,,,,@@@@@@@,,,,,,,,,,,,,,,,,,,,,,,,
    ,,,,,,,,,,,,,,,,,,,,,,,@,,,,,,@@@@@@@@,,,,,,,,,,,,,,,,,,,,,,,
    ,,,,,,,,,,,,,,,,,,,,,#&,,,,,,,@@@@@@@@@&,,,,,,,,,,,,,,,,,,,,,
    ,,,,,,,,,,,,,,,,,,,,@,,,,,,,,,@@@@@@@@@@@,,,,,,,,,,,,,,,,,,,,
    ,,,,,,,,,,,,,,,,,,&#,,,,,,,,/&&,@@@@@@@@@@@,,,,,,,,,,,,,,,,,,
    ,,,,,,,,,,,,,,,,,@,,,,,,,,,@,,@@,#@@@@@@@@@@,,,,,,,,,,,,,,,,,
    ,,,,,,,,,,,,,,,&(,,,,,,,,#&,,,@@@@,@@@@@@@@@@@,,,,,,,,,,,,,,,
    ,,,,,,,,,,,,,,@,,,,,,,,,@,,,,,@@@@@#,@@@@@@@@@@*,,,,,,,,,,,,,
    ,,,,,,,,,,,,@/,,,,,,,,&#,,,,,,@@@@@@@,&@@@@@@@@@@,,,,,,,,,,,,
    ,,,,,,,,,,,@,,,,,,,,,@,,,,,,,,@@@@@@@@@,@@@@@@@@@@,,,,,,,,,,,
    ,,,,,,,,,&*,,,,,,,,#(,,,,,,,,,@@@@@@@@@@#/@@@@@@@@@@,,,,,,,,,
    ,,,,,,,*@,,,,,,,,,@,,,,,,,,,,,@@@@@@@@@@@@,@@@@@@@@@@(,,,,,,,
    ,,,,,,@/,,,,,,#@@%@/,,,,,,,,,,@@@@@@@@@@@&,,,,*@@@@@@@@,,,,,,
    ,,,,*@,/@@/,,,,,,,,,,,@@,,,,,,@@@@@@%,*@@@@@@@@@@@&,,(@@#,,,,
    ,,,,@@,,,,,,,,,,,,,,,,,,,,#@(,@@,,@@@@@@@@@@@@@@@@@@@@@@@,,,,
    ,,,,,,,,(@(,,,,,,,,,,,,,,,,,,,@@@@@@@@@@@@@@@@@@@@@@%,,,,,,,,
    ,,,,,,,,,,,,,@@,,,,,,,,,,,,,,,@@@@@@@@@@@@@@@@@@,,,,,,,,,,,,,
    ,,,,,,,,,,,,,,,,,/@%,,,,,,,,,,@@@@@@@@@@@@@#,,,,,,,,,,,,,,,,,
    ,,,,,,,,,,,,,,,,,,,,,,&@*,,,,,@@@@@@@@@,,,,,,,,,,,,,,,,,,,,,,
    ,,,,,,,,,,,,,,,,,,,,,,,,,,*@%,@@@@(,,,,,,,,,,,,,,,,,,,,,,,,,,
    ,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,

			    by Spectral

endef
export LOGO

show-logo: ## Display the Lux logo
	@printf "$(CYAN)%s$(RESET)" "$$LOGO" | sed -e "s/spectral/$(DIM)spectral$(RESET)/g"

help: show-logo ## Show this help
	@echo "Lux Development Setup Commands:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "$(CYAN)%-30s$(RESET) %s\n", $$1, $$2}'

setup: show-logo ## Run complete setup (recommended)
	@echo "Welcome to Lux setup!"
	@echo "This setup process will:"
	@echo "  1. Configure your shell for asdf (modifies shell config files)"
	@echo "  2. Install required asdf plugins and tools"
	@echo "  3. Set up project dependencies"
	@echo ""
	@echo "Would you like to proceed? [y/N] "
	@read -r response; \
	if [ "$$response" != "y" ] && [ "$$response" != "Y" ]; then \
		echo "Setup cancelled."; \
		exit 1; \
	fi
	@if [ ! -x "$$(command -v asdf)" ]; then \
		echo "asdf not found. Please install asdf first:"; \
		echo "  Mac: brew install asdf"; \
		echo "  Linux: git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.13.1"; \
		echo "  Then add it to your shell config and restart your terminal"; \
		exit 1; \
	fi
	@$(MAKE) setup-shell
	@$(MAKE) setup-asdf
	@$(MAKE) setup-deps
	@echo "Setup complete! Run 'make test' to verify installation"

setup-shell: ## Configure shell for asdf
	@echo "Shell Configuration"
	@echo "==================="
	@SHELL_TYPE=$$(basename $$SHELL); \
	ASDF_DIR="$${HOME}/.asdf"; \
	if [ "$$SHELL_TYPE" = "zsh" ]; then \
		RCFILE="$$HOME/.zshrc"; \
	else \
		RCFILE="$$HOME/.bashrc"; \
	fi; \
	echo "Your current shell is: $$SHELL_TYPE"; \
	echo "Configuration file: $$RCFILE"; \
	echo ""; \
	if [ ! -f "$$RCFILE" ]; then \
		echo "Configuration file does not exist. Would you like to create it? [y/N] "; \
		read -r response; \
		if [ "$$response" != "y" ] && [ "$$response" != "Y" ]; then \
			echo "Setup cancelled."; \
			exit 1; \
		fi; \
		touch "$$RCFILE"; \
	fi; \
	if ! grep -q "asdf.sh" "$$RCFILE"; then \
		echo "Would you like to add asdf to your shell configuration? This will modify $$RCFILE [y/N] "; \
		read -r response; \
		if [ "$$response" = "y" ] || [ "$$response" = "Y" ]; then \
			echo "Adding asdf to $$RCFILE..."; \
			echo '. "$$ASDF_DIR/asdf.sh"' >> "$$RCFILE"; \
			if [ "$$SHELL_TYPE" = "zsh" ]; then \
				echo "fpath=($$ASDF_DIR/completions $$fpath)" >> "$$RCFILE"; \
			else \
				echo '. "$$ASDF_DIR/completions/asdf.bash"' >> "$$RCFILE"; \
			fi; \
			echo "Shell configuration updated."; \
		else \
			echo "Shell configuration skipped. You will need to manually configure asdf."; \
			echo "Add these lines to $$RCFILE:"; \
			echo '. "$$ASDF_DIR/asdf.sh"'; \
			if [ "$$SHELL_TYPE" = "zsh" ]; then \
				echo 'fpath=($$ASDF_DIR/completions $$fpath)'; \
			else \
				echo '. "$$ASDF_DIR/completions/asdf.bash"'; \
			fi; \
			exit 1; \
		fi; \
	else \
		echo "asdf is already configured in your shell."; \
	fi; \
	if [ "$$SHELL_TYPE" = "zsh" ] && [ -f "$$HOME/.zshenv" ]; then \
		if ! grep -q "ASDF_DIR" "$$HOME/.zshenv"; then \
			echo "Would you like to add ASDF_DIR to your .zshenv? [y/N] "; \
			read -r response; \
			if [ "$$response" = "y" ] || [ "$$response" = "Y" ]; then \
				echo "export ASDF_DIR=$$ASDF_DIR" >> "$$HOME/.zshenv"; \
				echo ".zshenv updated."; \
			fi; \
		fi; \
	fi
	@echo "Shell configuration complete. Please run: source $$RCFILE"

setup-asdf: ## Install asdf plugins and tools
	@echo "Installing asdf plugins..."
	@asdf plugin add erlang https://github.com/asdf-vm/asdf-erlang.git || true
	@asdf plugin add elixir https://github.com/asdf-vm/asdf-elixir.git || true
	@asdf plugin add nodejs https://github.com/asdf-vm/asdf-nodejs.git || true
	@asdf plugin add python https://github.com/danhper/asdf-python.git || true
	@asdf plugin add poetry https://github.com/asdf-community/asdf-poetry.git || true
	@echo "Installing tools with asdf..."
	@asdf install

setup-mac: ## Install Mac-specific dependencies
	@echo "Installing Mac dependencies..."
	@echo "This will install required system dependencies using Homebrew."
	@echo "The following packages will be installed:"
	@echo "  - autoconf"
	@echo "  - automake"
	@echo "  - libtool"
	@echo "  - wxmac"
	@echo "  - fop"
	@echo "  - openssl@3"
	@echo ""
	@echo "Would you like to proceed? [y/N] "
	@read -r response; \
	if [ "$$response" != "y" ] && [ "$$response" != "Y" ]; then \
		echo "Setup cancelled."; \
		exit 1; \
	fi
	@xcode-select --install || true
	@if [ ! -x "$$(command -v brew)" ]; then \
		echo "Homebrew not found. Would you like to install it? [y/N] "; \
		read -r response; \
		if [ "$$response" != "y" ] && [ "$$response" != "Y" ]; then \
			echo "Setup cancelled."; \
			exit 1; \
		fi; \
		/bin/bash -c "$$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; \
	fi
	@brew install autoconf automake libtool wxmac fop openssl@3
	@SHELL_TYPE=$$(basename $$SHELL); \
	if [ "$$SHELL_TYPE" = "zsh" ]; then \
		RCFILE="$$HOME/.zshrc"; \
	else \
		RCFILE="$$HOME/.bashrc"; \
	fi; \
	if ! grep -q "KERL_CONFIGURE_OPTIONS" "$$RCFILE"; then \
		echo "Would you like to configure OpenSSL for Erlang compilation? This will modify $$RCFILE [y/N] "; \
		read -r response; \
		if [ "$$response" = "y" ] || [ "$$response" = "Y" ]; then \
			echo "export KERL_CONFIGURE_OPTIONS=\"--with-ssl=$$(brew --prefix openssl@3)\"" >> "$$RCFILE"; \
			echo "OpenSSL configuration added to $$RCFILE"; \
		else \
			echo "OpenSSL configuration skipped. You may need to configure this manually."; \
			echo "Add this line to $$RCFILE:"; \
			echo "export KERL_CONFIGURE_OPTIONS=\"--with-ssl=$$(brew --prefix openssl@3)\""; \
		fi; \
	fi
	@export KERL_CONFIGURE_OPTIONS="--with-ssl=$$(brew --prefix openssl@3)"

setup-linux: ## Install Linux-specific dependencies
	@echo "Installing Linux dependencies..."
	@echo "This will install required system packages."
	@echo "You may be prompted for sudo password."
	@echo ""
	@echo "Would you like to proceed? [y/N] "
	@read -r response; \
	if [ "$$response" != "y" ] && [ "$$response" != "Y" ]; then \
		echo "Setup cancelled."; \
		exit 1; \
	fi
	@if [ -f /etc/debian_version ]; then \
		if grep -q "Ubuntu" /etc/os-release; then \
			echo "Detected Ubuntu system."; \
			echo "The following packages will be installed:"; \
			echo "  - build-essential"; \
			echo "  - autoconf"; \
			echo "  - m4"; \
			echo "  - libncurses-dev"; \
			echo "  - libwxgtk3.2-dev"; \
			echo "  - libwxgtk-webview3.2-dev"; \
			echo "  - libgl1-mesa-dev"; \
			echo "  - libglu1-mesa-dev"; \
			echo "  - libpng-dev"; \
			echo "  - libssh-dev"; \
			echo "  - unixodbc-dev"; \
			echo "  - xsltproc"; \
			echo "  - fop"; \
			echo "  - libxml2-utils"; \
			echo "  - openjdk-11-jdk"; \
			echo "  - libffi-dev"; \
			echo "  - libsqlite3-dev"; \
			echo "  - libbz2-dev"; \
			echo "  - libreadline-dev"; \
			echo "  - liblzma-dev"; \
			echo ""; \
			echo "Continue? [y/N] "; \
			read -r response; \
			if [ "$$response" = "y" ] || [ "$$response" = "Y" ]; then \
				if command -v sudo > /dev/null 2>&1; then \
					sudo apt-get update && \
					sudo apt-get install -y build-essential autoconf m4 libncurses-dev libwxgtk3.2-dev libwxgtk-webview3.2-dev libgl1-mesa-dev libglu1-mesa-dev libpng-dev libssh-dev unixodbc-dev xsltproc fop libxml2-utils openjdk-11-jdk libffi-dev libsqlite3-dev libbz2-dev libreadline-dev liblzma-dev; \
				else \
					apt-get update && \
					apt-get install -y build-essential autoconf m4 libncurses-dev libwxgtk3.2-dev libwxgtk-webview3.2-dev libgl1-mesa-dev libglu1-mesa-dev libpng-dev libssh-dev unixodbc-dev xsltproc fop libxml2-utils openjdk-11-jdk libffi-dev libsqlite3-dev libbz2-dev libreadline-dev liblzma-dev; \
				fi; \
			else \
				echo "Setup cancelled."; \
				exit 1; \
			fi; \
		else \
			echo "Detected Debian system."; \
			echo "The following packages will be installed:"; \
			echo "  - build-essential"; \
			echo "  - autoconf"; \
			echo "  - m4"; \
			echo "  - libncurses5-dev"; \
			echo "  - libwxgtk3.0-gtk3-dev"; \
			echo "  - libwxgtk-webview3.0-gtk3-dev"; \
			echo "  - libgl1-mesa-dev"; \
			echo "  - libglu1-mesa-dev"; \
			echo "  - libpng-dev"; \
			echo "  - libssh-dev"; \
			echo "  - unixodbc-dev"; \
			echo "  - xsltproc"; \
			echo "  - fop"; \
			echo "  - libxml2-utils"; \
			echo "  - libncurses-dev"; \
			echo "  - openjdk-11-jdk"; \
			echo ""; \
			echo "Continue? [y/N] "; \
			read -r response; \
			if [ "$$response" = "y" ] || [ "$$response" = "Y" ]; then \
				if command -v sudo > /dev/null 2>&1; then \
					sudo apt-get update && \
					sudo apt-get install -y build-essential autoconf m4 libncurses5-dev libwxgtk3.0-gtk3-dev libwxgtk-webview3.0-gtk3-dev libgl1-mesa-dev libglu1-mesa-dev libpng-dev libssh-dev unixodbc-dev xsltproc fop libxml2-utils libncurses-dev openjdk-11-jdk; \
				else \
					apt-get update && \
					apt-get install -y build-essential autoconf m4 libncurses5-dev libwxgtk3.0-gtk3-dev libwxgtk-webview3.0-gtk3-dev libgl1-mesa-dev libglu1-mesa-dev libpng-dev libssh-dev unixodbc-dev xsltproc fop libxml2-utils libncurses-dev openjdk-11-jdk; \
				fi; \
			else \
				echo "Setup cancelled."; \
				exit 1; \
			fi; \
		fi; \
	elif [ -f /etc/redhat-release ]; then \
		echo "Detected RHEL/CentOS system."; \
		echo "The following package groups/packages will be installed:"; \
		echo "  - Development Tools"; \
		echo "  - autoconf"; \
		echo "  - ncurses-devel"; \
		echo "  - openssl-devel"; \
		echo "  - wxGTK3-devel"; \
		echo "  - wxGTK-webview3-devel"; \
		echo "  - mesa-libGL-devel"; \
		echo "  - mesa-libGLU-devel"; \
		echo "  - libpng-devel"; \
		echo "  - libssh-devel"; \
		echo "  - unixODBC-devel"; \
		echo "  - xsltproc"; \
		echo "  - fop"; \
		echo "  - libxml2-utils"; \
		echo "  - ncurses-devel"; \
		echo "  - java-11-openjdk-devel"; \
		echo ""; \
		echo "Continue? [y/N] "; \
		read -r response; \
		if [ "$$response" = "y" ] || [ "$$response" = "Y" ]; then \
			if command -v sudo > /dev/null 2>&1; then \
				sudo yum groupinstall -y "Development Tools" && \
				sudo yum install -y autoconf ncurses-devel openssl-devel wxGTK3-devel wxGTK-webview3-devel mesa-libGL-devel mesa-libGLU-devel libpng-devel libssh-devel unixODBC-devel xsltproc fop libxml2-utils ncurses-devel java-11-openjdk-devel; \
			else \
				yum groupinstall -y "Development Tools" && \
				yum install -y autoconf ncurses-devel openssl-devel wxGTK3-devel wxGTK-webview3-devel mesa-libGL-devel mesa-libGLU-devel libpng-devel libssh-devel unixODBC-devel xsltproc fop libxml2-utils ncurses-devel java-11-openjdk-devel; \
			fi; \
		else \
			echo "Setup cancelled."; \
			exit 1; \
		fi; \
	else \
		echo "Unsupported Linux distribution"; \
		exit 1; \
	fi

setup-deps: ## Install project dependencies
	@echo "Installing project dependencies..."
	@echo "This will:"
	@echo "  1. Install Hex package manager"
	@echo "  2. Install Rebar build tool"
	@echo "  3. Set up project dependencies"
	@echo ""
	@echo "Would you like to proceed? [y/N] "
	@read -r response; \
	if [ "$$response" != "y" ] && [ "$$response" != "Y" ]; then \
		echo "Setup cancelled."; \
		exit 1; \
	fi
	@mix local.hex --force
	@mix local.rebar --force
	@mix deps.get
	@mix setup 

test: ## Run test suite
	@echo "Running test suite..."
	@mix test.unit
	@mix python.test 