# Whisper ROCm (AMD GPU) Local AI Station

A high-performance, containerized environment for **OpenAI Whisper** using **AMD ROCm**.
This setup allows you to transcribe files anywhere in your home directory with full GPU acceleration, without leaving background processes running.

## 🚀 Key Features

- **On-Demand Execution**: Container spins up, transcribes, and cleans up immediately.
- **Auto-Detection**: `setup.sh` automatically detects your AMD GPU architecture.
- **Local Model Cache**: Whisper models are stored in `./models` to save bandwidth and startup time.
- **Permission Sync**: Files created belong to your user, not `root`.

---

## 🛠 Quick Start

### 1. Initial Permissions

Ensure your user can access the GPU hardware:

```bash
sudo usermod -a -G render,video $USER
# Important: Log out and back in (or reboot) for this to take effect!
```

### 2. Run Setup

The setup script will detect your GPU, update your `.zshrc`, and build the image.

```bash
chmod +x setup.sh
./setup.sh
source ~/.zshrc

```

---

## 🎙 Usage

Use the `whisper-gpu` alias from any terminal.Since your home directory is mapped, you can use standard paths.
The output files (`.txt`, `.srt`, etc.) will appear in the **same folder** as the input file.

**Basic Transcription:**

```bash
whisper-gpu ~/Videos/meeting.mp4 --model large --device cuda

```

**Translate to English:**

```bash
whisper-gpu ~/Videos/recording.mkv --model medium --task translate --device cuda
```

---

## 📂 Project Structure

- `Dockerfile`: ROCm + PyTorch + FFmpeg build.
- `docker-compose.yml`: Handles hardware passthrough and user mapping.
- `setup.sh`: Automated environment configuration and alias creation.
- `cleanup.sh`: Utility to reclaim disk space and delete model cache.
- `models/`: (Generated) Stores downloaded Whisper models.

## ⚠️ Troubleshooting

- **HIP Error**: Usually means `HSA_OVERRIDE_GFX_VERSION` is incorrect. Run `rocminfo` to verify your `gfx` version.
- **Slow Startup**: The first run for any model takes time to download (e.g., `large` is 3GB). Subsequent runs are near-instant.
- **UID/GID Warnings**: If you see these, ensure you have run `source ~/.zshrc` or that you are running from the project directory.
