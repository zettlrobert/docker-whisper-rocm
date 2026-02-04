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

# 3. Update .zshrc
echo "📝 Updating $ZSHRC..."

add_to_zshrc() {
    grep -qF "$1" "$ZSHRC" || echo "$1" >> "$ZSHRC"
}

# Add GPU override
add_to_zshrc "export HSA_OVERRIDE_GFX_VERSION=$DETECTED_GFX"

# 4. Use a Function instead of an Alias for better Autocomplete
# We use a heredoc to write the function cleanly into .zshrc
if ! grep -q "whisper-gpu()" "$ZSHRC"; then
cat << EOF >> "$ZSHRC"

# Whisper ROCm Function
function whisper-gpu() {
    UID=\$(id -u) GID=\$(id -g) docker compose -f "$PROJECT_DIR/docker-compose.yml" run --rm whisper "\$@"
}
EOF
fi

# 5. Build the image
echo "🛠 Building the Docker image..."
UID=$(id -u) GID=$(id -g) docker compose -f "$PROJECT_DIR/docker-compose.yml" build

echo "---"
echo "✅ Setup Complete!"
echo "🔄 PLEASE RUN: source ~/.zshrc"
echo "🎙 You can now use 'whisper-gpu' with full autocomplete."
