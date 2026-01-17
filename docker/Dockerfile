# =============================================================================
# ComfyUI + FaceFusion Docker Image for RunPod
# =============================================================================

FROM nvidia/cuda:12.8.1-cudnn-devel-ubuntu24.04

LABEL maintainer="ShunL12324"
LABEL description="ComfyUI + FaceFusion for RunPod"

# =============================================================================
# Build Arguments
# =============================================================================

# Custom pip index URL (e.g., https://mirrors.aliyun.com/pypi/simple/)
ARG PIP_INDEX_URL=""

# =============================================================================
# Environment Variables
# =============================================================================

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    SHELL=/bin/zsh \
    WORKSPACE=/workspace \
    COMFYUI_DIR=/comfyui \
    FACEFUSION_DIR=/facefusion \
    PIP_INDEX_URL=${PIP_INDEX_URL} \
    UV_INDEX_URL=${PIP_INDEX_URL}

# =============================================================================
# System Packages
# =============================================================================

RUN apt-get update && apt-get install -y --no-install-recommends \
    # Basic tools
    git \
    curl \
    wget \
    vim \
    htop \
    ncdu \
    tmux \
    screen \
    zsh \
    bc \
    # Build tools
    build-essential \
    pkg-config \
    # Python
    python3.12 \
    python3.12-venv \
    python3.12-dev \
    python3-pip \
    # Media processing (for FaceFusion)
    ffmpeg \
    libsm6 \
    libxext6 \
    libgl1 \
    libglib2.0-0 \
    # Download tools
    aria2 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set python3.12 as default
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1 && \
    update-alternatives --install /usr/bin/python python /usr/bin/python3.12 1

# =============================================================================
# UV Package Manager
# =============================================================================

# Install uv
RUN curl -LsSf https://astral.sh/uv/install.sh | sh && \
    /root/.local/bin/uv --version
ENV PATH="/root/.local/bin:$PATH"

# =============================================================================
# Oh My Zsh
# =============================================================================

RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended && \
    git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions && \
    git clone https://github.com/zsh-users/zsh-syntax-highlighting ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting && \
    chsh -s /bin/zsh root

# =============================================================================
# ComfyUI Installation
# =============================================================================

WORKDIR /

# Clone ComfyUI
RUN git clone https://github.com/comfyanonymous/ComfyUI.git ${COMFYUI_DIR}

WORKDIR ${COMFYUI_DIR}

# Create and setup venv
RUN python3 -m venv venv && \
    . venv/bin/activate && \
    pip install --upgrade pip && \
    pip install -r requirements.txt && \
    pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128

# Install custom nodes
RUN mkdir -p custom_nodes && \
    git clone --depth 1 https://github.com/ltdrdata/ComfyUI-Manager.git custom_nodes/ComfyUI-Manager && \
    git clone --depth 1 https://github.com/ShunL12324/comfy-portal-endpoint.git custom_nodes/comfy-portal-endpoint && \
    git clone --depth 1 https://github.com/hayden-fr/ComfyUI-Model-Manager.git custom_nodes/ComfyUI-Model-Manager

# Create model directories
RUN mkdir -p models/{checkpoints,clip,clip_vision,configs,controlnet,embeddings,loras,unet,upscale_models,vae}

# =============================================================================
# FaceFusion Installation
# =============================================================================

WORKDIR /

# Clone FaceFusion
RUN git clone https://github.com/facefusion/facefusion.git ${FACEFUSION_DIR}

WORKDIR ${FACEFUSION_DIR}

# Install FaceFusion dependencies using uv with Python 3.12
# Note: PyTorch must use official index, other packages use UV_INDEX_URL if set
RUN uv venv --python 3.12 venv && \
    . venv/bin/activate && \
    uv pip install --upgrade pip && \
    uv pip install \
    torch==2.6.0 \
    torchvision==0.21.0 \
    torchaudio==2.6.0 \
    --index-url https://download.pytorch.org/whl/cu128 && \
    python install.py --onnxruntime cuda --skip-conda

# Apply patch to disable NSFW check (skips content analysis, no NSFW models needed)
# Placed after dependencies for better cache efficiency
COPY patches/disable-nsfw-check.py /tmp/disable-nsfw-check.py
RUN python3 /tmp/disable-nsfw-check.py ${FACEFUSION_DIR} && rm /tmp/disable-nsfw-check.py

# =============================================================================
# Scripts & Configuration
# =============================================================================

# Copy scripts
COPY scripts/start.sh /scripts/start.sh
COPY scripts/start_comfyui.sh /scripts/start_comfyui.sh
COPY scripts/start_facefusion.sh /scripts/start_facefusion.sh
COPY scripts/download-models.sh /scripts/download-models.sh

# Copy config
COPY config/.zshrc /root/.zshrc

# Make scripts executable
RUN chmod +x /scripts/*.sh

# Create symlinks for convenience
RUN ln -s /scripts/download-models.sh /usr/local/bin/download-models && \
    ln -s /scripts/start_comfyui.sh /usr/local/bin/comfy-start && \
    ln -s /scripts/start_facefusion.sh /usr/local/bin/ff-start

# =============================================================================
# Expose Ports & Entrypoint
# =============================================================================

EXPOSE 8188 7860

WORKDIR /

CMD ["/scripts/start.sh"]
