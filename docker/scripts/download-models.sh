#!/bin/bash

# =============================================================================
# Model Download Script for ComfyUI
# =============================================================================
# Usage:
#   ./download-models.sh              # Download all models (~60GB)
#   ./download-models.sh --minimal    # Download essential models only (~30GB)
#   ./download-models.sh --force      # Re-download even if files exist
#   ./download-models.sh --list       # List all available models
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# =============================================================================
# Configuration
# =============================================================================

MODELS_DIR="${WORKSPACE:-/workspace}/comfyui-models"
FACEFUSION_MODELS_DIR="/facefusion/.assets/models"

# Model definitions: name|size_mb|subdir|url|essential
# essential=1 means included in --minimal
MODELS=(
    "wan_2.1_vae.safetensors|243|vae|https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors|1"
    "Wan2.2_Remix_NSFW_i2v_14b_high_lighting_fp8_e4m3fn_v2.1.safetensors|14336|unet|https://huggingface.co/FX-FeiHou/wan2.2-Remix/resolve/main/NSFW/Wan2.2_Remix_NSFW_i2v_14b_high_lighting_fp8_e4m3fn_v2.1.safetensors|0"
    "Wan2.2_Remix_NSFW_i2v_14b_low_lighting_fp8_e4m3fn_v2.1.safetensors|14336|unet|https://huggingface.co/FX-FeiHou/wan2.2-Remix/resolve/main/NSFW/Wan2.2_Remix_NSFW_i2v_14b_low_lighting_fp8_e4m3fn_v2.1.safetensors|0"
    "wan2.2-rapid-mega-nsfw-aio-v3.1.safetensors|23552|checkpoints|https://huggingface.co/Phr00t/WAN2.2-14B-Rapid-AllInOne/resolve/main/Mega-v3/wan2.2-rapid-mega-nsfw-aio-v3.1.safetensors|1"
    "nsfw_wan_umt5-xxl_fp8_scaled.safetensors|6451|clip|https://huggingface.co/NSFW-API/NSFW-Wan-UMT5-XXL/resolve/main/nsfw_wan_umt5-xxl_fp8_scaled.safetensors|1"
    "clip-vision_vit-h.safetensors|2458|clip_vision|https://huggingface.co/hfmaster/models-moved/resolve/8b8d4cae76158cd49410d058971bb0e591966e04/sdxl/ipadapter/clip-vision_vit-h.safetensors|1"
)

# =============================================================================
# FaceFusion Models
# =============================================================================
# Format: name|size_mb|url|essential
# HuggingFace URL pattern: https://huggingface.co/facefusion/{version}/resolve/main/{filename}

