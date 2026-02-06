# Whisper ROCm (AMD GPU) Local AI Transcription

A high-performance, containerized environment for **OpenAI Whisper** using **AMD ROCm**.
This setup allows you to transcribe files anywhere in your home directory with full GPU acceleration, without leaving background processes running.

## 🚀 Key Features

- **On-Demand Execution**: Container spins up, transcribes, and cleans up immediately (`--rm`).
- **Auto-Architecture Detection**: `setup.sh` detects your GFX version (e.g., 10.3.0 or 11.0.0) automatically.
- **Local Model Cache**: Models are stored in `./models` within this repo to persist between runs.
- **Global Alias**: Use `whisper-gpu` from any directory on your system.
- **Permission Sync**: Output files are owned by your user, not root.

---

## 🛠 Quick Start

### 1. Initial Permissions

Ensure your user has hardware access:

On Linux, hardware devices are treated like files.
If you look at your GPU device nodes (run ls -l /dev/dri /dev/kfd), you will see they are owned by root but belong to the groups video or render.

Permissions: By default, a standard user doesn't have permission to "talk" to the GPU.

The Groups: The video group usually handles display and legacy acceleration, while the render group handles modern compute tasks (like AI and OpenCL).

The Result: Without being in these groups, Docker can't "pass" the hardware into the container.
Whisper would fail to see the GPU and either crash or fall back to your CPU, making transcription 10x slower.

```bash
sudo usermod -a -G render,video $USER
# Important: Log out and back in (or reboot) for this to take effect!
```

### 2. Run Setup

The script configures your `.zshrc`, creates the model directory, and builds the image.

```bash
chmod +x setup.sh
./setup.sh
source ~/.zshrc

```

---

## 🎙 Usage

You can now use the `whisper-gpu` command anywhere. It maps your home directory exactly, so relative paths like `~/` work perfectly.

**Transcribe a video:**

```bash
whisper-gpu ~/Videos/lecture.mp4 --model large --device cuda

```

**Translate a recording to English:**

```bash
whisper-gpu ~/Downloads/audio.wav --model medium --task translate --device cuda

```

---

## 📂 Project Structure

- `Dockerfile`: ROCm + PyTorch + FFmpeg build.
- `docker-compose.yml`: Handles GPU passthrough and home directory mapping.
- `setup.sh`: Automated configuration and directory-aware alias creation.
- `cleanup.sh`: Utility to reclaim disk space (ROCm images are ~15GB).
- `models/`: Local cache for downloaded Whisper model weights.

## 🧹 Maintenance

If you need to free up disk space, run the cleanup script:

```bash
./cleanup.sh
```

## ⚠️ Troubleshooting

- **Command not found**: Ensure you ran `source ~/.zshrc` after setup.
- **HIP Error**: Verify your GPU architecture via `rocminfo`. The setup script usually handles this, but you can override `HSA_OVERRIDE_GFX_VERSION` in `docker-compose.yml`.
- **VRAM**: The `large` model requires ~10GB of VRAM. If your card has less, use `--model medium`.

### Test Debug

```bash
# In the project directory
docker compose run --rm --entrypoint python3 whisper -c "import torch; print(f'ROCm version: {torch.version.hip}'); print(f'GPU available: {torch.cuda.is_available()}')"
```

---

## 🌍 System Portability Notes

### Group ID Requirements

The setup uses numeric group IDs for `/dev/kfd` and `/dev/dri` device access. These are auto-detected during `setup.sh`:

- **video** group: Typically GID 44 on Debian/Ubuntu
- **render** group: Typically GID 110 (can vary by system)

The setup script stores these in `~/.zshrc` as `VIDEO_GID` and `RENDER_GID`.

### On Another System

If you clone this repo to another AMD system:

1. Check if groups exist:

   ```bash
   getent group video
   getent group render
   ```

2. If GIDs differ, re-run setup:

   ```bash
   ./setup.sh
   source ~/.zshrc
   ```

3. Verify:
   ```bash
   echo $VIDEO_GID  # Should match: getent group video | cut -d: -f3
   echo $RENDER_GID # Should match: getent group render | cut -d: -f3
   ```

### Manual GID Override (if needed)

If you need to manually specify GIDs:

```bash
export VIDEO_GID=44
export RENDER_GID=125  # Example different value
./setup.sh
```

---

## 🔍 Debugging GPU Issues

See `DEBUG.md` for detailed analysis of common errors:

- NumPy version incompatibility with Numba
- Missing llvmlite dependency
- ROCm device access via GID mismatch

### Quick GPU Test

```bash
# Test inside container
docker compose run --rm whisper python3 -c "import torch; print(f'GPU available: {torch.cuda.is_available()}')"
```

Expected output: `GPU available: True`
