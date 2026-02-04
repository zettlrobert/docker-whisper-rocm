#!/usr/bin/env bash

# --- Configuration ---
# This line finds the absolute path of the directory where THIS script is saved
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
ZSHRC="$HOME/.zshrc"

echo "🚀 Starting Whisper ROCm Setup (Project: $PROJECT_DIR)"

# Create the models folder inside that specific directory
echo "📁 Ensuring models directory exists at $PROJECT_DIR/models..."
mkdir -p "$PROJECT_DIR/models"

# 1. Export UID and GID for the build process
export UID=$(id -u)
export GID=$(id -g)

# 2. Auto-detect GFX Version (Improved for Pop!_OS)
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
    echo "⚠️ rocminfo not found, defaulting to 11.0.0"
    DETECTED_GFX="11.0.0"
fi
echo "✅ Detected GFX Version: $DETECTED_GFX"

# 3. Create the models directory locally
mkdir -p "$PROJECT_DIR/models"

# 4. Update .zshrc
echo "📝 Updating $ZSHRC..."

add_to_zshrc() {
    # Only adds the line if it doesn't already exist
    grep -qF "$1" "$ZSHRC" || echo "$1" >> "$ZSHRC"
}

# Add essential environment variables for the alias to function
add_to_zshrc "export UID=$(id -u)"
add_to_zshrc "export GID=$(id -g)"
add_to_zshrc "export HSA_OVERRIDE_GFX_VERSION=$DETECTED_GFX"

# IMPORTANT: The alias now uses the absolute path to your docker-compose.yml
# This allows 'whisper-gpu' to work from any folder in your system.
WHISPER_ALIAS="alias whisper-gpu='docker compose -f $PROJECT_DIR/docker-compose.yml run --rm whisper'"
add_to_zshrc "$WHISPER_ALIAS"

# 5. Build the image
echo "🛠 Building the Docker image..."
# Explicitly pass the file path so build works even if not in the folder
UID=$UID GID=$GID docker compose -f "$PROJECT_DIR/docker-compose.yml" build

echo "---"
echo "✅ Setup Complete!"
echo "🔄 PLEASE RUN: source ~/.zshrc"
echo "🎙 You can now use 'whisper-gpu' from any folder."
