# TinyNPU200J — Deep Learning Model Design Specification
**For: DL Model Engineer (Hardware-Dedicated Training Pipeline)**
**Hardware Platform**: PYNQ-Z2 (Xilinx Zynq-7020, xc7z020clg400-1)
**Prepared by**: FPGA Architecture Team

---

## 1. Hardware At A Glance

| Parameter                    | Value                            |
|------------------------------|----------------------------------|
| NPU Clock                    | 125 MHz                          |
| Systolic Array Topology      | 20 rows × 8 columns              |
| Total Processing Elements    | 160 INT8 MACs                    |
| Peak Throughput (Compute)    | **20.0 GOPS** (INT8)             |
| DSP48E1 Slices Used          | 160 / 220 (73%)                  |
| On-Chip BRAM                 | 140 × 36K blocks (5.1 Mb)        |
| External DDR3 Memory         | 512 MB (shared PS+PL)            |
| AXI DMA Bus Width            | 32-bit @ 125 MHz                 |
| Available PL DDR Bandwidth   | ~1.0 GB/s (AXI4 Memory Mapped)   |
| HDMI Input Resolution        | Up to 720p @ 60fps               |
| HDMI Output Resolution       | Up to 720p @ 60fps               |
| Target Host API              | PYNQ Python (Jupyter Notebook)   |

---

## 2. Quantization Requirements (CRITICAL — Read First)

The NPU **only supports INT8 arithmetic**. Your model must be quantized before deployment.

| Parameter               | Requirement                                      |
|-------------------------|--------------------------------------------------|
| Activation Precision    | **INT8** (signed, [-128, 127])                   |
| Weight Precision        | **INT8** (signed, [-128, 127])                   |
| Accumulator Precision   | INT32 (handled internally by NPU)                |
| Bias Precision          | INT32 (fused into requantization unit)           |
| Requantization Scheme   | **Per-channel** scale (M0) + right-shift (n)     |
| Quantization Method     | Post-Training Quantization (PTQ) or QAT          |
| Recommended Framework   | PyTorch + ONNX → custom INT8 export pipeline     |

> **Important**: The NPU uses the standard **ARM NN / TFLite-compatible** per-channel affine quantization format:
> `q = clamp(round(r / scale) + zero_point, -128, 127)`
> The requantizer on the hardware implements: `output = (acc + bias) * M0 >> n_shift`

---

## 3. Supported Neural Network Operators

