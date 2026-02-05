# Use the verified ROCm PyTorch image as base
FROM rocm/pytorch:latest

# Set environment variables for non-interactive installs and AMD GPU
ENV DEBIAN_FRONTEND=noninteractive

# Install FFmpeg and Git (Whisper requirements)
RUN apt-get update && apt-get install -y \
  ffmpeg \
  git \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Whisper WITHOUT dependencies (this keeps your ROCm Torch safe)
RUN pip install --no-cache-dir openai-whisper --no-deps

# Install all the OTHER things Whisper needs with explicit numpy version
RUN pip install --no-cache-dir \
    numpy==2.3.5 \
    tiktoken \
    numba==0.63.1 \
    llvmlite==0.46.0 \
    tqdm \
    more-itertools \
    fsspec

WORKDIR /app

# Set whisper as the default command
CMD ["whisper"]
