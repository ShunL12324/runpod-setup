# ComfyUI + FaceFusion for RunPod

One-click setup script to run ComfyUI and FaceFusion on RunPod.

## Quick Start

### 1. Create a RunPod Pod

**Image (choose one):**
```
runpod/pytorch:2.4.0-py3.11-cuda12.4.1-devel-ubuntu22.04
```
or
```
runpod/pytorch:1.0.2-cu1281-torch280-ubuntu2404
```

**Docker Command:**
```bash
bash -c "curl -fsSL https://raw.githubusercontent.com/ShunL12324/runpod-setup/master/scripts/runpod-setup.sh -o /tmp/setup.sh && bash /tmp/setup.sh && zsh"
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
| `comfy` | Attach to ComfyUI tmux session |
| `ff-start` | Start FaceFusion (tmux session) |
| `ff-stop` | Stop FaceFusion |
| `ff` | Attach to FaceFusion tmux session |

## Included Models

| Model | Size | Path |
|-------|------|------|
| SDXL Base 1.0 | ~6.5GB | checkpoints/ |
| SDXL VAE | ~335MB | vae/ |
| FLUX.1 Schnell | ~23GB | unet/ |
| FLUX VAE | ~335MB | vae/ |
| CLIP-L | ~235MB | clip/ |
| T5-XXL FP8 | ~4.9GB | clip/ |
| 4x ClearReality | ~67MB | upscale_models/ |

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
└── facefusion/
```

## Notes

- Script is idempotent - safe to run multiple times
- Models are skipped if already downloaded
- Services use tmux for session management
- NSFW check is disabled for FaceFusion
