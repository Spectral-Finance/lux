#!/bin/bash

# Interactive menu function that supports arrow keys
menu() {
    local options=("$@")
    local selected=0
    local num_options=${#options[@]}

    # Hide cursor
    tput civis

    while true; do
        # Clear previous options
        for ((i=0; i<$num_options; i++)); do
            printf "\033[1A\033[K"
        done

        # Print options
        for ((i=0; i<$num_options; i++)); do
            if [ $i -eq $selected ]; then
                printf "\033[36m> %s\033[0m\n" "${options[$i]}"
            else
                printf "  %s\n" "${options[$i]}"
            fi
        done

        # Read a single keystroke
        read -rsn1 input
        if [[ "$input" = $'\x1b' ]]; then
            read -rsn2 input
            case "$input" in
                '[A') # Up arrow
                    ((selected--))
                    [ $selected -lt 0 ] && selected=$((num_options-1))
                    ;;
                '[B') # Down arrow
                    ((selected++))
                    [ $selected -ge $num_options ] && selected=0
                    ;;
            esac
        elif [[ "$input" = "" ]]; then # Enter key
            break
        fi
    done

    # Show cursor
    tput cnorm
    printf "\n"
    return $selected
}

# Handle command line arguments
if [ "$1" = "--cleanup" ]; then
    check_ssh_config
    cleanup_old_configs
    echo "✨ Cleaned up all Lux Codespace configurations from ~/.ssh/codespaces.auto"
    exit 0
fi

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

# List existing codespaces and get available ones
echo -e "\nExisting Codespaces:"
gh codespace list

# Add some spacing and explanation
echo -e "\nCodespaces are cloud-based development environments that mirror your local setup."
echo "You can either connect to an existing Codespace or create a new one."
echo -e "\nAvailable options:"
echo "- Existing Codespaces: Connect to a running development environment"
echo "- Create new Codespace: Set up a fresh environment with custom settings"
echo -e "\n"

# Get available codespaces (more compatible approach)
# Initialize empty array
CODESPACE_ARRAY=()
while IFS= read -r line; do
    CODESPACE_ARRAY+=("$line")
done < <(gh codespace list | grep "Available" | awk '{print $1}')

# Add "Create new Codespace" option
CODESPACE_ARRAY+=("Create new Codespace")

# Create menu options with existing codespaces plus "Create new" option
echo -e "📍 Step 1: Select Your Development Environment"
echo "Please select an existing Codespace to connect to, or choose to create a new one:"
echo "Use ↑↓ arrows and Enter to select:"
menu "${CODESPACE_ARRAY[@]}"
SELECTION=$?

# Check if user selected "Create new Codespace" (last option)
if [ $SELECTION -eq $((${#CODESPACE_ARRAY[@]} - 1)) ]; then
    # User selected "Create new Codespace"
    # Get current branch
    CURRENT_BRANCH=$(git branch --show-current)
    
    # Branch selection
    echo -e "\n📍 Step 2: Select the Git Branch"
    echo "Please select which Git branch you want to use in your Codespace:"
    echo "This will determine which version of the code you'll be working with."
    echo "Use ↑↓ arrows and Enter to select:"
    menu "$CURRENT_BRANCH (current branch)" "main" "Enter different branch name"
    BRANCH_CHOICE=$?

    branch_arg=""
    case $BRANCH_CHOICE in
        0) branch_arg="--branch $CURRENT_BRANCH";;
        1) branch_arg="--branch main";;
        2)
            read -p "Please enter the name of the branch you want to use: " custom_branch
            branch_arg="--branch $custom_branch"
            ;;
    esac

    # Machine type selection
    echo -e "\n📍 Step 3: Select the Machine Type"
    echo "Please select the computational resources for your development environment:"
    echo "Choose based on your development needs - larger machines are better for"
    echo "heavy workloads but have shorter retention periods."
    echo "Use ↑↓ arrows and Enter to select:"
    menu "2-core  (8GB RAM, 32GB storage) - Good for basic development" \
         "4-core  (16GB RAM, 32GB storage) - Better for testing and medium workloads" \
         "8-core  (32GB RAM, 64GB storage) - Great for heavy compilation" \
         "16-core (64GB RAM, 128GB storage) - Best for intensive workloads"
    MACHINE_CHOICE=$?

    # Set machine type
    case $MACHINE_CHOICE in
        0) machine_arg="--machine basicLinux32gb";;
        1) machine_arg="--machine standardLinux32gb";;
        2) machine_arg="--machine premiumLinux";;
        3) machine_arg="--machine largePremiumLinux";;
    esac

    # Region selection
    echo -e "\n📍 Step 4: Select the Server Region"
    echo "Please select the geographical location for your development environment:"
    echo "Choose the region closest to you for the best performance and lowest latency."
    echo "Use ↑↓ arrows and Enter to select:"
    menu "US East (Virginia) - Default region, good for Eastern US and Canada" \
         "US West (Oregon) - Best for Western US and Pacific regions" \
         "Europe West (Netherlands) - Optimal for Europe and Middle East" \
         "Southeast Asia (Singapore) - Best for Asia and Pacific regions" \
         "Australia (Sydney) - Optimal for Australia and New Zealand"
    REGION_CHOICE=$?

    # Set region
    case $REGION_CHOICE in
        0) region_arg="--location UsEast";;
        1) region_arg="--location UsWest";;
        2) region_arg="--location EuropeWest";;
        3) region_arg="--location SoutheastAsia";;
        4) region_arg="--location Australia";;
    esac

    echo -e "\n📍 Configuration Summary:"
    echo "You have selected the following configuration for your new Codespace:"
    echo "- Branch: ${branch_arg#--branch }"
    echo "- Machine: ${machine_arg#--machine }"
    echo "- Region: ${region_arg#--location }"
    echo ""
    
    NEW_CODESPACE=$(gh codespace create --repo $REPO_FULL_PATH $branch_arg $machine_arg $region_arg)
    if [ -z "$NEW_CODESPACE" ]; then
        echo "Error: Failed to create codespace"
        exit 1
    fi
    echo "New Codespace created: $NEW_CODESPACE"
    
    # Wait for the codespace to be ready
    echo "Waiting for Codespace to be ready..."
    max_attempts=30
    attempt=0
    while [ $attempt -lt $max_attempts ]; do
        STATUS=$(gh codespace list | grep "$NEW_CODESPACE" | awk '{print $5}')
        if [ "$STATUS" = "Available" ]; then
            echo "✨ Codespace is ready!"
            break
        fi
        echo "Status: $STATUS (attempt $((attempt + 1))/$max_attempts)"
        attempt=$((attempt + 1))
        sleep 5
    done
    
    if [ $attempt -eq $max_attempts ]; then
        echo "❌ Timed out waiting for Codespace to be ready"
        exit 1
    fi
    
    CODESPACE_NAME=$NEW_CODESPACE
