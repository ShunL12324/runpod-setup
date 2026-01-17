#!/bin/bash
# =============================================================================
# ComfyUI + FaceFusion One-Click Setup for RunPod
# =============================================================================

set -e

# =============================================================================
# Configuration
# =============================================================================
WORKSPACE="${WORKSPACE:-/workspace}"
COMFYUI_DIR="${WORKSPACE}/comfyui"
FACEFUSION_DIR="${WORKSPACE}/facefusion"
MODELS_DIR="${COMFYUI_DIR}/models"
LOGS_DIR="${WORKSPACE}/logs"

# =============================================================================
# Colors and Logging
# =============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step()  { echo -e "${CYAN}[STEP]${NC} $1"; }

# =============================================================================
# Utility Functions
# =============================================================================

# Cleanup on exit
cleanup() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo ""
        log_error "Setup failed with exit code: ${exit_code}"
        log_error "Check the output above for error details."
    fi
    rm -f /tmp/nsfw_patch.py 2>/dev/null
    exit $exit_code
}
trap cleanup EXIT

# Check disk space
check_disk_space() {
    local required_mb=$1
    local check_path="${2:-${WORKSPACE}}"
    local available_mb
    available_mb=$(df -BM "${check_path}" 2>/dev/null | awk 'NR==2 {print $4}' | tr -d 'M')

    if [ -z "${available_mb}" ]; then
        log_warn "Could not check disk space"
        return 0
    fi

    if [ "${available_mb}" -lt "${required_mb}" ]; then
        log_error "Insufficient disk space: ${available_mb}MB available, ${required_mb}MB required"
        return 1
    fi

    log_info "Disk space: ${available_mb}MB available (need ${required_mb}MB)"
    return 0
}

# Check GPU availability
check_gpu() {
    if ! command -v nvidia-smi &> /dev/null; then
        log_error "nvidia-smi not found. NVIDIA drivers may not be installed."
        return 1
    fi

    if ! nvidia-smi &> /dev/null; then
        log_error "nvidia-smi failed. GPU may not be accessible."
        return 1
    fi

    local gpu_name gpu_memory driver_version
    gpu_name=$(nvidia-smi --query-gpu=gpu_name --format=csv,noheader 2>/dev/null | head -n1)
    gpu_memory=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | head -n1)
    driver_version=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -n1)

    log_info "GPU: ${gpu_name} (${gpu_memory}MB VRAM)"
    log_info "Driver: ${driver_version}"
    return 0
}

# APT install with lock handling
apt_install() {
    local max_wait=300
    local waited=0

    while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
        if [ $waited -ge $max_wait ]; then
            log_error "Timed out waiting for apt lock"
            return 1
        fi
        log_warn "Waiting for apt lock..."
        sleep 5
        waited=$((waited + 5))
    done

    DEBIAN_FRONTEND=noninteractive apt-get "$@"
}

# Check if file exists with expected size (10% tolerance)
file_exists_with_size() {
    local file_path="$1"
    local expected_mb="$2"

    if [ ! -f "$file_path" ]; then
        return 1
    fi

    local actual_size expected_bytes tolerance_bytes
    actual_size=$(stat -c%s "$file_path" 2>/dev/null || echo "0")
    expected_bytes=$((expected_mb * 1024 * 1024))
    tolerance_bytes=$((expected_bytes / 10))

    if [ "$actual_size" -gt "$((expected_bytes - tolerance_bytes))" ]; then
        return 0
    fi

    return 1
}

# =============================================================================
# Main Setup
# =============================================================================

echo ""
echo -e "${CYAN}==========================================${NC}"
echo -e "${CYAN}  ComfyUI + FaceFusion Setup${NC}"
echo -e "${CYAN}==========================================${NC}"
echo ""

cd "${WORKSPACE}" || exit 1
mkdir -p "${LOGS_DIR}"

# =============================================================================
# Pre-flight Checks
# =============================================================================
log_step "Running pre-flight checks..."

if ! check_gpu; then
    log_error "GPU check failed. This setup requires NVIDIA GPU."
    exit 1
fi

# Check for ~65GB free space (models + installations)
if ! check_disk_space 65000; then
    log_error "Please free up disk space before continuing."
    exit 1
fi

log_info "Pre-flight checks passed"

