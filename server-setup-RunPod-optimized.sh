#!/bin/bash

set -euo pipefail

# =============================================================================
# ComfyUI Optimized Installation Script for RunPod
# Includes automatic model downloads with parallel downloading via aria2c
# =============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${CYAN}[STEP]${NC} ${BOLD}$1${NC}"; }

# Error handling
handle_error() {
    log_error "An error occurred on line $1"
    exit 1
}
trap 'handle_error $LINENO' ERR

# =============================================================================
# Configuration
# =============================================================================

WORKSPACE="/workspace"
COMFYUI_DIR="${WORKSPACE}/ComfyUI"
MODELS_DIR="${COMFYUI_DIR}/models"

# Model definitions: name|size_mb|subdir|url
MODELS=(
    "wan_2.1_vae.safetensors|243|vae|https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors"
    "Wan2.2_Remix_NSFW_i2v_14b_high_lighting_fp8_e4m3fn_v2.1.safetensors|14336|unet|https://huggingface.co/FX-FeiHou/wan2.2-Remix/resolve/main/NSFW/Wan2.2_Remix_NSFW_i2v_14b_high_lighting_fp8_e4m3fn_v2.1.safetensors"
    "Wan2.2_Remix_NSFW_i2v_14b_low_lighting_fp8_e4m3fn_v2.1.safetensors|14336|unet|https://huggingface.co/FX-FeiHou/wan2.2-Remix/resolve/main/NSFW/Wan2.2_Remix_NSFW_i2v_14b_low_lighting_fp8_e4m3fn_v2.1.safetensors"
    "wan2.2-rapid-mega-nsfw-aio-v3.1.safetensors|23552|checkpoints|https://huggingface.co/Phr00t/WAN2.2-14B-Rapid-AllInOne/resolve/main/Mega-v3/wan2.2-rapid-mega-nsfw-aio-v3.1.safetensors"
    "nsfw_wan_umt5-xxl_fp8_scaled.safetensors|6451|clip|https://huggingface.co/NSFW-API/NSFW-Wan-UMT5-XXL/resolve/main/nsfw_wan_umt5-xxl_fp8_scaled.safetensors"
    "clip-vision_vit-h.safetensors|2458|clip_vision|https://huggingface.co/hfmaster/models-moved/resolve/8b8d4cae76158cd49410d058971bb0e591966e04/sdxl/ipadapter/clip-vision_vit-h.safetensors"
)

REQUIRED_SPACE_GB=70
DOWNLOAD_PIDS=()
DOWNLOAD_RESULTS=()

# =============================================================================
# Help message
# =============================================================================

show_help() {
    cat << EOF
${BOLD}ComfyUI Optimized Setup Script for RunPod${NC}

Usage: $0 [OPTIONS]

Options:
  --skip-models        Skip model downloads (only install ComfyUI)
  --models-only        Only download models (skip ComfyUI installation)
  --no-model-manager   Skip ComfyUI Model Manager installation
  --help               Show this help message

Models Downloaded (~60GB total):
  - VAE: wan_2.1_vae.safetensors (243 MB)
  - UNet High Lighting: 14 GB
  - UNet Low Lighting: 14 GB
  - Checkpoint AIO: 23 GB
  - CLIP Text Encoder: 6.3 GB
  - CLIP Vision: 2.4 GB

Examples:
  sudo $0                    # Full installation with models
  sudo $0 --skip-models      # Install ComfyUI only, no models
  sudo $0 --models-only      # Download models to existing installation
EOF
}

# =============================================================================
# Pre-flight checks
# =============================================================================

check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "Please run as root (use sudo)"
        exit 1
    fi
}

check_runpod() {
    if [ ! -d "${WORKSPACE}" ]; then
        log_error "This script is designed for RunPod environment (/workspace not found)"
        exit 1
    fi
}

check_gpu() {
    log_step "Checking GPU availability..."
    if command -v nvidia-smi &> /dev/null; then
        GPU_INFO=$(nvidia-smi --query-gpu=name,memory.total --format=csv,noheader,nounits 2>/dev/null || echo "Unknown")
        log_info "GPU detected: ${GPU_INFO}"
    else
        log_warn "nvidia-smi not found - GPU may not be available"
        log_warn "ComfyUI will run but may be slow without GPU acceleration"
    fi
}

check_disk_space() {
    log_step "Checking disk space..."
    AVAILABLE_GB=$(df -BG "${WORKSPACE}" | awk 'NR==2 {print $4}' | tr -d 'G')

    if [ "${AVAILABLE_GB}" -lt "${REQUIRED_SPACE_GB}" ]; then
        log_error "Insufficient disk space: ${AVAILABLE_GB}GB available, ${REQUIRED_SPACE_GB}GB required"
        log_error "Use --skip-models to install without downloading models"
        exit 1
    fi
    log_info "Disk space OK: ${AVAILABLE_GB}GB available (${REQUIRED_SPACE_GB}GB required)"
}

# =============================================================================
# System setup
# =============================================================================

