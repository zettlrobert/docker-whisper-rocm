#!/usr/bin/env bash

# --- Configuration ---
# Finds the absolute path of the directory where THIS script is saved
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
ZSHRC="$HOME/.zshrc"

echo "🚀 Starting Whisper ROCm Setup (Project: $PROJECT_DIR)"

# 1. Ensure models directory exists
echo "📁 Ensuring models directory exists at $PROJECT_DIR/models..."
mkdir -p "$PROJECT_DIR/models"

# 2. Auto-detect GFX Version
echo "🔍 Detecting AMD GPU Architecture..."
ROC_PATH=$(which rocminfo 2>/dev/null || ls /opt/rocm/bin/rocminfo 2>/dev/null)

if [ -f "$ROC_PATH" ]; then
    # Extracts gfx1100 -> 11.0.0
    GFX_RAW=$($ROC_PATH | grep -om1 "gfx[0-9]\{3,4\}")
    if [[ $GFX_RAW =~ gfx([0-9]{2})([0-9]) ]]; then
        DETECTED_GFX="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.0"
    else
        DETECTED_GFX="11.0.0"
    fi
else
    echo "⚠️  rocminfo not found, defaulting to 11.0.0"
    DETECTED_GFX="11.0.0"
fi
echo "✅ Detected GFX Version: $DETECTED_GFX"

# 3. Update .zshrc
echo "📝 Updating $ZSHRC..."

add_to_zshrc() {
    # Only adds the line if it doesn't already exist
    grep -qF "$1" "$ZSHRC" || echo "$1" >> "$ZSHRC"
}

# Add GPU override for ROCm
add_to_zshrc "export HSA_OVERRIDE_GFX_VERSION=$DETECTED_GFX"

# IMPORTANT: UID and GID are passed ONLY when the alias is executed.
# This prevents overriding the shell's read-only variables globally.
WHISPER_ALIAS="alias whisper-gpu='UID=\$(id -u) GID=\$(id -g) docker compose -f \"$PROJECT_DIR/docker-compose.yml\" run --rm whisper'"
add_to_zshrc "$WHISPER_ALIAS"

# 4. Build the image
echo "🛠  Building the Docker image..."
# Pass UID/GID locally for the build command
UID=$(id -u) GID=$(id -g) docker compose -f "$PROJECT_DIR/docker-compose.yml" build

echo "---"
echo "✅ Setup Complete!"
echo "🔄 PLEASE RUN: source ~/.zshrc"
echo "🎙  You can now use 'whisper-gpu' from any folder."
