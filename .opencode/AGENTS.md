# AGENTS.md - Docker Whisper ROCm Project

## Project Overview

This is a Docker-based project for OpenAI Whisper with AMD GPU (ROCm) support. The project provides containerized speech-to-text transcription with GPU acceleration for AMD hardware.

## Build, Lint, and Test Commands

### Build Commands

```bash
# Build the Docker image
docker compose build
```

### Cleanup Commands

```bash
# Stop containers and prune build cache
docker compose down
docker builder prune -f

# Full cleanup including models and image
./cleanup.sh
```

### Test Commands

```bash
# Test GPU detection and ROCm setup
docker compose run --rm --entrypoint python3 whisper -c "import torch; print(f'ROCm version: {torch.version.hip}'); print(f'GPU available: {torch.cuda.is_available()}')"

# Test basic whisper functionality
docker compose run --rm whisper --help
```

## Code Style Guidelines

### Shell Scripting (Bash)

- **Shebang**: Always use `#!/usr/bin/env bash` for shell scripts
- **Indentation**: Use 4 spaces for indentation
- **Comments**: Use `#` for single-line comments, `# ---` for section dividers
- **Variable naming**: Use UPPERCASE_WITH_UNDERSCORES for constants and exports (e.g., `PROJECT_DIR`, `DETECTED_GFX`)
- **String quoting**: Always quote variables (e.g., `"${BASH_SOURCE[0]}"`)
- **Error checking**: Check command existence before execution (e.g., `2>/dev/null`)
- **Function definitions**: Use `function name() { ... }` or `name() { ... }` syntax
- **Exit codes**: Return appropriate exit codes (0 for success, non-zero for errors)
- **User prompts**: Use `read -p` with `echo` for user interaction

### Docker Configuration

- **Dockerfile**: Keep image layers minimal and clean up apt caches in the same RUN step
- **docker-compose.yml**: Use environment variables for sensitive values, document all volumes
- **Image naming**: Use descriptive names (e.g., `whisper-rocm`)
- **Container naming**: Use meaningful names (e.g., `whisper-ai-rocm`)

### File Organization

- **Scripts**: Place in project root with executable permissions
- **Documentation**: Keep in project root or dedicated docs directory
- **Configuration**: Use `.yml` or `.yaml` format for Docker Compose
- **Model cache**: Store in `./models` directory for persistence

### Naming Conventions

- **Project directory**: Use kebab-case (e.g., `docker-whisper-rocm`)
- **Docker image**: Use lowercase with hyphens (e.g., `whisper-rocm`)
- **Container name**: Use lowercase with hyphens (e.g., `whisper-ai-rocm`)
- **Shell functions**: Use hyphens for command aliases (e.g., `whisper-gpu`)
- **Environment variables**: Use uppercase with underscores (e.g., `HSA_OVERRIDE_GFX_VERSION`)

### Error Handling

- **Command failures**: Check exit codes with `if [[ $? -ne 0 ]]; then ... fi`
- **File existence**: Use `-f` for files, `-d` for directories
- **User input**: Validate user responses with regex patterns
- **Graceful degradation**: Provide fallback values when possible

### Documentation Standards

- **README.md**: Use Markdown with clear sections, code blocks, and emojis for visual appeal
- **Comments**: Explain complex logic, especially GPU detection and Docker configuration
- **Usage examples**: Provide concrete examples with expected output
- **Troubleshooting**: Include common issues and solutions

### Security Considerations

- **File permissions**: Ensure scripts are executable (`chmod +x`)
- **User context**: Use `${UID}:${GID}` for proper file ownership
- **Device access**: Document required permissions for GPU devices
- **Environment variables**: Never hardcode sensitive values

### Project-Specific Guidelines

- **GPU detection**: Auto-detect AMD GPU architecture using `rocminfo`
- **Model caching**: Persist models in `./models` directory
- **Home directory mapping**: Always map `${HOME}` for user file access
- **Cleanup**: Provide cleanup script to reclaim disk space
- **Alias setup**: Create shell function for easy command access

## Development Workflow

1. **Setup**: Run `./setup.sh` to configure environment and build image
2. **Usage**: Use `whisper-gpu` command from any directory
3. **Maintenance**: Run `./cleanup.sh` when needed
4. **Testing**: Verify GPU detection and functionality with test commands

## Important Notes

- This project uses AMD ROCm for GPU acceleration
- Requires user to be in `video` and `render` groups
- Models are cached locally in `./models` directory
- Docker containers are removed automatically with `--rm` flag
