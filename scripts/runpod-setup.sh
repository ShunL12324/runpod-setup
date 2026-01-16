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
echo "[1/7] Installing system dependencies..."
apt-get update < /dev/null
# Core packages
apt-get install -y git curl wget vim htop tmux screen aria2 ffmpeg zsh bc < /dev/null
# Graphics libs (different names on Ubuntu 22.04 vs 24.04)
apt-get install -y libsm6 libxext6 < /dev/null
apt-get install -y libgl1 2>/dev/null || apt-get install -y libgl1-mesa-glx 2>/dev/null || true
apt-get install -y libglib2.0-0t64 2>/dev/null || apt-get install -y libglib2.0-0 2>/dev/null || true
echo "Done."

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

mkdir -p "${MODELS_DIR}"/{checkpoints,clip,clip_vision,vae,unet}
mkdir -p "${FACEFUSION_DIR}/.assets/models"

FF_MODELS_DIR="${FACEFUSION_DIR}/.assets/models"

# Create download list
DOWNLOAD_LIST="/tmp/model_downloads.txt"
> "${DOWNLOAD_LIST}"

# ===== ComfyUI Models =====
# VAE
[ ! -f "${MODELS_DIR}/vae/wan_2.1_vae.safetensors" ] && cat >> "${DOWNLOAD_LIST}" << 'EOF'
https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors
  dir=vae
  out=wan_2.1_vae.safetensors
EOF

# Checkpoint (All-in-One)
[ ! -f "${MODELS_DIR}/checkpoints/wan2.2-rapid-mega-nsfw-aio-v3.1.safetensors" ] && cat >> "${DOWNLOAD_LIST}" << 'EOF'
https://huggingface.co/Phr00t/WAN2.2-14B-Rapid-AllInOne/resolve/main/Mega-v3/wan2.2-rapid-mega-nsfw-aio-v3.1.safetensors
  dir=checkpoints
  out=wan2.2-rapid-mega-nsfw-aio-v3.1.safetensors
EOF

# CLIP
[ ! -f "${MODELS_DIR}/clip/nsfw_wan_umt5-xxl_fp8_scaled.safetensors" ] && cat >> "${DOWNLOAD_LIST}" << 'EOF'
https://huggingface.co/NSFW-API/NSFW-Wan-UMT5-XXL/resolve/main/nsfw_wan_umt5-xxl_fp8_scaled.safetensors
  dir=clip
  out=nsfw_wan_umt5-xxl_fp8_scaled.safetensors
EOF

# CLIP Vision
[ ! -f "${MODELS_DIR}/clip_vision/clip-vision_vit-h.safetensors" ] && cat >> "${DOWNLOAD_LIST}" << 'EOF'
https://huggingface.co/hfmaster/models-moved/resolve/8b8d4cae76158cd49410d058971bb0e591966e04/sdxl/ipadapter/clip-vision_vit-h.safetensors
  dir=clip_vision
  out=clip-vision_vit-h.safetensors
EOF

# Download ComfyUI models
if [ -s "${DOWNLOAD_LIST}" ]; then
    echo ""
    echo "Downloading ComfyUI models..."
    aria2c --max-connection-per-server=16 --split=16 --max-concurrent-downloads=2 \
        --max-tries=10 --retry-wait=5 --timeout=120 --connect-timeout=30 \
        --dir="${MODELS_DIR}" --input-file="${DOWNLOAD_LIST}" \
        --console-log-level=notice --summary-interval=10 --continue=true
fi

# ===== FaceFusion Models =====
FF_DOWNLOAD_LIST="/tmp/ff_model_downloads.txt"
> "${FF_DOWNLOAD_LIST}"

# Core models
FF_MODELS=(
    "yoloface_8n.onnx|https://huggingface.co/facefusion/models-3.0.0/resolve/main/yoloface_8n.onnx"
    "2dfan4.onnx|https://huggingface.co/facefusion/models-3.0.0/resolve/main/2dfan4.onnx"
    "arcface_w600k_r50.onnx|https://huggingface.co/facefusion/models-3.0.0/resolve/main/arcface_w600k_r50.onnx"
    "bisenet_resnet_34.onnx|https://huggingface.co/facefusion/models-3.0.0/resolve/main/bisenet_resnet_34.onnx"
    "fairface.onnx|https://huggingface.co/facefusion/models-3.0.0/resolve/main/fairface.onnx"
    "inswapper_128_fp16.onnx|https://huggingface.co/facefusion/models-3.0.0/resolve/main/inswapper_128_fp16.onnx"
    "hyperswap_1a_256.onnx|https://huggingface.co/facefusion/models-3.3.0/resolve/main/hyperswap_1a_256.onnx"
    "gfpgan_1.4.onnx|https://huggingface.co/facefusion/models-3.0.0/resolve/main/gfpgan_1.4.onnx"
    "codeformer.onnx|https://huggingface.co/facefusion/models-3.0.0/resolve/main/codeformer.onnx"
    "gpen_bfr_1024.onnx|https://huggingface.co/facefusion/models-3.0.0/resolve/main/gpen_bfr_1024.onnx"
    "xseg_1.onnx|https://huggingface.co/facefusion/models-3.1.0/resolve/main/xseg_1.onnx"
    "bisenet_resnet_18.onnx|https://huggingface.co/facefusion/models-3.1.0/resolve/main/bisenet_resnet_18.onnx"
    "real_esrgan_x2_fp16.onnx|https://huggingface.co/facefusion/models-3.0.0/resolve/main/real_esrgan_x2_fp16.onnx"
    "real_esrgan_x4_fp16.onnx|https://huggingface.co/facefusion/models-3.0.0/resolve/main/real_esrgan_x4_fp16.onnx"
    "span_kendata_x4.onnx|https://huggingface.co/facefusion/models-3.0.0/resolve/main/span_kendata_x4.onnx"
    "ddcolor.onnx|https://huggingface.co/facefusion/models-3.0.0/resolve/main/ddcolor.onnx"
    "kim_vocal_2.onnx|https://huggingface.co/facefusion/models-3.0.0/resolve/main/kim_vocal_2.onnx"
    "fan_68_5.onnx|https://huggingface.co/facefusion/models-3.0.0/resolve/main/fan_68_5.onnx"
)

for item in "${FF_MODELS[@]}"; do
    name="${item%%|*}"
    url="${item##*|}"
    if [ ! -f "${FF_MODELS_DIR}/${name}" ]; then
        echo "${url}" >> "${FF_DOWNLOAD_LIST}"
        echo "  out=${name}" >> "${FF_DOWNLOAD_LIST}"
        echo "" >> "${FF_DOWNLOAD_LIST}"
    else
        echo "  [SKIP] ${name}"
    fi
done

# Download FaceFusion models
if [ -s "${FF_DOWNLOAD_LIST}" ]; then
    echo ""
    echo "Downloading FaceFusion models..."
    aria2c --max-connection-per-server=16 --split=16 --max-concurrent-downloads=4 \
        --max-tries=10 --retry-wait=5 --timeout=120 --connect-timeout=30 \
        --dir="${FF_MODELS_DIR}" --input-file="${FF_DOWNLOAD_LIST}" \
        --console-log-level=notice --summary-interval=10 --continue=true
fi

echo ""
echo "Model download complete."

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