FACEFUSION_MODELS=(
    # ===== Core Models (Essential for any face operation) =====
    # Face Detector
    "yoloface_8n.onnx|17|https://huggingface.co/facefusion/models-3.0.0/resolve/main/yoloface_8n.onnx|1"
    # Face Landmarker
    "2dfan4.onnx|100|https://huggingface.co/facefusion/models-3.0.0/resolve/main/2dfan4.onnx|1"
    # Face Recognizer (for face matching)
    "arcface_w600k_r50.onnx|167|https://huggingface.co/facefusion/models-3.0.0/resolve/main/arcface_w600k_r50.onnx|1"
    # Face Masker
    "bisenet_resnet_34.onnx|84|https://huggingface.co/facefusion/models-3.0.0/resolve/main/bisenet_resnet_34.onnx|1"
    # Face Classifier
    "fairface.onnx|86|https://huggingface.co/facefusion/models-3.0.0/resolve/main/fairface.onnx|1"

    # ===== Face Swapper Models =====
    # InSwapper (default, fast, good quality)
    "inswapper_128.onnx|554|https://huggingface.co/facefusion/models-3.0.0/resolve/main/inswapper_128.onnx|0"
    "inswapper_128_fp16.onnx|277|https://huggingface.co/facefusion/models-3.0.0/resolve/main/inswapper_128_fp16.onnx|1"
    # HyperSwap (newest, best quality, 2x resolution)
    "hyperswap_1a_256.onnx|384|https://huggingface.co/facefusion/models-3.3.0/resolve/main/hyperswap_1a_256.onnx|1"
    "hyperswap_1b_256.onnx|356|https://huggingface.co/facefusion/models-3.3.0/resolve/main/hyperswap_1b_256.onnx|0"
    "hyperswap_1c_256.onnx|356|https://huggingface.co/facefusion/models-3.3.0/resolve/main/hyperswap_1c_256.onnx|0"
    # Ghost models (good quality, larger models)
    "ghost_1_256.onnx|252|https://huggingface.co/facefusion/models-3.0.0/resolve/main/ghost_1_256.onnx|0"
    "ghost_2_256.onnx|252|https://huggingface.co/facefusion/models-3.0.0/resolve/main/ghost_2_256.onnx|0"
    "ghost_3_256.onnx|252|https://huggingface.co/facefusion/models-3.0.0/resolve/main/ghost_3_256.onnx|0"
    # BlendSwap
    "blendswap_256.onnx|240|https://huggingface.co/facefusion/models-3.0.0/resolve/main/blendswap_256.onnx|0"
    # SimSwap
    "simswap_256.onnx|89|https://huggingface.co/facefusion/models-3.0.0/resolve/main/simswap_256.onnx|0"
    "simswap_unofficial_512.onnx|90|https://huggingface.co/facefusion/models-3.0.0/resolve/main/simswap_unofficial_512.onnx|0"
    # UniFace
    "uniface_256.onnx|258|https://huggingface.co/facefusion/models-3.0.0/resolve/main/uniface_256.onnx|0"
    # HiFiFace
    "hififace_unofficial_256.onnx|424|https://huggingface.co/facefusion/models-3.1.0/resolve/main/hififace_unofficial_256.onnx|0"
    # CrossFace (embedding converters for ghost/hififace/simswap)
    "crossface_ghost.onnx|3|https://huggingface.co/facefusion/models-3.4.0/resolve/main/crossface_ghost.onnx|0"
    "crossface_hififace.onnx|3|https://huggingface.co/facefusion/models-3.4.0/resolve/main/crossface_hififace.onnx|0"
    "crossface_simswap.onnx|4|https://huggingface.co/facefusion/models-3.4.0/resolve/main/crossface_simswap.onnx|0"

    # ===== Face Enhancer Models =====
    # GFPGAN (popular, good quality)
    "gfpgan_1.4.onnx|348|https://huggingface.co/facefusion/models-3.0.0/resolve/main/gfpgan_1.4.onnx|1"
    "gfpgan_1.3.onnx|332|https://huggingface.co/facefusion/models-3.0.0/resolve/main/gfpgan_1.3.onnx|0"
    "gfpgan_1.2.onnx|332|https://huggingface.co/facefusion/models-3.0.0/resolve/main/gfpgan_1.2.onnx|0"
    # CodeFormer (best for identity preservation)
    "codeformer.onnx|375|https://huggingface.co/facefusion/models-3.0.0/resolve/main/codeformer.onnx|1"
    # GPEN (different resolutions)
    "gpen_bfr_256.onnx|81|https://huggingface.co/facefusion/models-3.0.0/resolve/main/gpen_bfr_256.onnx|0"
    "gpen_bfr_512.onnx|268|https://huggingface.co/facefusion/models-3.0.0/resolve/main/gpen_bfr_512.onnx|0"
    "gpen_bfr_1024.onnx|272|https://huggingface.co/facefusion/models-3.0.0/resolve/main/gpen_bfr_1024.onnx|1"
    "gpen_bfr_2048.onnx|2509|https://huggingface.co/facefusion/models-3.0.0/resolve/main/gpen_bfr_2048.onnx|0"
    # RestoreFormer
    "restoreformer_plus_plus.onnx|116|https://huggingface.co/facefusion/models-3.0.0/resolve/main/restoreformer_plus_plus.onnx|0"

    # ===== Additional Face Masker Models =====
    "xseg_1.onnx|67|https://huggingface.co/facefusion/models-3.1.0/resolve/main/xseg_1.onnx|1"
    "xseg_2.onnx|6|https://huggingface.co/facefusion/models-3.1.0/resolve/main/xseg_2.onnx|0"
    "xseg_3.onnx|6|https://huggingface.co/facefusion/models-3.2.0/resolve/main/xseg_3.onnx|0"
    "bisenet_resnet_18.onnx|51|https://huggingface.co/facefusion/models-3.1.0/resolve/main/bisenet_resnet_18.onnx|1"

    # ===== Content Analyser (NSFW detection) - DISABLED by patch =====
    # These models are NOT needed since NSFW check is disabled
    # "nsfw_1.onnx|77|https://huggingface.co/facefusion/models-3.3.0/resolve/main/nsfw_1.onnx|0"
    # "nsfw_2.onnx|21|https://huggingface.co/facefusion/models-3.3.0/resolve/main/nsfw_2.onnx|0"
    # "nsfw_3.onnx|342|https://huggingface.co/facefusion/models-3.3.0/resolve/main/nsfw_3.onnx|0"

    # ===== Frame Enhancer (Video Upscaling) =====
    "real_esrgan_x2_fp16.onnx|35|https://huggingface.co/facefusion/models-3.0.0/resolve/main/real_esrgan_x2_fp16.onnx|1"
    "real_esrgan_x4_fp16.onnx|35|https://huggingface.co/facefusion/models-3.0.0/resolve/main/real_esrgan_x4_fp16.onnx|1"
    "real_esrgan_x8_fp16.onnx|35|https://huggingface.co/facefusion/models-3.0.0/resolve/main/real_esrgan_x8_fp16.onnx|0"
    "span_kendata_x4.onnx|2|https://huggingface.co/facefusion/models-3.0.0/resolve/main/span_kendata_x4.onnx|1"
    "ultra_sharp_x4.onnx|64|https://huggingface.co/facefusion/models-3.0.0/resolve/main/ultra_sharp_x4.onnx|0"
    "clear_reality_x4.onnx|64|https://huggingface.co/facefusion/models-3.0.0/resolve/main/clear_reality_x4.onnx|0"

    # ===== Frame Colorizer (B&W to Color) =====
    "ddcolor.onnx|935|https://huggingface.co/facefusion/models-3.0.0/resolve/main/ddcolor.onnx|1"
    "deoldify.onnx|149|https://huggingface.co/facefusion/models-3.0.0/resolve/main/deoldify.onnx|0"

    # ===== Voice Extractor =====
    "kim_vocal_2.onnx|64|https://huggingface.co/facefusion/models-3.0.0/resolve/main/kim_vocal_2.onnx|1"

    # ===== Additional Face Detectors =====
    "retinaface_10g.onnx|16|https://huggingface.co/facefusion/models-3.0.0/resolve/main/retinaface_10g.onnx|0"
    "scrfd_2.5g.onnx|3|https://huggingface.co/facefusion/models-3.0.0/resolve/main/scrfd_2.5g.onnx|0"
    "yunet_2023_mar.onnx|1|https://huggingface.co/facefusion/models-3.4.0/resolve/main/yunet_2023_mar.onnx|0"

    # ===== Additional Face Landmarkers =====
    "fan_68_5.onnx|1|https://huggingface.co/facefusion/models-3.0.0/resolve/main/fan_68_5.onnx|1"
    "peppa_wutz.onnx|33|https://huggingface.co/facefusion/models-3.0.0/resolve/main/peppa_wutz.onnx|0"
)

