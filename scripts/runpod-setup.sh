#!/bin/bash
# =============================================================================
# ComfyUI + FaceFusion One-Click Setup for RunPod
# =============================================================================

echo "=========================================="
echo "  ComfyUI + FaceFusion Setup"
echo "=========================================="
echo ""

WORKSPACE="${WORKSPACE:-/workspace}"
COMFYUI_DIR="${WORKSPACE}/comfyui"
FACEFUSION_DIR="${WORKSPACE}/facefusion"
MODELS_DIR="${COMFYUI_DIR}/models"

cd "${WORKSPACE}" || exit 1

# =============================================================================
# System Dependencies
# =============================================================================
if ! command -v aria2c &> /dev/null; then
    echo "[1/7] Installing system dependencies..."
    apt-get update < /dev/null
    apt-get install -y git curl wget vim htop tmux screen aria2 ffmpeg zsh \
        libsm6 libxext6 libgl1-mesa-glx libglib2.0-0 bc < /dev/null
    echo "Done."
else
    echo "[1/7] System dependencies already installed, skipping..."
fi

# =============================================================================
# ComfyUI
# =============================================================================
if [ ! -d "${COMFYUI_DIR}" ]; then
    echo ""
    echo "[2/7] Installing ComfyUI..."
    git clone --depth 1 https://github.com/comfyanonymous/ComfyUI.git "${COMFYUI_DIR}"
    cd "${COMFYUI_DIR}"
    pip install -r requirements.txt
    mkdir -p models/{checkpoints,clip,clip_vision,configs,controlnet,embeddings,loras,unet,upscale_models,vae}
    echo "Done."
else
    echo "[2/7] ComfyUI already installed, skipping..."
fi

# =============================================================================
# ComfyUI Custom Nodes
# =============================================================================
echo ""
echo "[3/7] Checking ComfyUI custom nodes..."
mkdir -p "${COMFYUI_DIR}/custom_nodes"
cd "${COMFYUI_DIR}/custom_nodes"
[ ! -d "ComfyUI-Manager" ] && git clone --depth 1 https://github.com/ltdrdata/ComfyUI-Manager.git && echo "  - ComfyUI-Manager installed"
[ ! -d "comfy-portal-endpoint" ] && git clone --depth 1 https://github.com/ShunL12324/comfy-portal-endpoint.git && echo "  - comfy-portal-endpoint installed"
[ ! -d "ComfyUI-Model-Manager" ] && git clone --depth 1 https://github.com/hayden-fr/ComfyUI-Model-Manager.git && echo "  - ComfyUI-Model-Manager installed"
echo "Done."

# =============================================================================
# FaceFusion
# =============================================================================
if [ ! -d "${FACEFUSION_DIR}" ]; then
    echo ""
    echo "[4/7] Installing FaceFusion..."
    cd "${WORKSPACE}"
    git clone --depth 1 https://github.com/facefusion/facefusion.git "${FACEFUSION_DIR}"
    cd "${FACEFUSION_DIR}"

    # Install uv
    if ! command -v uv &> /dev/null; then
        echo "Installing uv..."
        curl -LsSf https://astral.sh/uv/install.sh | sh
        export PATH="/root/.local/bin:$PATH"
    fi

    echo "Creating FaceFusion venv..."
    uv venv --python 3.11 venv
    source venv/bin/activate
    echo "Installing PyTorch for FaceFusion..."
    uv pip install torch==2.6.0 torchvision==0.21.0 torchaudio==2.6.0 --index-url https://download.pytorch.org/whl/cu124
    echo "Running FaceFusion install.py..."
    python install.py --onnxruntime cuda --skip-conda
    deactivate
    echo "Done."
else
    echo "[4/7] FaceFusion already installed, skipping..."
fi