# =============================================================================
# [1/8] System Dependencies
# =============================================================================
log_step "[1/8] Installing system dependencies..."

apt_install update -qq
apt_install install -y -qq --no-install-recommends \
    git curl wget vim htop tmux screen aria2 ffmpeg zsh bc \
    libsm6 libxext6 2>/dev/null

# Try alternative packages for compatibility
apt_install install -y -qq libgl1 2>/dev/null || apt_install install -y -qq libgl1-mesa-glx 2>/dev/null || true
apt_install install -y -qq libglib2.0-0t64 2>/dev/null || apt_install install -y -qq libglib2.0-0 2>/dev/null || true

# Install zsh-autosuggestions if available
apt_install install -y -qq zsh-autosuggestions 2>/dev/null || true

log_info "System dependencies installed"

# =============================================================================
# [2/8] UV Package Manager
# =============================================================================
log_step "[2/8] Installing uv package manager..."

if ! command -v uv &> /dev/null; then
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="/root/.local/bin:$PATH"

    if ! command -v uv &> /dev/null; then
        log_error "uv installation failed"
        exit 1
    fi

    # Add to shell profiles for persistence
    for profile in ~/.bashrc ~/.zshrc ~/.profile; do
        if [ -f "$profile" ] && ! grep -q '/root/.local/bin' "$profile" 2>/dev/null; then
            echo 'export PATH="/root/.local/bin:$PATH"' >> "$profile"
        fi
    done
fi

log_info "uv version: $(uv --version)"

# =============================================================================
# [3/8] ComfyUI
# =============================================================================
log_step "[3/8] Setting up ComfyUI..."

if [ ! -d "${COMFYUI_DIR}" ]; then
    log_info "Cloning ComfyUI..."
    git clone --depth 1 https://github.com/comfyanonymous/ComfyUI.git "${COMFYUI_DIR}"
else
    log_info "ComfyUI directory exists, skipping clone"
fi

cd "${COMFYUI_DIR}"

NEED_COMFYUI_INSTALL=false
if [ ! -d "venv" ]; then
    NEED_COMFYUI_INSTALL=true
    log_info "Creating new virtual environment..."
elif ! venv/bin/python -c "import torch; assert torch.cuda.is_available()" 2>/dev/null; then
    NEED_COMFYUI_INSTALL=true
    log_warn "PyTorch CUDA not working, reinstalling..."
fi

if [ "$NEED_COMFYUI_INSTALL" = true ]; then
    rm -rf venv
    uv venv venv
    source venv/bin/activate
    uv pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128
    uv pip install -r requirements.txt
    deactivate
    log_info "ComfyUI dependencies installed"
else
    log_info "ComfyUI venv already configured"
fi

# =============================================================================
# [4/8] ComfyUI Custom Nodes
# =============================================================================
log_step "[4/8] Setting up ComfyUI custom nodes..."

mkdir -p "${COMFYUI_DIR}/custom_nodes"
cd "${COMFYUI_DIR}/custom_nodes"

clone_node() {
    local name="$1"
    local url="$2"
    if [ ! -d "${name}" ]; then
        log_info "Cloning ${name}..."
        git clone --depth 1 "${url}" "${name}"
    else
        log_info "${name} already exists"
    fi
}

clone_node "ComfyUI-Manager" "https://github.com/ltdrdata/ComfyUI-Manager.git"
clone_node "comfy-portal-endpoint" "https://github.com/ShunL12324/comfy-portal-endpoint.git"
clone_node "ComfyUI-Model-Manager" "https://github.com/hayden-fr/ComfyUI-Model-Manager.git"

log_info "Custom nodes ready"

# =============================================================================
# [5/8] FaceFusion
# =============================================================================
log_step "[5/8] Setting up FaceFusion..."

if [ ! -d "${FACEFUSION_DIR}" ]; then
    cd "${WORKSPACE}"
    log_info "Cloning FaceFusion..."
    git clone --depth 1 https://github.com/facefusion/facefusion.git "${FACEFUSION_DIR}"
else
    log_info "FaceFusion directory exists, skipping clone"
fi

cd "${FACEFUSION_DIR}"

NEED_FF_INSTALL=false
if [ ! -d "venv" ]; then
    NEED_FF_INSTALL=true
    log_info "Creating new virtual environment..."
