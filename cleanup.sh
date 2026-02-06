#!/usr/bin/env bash

echo "🧹 Starting Whisper ROCm Cleanup..."

# Set DOCKER_WHISPER_ROCM_DIR from environment if available
if [ -n "$DOCKER_WHISPER_ROCM_DIR" ] && [ -d "$DOCKER_WHISPER_ROCM_DIR" ]; then
    cd "$DOCKER_WHISPER_ROCM_DIR"
else
    echo "⚠️ DOCKER_WHISPER_ROCM_DIR not set or invalid. Using current directory."
fi

# 1. Remove installed whisper-gpu script from ~/.local/bin
echo "🗑 Removing installed whisper-gpu script..."
rm -f "$HOME/.local/bin/whisper-gpu"

# 2. Remove Whisper ROCm function and exports from .zshrc
echo "📝 Cleaning up .zshrc..."

# Get line number of the function
FUNC_LINE=$(grep -n "^function whisper-gpu()" "$HOME/.zshrc" | cut -d: -f1)

if [ -n "$FUNC_LINE" ]; then
    # Find closing brace (end of function)
    FUNC_END=$(awk -v start="$FUNC_LINE" 'NR>=start && /^}$/{print NR; exit}' "$HOME/.zshrc")
    
    if [ -n "$FUNC_END" ]; then
        # Remove lines from function start to end
        sed -i "${FUNC_LINE},${FUNC_END}d" "$HOME/.zshrc"
        echo "✅ Removed whisper-gpu function (lines $FUNC_LINE-$FUNC_END)"
    fi
fi

# Remove any remaining exports related to whisper
sed -i '/^export DOCKER_WHISPER_ROCM_DIR/d' "$HOME/.zshrc"
sed -i '/^export HSA_OVERRIDE_GFX_VERSION/d' "$HOME/.zshrc"
sed -i '/^export VIDEO_GID=/d' "$HOME/.zshrc"
sed -i '/^export RENDER_GID=/d' "$HOME/.zshrc"

# 3. Clear Docker resources
echo "🧼 Removing containers and pruning build cache..."
docker compose down
docker builder prune -f

# 4. Handle the Model Cache
if [ -d "./models" ]; then
    SIZE=$(du -sh "./models" | cut -f1)
    echo "📂 Local model cache contains $SIZE of data."
    read -p "❓ Delete downloaded models in ./models? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf ./models/*
        echo "✅ Models deleted."
    fi
fi

# 5. Handle the Image
read -p "❓ Remove the 15GB Whisper-ROCm image? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    docker rmi whisper-rocm
    echo "✅ Image removed."
fi

echo "✨ Cleanup complete!"