# =============================================================================
# Functions
# =============================================================================

show_help() {
    cat << EOF
${CYAN}Model Download Script for ComfyUI + FaceFusion${NC}

Usage: $0 [OPTIONS]

Options:
  --minimal       Download essential models only
  --comfyui-only  Download only ComfyUI models
  --facefusion-only  Download only FaceFusion models
  --force         Re-download even if files exist
  --list          List all available models
  --help          Show this help message

ComfyUI Models (${MODELS_DIR}):
  ${GREEN}Essential (--minimal):${NC}
    - wan_2.1_vae.safetensors (243 MB) - VAE
    - wan2.2-rapid-mega-nsfw-aio-v3.1.safetensors (23 GB) - All-in-One
    - nsfw_wan_umt5-xxl_fp8_scaled.safetensors (6.3 GB) - CLIP
    - clip-vision_vit-h.safetensors (2.4 GB) - CLIP Vision

FaceFusion Models (${FACEFUSION_MODELS_DIR}):
  ${GREEN}Essential (--minimal):${NC}
    - yoloface_8n.onnx (17 MB) - Face Detector
    - 2dfan4.onnx (100 MB) - Face Landmarker
    - arcface_w600k_r50.onnx (167 MB) - Face Recognizer
    - inswapper_128_fp16.onnx (277 MB) - Face Swapper (fast)
    - hyperswap_1c_256.onnx (356 MB) - Face Swapper (best quality)
    - gfpgan_1.4.onnx (348 MB) - Face Enhancer (fast)
    - codeformer.onnx (375 MB) - Face Enhancer (best quality)
EOF
}

