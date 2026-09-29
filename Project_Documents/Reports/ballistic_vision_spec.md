# TinyNPU200J — Ballistic Vision Application Specification
**Application Domain**: Ballistic Vision & Threat Detection System
**Hardware Platform**: PYNQ-Z2 (TinyNPU200J @ 125 MHz, 20 GOPS INT8)
**Document Type**: Application Design Specification for DL Engineer

---

## 1. What is Ballistic Vision?

Ballistic Vision is a real-time computer vision system designed to **detect, classify, track, and predict** objects and events in high-stakes kinetic environments. This includes:

- Detecting and tracking **fast-moving projectiles**, vehicles, and aerial threats
- Identifying **muzzle flash signatures** to locate the origin of fire
- Classifying **threat vs. non-threat** targets in live video streams
- Estimating **ballistic trajectories** using temporal motion analysis
- Providing **targeting overlays and lock-on feedback** via the HDMI output

Your PYNQ-Z2 hardware with its dedicated 125 MHz NPU is perfectly suited for **edge-deployed ballistic vision** — running inference directly on the embedded system without a cloud server, at **real-time 720p video** speed.

---

## 2. System Architecture Overview

```
[Camera / Thermal Input]
         │
         ▼ (HDMI IN @ 720p 60fps)
[PYNQ-Z2 FPGA — TinyNPU200J]
         │
    ┌────┴─────────────────────────────────┐
    │  Stage 1: Pre-processing (PL)        │
    │  - Grayscale / channel normalization │
    │  - Frame differencing (motion mask)  │
    └────┬─────────────────────────────────┘
         │
    ┌────┴─────────────────────────────────┐
    │  Stage 2: NPU Inference (160 MACs)   │
    │  - Object detection (YOLO-Nano)      │
    │  - Threat classification             │
    │  - Flash / bloom detection           │
    └────┬─────────────────────────────────┘
         │
    ┌────┴─────────────────────────────────┐
    │  Stage 3: ARM Cortex-A9 (PS7)        │
    │  - Kalman Filter trajectory tracking │
    │  - Threat scoring & decision logic   │
    │  - Ballistic drop compensation tables│
    └────┬─────────────────────────────────┘
         │
         ▼ (HDMI OUT @ 720p)
[Display — Targeting Overlay / Alert HUD]
```

---

## 3. Ballistic Vision Sub-Applications

### 3.1 🎯 Target Detection & Classification
**What it does**: Detects and draws bounding boxes around humans, vehicles, drones, and animals in a live video feed.

| Spec                | Details                                     |
|---------------------|---------------------------------------------|
| Model Family        | YOLO-Nano / NanoDet (INT8 quantized)        |
| Input Resolution    | 320×320 (letterboxed from 720p)             |
| Output              | Bounding boxes + class labels + confidence  |
| Target Classes      | Person, vehicle, UAV/drone, animal          |
| Estimated FPS       | **20–30 FPS** on NPU                        |

---

### 3.2 💥 Muzzle Flash & Gunshot Origin Detection
**What it does**: Detects the characteristic high-luminance bloom created by a firearm's muzzle flash in a single frame (< 2ms event). Pinpoints the origin of fire in the scene.

| Spec                | Details                                          |
|---------------------|--------------------------------------------------|
| Approach            | Frame differencing + CNN bloom classifier        |
| Model Type          | Lightweight binary classifier (Flash / No-Flash) |
| Key Feature         | Temporal delta frame fed as extra input channel  |
| Input               | 3-channel: R, G, Δframe (motion residual)        |
| Output              | Bounding box at flash origin + confidence score  |
| Critical Constraint | Must run at **60 FPS** (every frame must be analyzed) |

**DL Engineer Note**: Build a temporal 2-frame differencing pipeline. The NPU runs the CNN on the stacked `[frame_N, frame_N-1, delta]` input. The delta channel naturally highlights transient high-energy events like muzzle flash, explosions, and laser pulses.

---

### 3.3 🚁 Aerial Threat Detection (UAV / Drone)
**What it does**: Classifies and tracks small aerial objects that are moving against sky or terrain backgrounds. Distinguishes UAVs from birds and aircraft.

| Spec                | Details                                           |
|---------------------|---------------------------------------------------|
| Challenge           | Very small objects (< 20px) at long range         |
| Approach            | Multi-scale depthwise separable feature extractor |
| Model               | MobileNetV2-Nano backbone + custom detection head |
| Input               | 416×416 (tiled from 720p with stride 2 pre-scale) |
| Output              | UAV/Drone bounding box + velocity vector          |
| FPS Target          | **15–20 FPS** (acceptable for slow aerial targets)|

---

### 3.4 🏃 Moving Target Tracking (Kalman + NPU Hybrid)
**What it does**: Maintains persistent track IDs on detected targets across frames, predicts where a fast-moving target will be **next frame** using Kalman filtering on the ARM CPU.

| Component           | Runs On        | Function                                 |
|---------------------|----------------|------------------------------------------|
| Detection CNN       | NPU (PL)       | Bounding box + class every frame         |
| Kalman Filter       | ARM PS7 (C++)  | Predict next position from velocity      |
| Track Association   | ARM PS7 (C++)  | Hungarian algorithm: match detections    |
| Trajectory Overlay  | ARM PS7 (C++)  | Draw predicted path on HDMI output       |

