#!/usr/bin/env bash

# --- Configuration ---
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
ZSHRC="$HOME/.zshrc"

echo "🚀 Starting Whisper ROCm Setup (Project: $PROJECT_DIR)"

# 1. Ensure models directory exists
mkdir -p "$PROJECT_DIR/models"

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
if ! grep -q "HSA_OVERRIDE_GFX_VERSION" "$ZSHRC"; then
    echo "export HSA_OVERRIDE_GFX_VERSION=$DETECTED_GFX" >> "$ZSHRC"
fi

# Add numeric GIDs as environment variables (for docker-compose.yml)
if ! grep -q "VIDEO_GID" "$ZSHRC"; then
    echo "export VIDEO_GID=$VIDEO_GID" >> "$ZSHRC"
fi

if ! grep -q "RENDER_GID" "$ZSHRC"; then
    echo "export RENDER_GID=$RENDER_GID" >> "$ZSHRC"
fi

# 5. Use a Function for better Autocomplete and variable scoping
if ! grep -q "function whisper-gpu()" "$ZSHRC"; then
cat << EOF >> "$ZSHRC"

# Whisper ROCm Function
function whisper-gpu() {
  (
    # Exporting ensures docker-compose.yml sees these
    export UID=$(id -u)
    export GID=$(id -g)
    export PWD=$(pwd)
    export HSA_OVERRIDE_GFX_VERSION="${HSA_OVERRIDE_GFX_VERSION:-11.0.0}"
    export VIDEO_GID="${VIDEO_GID:-$VIDEO_GID}"
    export RENDER_GID="${RENDER_GID:-$RENDER_GID}"
    export TORCH_CUDA_ARCH_LIST="10.0;11.0;11.1;11.2;11.3;11.4;11.5;11.6;11.7;11.8;12.0;12.1"
    export HOME=$HOME
    
    # Call whisper with all arguments passed through
    docker compose -f "$PROJECT_DIR/docker-compose.yml" run --rm whisper whisper "$@"
  )
}
EOF
fi

# 6. Build the image
echo "🛠 Building the Docker image..."
# Clear any old model artifacts that might be causing load errors
rm -rf "$PROJECT_DIR/models/*"

# Execute build with current ID context
UID=$(id -u) GID=$(id -g) VIDEO_GID=$VIDEO_GID RENDER_GID=$RENDER_GID docker compose -f "$PROJECT_DIR/docker-compose.yml" build

echo "---"
echo "✅ Setup Complete!"
echo "🔄 PLEASE RUN: source ~/.zshrc"
echo "🎙 You can now use 'whisper-gpu' with full autocomplete."
