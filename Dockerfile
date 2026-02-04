# Use the verified ROCm PyTorch image as base
FROM rocm/pytorch:latest

# Set environment variables for non-interactive installs and AMD GPU
ENV DEBIAN_FRONTEND=noninteractive

# Set this based on your GPU (11.0.0 for RX 7000, 10.3.0 for RX 6000)
ENV HSA_OVERRIDE_GFX_VERSION=11.0.0 

# Install FFmpeg and Git (Whisper requirements)
RUN apt-get update && apt-get install -y \
  ffmpeg \
  git \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install OpenAI Whisper
RUN pip install --no-cache-dir openai-whisper

WORKDIR /app

# Set whisper as the default command
ENTRYPOINT ["whisper"]
