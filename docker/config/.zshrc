# =============================================================================
# ZSH Configuration for ComfyUI + FaceFusion on RunPod
# =============================================================================

# Oh My Zsh
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"

plugins=(
    git
    zsh-autosuggestions
    zsh-syntax-highlighting
)

source $ZSH/oh-my-zsh.sh

# UV/Python path
export PATH="/root/.local/bin:$PATH"

# =============================================================================
# Environment
# =============================================================================

export EDITOR='vim'
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

export WORKSPACE=/workspace
export COMFYUI_DIR=/comfyui
export FACEFUSION_DIR=/facefusion

# =============================================================================
# ComfyUI Aliases
# =============================================================================

alias comfy='tmux attach -t comfyui'
alias comfy-start='/scripts/start_comfyui.sh'
alias comfy-stop='tmux kill-session -t comfyui 2>/dev/null && echo "ComfyUI stopped"'
alias comfy-restart='comfy-stop; comfy-start'
alias comfy-logs='tail -f /workspace/logs/comfyui.log'

# =============================================================================
# FaceFusion Aliases
# =============================================================================

alias facefusion='tmux attach -t facefusion'
alias ff-start='/scripts/start_facefusion.sh'
alias ff-stop='tmux kill-session -t facefusion 2>/dev/null && echo "FaceFusion stopped"'
alias ff-restart='ff-stop; ff-start'
alias ff-logs='tail -f /workspace/logs/facefusion.log'
alias ff-env='cd /facefusion && source venv/bin/activate'

# =============================================================================
# Model Management
# =============================================================================

alias download-models='/scripts/download-models.sh'
alias download-minimal='/scripts/download-models.sh --minimal'
alias list-models='/scripts/download-models.sh --list'

# =============================================================================
# Navigation
# =============================================================================

alias cdw='cd /workspace'
alias cdc='cd /comfyui'
alias cdf='cd /facefusion'
alias cdm='cd /workspace/comfyui-models'
alias cdn='cd /comfyui/custom_nodes'

# =============================================================================
# General Aliases
# =============================================================================

alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'

alias df='df -h'
alias du='du -h'
alias duh='du -h --max-depth=1 | sort -hr'

alias gpu='nvidia-smi'
alias gpuw='watch -n 1 nvidia-smi'

alias psg='ps aux | grep'

# =============================================================================
# Functions
# =============================================================================

# Show model sizes
models-size() {
    echo "ComfyUI Models:"
    du -h --max-depth=1 /workspace/comfyui-models 2>/dev/null | sort -hr
}

# Check GPU memory
gpu-mem() {
    nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader,nounits | \
    awk '{printf "GPU Memory: %d MB / %d MB (%.1f%%)\n", $1, $2, $1/$2*100}'
}

# Service status
status() {
    echo "Service Status:"
    echo "─────────────────────────────────────────"
    if tmux has-session -t comfyui 2>/dev/null; then
        echo -e "  ComfyUI:     \033[0;32m● Running\033[0m (port 8188)"
    else
        echo -e "  ComfyUI:     \033[0;31m○ Stopped\033[0m"
    fi
    if tmux has-session -t facefusion 2>/dev/null; then
        echo -e "  FaceFusion:  \033[0;32m● Running\033[0m (port 3001)"
    else
        echo -e "  FaceFusion:  \033[0;31m○ Stopped\033[0m"
    fi
    echo "─────────────────────────────────────────"
}

# Restart ComfyUI with custom args
comfy-custom() {
    tmux kill-session -t comfyui 2>/dev/null || true
    tmux new-session -d -s comfyui
    tmux send-keys -t comfyui "cd /comfyui && source venv/bin/activate && python main.py --listen 0.0.0.0 --port 8188 $*" C-m
    echo "ComfyUI started with args: $*"
}

# =============================================================================
# Welcome Message
# =============================================================================

echo ""
echo "🎨 ComfyUI + FaceFusion RunPod Environment"
echo "─────────────────────────────────────────────────────"
echo "  status         Show service status"
echo "  comfy          Attach to ComfyUI logs"
echo "  ff-start       Start FaceFusion"
echo "  facefusion     Attach to FaceFusion logs"
echo "  download-models Download ComfyUI models"
echo "  gpu            Show GPU status"
echo "─────────────────────────────────────────────────────"
status
echo ""