elif ! venv/bin/python -c "import onnxruntime; import cv2; import torch; assert torch.cuda.is_available()" 2>/dev/null; then
    NEED_FF_INSTALL=true
    log_warn "FaceFusion dependencies incomplete, reinstalling..."
fi

if [ "$NEED_FF_INSTALL" = true ]; then
    rm -rf venv
    uv venv venv
    source venv/bin/activate
    uv pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128
    uv pip install -r requirements.txt
    uv pip install onnxruntime-gpu
    uv pip uninstall opencv-python -y 2>/dev/null || true
    uv pip install opencv-python-headless
    deactivate
    log_info "FaceFusion dependencies installed"
else
    log_info "FaceFusion venv already configured"
fi

# =============================================================================
# [6/8] NSFW Patch
# =============================================================================
log_step "[6/8] Applying NSFW patch..."

CONTENT_ANALYSER="${FACEFUSION_DIR}/facefusion/content_analyser.py"

if [ -f "${CONTENT_ANALYSER}" ] && grep -q "# NSFW check disabled" "${CONTENT_ANALYSER}" 2>/dev/null; then
    log_info "NSFW patch already applied"
else
    # Embedded Python patch script for robustness
    cat > /tmp/nsfw_patch.py << 'PATCH_EOF'
#!/usr/bin/env python3
import sys
import re
from pathlib import Path

def patch_content_analyser(file_path):
    if not file_path.exists():
        print(f"File not found: {file_path}")
        return False

    content = file_path.read_text()

    # Add early return to pre_check
    content = re.sub(
        r'(def pre_check\(\) -> bool:)\n(\s)',
        r'\1\n    return True  # NSFW check disabled\n\2',
        content
    )

    # Add early return to analyse_frame
    content = re.sub(
        r'(def analyse_frame\(vision_frame\s*:\s*VisionFrame\) -> bool:)\n(\s)',
        r'\1\n    return False  # NSFW check disabled\n\2',
        content
    )

    # Add early return to analyse_image
    content = re.sub(
        r'(def analyse_image\(image_path\s*:\s*str\) -> bool:)\n(\s)',
        r'\1\n    return False  # NSFW check disabled\n\2',
        content
    )

    # Add early return to analyse_video
    content = re.sub(
        r'(def analyse_video\([^)]+\) -> bool:)\n(\s)',
        r'\1\n    return False  # NSFW check disabled\n\2',
        content
    )

    # Add early return to analyse_stream
    content = re.sub(
        r'(def analyse_stream\([^)]+\) -> bool:)\n(\s)',
        r'\1\n    return False  # NSFW check disabled\n\2',
        content
    )

    file_path.write_text(content)
    print(f"Patched: {file_path}")
    return True

def patch_core(file_path):
    if not file_path.exists():
        print(f"File not found: {file_path}")
        return False

    content = file_path.read_text()

    # Remove hash check with flexible pattern
    content = re.sub(
        r"return all\(module\.pre_check\(\) for module in common_modules\) and content_analyser_hash == '[^']+'",
        "return all(module.pre_check() for module in common_modules)  # Hash check disabled",
        content
    )

    file_path.write_text(content)
    print(f"Patched: {file_path}")
    return True

if __name__ == "__main__":
    facefusion_dir = Path(sys.argv[1])
    patch_content_analyser(facefusion_dir / "facefusion" / "content_analyser.py")
    patch_core(facefusion_dir / "facefusion" / "core.py")
PATCH_EOF

    python3 /tmp/nsfw_patch.py "${FACEFUSION_DIR}"
    rm -f /tmp/nsfw_patch.py
    log_info "NSFW patch applied"
fi

# =============================================================================
# [7/8] Model Downloads
# =============================================================================
log_step "[7/8] Downloading models..."

mkdir -p "${MODELS_DIR}"/{checkpoints,clip,clip_vision,configs,controlnet,embeddings,loras,unet,upscale_models,vae}

