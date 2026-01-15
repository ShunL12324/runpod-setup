#!/bin/bash

# =============================================================================
# ComfyUI Startup Script
# =============================================================================

COMFYUI_DIR=${COMFYUI_DIR:-/comfyui}
WORKSPACE=${WORKSPACE:-/workspace}
LOG_FILE="${WORKSPACE}/logs/comfyui.log"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Check if already running
if tmux has-session -t comfyui 2>/dev/null; then
    echo -e "${YELLOW}[WARN]${NC} ComfyUI is already running"
    echo -e "Use 'comfy' to view logs or 'comfy-restart' to restart"
    exit 0
fi

# Kill any existing session (cleanup)
tmux kill-session -t comfyui 2>/dev/null || true

# Start ComfyUI in tmux
if tmux new-session -d -s comfyui; then
    tmux send-keys -t comfyui "cd ${COMFYUI_DIR}" C-m
    tmux send-keys -t comfyui "source venv/bin/activate" C-m
    tmux send-keys -t comfyui "python main.py --listen 0.0.0.0 --port 8188 --front-end-version Comfy-Org/ComfyUI_frontend@latest 2>&1 | tee ${LOG_FILE}" C-m

    sleep 2

    if tmux has-session -t comfyui 2>/dev/null; then
        echo -e "${GREEN}[INFO]${NC} ComfyUI started on port 8188"
        echo -e "${GREEN}[INFO]${NC} Logs: ${LOG_FILE}"
    else
        echo -e "${RED}[ERROR]${NC} ComfyUI failed to start"
        exit 1
    fi
else
    echo -e "${RED}[ERROR]${NC} Failed to create tmux session"
    exit 1
fi
