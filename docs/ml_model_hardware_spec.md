# ML Model Hardware Constraints Specification
**Target Hardware:** Custom Zynq-7020 YOLO-style NPU Accelerator

To ensure the Deep Learning model can be successfully deployed onto the custom FPGA hardware accelerator, the AI/ML engineer must strictly adhere to the following architectural constraints during model design, training, and export.

---

## 1. Network Architecture & Output Head
The hardware is specifically designed to accelerate a **YOLOv8-style anchor-free detection head** with Distribution Focal Loss (DFL). 

*   **Regression Mechanism:** The model MUST use DFL for bounding box regression, NOT direct coordinate regression.
*   **DFL Bins (`REG_MAX`):** The hardware expects exactly **17 bins** per edge (`REG_MAX = 16`).
*   **Total Regression Channels:** Each anchor/grid cell must output `4 edges * 17 bins = 68 channels` for bounding box regression.
*   **Classification Channels:** The hardware supports up to **200 classes**. The classification head must output exactly `N` channels (where `N <= 200`).
*   **Activation Functions (CRITICAL):**
    *   Do **NOT** apply `Sigmoid` or `Softmax` at the very end of the model prior to export.
    *   The hardware performs **Logit-domain thresholding** for classes (filtering happens before any sigmoid is calculated to save DSPs).
    *   The hardware performs a **custom max-subtracted exponential LUT** for the DFL softmax.
    *   *Export Requirement:* The model must output **RAW LOGITS** for both the classification branch and the regression branch.

## 2. Quantization Requirements
The entire NPU data path is built on fixed-point arithmetic to fit within the Zynq-7020's limited DSP and BRAM resources.

*   **Precision:** The model must be fully Quantization-Aware Trained (QAT) or Post-Training Quantized (PTQ) to **INT8**.
*   **Symmetric vs Asymmetric:** Symmetric INT8 quantization is heavily preferred for the intermediate convolution layers.
*   **Detection Head Inputs:** The final tensors streaming into the NPU Detection Head must be **INT8 signed logits** (range: `-128` to `+127`).
*   **Scale Factors:** The hardware relies on a fixed scale factor for the DFL exponential LUT (currently tuned for a scale of `1/16` or `0.0625`). If the PTQ calibration drastically alters the logit scale of the final layer, the FPGA engineer must be notified so the `exp_lut` and `sigmoid_lut` hexadecimal files can be regenerated.

## 3. Supported Operations (Backbone & Neck)
The general matrix multiply (GEMM) systolic array and routing logic support a specific subset of operations. Do not use exotic layers.

*   **Convolutions:** standard `Conv2D`, `DepthwiseConv2D`, `PointwiseConv2D (1x1)`.
*   **Activations:** `ReLU`, `LeakyReLU`, or `SiLU/Swish` (SiLU is supported via hardware LUT).
*   **Pooling:** `MaxPool2d`, `AvgPool2d`.
*   **Upsampling:** Nearest-neighbor `Upsample` (avoid transposed convolutions / deconv).
*   **Skip Connections:** Standard addition/concatenation.

## 4. Post-Processing & NMS
The ML engineer does **not** need to include Non-Maximum Suppression (NMS) or Top-K selection in the ONNX/TFLite graph.

*   **Hardware Top-K:** The FPGA PL (Programmable Logic) automatically filters out background cells and compacts the surviving candidates into a sparse 128-bit memory stream.
*   **Software NMS:** Class-aware NMS and integer-based Intersection-over-Union (IoU) are handled by bare-metal C++ firmware running on the RISC-V soft-core. 
*   *Conclusion:* The ML model's job ends at the raw multi-scale feature maps.

## 5. Training Checklist for the ML Engineer
- [ ] Train a YOLOv8-nano or YOLOv8-micro topology.
- [ ] Set `reg_max=16` in the YOLOv8 configuration.
- [ ] Train on your custom dataset (up to 200 classes).
- [ ] Remove the final `Sigmoid`/`Softmax` activations from the Detect head in PyTorch.
- [ ] Run PTQ (Post-Training Quantization) to INT8 using a representative calibration dataset.
- [ ] Verify that the final output tensors are signed INT8.
- [ ] Export to ONNX. Send the `.onnx` file to the FPGA team.