# Model definitions: name|size_mb|subdir|url
MODELS=(
    "wan_2.1_vae.safetensors|243|vae|https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors"
    "wan2.2-rapid-mega-nsfw-aio-v3.1.safetensors|23552|checkpoints|https://huggingface.co/Phr00t/WAN2.2-14B-Rapid-AllInOne/resolve/main/Mega-v3/wan2.2-rapid-mega-nsfw-aio-v3.1.safetensors"
    "nsfw_wan_umt5-xxl_fp8_scaled.safetensors|6451|clip|https://huggingface.co/NSFW-API/NSFW-Wan-UMT5-XXL/resolve/main/nsfw_wan_umt5-xxl_fp8_scaled.safetensors"
    "clip-vision_vit-h.safetensors|2458|clip_vision|https://huggingface.co/hfmaster/models-moved/resolve/8b8d4cae76158cd49410d058971bb0e591966e04/sdxl/ipadapter/clip-vision_vit-h.safetensors"
    "Wan2.2_Remix_NSFW_i2v_14b_high_lighting_fp8_e4m3fn_v2.1.safetensors|14336|unet|https://huggingface.co/FX-FeiHou/wan2.2-Remix/resolve/main/NSFW/Wan2.2_Remix_NSFW_i2v_14b_high_lighting_fp8_e4m3fn_v2.1.safetensors"
    "Wan2.2_Remix_NSFW_i2v_14b_low_lighting_fp8_e4m3fn_v2.1.safetensors|14336|unet|https://huggingface.co/FX-FeiHou/wan2.2-Remix/resolve/main/NSFW/Wan2.2_Remix_NSFW_i2v_14b_low_lighting_fp8_e4m3fn_v2.1.safetensors"
)

DOWNLOAD_COUNT=0
SKIP_COUNT=0
FAIL_COUNT=0

for model_def in "${MODELS[@]}"; do
    IFS='|' read -r name size_mb subdir url <<< "${model_def}"
    output_path="${MODELS_DIR}/${subdir}/${name}"

    # Check if file exists with proper size
    if file_exists_with_size "${output_path}" "${size_mb}"; then
        log_info "Skipping ${name} (already exists)"
        ((SKIP_COUNT++))
        continue
    fi

    # Format size for display
    if [ "${size_mb}" -gt 1024 ]; then
        size_str="$(echo "scale=1; ${size_mb}/1024" | bc)GB"
    else
        size_str="${size_mb}MB"
    fi

    log_info "Downloading ${name} (${size_str})..."
    mkdir -p "${MODELS_DIR}/${subdir}"

    if aria2c -x 16 -s 16 -k 1M -c \
        --max-tries=10 --retry-wait=5 --timeout=120 --connect-timeout=30 \
        --console-log-level=notice --summary-interval=30 \
        -d "${MODELS_DIR}/${subdir}" -o "${name}" \
        "${url}"; then
        ((DOWNLOAD_COUNT++))
        log_info "Downloaded ${name}"
    else
        log_error "Failed to download ${name}"
        ((FAIL_COUNT++))
    fi
done

log_info "Downloads: ${DOWNLOAD_COUNT} completed, ${SKIP_COUNT} skipped, ${FAIL_COUNT} failed"

if [ "${FAIL_COUNT}" -gt 0 ]; then
    log_warn "Some downloads failed. You can retry by running this script again."
fi

# =============================================================================
# [8/8] Helper Scripts & Shell Config
# =============================================================================
log_step "[8/8] Setting up helper scripts..."

# ComfyUI start script
cat > /usr/local/bin/comfy-start << 'EOF'
#!/bin/bash
COMFYUI_DIR="${COMFYUI_DIR:-/workspace/comfyui}"
LOG_FILE="${WORKSPACE:-/workspace}/logs/comfyui.log"
mkdir -p "$(dirname "${LOG_FILE}")"

if tmux has-session -t comfyui 2>/dev/null; then
    echo -e "\033[1;33m[WARN]\033[0m ComfyUI already running"
    echo "Use 'comfy' to view logs or 'comfy-restart' to restart"
    exit 0
fi

tmux kill-session -t comfyui 2>/dev/null || true

if tmux new-session -d -s comfyui; then
    tmux send-keys -t comfyui "cd ${COMFYUI_DIR}" C-m
    tmux send-keys -t comfyui "source venv/bin/activate" C-m
    tmux send-keys -t comfyui "python main.py --listen 0.0.0.0 --port 8188 2>&1 | tee ${LOG_FILE}" C-m
    sleep 2
    if tmux has-session -t comfyui 2>/dev/null; then
        echo -e "\033[0;32m[INFO]\033[0m ComfyUI started on port 8188"
        echo -e "\033[0;32m[INFO]\033[0m Logs: ${LOG_FILE}"
    else
        echo -e "\033[0;31m[ERROR]\033[0m ComfyUI failed to start"
        exit 1
    fi