**Ballistic Trajectory Estimation**: Once a projectile or fast-moving target is tracked for ≥3 frames, the ARM CPU fits a **parabolic trajectory model** (accounting for gravity drop at known range) and displays the predicted impact point on screen.

---

### 3.5 🌡️ Thermal + Visible Fusion (Optional Upgrade)
**What it does**: Fuses a thermal IR channel with visible light for nighttime or camouflaged target detection.

| Spec                | Details                                        |
|---------------------|------------------------------------------------|
| Thermal Camera      | OV5647 IR + FLIR Lepton 3.5 (via SPI)         |
| Fusion Method       | Concatenate IR as 4th input channel to CNN     |
| Benefit             | Detects humans / engines even behind cover     |
| NPU Impact          | Minor (one extra channel in first conv layer)  |

---

## 4. Model Architecture for Your DL Engineer

### Primary Model: BVNet-Nano (Ballistic Vision Network)
Design a unified detection backbone optimized for your hardware:

```
Input: [320 × 320 × 3] or [320 × 320 × 4 with thermal]
↓
ConvDW 3×3, stride=2, 3→16ch          [160×160×16]
ReLU6
↓
InvertedResidual ×2, expand=1, 16→16ch [160×160×16]
↓
InvertedResidual ×3, expand=6, 16→32ch [80×80×32]   ← Small object head here
↓
InvertedResidual ×4, expand=6, 32→64ch [40×40×64]   ← Medium object head here
↓
InvertedResidual ×3, expand=6, 64→96ch [20×20×96]   ← Large object head here
↓
Detection Heads (3 scales) — On ARM CPU
↓
Output: [N × (4 + 1 + num_classes)] bounding boxes
```

**All channel counts are multiples of 8** ✅ — 100% NPU utilization at every layer.

---

## 5. Dataset Requirements

| Dataset                    | Source / Note                                          |
|----------------------------|--------------------------------------------------------|
| VisDrone 2023              | UAV imagery, drone detection benchmark                 |
| LADD (Large Aerial Drone)  | Long-range aerial object detection                     |
| MFSD (Muzzle Flash)        | Collect synthetic + real firing event frames           |
| COCO Person + Vehicle      | Standard detection pretraining backbone                |
| Custom Thermal Data        | If using thermal fusion — collect 500+ paired frames   |

**Synthetic Data Strategy**: Use a game engine (Unreal / Unity) to render ballistic scenarios for:
- Projectile trails at different ranges
- Muzzle flash events at different angles / weapons
- Fast-moving drone paths against sky backgrounds

---

## 6. Training Configuration

```python
# Recommended Training Setup
framework     = "PyTorch 2.x"
quant_method  = "QAT (torch.ao.quantization)"
backbone_init = "MobileNetV2 pretrained on ImageNet (FP32)"
fine_tune     = "COCO + VisDrone + custom ballistic data"
input_size    = (320, 320)
batch_size    = 64
epochs        = 200  # FP32, then 50 QAT epochs
optimizer     = "AdamW, lr=1e-3, cosine decay"
augmentation  = ["RandomFlip", "Mosaic", "ColorJitter",
                 "MotionBlur",   # Critical for fast-moving targets
                 "BrightnessBurst"]  # Simulate muzzle flash events
```

---

## 7. NPU Export Checklist for Each Layer

Your DL engineer must provide the following per-layer files:

| File                     | Format        | Content                                      |
|--------------------------|---------------|----------------------------------------------|
| `weights_layerN.bin`     | INT8 flat     | Weight tensor in [OC, IC, KH, KW] order      |
| `bias_layerN.bin`        | INT32 flat    | Fused BN bias per output channel             |
| `M0_layerN.bin`          | UINT32 flat   | Per-channel scale multiplier                 |
| `nshift_layerN.bin`      | UINT8 flat    | Per-channel right-shift amount               |
| `bvnet_config.json`      | JSON          | Full layer topology, strides, activations    |

---

## 8. HDMI Output — Tactical Display HUD

The PYNQ-Z2 HDMI output can render a real-time **Heads-Up Display (HUD)** overlaying inference results on the live video feed:

```
┌──────────────────────────────────────────────┐
│  [THREAT: HIGH]   TARGET #3   CONF: 94.2%    │
│  ┌─────────────────┐                         │
│  │                 │  ← Bounding Box         │
│  │   [VEHICLE]     │                         │
│  └────────┬────────┘                         │
│           │ ← Predicted trajectory (parabola)│
│           ▼ ← Estimated impact point         │
│  RANGE: ~240m  |  VELOCITY: ~12 m/s NW       │
│  FLASH DETECTED: Sector 3 [0.32ms AGO]       │
└──────────────────────────────────────────────┘
```

Rendered by the ARM CPU and composited onto the live HDMI stream in real-time.

---

## 9. Performance Summary

| Sub-Application            | NPU Load | FPS     | Latency  |
|----------------------------|----------|---------|----------|
| Target Detection (320×320) | ~65%     | 25 FPS  | 40ms     |
| Muzzle Flash Detection     | ~20%     | 60 FPS  | 16ms     |
| UAV/Drone Detection        | ~70%     | 18 FPS  | 55ms     |
| Multi-target Tracking      | ~65%     | 22 FPS  | 45ms     |
| Full Fusion Pipeline       | ~85%     | 15 FPS  | 66ms     |

---

*Specification finalized by FPGA Architecture Team. Hardware: TinyNPU200J @ 125 MHz, WNS = +0.204 ns.*
