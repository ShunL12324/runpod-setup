# ComfyUI + FaceFusion for RunPod

One-click setup script to run ComfyUI and FaceFusion on RunPod.

## Quick Start

### 1. Create a RunPod Pod

**Image:**
```
runpod/pytorch:2.9.1-py3.12-cuda12.8.1-cudnn-devel-ubuntu24.04
```

**Docker Command:**
```bash
bash -c "curl -fsSL https://raw.githubusercontent.com/ShunL12324/runpod-setup/master/scripts/runpod-setup.sh -o /tmp/setup.sh && bash /tmp/setup.sh && exec zsh"
```

**Expose Ports:**
- `8188` - ComfyUI
- `7860` - FaceFusion

### 2. After Setup

```bash
comfy-start  # Start ComfyUI in tmux
ff-start     # Start FaceFusion in tmux
```

## Commands

| Command | Description |
|---------|-------------|
| `comfy-start` | Start ComfyUI (tmux session) |
| `comfy-stop` | Stop ComfyUI |
| `comfy-restart` | Restart ComfyUI |
| `comfy` | Attach to ComfyUI tmux session |
| `ff-start` | Start FaceFusion (tmux session) |
| `ff-stop` | Stop FaceFusion |
| `ff-restart` | Restart FaceFusion |
| `ff` | Attach to FaceFusion tmux session |
| `status` | Show running status of services |
| `gpu` | Run nvidia-smi |
| `gpu-mem` | Show GPU memory usage |

## Included Models

| Model | Path | Size |
|-------|------|------|
| Wan 2.1 VAE | vae/ | 243 MB |
| Wan 2.2 Rapid Mega AIO v3.1 | checkpoints/ | 23 GB |
| Qwen Rapid AIO NSFW v20 | checkpoints/ | 28.4 GB |
| NSFW Wan UMT5-XXL FP8 | clip/ | 6.3 GB |
| CLIP Vision ViT-H | clip_vision/ | 2.4 GB |
| Wan 2.2 i2v High Lighting | unet/ | 14 GB |
| Wan 2.2 i2v Low Lighting | unet/ | 14 GB |

## Included Custom Nodes

- [ComfyUI-Manager](https://github.com/ltdrdata/ComfyUI-Manager)
- [comfy-portal-endpoint](https://github.com/ShunL12324/comfy-portal-endpoint)
- [ComfyUI-Model-Manager](https://github.com/hayden-fr/ComfyUI-Model-Manager)

## File Locations

```
/workspace/
├── comfyui/
│   ├── models/          # Models
│   ├── output/          # Generated images
│   └── custom_nodes/    # Custom nodes
├── facefusion/
└── logs/                # Service logs
```

## Notes

- Script is idempotent - safe to run multiple times
- Pre-flight checks verify GPU and disk space (~95GB required)
- Models are skipped if already downloaded
- Services use tmux for session management
- Logs are saved to `/workspace/logs/`
- NSFW check is disabled for FaceFusion
- Uses PyTorch with CUDA 12.8 (cu128)
