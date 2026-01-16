#!/bin/bash
# =============================================================================
# ComfyUI + FaceFusion One-Click Setup for RunPod
# =============================================================================
# Usage: curl -sSL https://raw.githubusercontent.com/ShunL12324/runpod-setup/master/scripts/runpod-setup.sh | bash
#
# Recommended RunPod Image: runpod/pytorch:2.4.0-py3.11-cuda12.4.1-devel-ubuntu22.04
# =============================================================================

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_step() { echo -e "${CYAN}[STEP]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  ComfyUI + FaceFusion One-Click Setup                      ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo

WORKSPACE=${WORKSPACE:-/workspace}
COMFYUI_DIR="${WORKSPACE}/comfyui"
FACEFUSION_DIR="${WORKSPACE}/facefusion"

cd "${WORKSPACE}"

# =============================================================================
# System Dependencies
# =============================================================================

log_step "Installing system dependencies..."
apt-get update && apt-get install -y --no-install-recommends \
    git curl wget vim htop tmux screen aria2 ffmpeg \
    libsm6 libxext6 libgl1-mesa-glx libglib2.0-0 bc \
    > /dev/null 2>&1
log_info "System dependencies installed"

# =============================================================================
# ComfyUI Installation
# =============================================================================

if [ -d "${COMFYUI_DIR}" ]; then
    log_info "ComfyUI already exists, updating..."
    cd "${COMFYUI_DIR}" && git pull --quiet
else
    log_step "Installing ComfyUI..."
    git clone --depth 1 https://github.com/comfyanonymous/ComfyUI.git "${COMFYUI_DIR}"
fi

cd "${COMFYUI_DIR}"

# Install ComfyUI dependencies
log_step "Installing ComfyUI dependencies..."
pip install -q -r requirements.txt
pip install -q torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu124 2>/dev/null || true

# Install custom nodes
log_step "Installing ComfyUI custom nodes..."
mkdir -p custom_nodes
cd custom_nodes

[ ! -d "ComfyUI-Manager" ] && git clone --depth 1 https://github.com/ltdrdata/ComfyUI-Manager.git
[ ! -d "comfy-portal-endpoint" ] && git clone --depth 1 https://github.com/ShunL12324/comfy-portal-endpoint.git
[ ! -d "ComfyUI-Model-Manager" ] && git clone --depth 1 https://github.com/hayden-fr/ComfyUI-Model-Manager.git

cd "${COMFYUI_DIR}"

# Create model directories
mkdir -p models/{checkpoints,clip,clip_vision,configs,controlnet,embeddings,loras,unet,upscale_models,vae}

log_info "ComfyUI installed"

# =============================================================================
# FaceFusion Installation
# =============================================================================

if [ -d "${FACEFUSION_DIR}" ]; then
    log_info "FaceFusion already exists, updating..."
    cd "${FACEFUSION_DIR}" && git pull --quiet
else
    log_step "Installing FaceFusion..."
    git clone --depth 1 https://github.com/facefusion/facefusion.git "${FACEFUSION_DIR}"
fi

cd "${FACEFUSION_DIR}"

# Install uv if not exists
if ! command -v uv &> /dev/null; then
    log_step "Installing uv package manager..."
    curl -LsSf https://astral.sh/uv/install.sh | sh > /dev/null 2>&1
    export PATH="/root/.local/bin:$PATH"
fi

# Create venv and install dependencies
log_step "Installing FaceFusion dependencies..."
if [ ! -d "venv" ]; then
    uv venv --python 3.11 venv
fi
source venv/bin/activate

uv pip install -q torch==2.6.0 torchvision==0.21.0 torchaudio==2.6.0 --index-url https://download.pytorch.org/whl/cu124
python install.py --onnxruntime cuda --skip-conda > /dev/null 2>&1

deactivate

# Apply NSFW patch
log_step "Applying NSFW check patch..."
CONTENT_ANALYSER="${FACEFUSION_DIR}/facefusion/content_analyser.py"
if [ -f "${CONTENT_ANALYSER}" ]; then
    # Patch pre_check to skip NSFW model validation
    sed -i 's/def pre_check() -> bool:/def pre_check() -> bool:\n\treturn True  # NSFW check disabled/' "${CONTENT_ANALYSER}"
    # Patch analyse functions
    sed -i 's/def analyse_frame(vision_frame : VisionFrame) -> bool:/def analyse_frame(vision_frame : VisionFrame) -> bool:\n\treturn False  # NSFW check disabled/' "${CONTENT_ANALYSER}"
    sed -i 's/def analyse_image(image_path : str) -> bool:/def analyse_image(image_path : str) -> bool:\n\treturn False  # NSFW check disabled/' "${CONTENT_ANALYSER}"
    sed -i 's/def analyse_video(video_path : str, trim_frame_start : int, trim_frame_end : int) -> bool:/def analyse_video(video_path : str, trim_frame_start : int, trim_frame_end : int) -> bool:\n\treturn False  # NSFW check disabled/' "${CONTENT_ANALYSER}"
    sed -i 's/def analyse_stream(vision_frame : VisionFrame, video_fps : Fps) -> bool:/def analyse_stream(vision_frame : VisionFrame, video_fps : Fps) -> bool:\n\treturn False  # NSFW check disabled/' "${CONTENT_ANALYSER}"
    log_info "NSFW patch applied"
fi

log_info "FaceFusion installed"

# =============================================================================
# Create Helper Scripts
# =============================================================================

log_step "Creating helper scripts..."

# ComfyUI start script
cat > /usr/local/bin/comfy-start << 'SCRIPT'
#!/bin/bash
cd /workspace/comfyui
source /workspace/comfyui/venv/bin/activate 2>/dev/null || true
nohup python main.py --listen 0.0.0.0 --port 8188 > /workspace/comfyui.log 2>&1 &
echo "ComfyUI started on port 8188"
SCRIPT
chmod +x /usr/local/bin/comfy-start

# FaceFusion start script
cat > /usr/local/bin/ff-start << 'SCRIPT'
#!/bin/bash
cd /workspace/facefusion
source venv/bin/activate
nohup python facefusion.py run --ui-layouts default benchmark > /workspace/facefusion.log 2>&1 &
echo "FaceFusion started on port 7860"
SCRIPT
chmod +x /usr/local/bin/ff-start

# FaceFusion stop script
cat > /usr/local/bin/ff-stop << 'SCRIPT'
#!/bin/bash
pkill -f "facefusion.py" 2>/dev/null && echo "FaceFusion stopped" || echo "FaceFusion not running"
SCRIPT
chmod +x /usr/local/bin/ff-stop

# View logs
cat > /usr/local/bin/comfy << 'SCRIPT'
#!/bin/bash
tail -f /workspace/comfyui.log
SCRIPT
chmod +x /usr/local/bin/comfy

cat > /usr/local/bin/facefusion << 'SCRIPT'
#!/bin/bash
tail -f /workspace/facefusion.log
SCRIPT
chmod +x /usr/local/bin/facefusion

log_info "Helper scripts created"

# =============================================================================
# Start Services
# =============================================================================

log_step "Starting ComfyUI..."
cd "${COMFYUI_DIR}"
nohup python main.py --listen 0.0.0.0 --port 8188 > /workspace/comfyui.log 2>&1 &
sleep 3

# =============================================================================
# Done
# =============================================================================

echo
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Setup Complete!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo
echo -e "  ${CYAN}Services:${NC}"
echo -e "    ComfyUI:      http://localhost:8188  ${GREEN}[Running]${NC}"
echo -e "    FaceFusion:   http://localhost:7860  ${YELLOW}[Run: ff-start]${NC}"
echo
echo -e "  ${CYAN}Commands:${NC}"
echo -e "    comfy-start   Start ComfyUI"
echo -e "    ff-start      Start FaceFusion"
echo -e "    ff-stop       Stop FaceFusion"
echo -e "    comfy         View ComfyUI logs"
echo -e "    facefusion    View FaceFusion logs"
echo
echo -e "  ${CYAN}Paths:${NC}"
echo -e "    ComfyUI:      ${COMFYUI_DIR}"
echo -e "    FaceFusion:   ${FACEFUSION_DIR}"
echo -e "    Models:       ${COMFYUI_DIR}/models"
echo
