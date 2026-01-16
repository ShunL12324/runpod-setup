#!/bin/bash
# =============================================================================
# ComfyUI + FaceFusion One-Click Setup for RunPod
# =============================================================================

set -e

echo "=========================================="
echo "  ComfyUI + FaceFusion Setup"
echo "=========================================="
echo ""

WORKSPACE="${WORKSPACE:-/workspace}"
COMFYUI_DIR="${WORKSPACE}/comfyui"
FACEFUSION_DIR="${WORKSPACE}/facefusion"
MODELS_DIR="${COMFYUI_DIR}/models"
DOWNLOAD_LIST="/tmp/model_downloads.txt"

cd "${WORKSPACE}" || exit 1

# =============================================================================
# [1/7] System Dependencies
# =============================================================================
echo "[1/7] Installing system dependencies..."
apt-get update < /dev/null
apt-get install -y git curl wget vim htop tmux screen aria2 ffmpeg zsh zsh-autosuggestions bc < /dev/null
apt-get install -y libsm6 libxext6 < /dev/null
apt-get install -y libgl1 2>/dev/null || apt-get install -y libgl1-mesa-glx 2>/dev/null || true
apt-get install -y libglib2.0-0t64 2>/dev/null || apt-get install -y libglib2.0-0 2>/dev/null || true
echo "Done."

# =============================================================================
# [2/7] ComfyUI
# =============================================================================
echo ""
echo "[2/7] Setting up ComfyUI..."
if [ ! -d "${COMFYUI_DIR}" ]; then
    git clone --depth 1 https://github.com/comfyanonymous/ComfyUI.git "${COMFYUI_DIR}"
fi

cd "${COMFYUI_DIR}"

NEED_COMFYUI_INSTALL=false
if [ ! -d "venv" ]; then
    NEED_COMFYUI_INSTALL=true
elif ! venv/bin/python -c "import torch; torch.cuda.init()" 2>/dev/null; then
    NEED_COMFYUI_INSTALL=true
fi

if [ "$NEED_COMFYUI_INSTALL" = true ]; then
    echo "Installing ComfyUI dependencies..."
    rm -rf venv
    python3 -m venv venv
    source venv/bin/activate
    pip install --upgrade pip
    pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu124
    pip install -r requirements.txt
    deactivate
fi
echo "Done."

# =============================================================================
# [3/7] ComfyUI Custom Nodes
# =============================================================================
echo ""
echo "[3/7] Setting up ComfyUI custom nodes..."
mkdir -p "${COMFYUI_DIR}/custom_nodes"
cd "${COMFYUI_DIR}/custom_nodes"
[ ! -d "ComfyUI-Manager" ] && git clone --depth 1 https://github.com/ltdrdata/ComfyUI-Manager.git
[ ! -d "comfy-portal-endpoint" ] && git clone --depth 1 https://github.com/ShunL12324/comfy-portal-endpoint.git
[ ! -d "ComfyUI-Model-Manager" ] && git clone --depth 1 https://github.com/hayden-fr/ComfyUI-Model-Manager.git
echo "Done."

# =============================================================================
# [4/7] FaceFusion
# =============================================================================
echo ""
echo "[4/7] Setting up FaceFusion..."
if [ ! -d "${FACEFUSION_DIR}" ]; then
    cd "${WORKSPACE}"
    git clone --depth 1 https://github.com/facefusion/facefusion.git "${FACEFUSION_DIR}"
fi

cd "${FACEFUSION_DIR}"

# Install uv
if ! command -v uv &> /dev/null; then
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="/root/.local/bin:$PATH"
fi

NEED_FF_INSTALL=false
if [ ! -d "venv" ]; then
    NEED_FF_INSTALL=true
elif ! venv/bin/python -c "import onnxruntime; import cv2" 2>/dev/null; then
    NEED_FF_INSTALL=true
fi

if [ "$NEED_FF_INSTALL" = true ]; then
    echo "Installing FaceFusion dependencies..."
    rm -rf venv
    uv venv venv
    source venv/bin/activate
    uv pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu124
    uv pip install -r requirements.txt
    uv pip install onnxruntime-gpu
    uv pip uninstall opencv-python -y 2>/dev/null || true
    uv pip install opencv-python-headless
    deactivate
fi
echo "Done."

# =============================================================================
# [5/7] NSFW Patch
# =============================================================================
echo ""
echo "[5/7] Applying NSFW patch..."
CONTENT_ANALYSER="${FACEFUSION_DIR}/facefusion/content_analyser.py"
CORE_PY="${FACEFUSION_DIR}/facefusion/core.py"

if [ -f "${CONTENT_ANALYSER}" ] && ! grep -q "# NSFW disabled" "${CONTENT_ANALYSER}"; then
    sed -i 's/def pre_check() -> bool:/def pre_check() -> bool:\n\treturn True  # NSFW disabled/' "${CONTENT_ANALYSER}"
    sed -i 's/def analyse_frame(vision_frame : VisionFrame) -> bool:/def analyse_frame(vision_frame : VisionFrame) -> bool:\n\treturn False  # NSFW disabled/' "${CONTENT_ANALYSER}"
    sed -i 's/def analyse_image(image_path : str) -> bool:/def analyse_image(image_path : str) -> bool:\n\treturn False  # NSFW disabled/' "${CONTENT_ANALYSER}"
    sed -i 's/def analyse_video(video_path : str, trim_frame_start : int, trim_frame_end : int) -> bool:/def analyse_video(video_path : str, trim_frame_start : int, trim_frame_end : int) -> bool:\n\treturn False  # NSFW disabled/' "${CONTENT_ANALYSER}"
    sed -i 's/def analyse_stream(vision_frame : VisionFrame, video_fps : Fps) -> bool:/def analyse_stream(vision_frame : VisionFrame, video_fps : Fps) -> bool:\n\treturn False  # NSFW disabled/' "${CONTENT_ANALYSER}"