list_models() {
    echo -e "${CYAN}ComfyUI Models:${NC}"
    echo "─────────────────────────────────────────────────────────────────"
    printf "%-50s %8s %s\n" "Name" "Size" "Essential"
    echo "─────────────────────────────────────────────────────────────────"

    for model_def in "${MODELS[@]}"; do
        IFS='|' read -r name size subdir url essential <<< "${model_def}"

        if [ "${essential}" = "1" ]; then
            ess_mark="${GREEN}✓${NC}"
        else
            ess_mark="${YELLOW}○${NC}"
        fi

        # Format size
        if [ "${size}" -gt 1024 ]; then
            size_str="$(echo "scale=1; ${size}/1024" | bc) GB"
        else
            size_str="${size} MB"
        fi

        printf "%-50s %8s   %b\n" "${name:0:48}" "${size_str}" "${ess_mark}"
    done

    echo
    echo -e "${CYAN}FaceFusion Models:${NC}"
    echo "─────────────────────────────────────────────────────────────────"
    printf "%-50s %8s %s\n" "Name" "Size" "Essential"
    echo "─────────────────────────────────────────────────────────────────"

    for model_def in "${FACEFUSION_MODELS[@]}"; do
        IFS='|' read -r name size url essential <<< "${model_def}"

        if [ "${essential}" = "1" ]; then
            ess_mark="${GREEN}✓${NC}"
        else
            ess_mark="${YELLOW}○${NC}"
        fi

        # Format size
        if [ "${size}" -gt 1024 ]; then
            size_str="$(echo "scale=1; ${size}/1024" | bc) GB"
        else
            size_str="${size} MB"
        fi

        printf "%-50s %8s   %b\n" "${name:0:48}" "${size_str}" "${ess_mark}"
    done

    echo "─────────────────────────────────────────────────────────────────"
    echo -e "${GREEN}✓${NC} = Essential (included in --minimal)"
}

check_disk_space() {
    local required_mb=$1
    local available_mb=$(df -BM "${MODELS_DIR}" 2>/dev/null | awk 'NR==2 {print $4}' | tr -d 'M')

    if [ -z "${available_mb}" ]; then
        log_warn "Could not check disk space"
        return 0
    fi

    if [ "${available_mb}" -lt "${required_mb}" ]; then
        log_error "Insufficient disk space: ${available_mb}MB available, ${required_mb}MB required"
        return 1
    fi

    log_info "Disk space OK: ${available_mb}MB available"
    return 0
}

