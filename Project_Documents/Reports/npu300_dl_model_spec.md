# TinyNPU300PM / RISCV_ADAS_NPU Model Design Specifications

This document outlines the strict hardware constraints, supported operations, and quantization limits for designing Deep Learning models (e.g., in PyTorch or TensorFlow) that will compile and execute successfully on the fully synthesized Pure PL **TinyNPU300PM / RISCV_ADAS_NPU** architecture.

> [!IMPORTANT]
> Because this is a custom bare-metal FPGA hardware accelerator, your model architecture MUST adhere exactly to these layer geometries and operation types. If you use an unsupported operation in PyTorch (e.g., `nn.SiLU` or `nn.LayerNorm`), the firmware compiler will fail to map the graph to the hardware.

---

## 1. Core Hardware Geometry (The 160-MAC Array)

The heart of the NPU is a 20x8 Weight-Stationary Systolic Array. This physical structure directly dictates the most efficient tensor shapes for your Convolutional operations.

*   **Systolic Array Size:** `ARRAY_ROWS = 20`, `ARRAY_COLS = 8` (160 MACs total)
*   **Optimal Channel Multiples:** Hardware execution is heavily optimized for Output Channels ($C_{out}$) that are multiples of **8** and Input Channels ($C_{in}$) that are multiples of **20**.
*   **Maximum Activation Buffer Depth:** The internal PL BRAM can hold a maximum of **65,536** bytes per layer. 
*   **Operating Frequency:** The accelerator is routed and timed for **195 MHz**.

---

## 2. Quantization & Data Types

The NPU operates **exclusively in INT8**. There is absolutely no floating-point hardware on the chip.

*   **Activations (Inputs/Outputs):** Signed INT8 `[-128, 127]`
*   **Weights:** Signed INT8 `[-128, 127]`
*   **Biases:** Signed INT32
*   **Internal Accumulator:** INT32 (The 160-MAC array accumulates products without overflowing).
*   **Requantization:** The hardware uses a fixed-point `M0` multiplier and bit-shift logic to compress the INT32 accumulator back down to INT8 for the next layer. You must use PyTorch/TensorFlow Quantization-Aware Training (QAT) or Post-Training Quantization (PTQ) to generate the `M0` and `shift` parameters per channel.

> [!TIP]
> Use PyTorch's `torch.ao.quantization.FakeQuantize` during training to simulate INT8 precision boundaries, ensuring the model's accuracy doesn't collapse during deployment.

---

## 3. Supported Neural Network Layers

Your model graph can only consist of the following layers. 

### A. 2D Convolutions (`nn.Conv2d`)
*   **Kernel Sizes ($K$):** 1x1 or 3x3 only.
*   **Strides:** Stride 1 or Stride 2.
*   **Padding:** Padding 0 (Valid) or Padding 1 (Same).

### B. Depthwise Separable Convolutions
The hardware contains a dedicated parallel vector unit (20 Depthwise MACs) specifically for MobileNet-style layers.
*   **Groups:** Must equal `in_channels` ($C_{in}$).
*   **Recommendation:** Heavily prioritize $3\times3$ Depthwise Convolutions followed by $1\times1$ Pointwise Convolutions. The chip is architecturally optimized for this structure (e.g., MobileNetV1 / MobileNetV2 blocks).

### C. Pooling (`nn.MaxPool2d`, `nn.AvgPool2d`)
*   **Window Size:** Exactly 2x2.
*   **Stride:** Exactly 2.
*   *Note:* Global Average Pooling is supported at the end of the network by streaming the final tensor through the RISC-V software controller, not the hardware pooler.

---

## 4. Supported Activation Functions

The NPU contains a dedicated hardware Activation Unit that evaluates nonlinearities in a single clock cycle. You may use any of the following:

1.  **Identity:** Linear pass-through (No activation).
2.  **ReLU:** `max(0, x)`
3.  **ReLU6:** `clamp(x, 0, 6)`
4.  **Leaky ReLU:** Approximation using `alpha = 0.125` (computed in hardware as an arithmetic right shift by 3).
5.  **HardSwish:** $x \cdot \text{ReLU6}(x+3) / 6$. Implemented in hardware as a pre-computed 256-entry ROM LUT for extreme efficiency.

> [!WARNING]
> Standard Swish / SiLU ($x \cdot \sigma(x)$) or GELU are **not supported**. If you are importing an architecture like EfficientNet, you must swap its SiLU activations to HardSwish and retrain the model.

---

## 5. Post-Processing Hardware (Object Detection)

If you are designing an ADAS (Advanced Driver Assistance System) object detection model (e.g., YOLO or SSD), the NPU contains specialized ballistic logic for the final head:

*   **Bounding Box Extractor:** Automatically parses $x, y, w, h$ and confidence scores.
*   **Thresholding Unit:** Automatically drops bounding boxes below a pre-programmed INT8 confidence threshold before waking up the RISC-V processor, dramatically saving CPU cycles.
*   **Output Format:** You should design your final layer to output grid-based predictions (like YOLOv2 or YOLO Fastest) rather than complex anchor-free FCOS logic, as the hardware thresholding unit is designed for simple grid offsets.

---

## 6. Example: The Ideal NPU300 Block

To achieve the theoretical maximum utilization of the hardware, use Inverted Residual Blocks (MobileNetV2 style) shaped around the array dimensions:

```python
import torch.nn as nn

class NPU300_Optimized_Block(nn.Module):
    def __init__(self, in_channels, out_channels):
        super().__init__()
        # 1x1 Pointwise Expansion (Mapped to 20x8 Systolic Array)
        self.expand = nn.Conv2d(in_channels, in_channels * 2, kernel_size=1, bias=False)
        self.act1 = nn.Hardswish(inplace=True)
        
        # 3x3 Depthwise (Mapped to the 20-PE Vector Unit)
        self.depthwise = nn.Conv2d(in_channels * 2, in_channels * 2, kernel_size=3, 
                                   stride=1, padding=1, groups=in_channels * 2, bias=False)
        self.act2 = nn.Hardswish(inplace=True)
        
        # 1x1 Pointwise Projection (Mapped to 20x8 Systolic Array)
        self.project = nn.Conv2d(in_channels * 2, out_channels, kernel_size=1, bias=False)
        # Identity activation here

    def forward(self, x):
        x = self.expand(x)
        x = self.act1(x)
        x = self.depthwise(x)
        x = self.act2(x)
        x = self.project(x)
        return x
```

### Next Steps for the ML Engineer
1. Design your network using the `NPU300_Optimized_Block` structures.
2. Train it in PyTorch (FP32) on your dataset (e.g., BDD100k or COCO).
3. Apply PyTorch Post-Training Static Quantization (calibrate with validation data).
4. Export the weights to our custom `.hex` binary format using the NPU conversion script.
