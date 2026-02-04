# Whisper ROCm (AMD GPU) Local AI Station

This project provides a high-performance, containerized environment for **OpenAI Whisper** using **AMD ROCm**.
By mounting your home directory and syncing your user permissions, it allows you to transcribe files anywhere on your system while outputting results with correct file ownership.

## 🚀 Key Features

- **Full Home Access**: Seamlessly read from and write to any path in your `~/`.
- **AMD Hardware Acceleration**: Optimized for ROCm 6.x (PyTorch `cuda` backend).
- **Correct File Ownership**: Files created by the container belong to your user, not `root`.
- **GPU Healthcheck**: Automatic verification that the ROCm stack is initialized.

---

## 🛠 Prerequisites

### 1. Permissions

Ensure your user belongs to the `render` and `video` groups to access the GPU device nodes:

```bash
sudo usermod -a -G render $USER
sudo usermod -a -G video $USER
# Log out and back in (or reboot) for changes to take effect.

```

### 2. Environment Variables

To ensure files created by Docker have the correct permissions, add these to your `~/.bashrc` or `~/.zshrc`:

```bash
export UID=$(id -u)
export GID=$(id -g)

```

---

## 📦 Installation & Setup

1. **Clone the repository** and navigate into it.
2. **Configure GPU Arch**: If you are not using an RX 7000 series card, update the `HSA_OVERRIDE_GFX_VERSION` in `docker-compose.yml`:

- **RX 7000**: `11.0.0`
- **RX 6000**: `10.3.0`

3. **Build & Start**:

```bash
docker compose build
docker compose up -d

```

4. **Verify Health**:
   Wait ~10 seconds and run `docker ps`. You should see `(healthy)` next to the `whisper-ai-rocm` container.

---

## 🎙 Usage

Since your home directory is mounted, you can pass any absolute path within your home folder.
Whisper will automatically save the transcription outputs (`.txt`, `.srt`, `.vtt`) in the **same directory** as the input file.

### Basic Command

```bash
docker exec -it whisper-ai-rocm whisper "/home/youruser/Videos/recording.mkv" --model large --device cuda

```

### Recommended Alias

Add this to your `~/.bashrc` to use Whisper like a native system command:

```bash
alias whisper-gpu='docker exec -it whisper-ai-rocm whisper'

```

**After adding the alias, you can simply run:**

```bash
whisper-gpu ~/Videos/meeting.mp4 --model medium --device cuda --language German

```

---

## 📂 Project Structure

- `Dockerfile`: Builds the ROCm + PyTorch + FFmpeg + Whisper environment.
- `docker-compose.yml`: Manages the background service, GPU passthrough, and home directory mounting.
- `README.md`: This documentation.

## ⚠️ Troubleshooting

- **Permissions**: If the container fails to start, ensure `UID` and `GID` are exported in your current terminal session.
- **GFX Version**: If you get a "HIP Error," verify your `HSA_OVERRIDE_GFX_VERSION` matches your hardware.
- **VRAM**: The `large` model requires ~10GB of VRAM. Use `--model medium` if you experience crashes on 8GB cards.
