#!/bin/bash

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo "GitHub CLI (gh) is not installed. Please install it first:"
    echo "https://cli.github.com/"
    exit 1
fi

# Check if logged in to GitHub
if ! gh auth status &> /dev/null; then
    echo "Please login to GitHub first:"
    gh auth login
fi

# Get the current repository information
CURRENT_REMOTE=$(git config --get remote.origin.url)
REPO_FULL_PATH=$(echo $CURRENT_REMOTE | sed 's/.*github.com[:/]\(.*\).git/\1/')
if [ -z "$REPO_FULL_PATH" ]; then
    echo "Error: Could not determine repository path. Are you in a git repository?"
    exit 1
fi
echo "Using repository: $REPO_FULL_PATH"

# List existing codespaces
echo -e "\nExisting Codespaces:"
gh codespace list

# Ask if user wants to create a new codespace
read -p "Create a new Codespace? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Show available machine types
    echo -e "\nAvailable machine types:"
    echo "0) 2-core  (8GB RAM, 32GB storage)"
    echo "1) 4-core  (16GB RAM, 32GB storage)"
    echo "2) 8-core  (32GB RAM, 64GB storage)"
    echo "3) 16-core (64GB RAM, 128GB storage)"
    
    # Let user choose machine type
    read -p "Select machine type (0-3, or Enter for default 2-core): " machine_choice
    echo

    # Only specify machine if user made a choice
    machine_arg=""
    case $machine_choice in
        0) machine_arg="--machine basicLinux32gb";;
        1) machine_arg="--machine standardLinux32gb";;
        2) machine_arg="--machine premiumLinux";;
        3) machine_arg="--machine largePremiumLinux";;
        *) echo "Using default machine type (2-core, 8GB RAM, 32GB storage)";;
    esac

    # Show available regions
    echo -e "\nAvailable regions:"
    echo "1) US East"
    echo "2) US West"
    echo "3) Europe West"
    echo "4) Southeast Asia"
    echo "5) Australia"

    # Let user choose region
    read -p "Select region (1-5, or Enter for default): " region_choice
    echo

    # Set region argument
    region_arg=""
    case $region_choice in
        1) region_arg="--location UsEast";;
        2) region_arg="--location UsWest";;
        3) region_arg="--location EuropeWest";;
        4) region_arg="--location SoutheastAsia";;
        5) region_arg="--location Australia";;
        *) echo "Using default region";;
    esac

    echo "Creating new Codespace..."
    gh codespace create --repo $REPO_FULL_PATH $machine_arg $region_arg
fi

# Get the most recent codespace name
CODESPACE_NAME=$(gh codespace list --json name --jq '.[0].name')
echo "Using Codespace: $CODESPACE_NAME"

# Configure SSH
echo "Configuring SSH..."
gh codespace ssh --config

echo "
Setup complete! To connect with Cursor:
1. Open Cursor
2. Press Cmd/Ctrl + Shift + P
3. Type 'Connect to Host'
4. Select the Codespace (prefixed with 'codespaces-')

Your Codespace name is: $CODESPACE_NAME" 