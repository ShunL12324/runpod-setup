# ComfyUI + FaceFusion Docker Image for RunPod

预装 ComfyUI 和 FaceFusion 的 Docker 镜像，针对 RunPod 优化。

## 特性

- ✅ ComfyUI 预装 (Python 3.11 venv)
- ✅ FaceFusion 预装 (Micromamba + Python 3.12)
- ✅ Custom nodes: Manager, Portal Endpoint, Model Manager
- ✅ CUDA 12.4 支持
- ✅ zsh + oh-my-zsh 配置完整
- ✅ 模型下载脚本内置
- ✅ 持久化存储到 /workspace

## 服务端口

| 服务 | 端口 | 说明 |
|------|------|------|
| ComfyUI | 8188 | 图像/视频生成 |
| FaceFusion | 3001 | 人脸替换/增强 |

## 快速开始

### 构建镜像

```bash
cd docker
docker build -t YOUR_USERNAME/comfyui-facefusion:latest .
docker push YOUR_USERNAME/comfyui-facefusion:latest
```

### 在 RunPod 使用

1. 创建 Template 或直接部署 Pod
2. Container Image: `YOUR_USERNAME/comfyui-facefusion:latest`
3. Expose HTTP Ports: `8188, 3001`
4. Volume Disk: 100+ GB

## 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `SKIP_MODEL_DOWNLOAD` | false | 跳过 ComfyUI 模型下载 |
| `MINIMAL_MODELS` | false | 只下载必要模型 (~30GB) |
| `ENABLE_FACEFUSION` | false | 自动启动 FaceFusion |

**默认行为：** ComfyUI 自动启动，FaceFusion 需手动启动

## 使用命令

### 服务管理

```bash
# 查看服务状态
status

# ComfyUI (自动启动)
comfy              # 查看日志
comfy-restart      # 重启
comfy-stop         # 停止

# FaceFusion (手动启动)
ff-start           # 启动
facefusion         # 查看日志
ff-restart         # 重启
ff-stop            # 停止
```

### 模型下载

```bash
download-models              # 全部 (~60GB)
download-models --minimal    # 必要 (~30GB)
download-models --list       # 列出所有
download-models --force      # 强制重下
```

### 其他命令

```bash
gpu                # GPU 状态
gpu-mem            # GPU 显存使用
models-size        # 模型大小
```

## 目录结构

```
容器内:
├── /comfyui/              # ComfyUI 安装目录
├── /facefusion/           # FaceFusion 安装目录
├── /scripts/              # 启动脚本
└── /workspace/            # 持久存储 (RunPod)
    ├── comfyui-models/    # ComfyUI 模型
    ├── comfyui-output/    # ComfyUI 输出
    ├── facefusion-output/ # FaceFusion 输出
    └── logs/              # 日志文件
```

## ComfyUI 模型

### Essential (~30GB)

| 模型 | 大小 | 用途 |
|------|------|------|
| wan_2.1_vae.safetensors | 243 MB | VAE |
| wan2.2-rapid-mega-nsfw-aio-v3.1.safetensors | 23 GB | All-in-One |
| nsfw_wan_umt5-xxl_fp8_scaled.safetensors | 6.3 GB | CLIP Text |
| clip-vision_vit-h.safetensors | 2.4 GB | CLIP Vision |

### Additional (+28GB)

| 模型 | 大小 | 用途 |
|------|------|------|
| Wan2.2_Remix_high_lighting | 14 GB | UNet 高光 |
| Wan2.2_Remix_low_lighting | 14 GB | UNet 低光 |

## FaceFusion

FaceFusion 模型在首次运行时自动下载，存储在容器内。

### 使用方式

1. 启动服务: `ff-start`
2. 访问 Web UI: `http://localhost:3001`
3. 选择源图片和目标图片
4. 选择处理器 (face_swapper, face_enhancer 等)
5. 开始处理

### 输出目录

处理结果保存在 `/workspace/facefusion-output/`

## 故障排除

### ComfyUI 无法启动

```bash
comfy              # 查看错误日志
comfy-restart      # 重启服务
```

### FaceFusion 无法启动

```bash
ff-start           # 查看启动日志
facefusion         # 查看运行日志
```

### GPU 问题

```bash
nvidia-smi         # 检查 GPU 是否可用
gpu-mem            # 检查显存使用
```

### 磁盘空间不足

```bash
df -h /workspace   # 检查空间
models-size        # 查看模型大小
```

## 更新镜像

```bash
cd docker
docker build --no-cache -t YOUR_USERNAME/comfyui-facefusion:latest .
docker push YOUR_USERNAME/comfyui-facefusion:latest
```

## 文件说明

```
docker/
├── Dockerfile                 # 镜像定义
├── README.md                  # 本文件
├── scripts/
│   ├── start.sh              # 容器入口
│   ├── start_comfyui.sh      # ComfyUI 启动
│   ├── start_facefusion.sh   # FaceFusion 启动
│   └── download-models.sh    # 模型下载
└── config/
    └── .zshrc                # zsh 配置
```
