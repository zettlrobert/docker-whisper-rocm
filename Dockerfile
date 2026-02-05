# Use the verified ROCm PyTorch image as base
FROM rocm/pytorch:latest

# Set environment variables for non-interactive installs and AMD GPU
ENV DEBIAN_FRONTEND=noninteractive

# Install FFmpeg and Git (Whisper requirements)
RUN apt-get update && apt-get install -y \
  ffmpeg \
  git \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# 3. Install Whisper WITHOUT dependencies (this keeps your ROCm Torch safe)
RUN pip install --no-cache-dir openai-whisper --no-deps

# 4. Install all the OTHER things Whisper needs
RUN pip install --no-cache-dir tiktoken numba numpy tqdm more-itertools

# 5. Optional: Ensure Torch is the absolute latest ROCm version
# Note: The 'rocm/pytorch' base image usually has this, but this is your "insurance policy"
RUN pip install --no-cache-dir --upgrade torch torchvision torchaudio \
  --index-url https://download.pytorch.org/whl/rocm6.2

WORKDIR /app

# Set whisper as the default command
CMD ["whisper"]