else
    CODESPACE_NAME="${CODESPACE_ARRAY[$SELECTION]}"
fi

echo -e "\nUsing Codespace: $CODESPACE_NAME"

# Function to check if we can write to SSH config
check_ssh_config() {
    SSH_DIR=~/.ssh
    SSH_CONFIG=~/.ssh/codespaces.auto

    # Create .ssh directory if it doesn't exist
    if [ ! -d "$SSH_DIR" ]; then
        echo "Creating ~/.ssh directory..."
        mkdir -p "$SSH_DIR"
        chmod 700 "$SSH_DIR"
    fi

    # Create codespaces.auto file if it doesn't exist
    if [ ! -f "$SSH_CONFIG" ]; then
        echo "Creating ~/.ssh/codespaces.auto file..."
        touch "$SSH_CONFIG"
        chmod 600 "$SSH_CONFIG"
    fi

    # Check if we can write to the config file
    if [ ! -w "$SSH_CONFIG" ]; then
        echo "❌ Error: Cannot write to ~/.ssh/codespaces.auto"
        echo "Please check file permissions"
        exit 1
    fi
}

# Function to remove old Lux Codespace configurations
cleanup_old_configs() {
    echo "Cleaning up old Lux Codespace configurations..."
    if [ -f ~/.ssh/codespaces.auto ]; then
        # Create a temporary file
        TEMP_FILE=$(mktemp)
        # Copy everything except our managed block
        sed '/# BEGIN LUX CODESPACE CONFIGURATIONS/,/# END LUX CODESPACE CONFIGURATIONS/d' ~/.ssh/codespaces.auto > "$TEMP_FILE"
        # Replace the original file
        mv "$TEMP_FILE" ~/.ssh/codespaces.auto
        chmod 600 ~/.ssh/codespaces.auto
    fi
}

# Function to add new SSH configuration
add_ssh_config() {
    local codespace_name=$1
    echo "Adding SSH configuration for $codespace_name..."
    
    # Get the ProxyCommand for this codespace
    PROXY_CMD=$(gh codespace ssh -c "$codespace_name" --config 2>&1 | grep "ProxyCommand" | head -n 1 | cut -d' ' -f2-)
    
    if [ -z "$PROXY_CMD" ]; then
        echo "❌ Error: Could not get ProxyCommand for $codespace_name"
        exit 1
    fi

    # Add our configuration block
    cat >> ~/.ssh/codespaces.auto << EOF

# BEGIN LUX CODESPACE CONFIGURATIONS
# Last updated: $(date)
# Codespace: ${codespace_name}

Host codespaces-${codespace_name}
    ProxyCommand ${PROXY_CMD}
    User vscode
    UserKnownHostsFile=/dev/null
    StrictHostKeyChecking no
    LogLevel quiet
    ControlMaster auto
    IdentityFile ~/.ssh/codespaces.auto

# END LUX CODESPACE CONFIGURATIONS
EOF
}

# Main script continues...
check_ssh_config

# After selecting/creating a codespace...
echo "Configuring SSH for Codespace: $CODESPACE_NAME"
cleanup_old_configs
add_ssh_config "$CODESPACE_NAME"

echo "
✨ Setup complete! To connect with Cursor:
1. Open Cursor
2. Press Cmd/Ctrl + Shift + P
3. Type 'Connect to Host'
4. Select 'codespaces-${CODESPACE_NAME}'

Your Codespace name is: ${CODESPACE_NAME}

Note: SSH configuration has been added to ~/.ssh/codespaces.auto
To remove this configuration later, run this script with --cleanup" 