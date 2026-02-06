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

# 4. Install whisper-gpu to ~/.local/bin (standard Linux location)
echo "📝 Installing whisper-gpu to ~/.local/bin..."
mkdir -p "$HOME/.local/bin"
cp "$PROJECT_DIR/whisper-gpu" "$HOME/.local/bin/whisper-gpu"
chmod +x "$HOME/.local/bin/whisper-gpu"

# 5. Update .zshrc with new subshell-scoped function
echo "📝 Updating $ZSHRC..."

# # Add GPU override (safe for ROCm users) - but don't export, let function scope it
# if ! grep -q "^export HSA_OVERRIDE_GFX_VERSION" "$ZSHRC"; then
#     echo "# Whisper ROCm: HSA_OVERRIDE_GFX_VERSION is scoped to whisper-gpu function" >> "$ZSHRC"
# fi
#
# # Add numeric GIDs as environment variables (for docker-compose.yml group_add)
# if ! grep -q "^export VIDEO_GID=" "$ZSHRC"; then
#     echo "# Whisper ROCm: VIDEO_GID and RENDER_GID are scoped to whisper-gpu function" >> "$ZSHRC"
# fi

# 6. Add whisper-gpu function to .zshrc (subshell-scoped)
cat << 'WHISPER_EOF' >> "$ZSHRC"

# Whisper ROCm Function (wrapper script - uses ~/.local/bin/whisper-gpu)
function whisper-gpu() {
  (
    export HSA_OVERRIDE_GFX_VERSION="${HSA_OVERRIDE_GFX_VERSION:-11.0.0}"
    export VIDEO_GID="${VIDEO_GID:-44}"
    export RENDER_GID="${RENDER_GID:-110}"
    
    ~/.local/bin/whisper-gpu "$@"
  )
}
WHISPER_EOF

# 7. Build the image
echo "🛠 Building the Docker image..."

# Clear any old model artifacts that might be causing load errors
rm -rf "$PROJECT_DIR/models/*"

# Execute build with current ID context
UID=$(id -u) GID=$(id -g) VIDEO_GID=$VIDEO_GID RENDER_GID=$RENDER_GID docker compose -f "${PROJECT_DIR}/docker-compose.yml" build

echo "---"
echo "✅ Setup Complete!"
echo "🔄 PLEASE RUN: source ~/.zshrc"
echo "🎙 You can now use 'whisper-gpu' with full autocomplete."
