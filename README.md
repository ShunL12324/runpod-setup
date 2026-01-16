# ComfyUI + FaceFusion for RunPod

One-click setup script to run ComfyUI and FaceFusion on RunPod.

## Quick Start

### 1. Create a RunPod Pod

**Image:**
```
runpod/pytorch:2.4.0-py3.11-cuda12.4.1-devel-ubuntu22.04
```

**Docker Command:**
```bash
bash -c "curl -sSL https://raw.githubusercontent.com/ShunL12324/runpod-setup/master/scripts/runpod-setup.sh | bash && sleep infinity"
```

**Expose Ports:**
- `8188` - ComfyUI
- `7860` - FaceFusion

### 2. Access Services

| Service | Port | Status |
|---------|------|--------|
| ComfyUI | 8188 | Auto-start |
| FaceFusion | 7860 | Manual start |

## Commands

```bash
ff-start      # Start FaceFusion
ff-stop       # Stop FaceFusion
comfy         # View ComfyUI logs
facefusion    # View FaceFusion logs
comfy-start   # Restart ComfyUI
```

## Included Custom Nodes

- [ComfyUI-Manager](https://github.com/ltdrdata/ComfyUI-Manager)
- [comfy-portal-endpoint](https://github.com/ShunL12324/comfy-portal-endpoint)
- [ComfyUI-Model-Manager](https://github.com/hayden-fr/ComfyUI-Model-Manager)

## File Locations

```
/workspace/
├── comfyui/
│   ├── models/          # Put your models here
│   └── output/          # Generated images
├── facefusion/
├── comfyui.log
└── facefusion.log
```

## Notes

- First-time setup takes ~5-10 minutes
- Without Network Volume, data is lost when pod stops
- Models need to be downloaded after each restart
- NSFW check is disabled for FaceFusion
