#!/usr/bin/env bash

echo "🧹 Starting Whisper ROCm Cleanup..."

# 1. Clear Docker resources
echo "🧼 Removing containers and pruning build cache..."
docker compose down
docker builder prune -f

# 2. Handle the Model Cache
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

# 3. Handle the Image
read -p "❓ Remove the 15GB Whisper-ROCm image? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    docker rmi whisper-rocm
    echo "✅ Image removed."
fi

echo "✨ Cleanup complete!"