download_model() {
    local name="$1"
    local size_mb="$2"
    local subdir="$3"
    local url="$4"
    local output_dir="${MODELS_DIR}/${subdir}"
    local output_path="${output_dir}/${name}"

    mkdir -p "${output_dir}"

    # Check if already exists (unless --force)
    if [ "${FORCE}" != "true" ] && [ -f "${output_path}" ]; then
        local existing_size=$(stat -c%s "${output_path}" 2>/dev/null || echo "0")
        local expected_bytes=$((size_mb * 1024 * 1024))
        local tolerance=$((expected_bytes / 10))

        if [ "${existing_size}" -gt "$((expected_bytes - tolerance))" ]; then
            echo -e "  ${YELLOW}○${NC} ${name} (exists, skipping)"
            echo "SKIP:${name}" >> /tmp/download_results.txt
            return 0
        fi
    fi

    # Format size for display
    if [ "${size_mb}" -gt 1024 ]; then
        size_str="$(echo "scale=1; ${size_mb}/1024" | bc) GB"
    else
        size_str="${size_mb} MB"
    fi

    echo -e "  ${BLUE}↓${NC} ${name} (${size_str})"

    # Download with aria2c
    if aria2c -x 16 -s 16 -k 1M -c \
        --console-log-level=warn \
        --summary-interval=10 \
        --dir="${output_dir}" \
        --out="${name}" \
        "${url}" 2>&1; then
        echo -e "  ${GREEN}✓${NC} ${name}"
        echo "OK:${name}" >> /tmp/download_results.txt
    else
        echo -e "  ${RED}✗${NC} ${name}"
        echo "FAIL:${name}" >> /tmp/download_results.txt
    fi
}

download_facefusion_model() {
    local name="$1"
    local size_mb="$2"
    local url="$3"
    local output_dir="${FACEFUSION_MODELS_DIR}"
    local output_path="${output_dir}/${name}"

    mkdir -p "${output_dir}"

    # Check if already exists (unless --force)
    if [ "${FORCE}" != "true" ] && [ -f "${output_path}" ]; then
        local existing_size=$(stat -c%s "${output_path}" 2>/dev/null || echo "0")
        local expected_bytes=$((size_mb * 1024 * 1024))
        local tolerance=$((expected_bytes / 10))

        if [ "${existing_size}" -gt "$((expected_bytes - tolerance))" ]; then
            echo -e "  ${YELLOW}○${NC} [FF] ${name} (exists, skipping)"
            echo "SKIP:${name}" >> /tmp/download_results.txt
            return 0
        fi
    fi

    # Format size for display
    if [ "${size_mb}" -gt 1024 ]; then
        size_str="$(echo "scale=1; ${size_mb}/1024" | bc) GB"
    else
        size_str="${size_mb} MB"
    fi

    echo -e "  ${BLUE}↓${NC} [FF] ${name} (${size_str})"

    # Download with aria2c
    if aria2c -x 16 -s 16 -k 1M -c \
        --console-log-level=warn \
        --summary-interval=10 \
        --dir="${output_dir}" \
        --out="${name}" \
        "${url}" 2>&1; then
        echo -e "  ${GREEN}✓${NC} [FF] ${name}"
        echo "OK:${name}" >> /tmp/download_results.txt
    else
        echo -e "  ${RED}✗${NC} [FF] ${name}"
        echo "FAIL:${name}" >> /tmp/download_results.txt
    fi
}

# =============================================================================
# Main
# =============================================================================

MINIMAL=false
FORCE=false
COMFYUI_ONLY=false
FACEFUSION_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --minimal)
            MINIMAL=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --comfyui-only)
            COMFYUI_ONLY=true
            shift
            ;;
        --facefusion-only)
            FACEFUSION_ONLY=true
            shift
            ;;
        --list)
            list_models
            exit 0
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Calculate required space
TOTAL_SIZE=0
MODEL_COUNT=0
FF_MODEL_COUNT=0

# ComfyUI models
if [ "${FACEFUSION_ONLY}" != "true" ]; then
    for model_def in "${MODELS[@]}"; do
        IFS='|' read -r name size subdir url essential <<< "${model_def}"
        if [ "${MINIMAL}" = "true" ] && [ "${essential}" != "1" ]; then
            continue
        fi
        TOTAL_SIZE=$((TOTAL_SIZE + size))
        ((MODEL_COUNT++))
    done
fi

# FaceFusion models
if [ "${COMFYUI_ONLY}" != "true" ]; then
    for model_def in "${FACEFUSION_MODELS[@]}"; do
        IFS='|' read -r name size url essential <<< "${model_def}"
        if [ "${MINIMAL}" = "true" ] && [ "${essential}" != "1" ]; then
            continue
        fi
        TOTAL_SIZE=$((TOTAL_SIZE + size))
        ((FF_MODEL_COUNT++))
    done
