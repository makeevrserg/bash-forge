#!/bin/bash

# Usage:
# ./clone_all_github_repos.sh <github-user-or-org> <github-token>

USER_OR_ORG="$1"
TOKEN="$2"

if [ -z "$USER_OR_ORG" ] || [ -z "$TOKEN" ]; then
    echo "Usage: $0 <github-user-or-org> <github-token>"
    exit 1
fi

API_URL="https://api.github.com"
AUTH_CLONE_BASE="https://${TOKEN}:x-oauth-basic@github.com"

page=1

echo "Fetching repositories for: $USER_OR_ORG"

while : ; do
    # Request 100 repos per page
    RESPONSE=$(curl -s \
        -H "Authorization: token ${TOKEN}" \
        "${API_URL}/users/${USER_OR_ORG}/repos?per_page=100&page=${page}")

    # Stop if empty
    COUNT=$(echo "$RESPONSE" | jq length)
    if [ "$COUNT" -eq 0 ]; then
        echo "No more repositories."
        break
    fi

    # Iterate
    echo "$RESPONSE" | jq -r '.[].clone_url' | while read clone_url; do
        REPO_NAME=$(basename "$clone_url" .git)
        TARGET_DIR="./$REPO_NAME"

        if [ -d "$TARGET_DIR" ]; then
            echo "[SKIP] $REPO_NAME already exists"
            continue
        fi

        # Build authenticated clone URL
        AUTH_URL="${AUTH_CLONE_BASE}/${USER_OR_ORG}/${REPO_NAME}.git"

        echo "[CLONE] $REPO_NAME"
        git clone "$AUTH_URL"
    done

    page=$((page + 1))
done
