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
- `3001` - FaceFusion

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

| Model | Path |
|-------|------|
| Wan 2.1 VAE | vae/ |
| Wan 2.2 Rapid Mega AIO v3.1 | checkpoints/ |
| NSFW Wan UMT5-XXL FP8 | clip/ |
| CLIP Vision ViT-H | clip_vision/ |
| Wan 2.2 i2v High Lighting | unet/ |
| Wan 2.2 i2v Low Lighting | unet/ |

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
