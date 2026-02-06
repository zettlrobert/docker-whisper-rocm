#!/usr/bin/env bash

# --- Configuration ---
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
ZSHRC="$HOME/.zshrc"

echo "🚀 Starting Whisper ROCm Setup (Project: $PROJECT_DIR)"

# 1. Ensure models directory exists with correct ownership
mkdir -p "$PROJECT_DIR/models"
chown "${UID:-1000}:${GID:-1000}" "$PROJECT_DIR/models" 2>/dev/null || true

# 2. Auto-detect GFX Version
echo "🔍 Detecting AMD GPU Architecture..."
ROC_PATH=$(which rocminfo 2>/dev/null || ls /opt/rocm/bin/rocminfo 2>/dev/null)

if [ -f "$ROC_PATH" ]; then
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

# 3. Detect Host GIDs for Video and Render groups (for docker-compose.yml group_add)
echo "🔍 Detecting Group IDs..."
VIDEO_GID=$(getent group video | cut -d: -f3 || echo "44")
RENDER_GID=$(getent group render | cut -d: -f3 || echo "110")
echo "✅ Video GID: $VIDEO_GID, Render GID: $RENDER_GID"

# 4. Update .zshrc
echo "📝 Updating $ZSHRC..."

# Add GPU override globally (safe for ROCm users)
if ! grep -q "^export HSA_OVERRIDE_GFX_VERSION" "$ZSHRC"; then
    echo "export HSA_OVERRIDE_GFX_VERSION=$DETECTED_GFX" >> "$ZSHRC"
fi

# Add numeric GIDs as environment variables (for docker-compose.yml group_add)
if ! grep -q "^export VIDEO_GID=" "$ZSHRC"; then
    echo "export VIDEO_GID=$VIDEO_GID" >> "$ZSHRC"
fi

if ! grep -q "^export RENDER_GID=" "$ZSHRC"; then
    echo "export RENDER_GID=$RENDER_GID" >> "$ZSHRC"
fi

# Export PROJECT_DIR for the wrapper script to use (before function definition)
echo "export PROJECT_DIR=$PROJECT_DIR" >> "$ZSHRC"

# 5. Add whisper-gpu wrapper script reference to .zshrc
cat << 'WHISPER_EOF' >> "$ZSHRC"

# Whisper ROCm Function (wrapper script)
function whisper-gpu() {
  "$PROJECT_DIR/whisper-gpu" "$@"
}
WHISPER_EOF

# 6. Build the image
echo "🛠 Building the Docker image..."

# Clear any old model artifacts that might be causing load errors
rm -rf "$PROJECT_DIR/models/*"

# Execute build with current ID context
UID=$(id -u) GID=$(id -g) VIDEO_GID=$VIDEO_GID RENDER_GID=$RENDER_GID docker compose -f "${PROJECT_DIR}/docker-compose.yml" build

echo "---"
echo "✅ Setup Complete!"
echo "🔄 PLEASE RUN: source ~/.zshrc"
echo "🎙 You can now use 'whisper-gpu' with full autocomplete."