| Operator                      | Supported? | Notes                                          |
|-------------------------------|------------|------------------------------------------------|
| Depthwise Convolution (3×3)   | ✅ Yes      | Dedicated line buffer + pipelined 8×8 MAC      |
| Pointwise Convolution (1×1)   | ✅ Yes      | Mapped to systolic array directly              |
| Standard Convolution (3×3)    | ✅ Yes      | Mapped to systolic array via weight unrolling  |
| Batch Normalization           | ✅ Yes      | Fused into bias + requantization offline       |
| ReLU                          | ✅ Yes      | Hardware activation unit (act_sel = 3'b000)    |
| ReLU6                         | ✅ Yes      | Clamped to [0,6] (act_sel = 3'b010)            |
| Leaky ReLU (α=0.125)          | ✅ Yes      | Arithmetic right shift by 3 (act_sel = 3'b011) |
| HardSwish                     | ✅ Yes      | 256-entry LUT ROM (act_sel = 3'b100)           |
| Identity / Linear             | ✅ Yes      | Bypass mode (act_sel = 3'b001)                 |
| 2×2 MaxPool                   | ✅ Yes      | Dedicated hardware pooling unit                |
| 2×2 AvgPool                   | ✅ Yes      | Sum-shift accumulate (pool_mode = 2'b10)       |
| Global Average Pooling        | ⚠️ Partial  | Must implement as tiled AvgPool in firmware    |
| Fully Connected               | ❌ No       | Must run on PS7 ARM Cortex-A9 CPU              |
| Attention / Transformers      | ❌ No       | Not supported on this hardware generation      |
| Sigmoid / Softmax             | ❌ No       | Must compute on ARM CPU post-inference         |

---

## 4. Model Architectural Constraints

Design your CNN with the following hard limits in mind:

| Constraint                        | Limit                                    |
|-----------------------------------|------------------------------------------|
| Max input channels per tile       | 8 (one full array column)                |
| Max output channels per tile      | 8 (one full array column)                |
| Preferred channel granularity     | **Multiples of 8** (for full efficiency) |
| Max weight buffer size (BRAM)     | ~2MB per layer (must fit BRAM)           |
| Max activation buffer size        | Determined by input resolution           |
| Max input image size (HDMI path)  | 1280 × 720 × 3 (RGB, 8-bit)             |
| Kernel sizes supported            | 1×1, 3×3 (others need custom firmware)  |
| Stride support                    | 1, 2 (stride >2 needs software tiling)  |
| Padding                           | Same / Valid (both supported)            |

---

## 5. Recommended Model Architectures

Design a **MobileNet-style** architecture. This family is purpose-built for depthwise separable convolutions which are the exact operations this NPU hardware was engineered around.

### Recommended Starting Point: MobileNetV2-Nano
```
Input: 224×224×3 (or 320×320×3 for higher accuracy)
↓
Conv2d 3×3, stride=2, 3→16 ch     → 112×112×16
↓
Depthwise + Pointwise ×5           → Multiple stages
↓
Global Average Pool                → On CPU
↓
FC + Softmax                       → On CPU (ARM)
↓
Output: N-class probability vector
```

**Key Design Principles:**
- **Keep all channel counts as multiples of 8** for 100% NPU utilization
- **Fuse BatchNorm into the bias** at export time (standard practice for QAT/INT8 pipelines)
- **Use ReLU6 or HardSwish** — both are natively supported in hardware
- **Avoid residual skip connections** that span large channel count mismatches unless you implement the add in software
- **Total model parameter budget**: Keep under **10 MB** to stay within BRAM + DDR feasibility

---

## 6. Training Pipeline Recommendations

```
1. Train in FP32 using PyTorch (standard training)
2. Apply Quantization-Aware Training (QAT) for best accuracy
   - Use torch.quantization.prepare_qat()
   - Simulate INT8 quantization during training
3. Export to ONNX
4. Run per-channel calibration to extract:
   - M0 (scale multiplier per output channel)
   - n_shift (bit-shift amount per output channel)
   - bias_int32 (fused BatchNorm bias)
5. Pack weights into flat binary blobs for DMA transfer
```

Calibration data: Use **minimum 256 representative images** from your target dataset.

---

## 7. Performance Estimates

| Model                        | Estimated FPS (720p) | Accuracy Potential |
|------------------------------|---------------------|--------------------|
| MobileNetV2-Nano (224×224)   | ~45–60 FPS           | ~72% Top-1 (ImageNet) |
| MobileNetV2-Small (320×320)  | ~20–30 FPS           | ~78% Top-1           |
| Custom Object Detector       | ~15–25 FPS           | Task-dependent       |
| Semantic Segmentation (tiny) | ~10–15 FPS           | Task-dependent       |

---

## 8. Applications You Can Build With This Hardware

### 🎯 Real-Time Vision Classification
- **Object Classification**: Detect and classify objects (vehicles, animals, products) in a live HDMI video feed.
- **Defect Detection**: Industrial quality control — inspect manufactured parts for cracks, misalignment, or contamination.
- **Plant Disease Detection**: Point a camera at crops and detect leaf diseases in real time.

### 🚗 Edge Autonomous / Robotics
- **Lane Detection**: Segment lane markings from a camera feed for a rover or small vehicle.
- **Obstacle Classification**: Identify whether obstacles ahead are humans, vehicles, or static objects.
- **Gesture Recognition**: Classify hand gestures for touchless machine control.

### 🏥 Medical / Healthcare
- **Skin Lesion Screening**: Run a lightweight dermatology model on camera images for preliminary screening.
- **Pill Identification**: Classify pharmaceutical tablets by shape and color in a production line.
- **Eye Disease Triage**: Classify retinal camera images for diabetic retinopathy (lightweight model).

### 🏠 Smart Environment / IoT
- **Face Detection**: Detect faces in a video stream for smart door locks or attendance systems.
- **Fire / Smoke Detection**: Classify live video frames to trigger an early safety alarm.
- **Crowd Density Estimation**: Count and classify crowd density in a surveillance feed.
- **PPE Compliance**: Detect if workers are wearing helmets or safety vests.

### 🎓 Research & Education
- **FPGA-Accelerated Inference Demo**: Live showcase of hardware AI acceleration at 125 MHz.
- **Energy-Efficient AI Benchmarking**: Compare INT8 NPU vs. CPU inference power consumption.
- **Custom Layer Research**: Rapidly prototype new hardware-friendly activation functions.

---

## 9. Files Your Model Export Pipeline Must Generate

| File                        | Format          | Description                                     |
|-----------------------------|-----------------|--------------------------------------------------|
| `weights_layerN.bin`        | Flat INT8 binary| Weight tensor for each layer, channel-major order|
| `bias_layerN.bin`           | Flat INT32 binary| Fused BN + bias per output channel              |
| `scale_layerN.bin`          | Flat UINT32 binary| M0 multiplier per output channel              |
| `shift_layerN.bin`          | Flat UINT8 binary | n_shift per output channel                    |
| `model_config.json`         | JSON            | Layer topology, channel counts, strides          |
| `tinynpu200.bit`            | Vivado Bitstream| **Pre-built. Use as-is.**                        |
| `tinynpu200.hwh`            | Hardware Handoff| **Pre-built. Use as-is.**                        |

---

*Hardware designed and validated by the FPGA Architecture Team. Clock: 125 MHz, WNS: +0.204 ns.*