install_system_packages() {
    log_step "Updating system and installing packages..."
    export DEBIAN_FRONTEND=noninteractive

    apt-get update -qq
    apt-get upgrade -y -qq
    apt-get install -y -qq git zsh tmux python3-venv aria2

    log_info "System packages installed successfully"
}

# =============================================================================
# ComfyUI installation
# =============================================================================

install_comfyui() {
    log_step "Installing ComfyUI..."
    cd "${WORKSPACE}"

    if [ ! -d "ComfyUI" ]; then
        git clone --depth 1 https://github.com/comfyanonymous/ComfyUI.git
        log_info "ComfyUI cloned successfully"
    else
        log_warn "ComfyUI directory exists, skipping clone"
    fi

    cd "${COMFYUI_DIR}"

    # Setup virtual environment
    if [ ! -d "venv" ]; then
        log_info "Creating Python virtual environment..."
        python3 -m venv venv
    fi

    source venv/bin/activate

    # Upgrade pip first
    log_info "Upgrading pip..."
    pip install --quiet --upgrade pip

    # Install requirements
    log_info "Installing ComfyUI dependencies..."
    pip install --quiet --no-cache-dir -r requirements.txt

    log_info "ComfyUI installed successfully"
}

install_custom_nodes() {
    log_step "Installing custom nodes..."
    cd "${COMFYUI_DIR}"
    mkdir -p custom_nodes

    # ComfyUI Manager
    if [ ! -d "custom_nodes/ComfyUI-Manager" ]; then
        git clone --depth 1 https://github.com/ltdrdata/ComfyUI-Manager.git custom_nodes/ComfyUI-Manager
        log_info "ComfyUI Manager installed"
    else
        log_warn "ComfyUI Manager already installed"
    fi

    # Comfy Portal Endpoint
    if [ ! -d "custom_nodes/comfy-portal-endpoint" ]; then
        git clone --depth 1 https://github.com/ShunL12324/comfy-portal-endpoint.git custom_nodes/comfy-portal-endpoint
        log_info "Comfy Portal Endpoint installed"
    else
        log_warn "Comfy Portal Endpoint already installed"
    fi

    # Model Manager (optional)
    if [ "${INSTALL_MODEL_MANAGER}" = true ]; then
        if [ ! -d "custom_nodes/ComfyUI-Model-Manager" ]; then
            git clone --depth 1 https://github.com/hayden-fr/ComfyUI-Model-Manager.git custom_nodes/ComfyUI-Model-Manager
            log_info "ComfyUI Model Manager installed"
        else
            log_warn "ComfyUI Model Manager already installed"
        fi
    fi
}

# =============================================================================
# Model downloads
# =============================================================================

create_model_directories() {
    log_step "Creating model directories..."
    mkdir -p "${MODELS_DIR}"/{vae,unet,checkpoints,clip,clip_vision,configs,embeddings,loras,upscale_models}
    log_info "Model directories created"
}

download_model() {
    local name="$1"
    local size_mb="$2"
    local subdir="$3"
    local url="$4"
    local output_path="${MODELS_DIR}/${subdir}/${name}"

    # Skip if already exists and has reasonable size
    if [ -f "${output_path}" ]; then
        local existing_size=$(stat -c%s "${output_path}" 2>/dev/null || echo "0")
        local expected_bytes=$((size_mb * 1024 * 1024))
        local tolerance=$((expected_bytes / 10)) # 10% tolerance

        if [ "${existing_size}" -gt "$((expected_bytes - tolerance))" ]; then
            log_info "Skipping ${name} (already exists)"
            echo "SKIP:${name}" >> /tmp/download_results.txt
            return 0
        fi
    fi

    log_info "Downloading ${name} (${size_mb}MB)..."

    # Use aria2c for fast, resumable downloads
    if aria2c -x 16 -s 16 -k 1M -c \
        --console-log-level=warn \
        --summary-interval=0 \
        --dir="${MODELS_DIR}/${subdir}" \
        --out="${name}" \
        "${url}" 2>/dev/null; then
        log_info "Downloaded ${name}"
        echo "OK:${name}" >> /tmp/download_results.txt
    else
        log_error "Failed to download ${name}"
        echo "FAIL:${name}" >> /tmp/download_results.txt
    fi
}

