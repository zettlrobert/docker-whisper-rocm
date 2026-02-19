# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Summary

Containerized GPU-accelerated speech-to-text transcription using OpenAI Whisper on AMD GPUs via ROCm. Users run `whisper-gpu` from anywhere in their home directory — Docker handles GPU passthrough, model caching, and file permissions transparently.

## Build and Run Commands

```bash
# Initial setup (detects GPU arch, installs wrapper, builds image)
./setup.sh
source ~/.zshrc

# Build Docker image
docker compose build

# Force rebuild without cache
docker compose build --no-cache

# Transcribe a file
whisper-gpu ~/audio.mp3 --model large --device cuda

# Test GPU detection inside container
docker compose run --rm --entrypoint python3 whisper -c "import torch; print(torch.cuda.is_available())"

# Test whisper is functional
docker compose run --rm whisper --help

# Full cleanup (removes image, models, shell config)
./cleanup.sh
```

There is no test suite or linter configured for this project.

## Architecture

The execution flow is: `.zshrc` shell function (env vars) -> `whisper-gpu` script (directory detection + Docker run) -> Docker Compose -> container with ROCm + Whisper.

**`.zshrc` function**: Sets `HSA_OVERRIDE_GFX_VERSION`, `VIDEO_GID`, and `RENDER_GID` in a subshell, then calls the `whisper-gpu` script. These env vars are consumed by `docker-compose.yml` via variable interpolation.

**`whisper-gpu`** (installed to `~/.local/bin`): Auto-detects the project directory using two strategies: first searches upward from its own location for a directory containing both `docker-compose.yml` and `.git`, then falls back to `find $HOME -maxdepth 5 -name "docker-whisper-rocm"`. Checks/builds the Docker image, expands `~` paths to absolute paths, and runs whisper with `--user $(id -u):$(id -g)` to preserve file ownership.

**`docker-compose.yml`**: Configures GPU device passthrough (`/dev/kfd`, `/dev/dri`), mounts the user's home directory for file access, persists downloaded models in `./models`, and reads ROCm environment variables (`HSA_OVERRIDE_GFX_VERSION`, `VIDEO_GID`, `RENDER_GID`) from the shell environment.

**`Dockerfile`**: Builds on `rocm/pytorch:latest`. Installs whisper with `--no-deps` to avoid overwriting ROCm's PyTorch, then explicitly installs compatible dependencies (numpy==2.3.5, numba==0.63.1, llvmlite==0.46.0).

**`setup.sh`**: One-time setup that auto-detects GPU architecture via `rocminfo`, detects group IDs for `video`/`render`, installs the wrapper script, adds a shell function to `.zshrc` (uses subshell scoping to isolate env vars), and builds the image.

**`cleanup.sh`**: Interactive teardown that removes the wrapper, cleans `.zshrc`, and optionally deletes models and the Docker image (~15GB).

## Key Design Decisions

- Whisper is installed with `--no-deps` because its default dependencies would replace ROCm's PyTorch with CUDA PyTorch. Dependencies are then pinned individually.
- The `.zshrc` function wraps env var exports in a subshell `(...)` so they don't leak into the user's shell session.
- Numeric GIDs (not group names) are passed to Docker because container group name resolution differs from the host — the same name can map to different GIDs inside the container.
- `shm_size: 16G` is required for loading large whisper models.
- The wrapper uses `docker image inspect` to skip rebuilds when the image already exists.

## Shell Script Conventions

- Shebang: `#!/usr/bin/env bash`
- 4-space indentation
- Always quote variables: `"${VAR}"`
- UPPERCASE_WITH_UNDERSCORES for environment/exported variables
- Use `2>/dev/null` for error suppression
- Check exit codes: `if [[ $? -ne 0 ]]; then ... fi`
- Check file/dir existence with `-f` / `-d` before operating on them

## Documentation

- Project README lives at `docs/README.md` (intentionally not in repo root)
- GPU debugging guide lives at `docs/DEBUG.md`

## Known Issues

- **No `.gitignore`**: `models/` and `config/` directories have no `.gitignore` to prevent accidentally committing cached models or MIOpen config.
- **`config/miopen` not auto-created**: `docker-compose.yml` mounts `./config/miopen` but `setup.sh` never creates it (it exists from manual creation).

## System Requirements

- AMD GPU with ROCm support (user must be in `render` and `video` groups)
- Docker and Docker Compose
- ROCm drivers installed (`rocminfo` must be available for GPU auto-detection)
