#!/bin/bash

# =============================================================================
# Lux Codespace GPG Configuration Script
# =============================================================================
# This script configures GPG signing for commits in GitHub Codespaces.
# It should be run inside the Codespace, not on the local machine.
# =============================================================================

echo "Configuring GPG signing for GitHub Codespaces..."

# Function to check GitHub token
check_github_token() {
    # Try to get a new token if needed
    if [ -z "$GITHUB_TOKEN" ]; then
        echo "Attempting to get GitHub token..."
        export GITHUB_TOKEN=$(gh auth token)
    fi

    if [ -z "$GITHUB_TOKEN" ]; then
        echo "❌ Error: No GitHub token available"
        echo "Please ensure you're properly authenticated with GitHub"
        return 1
    fi

    # Verify token has correct permissions
    if ! gh auth status &> /dev/null; then
        echo "❌ Error: GitHub token is invalid or lacks required permissions"
        return 1
    fi

    return 0
}

# Configure git
configure_git() {
    # Set the GPG program
    if [ -f "/.codespaces/bin/gh-gpgsign" ]; then
        git config --global gpg.program "/.codespaces/bin/gh-gpgsign"
        git config --global commit.gpgsign true
        return 0
    else
        echo "❌ Error: GitHub Codespaces GPG signing program not found"
        echo "This script must be run inside a GitHub Codespace"
        return 1
    fi
}

# Main script
if ! check_github_token; then
    exit 1
fi

if ! configure_git; then
    exit 1
fi

# Test the configuration
echo "Testing GPG signing..."
if git commit --allow-empty -m "test: verifying GPG signing" &> /dev/null; then
    echo "✅ GPG signing configured successfully"
    echo "Your commits should now be verified by GitHub"
    # Clean up test commit
    git reset --hard HEAD^ &> /dev/null
else
    echo "❌ Error: Failed to sign commit"
    echo "Please check your GitHub token permissions"
    exit 1
fi 