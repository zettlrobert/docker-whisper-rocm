#!/usr/bin/env bash

# --- Configuration ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOCKER_WHISPER_ROCM_DIR="$SCRIPT_DIR"
ZSHRC="$HOME/.zshrc"

echo "🚀 Starting Whisper ROCm Setup (Project: $DOCKER_WHISPER_ROCM_DIR)"

# 1. Ensure models and config directories exist with correct ownership
mkdir -p "$DOCKER_WHISPER_ROCM_DIR/models"
mkdir -p "$DOCKER_WHISPER_ROCM_DIR/config/miopen"
chown "${MY_UID:-$(id -u)}:${GID:-$(id -g)}" "$DOCKER_WHISPER_ROCM_DIR/models" 2>/dev/null || true
chown "${MY_UID:-$(id -u)}:${GID:-$(id -g)}" "$DOCKER_WHISPER_ROCM_DIR/config/miopen" 2>/dev/null || true

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
GID=$(id -g)
VIDEO_GID=$(getent group video | cut -d: -f3 || echo "44")
RENDER_GID=$(getent group render | cut -d: -f3 || echo "110")
echo "✅ GID: $GID, Video GID: $VIDEO_GID, Render GID: $RENDER_GID"

# 4. Install whisper-gpu to ~/.local/bin (standard Linux location)
echo "📝 Installing whisper-gpu to ~/.local/bin..."
mkdir -p "$HOME/.local/bin"
cp "$DOCKER_WHISPER_ROCM_DIR/whisper-gpu" "$HOME/.local/bin/whisper-gpu"
chmod +x "$HOME/.local/bin/whisper-gpu"

# 5. Update .zshrc with new subshell-scoped function
echo "📝 Updating $ZSHRC..."

# Remove old Whisper ROCm entries from .zshrc (if any exist)
FUNC_LINE=$(grep -n "^function whisper-gpu()" "$ZSHRC" | cut -d: -f1)

if [ -n "$FUNC_LINE" ]; then
    FUNC_END=$(awk -v start="$FUNC_LINE" 'NR>=start && /^}$/{print NR; exit}' "$ZSHRC")
    
    if [ -n "$FUNC_END" ]; then
        sed -i "${FUNC_LINE},${FUNC_END}d" "$ZSHRC"
        echo "✅ Removed old whisper-gpu function (lines $FUNC_LINE-$FUNC_END)"
    fi
fi

sed -i '/^export DOCKER_WHISPER_ROCM_DIR/d' "$ZSHRC"

# Add export and function to .zshrc with detected values baked in
cat << WHISPER_EOF >> "$ZSHRC"

# Export DOCKER_WHISPER_ROCM_DIR for direct access (set during setup)
export DOCKER_WHISPER_ROCM_DIR="$DOCKER_WHISPER_ROCM_DIR"

function whisper-gpu() {
  (
    export HSA_OVERRIDE_GFX_VERSION="$DETECTED_GFX"
    export VIDEO_GID="$VIDEO_GID"
    export RENDER_GID="$RENDER_GID"
    ~/.local/bin/whisper-gpu "\$@"
  )
}
WHISPER_EOF

# 6. Build the image
echo "🛠 Building the Docker image..."

# Clear any old model artifacts that might be causing load errors
rm -rf "${DOCKER_WHISPER_ROCM_DIR}/models/"*

# Execute build (using cache for faster subsequent builds)
docker compose build

echo "---"
echo "✅ Setup Complete!"
echo "🔄 PLEASE RUN: source ~/.zshrc"
echo "🎙 You can now use 'whisper-gpu' with full autocomplete."
