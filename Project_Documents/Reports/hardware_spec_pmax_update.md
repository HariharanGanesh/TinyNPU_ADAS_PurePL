# NPU300PM (TinyNPU200JPMAX) — Deep Learning Model Design Specification
**For: DL Model Engineer (Hardware-Dedicated Training Pipeline)**
**Hardware Platform**: PYNQ-Z2 (Xilinx Zynq-7020, xc7z020clg400-1)
**Prepared by**: FPGA Architecture Team

---

## 1. Hardware At A Glance (UPDATED PMAX VERSION)

| Parameter                    | Value                            |
|------------------------------|----------------------------------|
| NPU Clock                    | 125 MHz                          |
| Systolic Array Topology      | **26 rows × 8 columns**          |
| Total Processing Elements    | **208 INT8 MACs** (All DSP-Accelerated) |
| Peak Throughput (Compute)    | **52.0 GOPS (0.052 TOPS)**       |
| Drone Tracking Capability    | Up to **~65 m/s** speed targets  |
| External DDR3 Memory         | 512 MB (shared PS+PL)            |
| Target Host API              | PYNQ Python (Jupyter Notebook)   |

---

## 2. Quantization Requirements (CRITICAL — Read First)

The NPU **only supports INT8 arithmetic**. Your model must be quantized before deployment. Standard FP32 models will not run.

| Parameter               | Requirement                                      |
|-------------------------|--------------------------------------------------|
| Activation Precision    | **INT8** (signed, [-128, 127])                   |
| Weight Precision        | **INT8** (signed, [-128, 127])                   |
| Accumulator Precision   | INT32 (handled internally by NPU)                |
| Bias Precision          | INT32 (fused into requantization unit)           |
| Requantization Scheme   | **Per-channel** scale (M0) + right-shift (n)     |
| Recommended Framework   | PyTorch QAT (Quantization-Aware Training)        |

---

## 3. Supported Neural Network Operators

| Operator                      | Supported? | Notes                                          |
|-------------------------------|------------|------------------------------------------------|
| Depthwise Convolution (3×3)   | ✅ Yes      | Dedicated hardware line buffers                |
| Pointwise Convolution (1×1)   | ✅ Yes      | Mapped to 26×8 systolic array                  |
| Standard Convolution (3×3)    | ✅ Yes      | Mapped via weight unrolling                    |
| Batch Normalization           | ✅ Yes      | **Must be fused into bias** offline            |
| ReLU / ReLU6                  | ✅ Yes      | Hardware activation unit natively supports     |
| Leaky ReLU (α=0.125)          | ✅ Yes      | Hardware arithmetic right shift natively       |
| HardSwish                     | ✅ Yes      | Dedicated 256-entry hardware LUT ROM           |
| 2×2 MaxPool / AvgPool         | ✅ Yes      | Dedicated hardware pooling unit                |
| Fully Connected / Softmax     | ❌ No       | Must run on the PS7 ARM Cortex-A9 CPU          |

---

## 4. Model Architectural Constraints (NEW LIMITS)

Design your CNN with the following hard limits in mind:

| Constraint                        | Limit                                    |
|-----------------------------------|------------------------------------------|
| Preferred channel granularity     | **Multiples of 8** (for 100% efficiency) |
| Max array processing block        | **26 input channels** simultaneously     |
| Max weight buffer size (BRAM)     | ~2MB per layer                           |
| Max input image size (HDMI path)  | 1280 × 720 × 3 (RGB, 8-bit)             |
| Total Parameter Budget            | Keep under **10 MB**                     |

---

## 5. Recommended Model Architecture

Design a **MobileNetV2-Nano** or **YOLO-Nano** style architecture. This family is purpose-built for depthwise separable convolutions which are the exact operations this NPU hardware was engineered around.

```
Input: 320×320×3 (or 416×416 for drone detection)
↓
Conv2d 3×3, stride=2, 3→16 ch (Must be multiple of 8)
↓
Depthwise + Pointwise stages (Use HardSwish or ReLU6)
↓
Detection Heads (Run on ARM CPU)
```

**Key Directives for the DL Engineer:**
1. Keep all channel counts as multiples of 8.
2. The hardware was upgraded to a 26-row array. You can feed up to 26 input channels per compute cycle now, which speeds up deeper layers significantly.
3. Fuse BatchNorm into the bias at export time (standard practice for QAT pipelines).

---

## 6. Files Your Export Pipeline Must Generate

Your training pipeline must output the following raw binaries for the hardware:

| File                        | Format          | Description                                     |
|-----------------------------|-----------------|--------------------------------------------------|
| `weights_layerN.bin`        | Flat INT8 binary| Weight tensor, channel-major order               |
| `bias_layerN.bin`           | Flat INT32 binary| Fused BN + bias per output channel              |
| `scale_layerN.bin`          | Flat UINT32 binary| M0 multiplier per output channel              |
| `shift_layerN.bin`          | Flat UINT8 binary | n_shift per output channel                    |
| `npu300pm.bit`              | Vivado Bitstream| **Pre-built by FPGA team. Use as-is.**           |
| `npu300pm.hwh`              | Hardware Handoff| **Pre-built by FPGA team. Use as-is.**           |

---

*Hardware finalized by FPGA Architecture Team. Clock: 125 MHz. WNS: +0.056 ns. TNS: 0.000 ns.*
