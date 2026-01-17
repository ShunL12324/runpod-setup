#!/bin/bash

# =============================================================================
# Main Startup Script for ComfyUI + FaceFusion
# =============================================================================
# Environment Variables:
#   SKIP_MODEL_DOWNLOAD=true  - Skip automatic model download
#   MINIMAL_MODELS=true       - Only download essential models (~30GB)
#   ENABLE_FACEFUSION=true    - Auto-start FaceFusion (default: manual)
# =============================================================================

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_step() { echo -e "${CYAN}[STEP]${NC} $1"; }

echo
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  ComfyUI + FaceFusion for RunPod                           ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo

# =============================================================================
# Setup Persistent Storage
# =============================================================================

log_step "Setting up persistent storage..."

WORKSPACE=${WORKSPACE:-/workspace}
COMFYUI_DIR=${COMFYUI_DIR:-/comfyui}
FACEFUSION_DIR=${FACEFUSION_DIR:-/facefusion}

# Create workspace directories
mkdir -p "${WORKSPACE}/comfyui-models"/{checkpoints,clip,clip_vision,configs,controlnet,embeddings,loras,unet,upscale_models,vae}
mkdir -p "${WORKSPACE}/comfyui-output"
mkdir -p "${WORKSPACE}/facefusion-output"
mkdir -p "${WORKSPACE}/logs"

# Symlink ComfyUI models to workspace
if [ -L "${COMFYUI_DIR}/models" ]; then
    log_info "ComfyUI models symlink exists"
elif [ -d "${COMFYUI_DIR}/models" ]; then
    rm -rf "${COMFYUI_DIR}/models"
    ln -s "${WORKSPACE}/comfyui-models" "${COMFYUI_DIR}/models"
    log_info "ComfyUI models linked to ${WORKSPACE}/comfyui-models"
else
    ln -s "${WORKSPACE}/comfyui-models" "${COMFYUI_DIR}/models"
    log_info "ComfyUI models linked to ${WORKSPACE}/comfyui-models"
fi

# Symlink ComfyUI output to workspace
if [ -L "${COMFYUI_DIR}/output" ]; then
    log_info "ComfyUI output symlink exists"
elif [ -d "${COMFYUI_DIR}/output" ]; then
    cp -rn "${COMFYUI_DIR}/output"/* "${WORKSPACE}/comfyui-output/" 2>/dev/null || true
    rm -rf "${COMFYUI_DIR}/output"
    ln -s "${WORKSPACE}/comfyui-output" "${COMFYUI_DIR}/output"
    log_info "ComfyUI output linked to ${WORKSPACE}/comfyui-output"
else
    ln -s "${WORKSPACE}/comfyui-output" "${COMFYUI_DIR}/output"
    log_info "ComfyUI output linked to ${WORKSPACE}/comfyui-output"
fi

# Copy scripts to workspace for easy access
cp /scripts/download-models.sh "${WORKSPACE}/" 2>/dev/null || true
chmod +x "${WORKSPACE}/download-models.sh" 2>/dev/null || true

log_info "Persistent storage configured"

# =============================================================================
# Model Download (Optional)
# =============================================================================

if [ "${SKIP_MODEL_DOWNLOAD}" = "true" ] || [ "${SKIP_MODEL_DOWNLOAD}" = "1" ]; then
    log_warn "Skipping model download (SKIP_MODEL_DOWNLOAD=true)"
    echo
    echo -e "${YELLOW}To download models later:${NC}"
    echo -e "  ${BLUE}download-models${NC}              # Full (~60GB)"
    echo -e "  ${BLUE}download-models --minimal${NC}    # Essential (~30GB)"
    echo
else
    # Check if models already exist
    MODEL_COUNT=$(find "${WORKSPACE}/comfyui-models" -name "*.safetensors" 2>/dev/null | wc -l)

    if [ "${MODEL_COUNT}" -gt 0 ]; then
        log_info "Found ${MODEL_COUNT} existing model(s), skipping download"
    else
        log_step "Downloading models..."
        if [ "${MINIMAL_MODELS}" = "true" ] || [ "${MINIMAL_MODELS}" = "1" ]; then
            /scripts/download-models.sh --minimal
        else
            /scripts/download-models.sh
        fi
    fi
fi

# =============================================================================
# Start Services
# =============================================================================

# Always start ComfyUI
log_step "Starting ComfyUI..."
/scripts/start_comfyui.sh

# Optionally start FaceFusion
if [ "${ENABLE_FACEFUSION}" = "true" ] || [ "${ENABLE_FACEFUSION}" = "1" ]; then
    log_step "Starting FaceFusion..."
    /scripts/start_facefusion.sh
else
    log_info "FaceFusion not auto-started (use 'ff-start' to start manually)"
fi

# =============================================================================
# Show Status
# =============================================================================

echo
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Services Started${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo
echo -e "  ${CYAN}ComfyUI:${NC}         http://localhost:8188  ${GREEN}[Running]${NC}"
if [ "${ENABLE_FACEFUSION}" = "true" ] || [ "${ENABLE_FACEFUSION}" = "1" ]; then
    echo -e "  ${CYAN}FaceFusion:${NC}      http://localhost:7860  ${GREEN}[Running]${NC}"
else
    echo -e "  ${CYAN}FaceFusion:${NC}      http://localhost:7860  ${YELLOW}[Manual: ff-start]${NC}"
fi
echo
echo -e "  ${CYAN}Commands:${NC}"
echo -e "    comfy            View ComfyUI logs"
echo -e "    comfy-restart    Restart ComfyUI"
echo -e "    ff-start         Start FaceFusion"
echo -e "    ff-stop          Stop FaceFusion"
echo -e "    facefusion       View FaceFusion logs"
echo -e "    download-models  Download ComfyUI models"
echo
echo -e "  ${CYAN}Storage:${NC}"
echo -e "    Models: ${WORKSPACE}/comfyui-models"
echo -e "    Output: ${WORKSPACE}/comfyui-output"
echo

# Keep container running
exec sleep infinity
