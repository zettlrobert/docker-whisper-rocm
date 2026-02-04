#!/usr/bin/env bash

# --- Configuration ---
ZSHRC="$HOME/.zshrc"
echo "🚀 Starting Whisper ROCm On-Demand Setup..."

# 1. Export UID and GID so Docker Compose can see them
export UID=$(id -u)
export GID=$(id -g)

# 2. Auto-detect GFX Version (Improved for Pop!_OS)
echo "🔍 Detecting AMD GPU Architecture..."

# Check for common ROCm paths if rocminfo isn't in PATH
ROC_PATH=$(which rocminfo 2>/dev/null || ls /opt/rocm/bin/rocminfo 2>/dev/null)

if [ -f "$ROC_PATH" ]; then
    GFX_RAW=$($ROC_PATH | grep -om1 "gfx[0-9]\{3,4\}")
    if [[ $GFX_RAW =~ gfx([0-9]{2})([0-9]) ]]; then
        DETECTED_GFX="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.0"
    else
        DETECTED_GFX="11.0.0"
    fi
else
    echo "⚠️ rocminfo not found, defaulting to 11.0.0 (RX 7000 Series)"
    DETECTED_GFX="11.0.0"
fi

echo "✅ Detected GFX Version: $DETECTED_GFX"

export HSA_OVERRIDE_GFX_VERSION=$DETECTED_GFX

# 3. Add to .zshrc if missing
echo "📝 Updating $ZSHRC..."

add_to_zshrc() {
    grep -qF "$1" "$ZSHRC" || echo "$1" >> "$ZSHRC"
}

add_to_zshrc "export UID=$(id -u)"
add_to_zshrc "export GID=$(id -g)"
add_to_zshrc "export HSA_OVERRIDE_GFX_VERSION=$DETECTED_GFX"
add_to_zshrc "alias whisper-gpu='docker compose run --rm whisper'"

# 4. Build the image with variables passed explicitly
echo "🛠 Building the Docker image..."

# Passing variables inline prevents the 'variable not set' warning
UID=$UID GID=$GID docker compose build

echo "✅ Setup Complete!"
echo "🔄 Run 'source ~/.zshrc' to start using 'whisper-gpu'."
