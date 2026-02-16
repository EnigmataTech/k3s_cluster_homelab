#!/bin/bash
# Load secrets from Bitwarden into environment
# Usage: source ~/bin/load-secrets.sh
#
# Prerequisites:
#   - Bitwarden CLI installed: sudo snap install bw
#   - Logged in: bw login
#   - jq installed: sudo apt install jq

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Loading secrets from Bitwarden...${NC}"

# Check if bw is installed
if ! command -v bw &> /dev/null; then
    echo -e "${RED}Error: Bitwarden CLI not installed${NC}"
    echo "Install with: sudo snap install bw"
    return 1
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq not installed${NC}"
    echo "Install with: sudo apt install jq"
    return 1
fi

# Check login status
BW_STATUS=$(bw status | jq -r '.status')

if [ "$BW_STATUS" = "unauthenticated" ]; then
    echo -e "${YELLOW}Please log in to Bitwarden:${NC}"
    bw login
    BW_STATUS="locked"
fi

if [ "$BW_STATUS" = "locked" ]; then
    echo -e "${YELLOW}Unlocking Bitwarden vault...${NC}"
    export BW_SESSION=$(bw unlock --raw)
fi

# Sync vault
bw sync --session "$BW_SESSION" > /dev/null 2>&1

# Function to get secret
get_secret() {
    local item_name="$1"
    local field_name="${2:-api_key}"

    local result=$(bw get item "$item_name" --session "$BW_SESSION" 2>/dev/null | \
        jq -r ".fields[] | select(.name==\"$field_name\") | .value" 2>/dev/null)

    if [ -z "$result" ] || [ "$result" = "null" ]; then
        # Try getting from password field
        result=$(bw get item "$item_name" --session "$BW_SESSION" 2>/dev/null | \
            jq -r '.login.password' 2>/dev/null)
    fi

    echo "$result"
}

# Load common API keys (customize these based on your Bitwarden items)
# Uncomment and modify as needed:

# export OPENAI_API_KEY=$(get_secret "OpenAI API Key")
# export ANTHROPIC_API_KEY=$(get_secret "Anthropic API Key")
# export GITHUB_TOKEN=$(get_secret "GitHub Token" "token")
# export HUGGINGFACE_TOKEN=$(get_secret "Hugging Face Token")
# export GEMINI_API_KEY=$(get_secret "Gemini API Key")

echo -e "${GREEN}Environment ready. Add your secrets to Bitwarden and uncomment the exports above.${NC}"
echo ""
echo "To add a secret to Bitwarden:"
echo "  bw create item <json> --session \$BW_SESSION"
echo ""
echo "Or use the Bitwarden desktop/web app to add items."
