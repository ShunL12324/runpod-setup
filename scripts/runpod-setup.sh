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

cd "${WORKSPACE}" || exit 1

# =============================================================================
# System Dependencies
# =============================================================================
echo "[1/6] Installing system dependencies..."
apt-get update
apt-get install -y git curl wget vim htop tmux screen aria2 ffmpeg libsm6 libxext6 libgl1-mesa-glx libglib2.0-0 bc
echo "Done."

# =============================================================================
# ComfyUI
# =============================================================================
echo ""
echo "[2/6] Installing ComfyUI..."
if [ ! -d "${COMFYUI_DIR}" ]; then
    git clone --depth 1 https://github.com/comfyanonymous/ComfyUI.git "${COMFYUI_DIR}"
fi
cd "${COMFYUI_DIR}"
pip install -r requirements.txt
mkdir -p models/{checkpoints,clip,clip_vision,configs,controlnet,embeddings,loras,unet,upscale_models,vae}
echo "Done."

# =============================================================================
# ComfyUI Custom Nodes
# =============================================================================
echo ""
echo "[3/6] Installing ComfyUI custom nodes..."
cd "${COMFYUI_DIR}/custom_nodes"
[ ! -d "ComfyUI-Manager" ] && git clone --depth 1 https://github.com/ltdrdata/ComfyUI-Manager.git
[ ! -d "comfy-portal-endpoint" ] && git clone --depth 1 https://github.com/ShunL12324/comfy-portal-endpoint.git
[ ! -d "ComfyUI-Model-Manager" ] && git clone --depth 1 https://github.com/hayden-fr/ComfyUI-Model-Manager.git
echo "Done."

# =============================================================================
# FaceFusion
# =============================================================================
echo ""
echo "[4/6] Installing FaceFusion..."
cd "${WORKSPACE}"
if [ ! -d "${FACEFUSION_DIR}" ]; then
    git clone --depth 1 https://github.com/facefusion/facefusion.git "${FACEFUSION_DIR}"
fi
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

# =============================================================================
# NSFW Patch
# =============================================================================
echo ""
echo "[5/6] Applying NSFW patch..."
CONTENT_ANALYSER="${FACEFUSION_DIR}/facefusion/content_analyser.py"
if [ -f "${CONTENT_ANALYSER}" ]; then
    sed -i 's/def pre_check() -> bool:/def pre_check() -> bool:\n\treturn True  # NSFW disabled/' "${CONTENT_ANALYSER}"
    sed -i 's/def analyse_frame(vision_frame : VisionFrame) -> bool:/def analyse_frame(vision_frame : VisionFrame) -> bool:\n\treturn False  # NSFW disabled/' "${CONTENT_ANALYSER}"
    sed -i 's/def analyse_image(image_path : str) -> bool:/def analyse_image(image_path : str) -> bool:\n\treturn False  # NSFW disabled/' "${CONTENT_ANALYSER}"
    sed -i 's/def analyse_video(video_path : str, trim_frame_start : int, trim_frame_end : int) -> bool:/def analyse_video(video_path : str, trim_frame_start : int, trim_frame_end : int) -> bool:\n\treturn False  # NSFW disabled/' "${CONTENT_ANALYSER}"
    sed -i 's/def analyse_stream(vision_frame : VisionFrame, video_fps : Fps) -> bool:/def analyse_stream(vision_frame : VisionFrame, video_fps : Fps) -> bool:\n\treturn False  # NSFW disabled/' "${CONTENT_ANALYSER}"
fi
echo "Done."

# =============================================================================
# Helper Scripts
# =============================================================================
echo ""
echo "[6/6] Creating helper scripts..."

cat > /usr/local/bin/comfy-start << 'EOF'
#!/bin/bash
cd /workspace/comfyui
nohup python main.py --listen 0.0.0.0 --port 8188 > /workspace/comfyui.log 2>&1 &
echo "ComfyUI started on port 8188"
EOF
chmod +x /usr/local/bin/comfy-start

cat > /usr/local/bin/ff-start << 'EOF'
#!/bin/bash
cd /workspace/facefusion
source venv/bin/activate
nohup python facefusion.py run --ui-layouts default benchmark > /workspace/facefusion.log 2>&1 &
echo "FaceFusion started on port 7860"
EOF
chmod +x /usr/local/bin/ff-start

cat > /usr/local/bin/ff-stop << 'EOF'
#!/bin/bash
pkill -f "facefusion.py" && echo "FaceFusion stopped" || echo "Not running"
EOF
chmod +x /usr/local/bin/ff-stop

echo "Done."

# =============================================================================
# Start ComfyUI
# =============================================================================
echo ""
echo "Starting ComfyUI..."
cd "${COMFYUI_DIR}"
nohup python main.py --listen 0.0.0.0 --port 8188 > /workspace/comfyui.log 2>&1 &
sleep 2

# =============================================================================
# Done
# =============================================================================
echo ""
echo "=========================================="
echo "  Setup Complete!"
echo "=========================================="
echo ""
echo "ComfyUI:     http://localhost:8188  [Running]"
echo "FaceFusion:  http://localhost:7860  [Run: ff-start]"
echo ""
echo "Commands:"
echo "  ff-start   - Start FaceFusion"
echo "  ff-stop    - Stop FaceFusion"
echo ""