fi

if [ -f "${CORE_PY}" ] && ! grep -q "# Hash check disabled" "${CORE_PY}"; then
    sed -i "s/return all(module.pre_check() for module in common_modules) and content_analyser_hash == 'b14e7b92'/return all(module.pre_check() for module in common_modules)  # Hash check disabled/" "${CORE_PY}"
fi
echo "Done."

# =============================================================================
# [6/7] Model Downloads
# =============================================================================
echo ""
echo "[6/7] Downloading models..."

mkdir -p "${MODELS_DIR}"/{checkpoints,clip,clip_vision,configs,controlnet,embeddings,loras,unet,upscale_models,vae}
> "${DOWNLOAD_LIST}"

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

# Wan2.2 i2v High Lighting
[ ! -f "${MODELS_DIR}/unet/Wan2.2_Remix_NSFW_i2v_14b_high_lighting_fp8_e4m3fn_v2.1.safetensors" ] && cat >> "${DOWNLOAD_LIST}" << 'EOF'
https://huggingface.co/FX-FeiHou/wan2.2-Remix/resolve/main/NSFW/Wan2.2_Remix_NSFW_i2v_14b_high_lighting_fp8_e4m3fn_v2.1.safetensors
  dir=unet
  out=Wan2.2_Remix_NSFW_i2v_14b_high_lighting_fp8_e4m3fn_v2.1.safetensors
EOF

# Wan2.2 i2v Low Lighting
[ ! -f "${MODELS_DIR}/unet/Wan2.2_Remix_NSFW_i2v_14b_low_lighting_fp8_e4m3fn_v2.1.safetensors" ] && cat >> "${DOWNLOAD_LIST}" << 'EOF'
https://huggingface.co/FX-FeiHou/wan2.2-Remix/resolve/main/NSFW/Wan2.2_Remix_NSFW_i2v_14b_low_lighting_fp8_e4m3fn_v2.1.safetensors
  dir=unet
  out=Wan2.2_Remix_NSFW_i2v_14b_low_lighting_fp8_e4m3fn_v2.1.safetensors
EOF

if [ -s "${DOWNLOAD_LIST}" ]; then
    aria2c --max-connection-per-server=16 --split=16 --max-concurrent-downloads=2 \
        --max-tries=10 --retry-wait=5 --timeout=120 --connect-timeout=30 \
        --dir="${MODELS_DIR}" --input-file="${DOWNLOAD_LIST}" \
        --console-log-level=notice --summary-interval=10 --continue=true
fi
echo "Done."

# =============================================================================
# [7/7] Helper Scripts & Shell Config
# =============================================================================
echo ""
echo "[7/7] Setting up helper scripts..."

# ComfyUI start script
cat > /usr/local/bin/comfy-start << 'EOF'
#!/bin/bash
if tmux has-session -t comfyui 2>/dev/null; then
    echo "ComfyUI already running. Use: tmux attach -t comfyui"
else
    tmux new-session -d -s comfyui
    tmux send-keys -t comfyui "cd /workspace/comfyui && source venv/bin/activate && python main.py --listen 0.0.0.0 --port 8188" Enter
    echo "ComfyUI started. Use: tmux attach -t comfyui"
fi
EOF
chmod +x /usr/local/bin/comfy-start

# ComfyUI stop script
cat > /usr/local/bin/comfy-stop << 'EOF'
#!/bin/bash
tmux kill-session -t comfyui 2>/dev/null && echo "ComfyUI stopped" || echo "ComfyUI not running"
EOF
chmod +x /usr/local/bin/comfy-stop

# FaceFusion start script
cat > /usr/local/bin/ff-start << 'EOF'
#!/bin/bash
if tmux has-session -t facefusion 2>/dev/null; then
    echo "FaceFusion already running. Use: tmux attach -t facefusion"
else
    tmux new-session -d -s facefusion
    tmux send-keys -t facefusion "cd /workspace/facefusion && source venv/bin/activate && GRADIO_SERVER_NAME=0.0.0.0 GRADIO_SERVER_PORT=3001 python facefusion.py run" Enter
    echo "FaceFusion started. Use: tmux attach -t facefusion"
fi
EOF
chmod +x /usr/local/bin/ff-start

# FaceFusion stop script
cat > /usr/local/bin/ff-stop << 'EOF'
#!/bin/bash
tmux kill-session -t facefusion 2>/dev/null && echo "FaceFusion stopped" || echo "FaceFusion not running"
EOF
chmod +x /usr/local/bin/ff-stop

# Shell config
if ! grep -q "# ComfyUI+FaceFusion Setup" ~/.zshrc 2>/dev/null; then
    cat >> ~/.zshrc << 'EOF'

# ComfyUI+FaceFusion Setup
export PATH="/root/.local/bin:$PATH"
source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh 2>/dev/null

alias comfy="tmux attach -t comfyui"
alias ff="tmux attach -t facefusion"

echo ""
echo "=========================================="
echo "  ComfyUI + FaceFusion Ready"
echo "=========================================="
echo ""
echo "Commands:"
echo "  comfy-start / comfy-stop / comfy"
echo "  ff-start    / ff-stop    / ff"
echo ""
echo "Ports: ComfyUI=8188, FaceFusion=3001"
echo ""
EOF
fi

chsh -s $(which zsh) 2>/dev/null || true
echo "Done."

# =============================================================================
# Cleanup & Exit
# =============================================================================
rm -f "${DOWNLOAD_LIST}"

echo ""
echo "=========================================="
echo "  Setup Complete!"
echo "=========================================="
echo ""