download_all_models() {
    log_step "Starting parallel model downloads (~60GB)..."
    log_info "This may take 10-20 minutes depending on network speed"
    echo

    # Clear results file
    > /tmp/download_results.txt

    # Start all downloads in parallel
    for model_def in "${MODELS[@]}"; do
        IFS='|' read -r name size subdir url <<< "${model_def}"
        download_model "${name}" "${size}" "${subdir}" "${url}" &
        DOWNLOAD_PIDS+=($!)
    done

    # Wait for all downloads to complete
    log_info "Waiting for ${#DOWNLOAD_PIDS[@]} downloads to complete..."

    local failed=0
    for pid in "${DOWNLOAD_PIDS[@]}"; do
        if ! wait "${pid}"; then
            ((failed++))
        fi
    done

    # Show summary
    echo
    log_step "Download Summary"
    echo "─────────────────────────────────────────"

    local ok_count=0
    local skip_count=0
    local fail_count=0

    while IFS= read -r line; do
        local status="${line%%:*}"
        local name="${line#*:}"
        case "${status}" in
            OK)
                echo -e "  ${GREEN}✓${NC} ${name}"
                ((ok_count++))
                ;;
            SKIP)
                echo -e "  ${YELLOW}○${NC} ${name} (skipped - exists)"
                ((skip_count++))
                ;;
            FAIL)
                echo -e "  ${RED}✗${NC} ${name}"
                ((fail_count++))
                ;;
        esac
    done < /tmp/download_results.txt

    echo "─────────────────────────────────────────"
    echo -e "  Downloaded: ${GREEN}${ok_count}${NC} | Skipped: ${YELLOW}${skip_count}${NC} | Failed: ${RED}${fail_count}${NC}"

    if [ "${fail_count}" -gt 0 ]; then
        log_warn "Some downloads failed. You can re-run with --models-only to retry"
    fi

    rm -f /tmp/download_results.txt
}

# =============================================================================
# Launch ComfyUI
# =============================================================================

launch_comfyui() {
    log_step "Starting ComfyUI..."

    # Kill existing session
    tmux kill-session -t comfyui 2>/dev/null || true

    if tmux new-session -d -s comfyui; then
        tmux send-keys -t comfyui "cd ${COMFYUI_DIR}" C-m
        tmux send-keys -t comfyui "source venv/bin/activate" C-m
        tmux send-keys -t comfyui "python main.py --listen 0.0.0.0 --port 8188 --front-end-version Comfy-Org/ComfyUI_frontend@latest" C-m

        sleep 3

        if tmux has-session -t comfyui 2>/dev/null; then
            echo
            echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
            echo -e "${GREEN}  ComfyUI is now running!${NC}"
            echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
            echo
            echo -e "  ${BOLD}Access:${NC}        http://localhost:8188"
            echo -e "  ${BOLD}View logs:${NC}     tmux attach -t comfyui"
            echo -e "  ${BOLD}Detach:${NC}        Ctrl+B, then D"
            echo -e "  ${BOLD}Stop server:${NC}   tmux kill-session -t comfyui"
            echo
        else
            log_warn "tmux session may have crashed"
            show_manual_instructions
        fi
    else
        log_warn "Failed to start tmux session"
        show_manual_instructions
    fi
}

show_manual_instructions() {
    echo
    echo -e "${YELLOW}=== Manual Start Instructions ===${NC}"
    echo -e "  cd ${COMFYUI_DIR}"
    echo -e "  source venv/bin/activate"
    echo -e "  python main.py --listen 0.0.0.0 --port 8188 --front-end-version Comfy-Org/ComfyUI_frontend@latest"
    echo
}

# =============================================================================
# Main
# =============================================================================

# Parse arguments
SKIP_MODELS=false
MODELS_ONLY=false
INSTALL_MODEL_MANAGER=true

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-models)
            SKIP_MODELS=true
            shift
            ;;
        --models-only)
            MODELS_ONLY=true
            shift
            ;;
        --no-model-manager)
            INSTALL_MODEL_MANAGER=false
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            log_error "Unknown argument: $1"
            show_help
            exit 1
            ;;
    esac
done

# Main execution
main() {
    echo
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  ${BOLD}ComfyUI Optimized Setup Script for RunPod${NC}${BLUE}                ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo

    # Pre-flight checks
    check_root
    check_runpod
    check_gpu

    if [ "${MODELS_ONLY}" = true ]; then
        # Models only mode
        log_info "Running in models-only mode"
        if [ ! -d "${COMFYUI_DIR}" ]; then
            log_error "ComfyUI not found. Run without --models-only first"
            exit 1
        fi
        check_disk_space
        create_model_directories
        download_all_models
        log_info "Model download complete!"
        exit 0
    fi

    # Show plan
    echo -e "${BOLD}Installation Plan:${NC}"
    echo -e "  1. Install system packages (git, tmux, aria2, etc.)"
    echo -e "  2. Clone and setup ComfyUI"
    echo -e "  3. Install custom nodes"
    if [ "${SKIP_MODELS}" = false ]; then
        echo -e "  4. Download models (~60GB)"
    else
        echo -e "  4. ${YELLOW}Skip model downloads${NC}"
    fi
    echo -e "  5. Launch ComfyUI in tmux"
    echo

    if [ "${SKIP_MODELS}" = false ]; then
        check_disk_space
    fi

    # Confirm
    read -p "Proceed with installation? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Installation cancelled"
        exit 0
    fi

    echo

    # Install
    install_system_packages
    install_comfyui
    install_custom_nodes

    if [ "${SKIP_MODELS}" = false ]; then
        create_model_directories
        download_all_models
    fi

    launch_comfyui

    echo
    log_info "Installation complete!"
}

main