# =============================================================================
# NSFW Patch
# =============================================================================
echo ""
echo "[5/7] Checking NSFW patch..."
CONTENT_ANALYSER="${FACEFUSION_DIR}/facefusion/content_analyser.py"
if [ -f "${CONTENT_ANALYSER}" ] && ! grep -q "# NSFW disabled" "${CONTENT_ANALYSER}"; then
    echo "Applying NSFW patch..."
    sed -i 's/def pre_check() -> bool:/def pre_check() -> bool:\n\treturn True  # NSFW disabled/' "${CONTENT_ANALYSER}"
    sed -i 's/def analyse_frame(vision_frame : VisionFrame) -> bool:/def analyse_frame(vision_frame : VisionFrame) -> bool:\n\treturn False  # NSFW disabled/' "${CONTENT_ANALYSER}"
    sed -i 's/def analyse_image(image_path : str) -> bool:/def analyse_image(image_path : str) -> bool:\n\treturn False  # NSFW disabled/' "${CONTENT_ANALYSER}"
    sed -i 's/def analyse_video(video_path : str, trim_frame_start : int, trim_frame_end : int) -> bool:/def analyse_video(video_path : str, trim_frame_start : int, trim_frame_end : int) -> bool:\n\treturn False  # NSFW disabled/' "${CONTENT_ANALYSER}"
    sed -i 's/def analyse_stream(vision_frame : VisionFrame, video_fps : Fps) -> bool:/def analyse_stream(vision_frame : VisionFrame, video_fps : Fps) -> bool:\n\treturn False  # NSFW disabled/' "${CONTENT_ANALYSER}"
    echo "Done."
else
    echo "NSFW patch already applied, skipping..."
fi

# =============================================================================
# Model Downloads (aria2c parallel)
# =============================================================================
echo ""
echo "[6/7] Downloading models..."

mkdir -p "${MODELS_DIR}"/{checkpoints,clip,vae,unet,loras,controlnet,upscale_models}

# Create download list file
DOWNLOAD_LIST="/tmp/model_downloads.txt"
cat > "${DOWNLOAD_LIST}" << 'MODELS'
# SDXL Base
https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors
  dir=checkpoints
  out=sd_xl_base_1.0.safetensors

# SDXL VAE
https://huggingface.co/stabilityai/sdxl-vae/resolve/main/sdxl_vae.safetensors
  dir=vae
  out=sdxl_vae.safetensors

# FLUX Schnell (fast)
https://huggingface.co/black-forest-labs/FLUX.1-schnell/resolve/main/flux1-schnell.safetensors
  dir=unet
  out=flux1-schnell.safetensors

# FLUX VAE
https://huggingface.co/black-forest-labs/FLUX.1-schnell/resolve/main/ae.safetensors
  dir=vae
  out=flux_ae.safetensors

# CLIP for FLUX
https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors
  dir=clip
  out=clip_l.safetensors

https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp8_e4m3fn.safetensors
  dir=clip
  out=t5xxl_fp8_e4m3fn.safetensors

# 4x Upscaler
https://huggingface.co/Kim2091/ClearRealityV1/resolve/main/4x-ClearRealityV1.safetensors
  dir=upscale_models
  out=4x-ClearRealityV1.safetensors
MODELS

# Filter out already downloaded models
FILTERED_LIST="/tmp/model_downloads_filtered.txt"
> "${FILTERED_LIST}"

current_url=""
current_dir=""
current_out=""

