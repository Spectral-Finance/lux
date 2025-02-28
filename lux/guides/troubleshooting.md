# Troubleshooting Guide

This guide helps resolve common issues encountered during Lux setup and development.

## Setup and Installation Issues

### 1. ASDF and Shell Integration

#### "Command not found: asdf"
1. **Verify Installation**:
   ```bash
   # On macOS
   brew list asdf || brew install asdf
   
   # On Linux
   ls ~/.asdf
   ```

2. **Check Shell Configuration**:
   ```bash
   # Identify your shell
   echo $SHELL
   
   # Check if asdf is in your PATH
   echo $PATH | grep asdf
   ```

3. **Fix Shell Integration**:
   ```bash
   # For Zsh
   echo '. "$HOME/.asdf/asdf.sh"' >> ~/.zshrc
   echo 'fpath=($HOME/.asdf/completions $fpath)' >> ~/.zshrc
   
   # For Bash
   echo '. "$HOME/.asdf/asdf.sh"' >> ~/.bashrc
   echo '. "$HOME/.asdf/completions/asdf.bash"' >> ~/.bashrc
   ```

### 2. Elixir/Mix Issues

#### "mix: command not found"
1. **Verify ASDF Integration**:
   ```bash
   # Check if mix is in asdf shims
   ls ~/.asdf/shims/mix
   
   # Try running mix directly from shims
   ~/.asdf/shims/mix --version
   ```

2. **Check Elixir Installation**:
   ```bash
   # List installed versions
   asdf list elixir
   asdf list erlang
   
   # If none installed, install them
   asdf install
   ```

3. **Verify Global Versions**:
   ```bash
   asdf current
   
   # If needed, set global versions
   asdf global erlang latest
   asdf global elixir latest
   ```

### 3. OpenSSL Issues (macOS)

#### Erlang Compilation Fails
1. **Verify OpenSSL Installation**:
   ```bash
   brew list openssl@3
   brew info openssl@3
   ```

2. **Check KERL Configuration**:
   ```bash
   echo $KERL_CONFIGURE_OPTIONS
   
   # Should output something like:
   # --with-ssl=/usr/local/opt/openssl@3
   ```

3. **Fix OpenSSL Configuration**:
   ```bash
   # Add to your shell config
   export KERL_CONFIGURE_OPTIONS="--with-ssl=$(brew --prefix openssl@3)"
   
   # Then reinstall Erlang
   asdf uninstall erlang
   asdf install erlang
   ```

### 4. Permission Issues

#### "Permission denied" Errors
1. **Check Directory Ownership**:
   ```bash
   ls -la ~/.asdf
   
   # Fix ownership if needed
   sudo chown -R $(whoami) ~/.asdf
   ```

2. **Check File Permissions**:
   ```bash
   # Ensure proper permissions
   chmod -R 755 ~/.asdf
   ```

### 5. Complete Reset

If you need to start fresh:

1. **Remove ASDF and Tools**:
   ```bash
   # Remove ASDF
   rm -rf ~/.asdf
   
   # Clean shell config (remove asdf-related lines)
   # For zsh:
   sed -i '' '/asdf/d' ~/.zshrc
   # For bash:
   sed -i '' '/asdf/d' ~/.bashrc
   ```

2. **Reinstall Everything**:
   ```bash
   # On macOS
   brew install asdf
   
   # On Linux
   git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.13.1
   
   # Then run setup
   cd /path/to/lux
   make setup
   ```

## Development Issues

### 1. Test Failures

#### Mix Test Failures
1. **Check Dependencies**:
   ```bash
   mix deps.get
   mix deps.compile
   ```

2. **Clean Build**:
   ```bash
   mix clean
   mix compile --force
   ```

### 2. Python Integration Issues

#### Poetry/Python Problems
1. **Verify Poetry Installation**:
   ```bash
   asdf which poetry
   poetry --version
   ```

2. **Reset Python Environment**:
   ```bash
   cd priv/python
   rm -rf .venv
   poetry env remove --all
   poetry install
   ```

## Getting Help

If you're still experiencing issues:

1. **Check Existing Issues**: Visit our [GitHub Issues](https://github.com/spectrallabs/lux/issues) to see if others have encountered the same problem.

2. **Join Our Community**:
   - [Discord Server](https://discord.gg/luxframework)
   - [GitHub Discussions](https://github.com/spectrallabs/lux/discussions)

3. **Debug Information**: When reporting issues, please include:
   - Your OS and version
   - Output of `asdf current`
   - Content of your shell configuration file
   - Any error messages
   - Steps to reproduce the issue

## Contributing

Found a solution to a common problem? Please consider:
1. Opening a PR to update this guide
2. Sharing your solution in our Discord
3. Adding it to our FAQ in the wiki

Remember to keep the solutions clear, concise, and focused on root causes rather than symptoms. 