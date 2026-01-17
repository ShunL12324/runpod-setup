#!/bin/bash

# =============================================================================
# FaceFusion Startup Script
# =============================================================================

FACEFUSION_DIR=${FACEFUSION_DIR:-/facefusion}
WORKSPACE=${WORKSPACE:-/workspace}
LOG_FILE="${WORKSPACE}/logs/facefusion.log"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Determine thread count
if [ -n "${RUNPOD_CPU_COUNT}" ]; then
    THREAD_COUNT=${RUNPOD_CPU_COUNT}
    if [ ${THREAD_COUNT} -gt 32 ]; then
        THREAD_COUNT=32
    fi
else
    THREAD_COUNT=8
fi

# Check if already running
if tmux has-session -t facefusion 2>/dev/null; then
    echo -e "${YELLOW}[WARN]${NC} FaceFusion is already running"
    echo -e "Use 'facefusion' to view logs or 'ff-restart' to restart"
    exit 0
fi

# Kill any existing session (cleanup)
tmux kill-session -t facefusion 2>/dev/null || true

# Create output directory
mkdir -p "${WORKSPACE}/facefusion-output"

# Start FaceFusion in tmux
if tmux new-session -d -s facefusion; then
    tmux send-keys -t facefusion "cd ${FACEFUSION_DIR}" C-m
    tmux send-keys -t facefusion "source venv/bin/activate" C-m
    tmux send-keys -t facefusion "python facefusion.py run --execution-thread-count ${THREAD_COUNT} --execution-providers cuda --output-path ${WORKSPACE}/facefusion-output 2>&1 | tee ${LOG_FILE}" C-m

    sleep 3

    if tmux has-session -t facefusion 2>/dev/null; then
        echo -e "${GREEN}[INFO]${NC} FaceFusion started on port 7860"
        echo -e "${GREEN}[INFO]${NC} Thread count: ${THREAD_COUNT}"
        echo -e "${GREEN}[INFO]${NC} Logs: ${LOG_FILE}"
    else
        echo -e "${RED}[ERROR]${NC} FaceFusion failed to start"
        exit 1
    fi
else
    echo -e "${RED}[ERROR]${NC} Failed to create tmux session"
    exit 1
fi