while IFS= read -r line || [ -n "$line" ]; do
    # Skip comments and empty lines
    [[ "$line" =~ ^#.*$ ]] && continue
    [[ -z "$line" ]] && continue

    if [[ "$line" =~ ^https:// ]]; then
        current_url="$line"
    elif [[ "$line" =~ ^[[:space:]]*dir= ]]; then
        current_dir="${line#*=}"
    elif [[ "$line" =~ ^[[:space:]]*out= ]]; then
        current_out="${line#*=}"
        # Check if file exists
        if [ ! -f "${MODELS_DIR}/${current_dir}/${current_out}" ]; then
            echo "$current_url" >> "${FILTERED_LIST}"
            echo "  dir=${current_dir}" >> "${FILTERED_LIST}"
            echo "  out=${current_out}" >> "${FILTERED_LIST}"
            echo "" >> "${FILTERED_LIST}"
        else
            echo "  [SKIP] ${current_out} already exists"
        fi
    fi
done < "${DOWNLOAD_LIST}"

# Download if there are files to download
if [ -s "${FILTERED_LIST}" ]; then
    echo ""
    echo "Downloading models with aria2c (16 connections)..."
    echo ""
    aria2c -x 16 -s 16 -j 4 -d "${MODELS_DIR}" -i "${FILTERED_LIST}" --console-log-level=notice --summary-interval=5
    echo ""
    echo "Model download complete."
else
    echo "All models already downloaded."
fi

# =============================================================================
# Helper Scripts & Shell Config
# =============================================================================
echo ""
echo "[7/7] Setting up helper scripts and shell config..."

# ComfyUI start script (tmux)
cat > /usr/local/bin/comfy-start << 'EOF'
#!/bin/bash
if tmux has-session -t comfyui 2>/dev/null; then
    echo "ComfyUI already running in tmux session 'comfyui'"
    echo "Use: tmux attach -t comfyui"
else
    tmux new-session -d -s comfyui -c /workspace/comfyui "python main.py --listen 0.0.0.0 --port 8188"
    echo "ComfyUI started in tmux session 'comfyui'"
    echo "Use: tmux attach -t comfyui"
fi
EOF
chmod +x /usr/local/bin/comfy-start

# ComfyUI stop script
cat > /usr/local/bin/comfy-stop << 'EOF'
#!/bin/bash
tmux kill-session -t comfyui 2>/dev/null && echo "ComfyUI stopped" || echo "ComfyUI not running"
EOF
chmod +x /usr/local/bin/comfy-stop

# FaceFusion start script (tmux)
cat > /usr/local/bin/ff-start << 'EOF'
#!/bin/bash
if tmux has-session -t facefusion 2>/dev/null; then
    echo "FaceFusion already running in tmux session 'facefusion'"
    echo "Use: tmux attach -t facefusion"
else
    tmux new-session -d -s facefusion -c /workspace/facefusion "source venv/bin/activate && python facefusion.py run --ui-layouts default benchmark"
    echo "FaceFusion started in tmux session 'facefusion'"
    echo "Use: tmux attach -t facefusion"
fi
EOF
chmod +x /usr/local/bin/ff-start

# FaceFusion stop script
cat > /usr/local/bin/ff-stop << 'EOF'
#!/bin/bash
tmux kill-session -t facefusion 2>/dev/null && echo "FaceFusion stopped" || echo "FaceFusion not running"
EOF
chmod +x /usr/local/bin/ff-stop

# Add to .zshrc if not already added
if ! grep -q "# ComfyUI+FaceFusion Setup" ~/.zshrc 2>/dev/null; then
    cat >> ~/.zshrc << 'EOF'

# ComfyUI+FaceFusion Setup
export PATH="/root/.local/bin:$PATH"

alias comfy="tmux attach -t comfyui"
alias ff="tmux attach -t facefusion"

echo ""
echo "=========================================="
echo "  ComfyUI + FaceFusion Ready"
echo "=========================================="
echo ""
echo "Commands:"
echo "  comfy-start  - Start ComfyUI (tmux)"
echo "  comfy-stop   - Stop ComfyUI"
echo "  comfy        - Attach to ComfyUI session"
echo ""
echo "  ff-start     - Start FaceFusion (tmux)"
echo "  ff-stop      - Stop FaceFusion"
echo "  ff           - Attach to FaceFusion session"
echo ""
echo "Ports:"
echo "  ComfyUI:     8188"
echo "  FaceFusion:  7860"
echo ""
EOF
    echo "Shell config added to .zshrc"
else
    echo "Shell config already exists in .zshrc"
fi

# =============================================================================
# Done
# =============================================================================
echo ""
echo "=========================================="
echo "  Setup Complete!"
echo "=========================================="
echo ""
echo "Start a new shell or run: source ~/.zshrc"
echo ""
echo "Then use:"
echo "  comfy-start  - Start ComfyUI"
echo "  ff-start     - Start FaceFusion"
echo ""