fi

# Header
echo
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
if [ "${MINIMAL}" = "true" ]; then
    echo -e "${BLUE}║  Model Download - Essential Only                           ║${NC}"
elif [ "${COMFYUI_ONLY}" = "true" ]; then
    echo -e "${BLUE}║  Model Download - ComfyUI Only                             ║${NC}"
elif [ "${FACEFUSION_ONLY}" = "true" ]; then
    echo -e "${BLUE}║  Model Download - FaceFusion Only                          ║${NC}"
else
    echo -e "${BLUE}║  Model Download - Full                                     ║${NC}"
fi
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo

log_info "ComfyUI models: ${MODEL_COUNT}"
log_info "FaceFusion models: ${FF_MODEL_COUNT}"
log_info "Total size: ~$((TOTAL_SIZE / 1024)) GB"
log_info "ComfyUI destination: ${MODELS_DIR}"
log_info "FaceFusion destination: ${FACEFUSION_MODELS_DIR}"
echo

# Check disk space
if ! check_disk_space "${TOTAL_SIZE}"; then
    exit 1
fi

# Create directories
mkdir -p "${MODELS_DIR}"/{checkpoints,clip,clip_vision,configs,controlnet,embeddings,loras,unet,upscale_models,vae}
mkdir -p "${FACEFUSION_MODELS_DIR}"

# Clear results
> /tmp/download_results.txt

# Download ComfyUI models
if [ "${FACEFUSION_ONLY}" != "true" ] && [ "${MODEL_COUNT}" -gt 0 ]; then
    echo -e "${CYAN}Downloading ComfyUI models...${NC}"
    echo

    PIDS=()
    for model_def in "${MODELS[@]}"; do
        IFS='|' read -r name size subdir url essential <<< "${model_def}"

        # Skip non-essential in minimal mode
        if [ "${MINIMAL}" = "true" ] && [ "${essential}" != "1" ]; then
            continue
        fi

        download_model "${name}" "${size}" "${subdir}" "${url}" &
        PIDS+=($!)
    done

    # Wait for all downloads
    for pid in "${PIDS[@]}"; do
        wait "${pid}" 2>/dev/null || true
    done
fi

# Download FaceFusion models
if [ "${COMFYUI_ONLY}" != "true" ] && [ "${FF_MODEL_COUNT}" -gt 0 ]; then
    echo
    echo -e "${CYAN}Downloading FaceFusion models...${NC}"
    echo

    PIDS=()
    for model_def in "${FACEFUSION_MODELS[@]}"; do
        IFS='|' read -r name size url essential <<< "${model_def}"

        # Skip non-essential in minimal mode
        if [ "${MINIMAL}" = "true" ] && [ "${essential}" != "1" ]; then
            continue
        fi

        download_facefusion_model "${name}" "${size}" "${url}" &
        PIDS+=($!)
    done

    # Wait for all downloads
    for pid in "${PIDS[@]}"; do
        wait "${pid}" 2>/dev/null || true
    done
fi

# Summary
echo
echo -e "${CYAN}Download Summary${NC}"
echo "─────────────────────────────────────────"

OK=0
SKIP=0
FAIL=0

while IFS= read -r line; do
    status="${line%%:*}"
    case "${status}" in
        OK) ((OK++)) ;;
        SKIP) ((SKIP++)) ;;
        FAIL) ((FAIL++)) ;;
    esac
done < /tmp/download_results.txt

echo -e "  Downloaded: ${GREEN}${OK}${NC}"
echo -e "  Skipped:    ${YELLOW}${SKIP}${NC}"
echo -e "  Failed:     ${RED}${FAIL}${NC}"
echo "─────────────────────────────────────────"

rm -f /tmp/download_results.txt

if [ "${FAIL}" -gt 0 ]; then
    log_warn "Some downloads failed. Run with --force to retry."
    exit 1
fi

log_info "All downloads complete!"