else
    echo -e "\033[0;31m[ERROR]\033[0m Failed to create tmux session"
    exit 1
fi
EOF
chmod +x /usr/local/bin/comfy-start

# ComfyUI stop script
cat > /usr/local/bin/comfy-stop << 'EOF'
#!/bin/bash
if tmux kill-session -t comfyui 2>/dev/null; then
    echo -e "\033[0;32m[INFO]\033[0m ComfyUI stopped"
else
    echo -e "\033[1;33m[WARN]\033[0m ComfyUI was not running"
fi
EOF
chmod +x /usr/local/bin/comfy-stop

# ComfyUI restart script
cat > /usr/local/bin/comfy-restart << 'EOF'
#!/bin/bash
/usr/local/bin/comfy-stop
sleep 1
/usr/local/bin/comfy-start
EOF
chmod +x /usr/local/bin/comfy-restart

# FaceFusion start script (default Gradio port 7860)
cat > /usr/local/bin/ff-start << 'EOF'
#!/bin/bash
FACEFUSION_DIR="${FACEFUSION_DIR:-/workspace/facefusion}"
LOG_FILE="${WORKSPACE:-/workspace}/logs/facefusion.log"
mkdir -p "$(dirname "${LOG_FILE}")"

# Determine thread count (cap at 32)
THREAD_COUNT="${RUNPOD_CPU_COUNT:-$(nproc)}"
if [ "${THREAD_COUNT}" -gt 32 ]; then
    THREAD_COUNT=32
fi

if tmux has-session -t facefusion 2>/dev/null; then
    echo -e "\033[1;33m[WARN]\033[0m FaceFusion already running"
    echo "Use 'ff' to view logs or 'ff-restart' to restart"
    exit 0
fi

tmux kill-session -t facefusion 2>/dev/null || true

if tmux new-session -d -s facefusion; then
    tmux send-keys -t facefusion "cd ${FACEFUSION_DIR}" C-m
    tmux send-keys -t facefusion "source venv/bin/activate" C-m
    tmux send-keys -t facefusion "GRADIO_SERVER_NAME=0.0.0.0 python facefusion.py run --execution-thread-count ${THREAD_COUNT} --execution-providers cuda 2>&1 | tee ${LOG_FILE}" C-m
    sleep 3
    if tmux has-session -t facefusion 2>/dev/null; then
        echo -e "\033[0;32m[INFO]\033[0m FaceFusion started on port 7860"
        echo -e "\033[0;32m[INFO]\033[0m Thread count: ${THREAD_COUNT}"
        echo -e "\033[0;32m[INFO]\033[0m Logs: ${LOG_FILE}"
    else
        echo -e "\033[0;31m[ERROR]\033[0m FaceFusion failed to start"
        exit 1
    fi
else
    echo -e "\033[0;31m[ERROR]\033[0m Failed to create tmux session"
    exit 1
fi
EOF
chmod +x /usr/local/bin/ff-start

# FaceFusion stop script
cat > /usr/local/bin/ff-stop << 'EOF'
#!/bin/bash
if tmux kill-session -t facefusion 2>/dev/null; then
    echo -e "\033[0;32m[INFO]\033[0m FaceFusion stopped"
else
    echo -e "\033[1;33m[WARN]\033[0m FaceFusion was not running"
fi
EOF
chmod +x /usr/local/bin/ff-stop

# FaceFusion restart script
cat > /usr/local/bin/ff-restart << 'EOF'
#!/bin/bash
/usr/local/bin/ff-stop
sleep 1
/usr/local/bin/ff-start
EOF
chmod +x /usr/local/bin/ff-restart

# Status command
cat > /usr/local/bin/status << 'EOF'
#!/bin/bash
echo ""
echo "Service Status:"
echo "---------------------------------------------"
if tmux has-session -t comfyui 2>/dev/null; then
    echo -e "  ComfyUI:     \033[0;32m● Running\033[0m (port 8188)"
else
    echo -e "  ComfyUI:     \033[0;31m○ Stopped\033[0m"
fi
if tmux has-session -t facefusion 2>/dev/null; then
    echo -e "  FaceFusion:  \033[0;32m● Running\033[0m (port 7860)"
else
    echo -e "  FaceFusion:  \033[0;31m○ Stopped\033[0m"
fi
echo "---------------------------------------------"
EOF
chmod +x /usr/local/bin/status

# GPU command
cat > /usr/local/bin/gpu << 'EOF'
#!/bin/bash
nvidia-smi
EOF
chmod +x /usr/local/bin/gpu

# GPU memory command
cat > /usr/local/bin/gpu-mem << 'EOF'
#!/bin/bash
nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader,nounits | \
awk '{printf "GPU Memory: %d MB / %d MB (%.1f%%)\n", $1, $2, $1/$2*100}'
EOF
chmod +x /usr/local/bin/gpu-mem

# Bash fallback to zsh
if ! grep -q "# Auto switch to zsh" ~/.bashrc 2>/dev/null; then
    cat >> ~/.bashrc << 'BASHRC_EOF'

# Auto switch to zsh
if [ -z "$ZSH_VERSION" ] && command -v zsh &> /dev/null; then
    exec zsh
fi
BASHRC_EOF
fi

# Shell config
if ! grep -q "# ComfyUI+FaceFusion Setup" ~/.zshrc 2>/dev/null; then
    cat >> ~/.zshrc << 'ZSHRC_EOF'

# ComfyUI+FaceFusion Setup
export PATH="/root/.local/bin:$PATH"
source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh 2>/dev/null

# Tmux session aliases
alias comfy="tmux attach -t comfyui"
alias ff="tmux attach -t facefusion"

# Log viewing
alias comfy-logs="tail -f ${WORKSPACE:-/workspace}/logs/comfyui.log"
alias ff-logs="tail -f ${WORKSPACE:-/workspace}/logs/facefusion.log"

# Navigation
alias cdw="cd ${WORKSPACE:-/workspace}"
alias cdc="cd ${WORKSPACE:-/workspace}/comfyui"
alias cdf="cd ${WORKSPACE:-/workspace}/facefusion"
alias cdm="cd ${WORKSPACE:-/workspace}/comfyui/models"

# GPU monitoring
alias gpu="nvidia-smi"
alias gpuw="watch -n 1 nvidia-smi"

gpu-mem() {
    nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader,nounits | \
    awk '{printf "GPU Memory: %d MB / %d MB (%.1f%%)\n", $1, $2, $1/$2*100}'
}

# Service status
status() {
    echo ""
    echo "Service Status:"
    echo "---------------------------------------------"
    if tmux has-session -t comfyui 2>/dev/null; then
        echo -e "  ComfyUI:     \033[0;32m● Running\033[0m (port 8188)"
    else
        echo -e "  ComfyUI:     \033[0;31m○ Stopped\033[0m"
    fi
    if tmux has-session -t facefusion 2>/dev/null; then
        echo -e "  FaceFusion:  \033[0;32m● Running\033[0m (port 7860)"
    else
        echo -e "  FaceFusion:  \033[0;31m○ Stopped\033[0m"
    fi
    echo "---------------------------------------------"
}

echo ""
echo "=========================================="
echo "  ComfyUI + FaceFusion Ready"
echo "=========================================="
echo ""
echo "Commands:"
echo "  comfy-start / comfy-stop / comfy-restart / comfy"
echo "  ff-start    / ff-stop    / ff-restart    / ff"
echo "  status      / gpu        / gpu-mem"
echo ""
echo "Ports: ComfyUI=8188, FaceFusion=7860"
echo ""
status
ZSHRC_EOF
fi

chsh -s "$(which zsh)" 2>/dev/null || true

log_info "Helper scripts installed"

# =============================================================================
# Complete
# =============================================================================
echo ""
echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN}  Setup Complete!${NC}"
echo -e "${GREEN}==========================================${NC}"
echo ""
echo "Commands:"
echo "  comfy-start / comfy-stop / comfy-restart / comfy"
echo "  ff-start    / ff-stop    / ff-restart    / ff"
echo "  status      / gpu        / gpu-mem"
echo ""
echo "Ports: ComfyUI=8188, FaceFusion=7860"
echo ""
