$ppt = New-Object -ComObject PowerPoint.Application
$ppt.Visible = [Microsoft.Office.Core.MsoTriState]::msoTrue
$presentation = $ppt.Presentations.Add()

function Add-Slide($title, $content) {
    $slide = $presentation.Slides.Add($presentation.Slides.Count + 1, 2) # ppLayoutText
    $slide.Shapes.Title.TextFrame.TextRange.Text = $title
    $slide.Shapes.Item(2).TextFrame.TextRange.Text = $content
}

# Slide 1
$slide1 = $presentation.Slides.Add(1, 1) # ppLayoutTitle
$slide1.Shapes.Title.TextFrame.TextRange.Text = "TinyNPU: Ultra-High-Speed AI Accelerator"
$slide1.Shapes.Item(2).TextFrame.TextRange.Text = "Custom INT8 Systolic Array Implementation on PYNQ-Z2"

# Slide 2
Add-Slide "Introduction & Problem Statement" "The Challenge:
- Ballistic Vision: Tracking ultra-high-speed objects requires extremely low-latency object detection (YOLOv8n).
- The Bottleneck: Traditional CPUs and GPUs have too much software overhead and memory latency.

The Solution:
- A custom, hardware-accelerated NPU deployed directly on the edge using a Zynq-7020 FPGA.
- Fully deterministic, predictable latency running independent of an OS."

# Slide 3
Add-Slide "TinyNPU Architecture Highlights" "Core Engine:
- 8x8 Systolic Array: Weight-stationary dataflow architecture maximizing MAC utilization.
- INT8 Quantization: Replaces costly floating-point math with highly efficient 8-bit integer arithmetic.
- Custom Activation: Features a 5-segment piecewise linear approximation for Sigmoid and ReLU to save BRAM.

Data Movement:
- AMBA AXI4 Standards: AXI4-Lite for configuration registers and AXI4-Stream for high-bandwidth DMA.
- Double Buffering: Hides memory latency by pre-fetching weights and activations."

# Slide 4
Add-Slide "Overcoming Edge Constraints" "Depthwise Separable Convolution Optimization:
- Heavily optimized our engine for Depthwise convolutions used in modern edge networks like YOLO.
- DSP Optimization: Implemented a 2-stage adder tree to reduce DSP cascade depth, improving max clock frequency.

Pipelined Requantization:
- Built a custom 3-stage pipelined requantization unit to handle INT32 to INT8 down-scaling without breaking timing."

# Slide 5
Add-Slide "Rigorous Verification Methodology" "Approach:
- 100% Verilog/SystemVerilog: No Python in the critical verification path to ensure ASIC-portability.
- Hardware Scoreboard: Built a robust testbench that compares AXI-Stream outputs against a golden hex file bit-by-bit.

Results:
- Functional Accuracy: 100.00% detection accuracy verified over 4,096 bytes of simulated data.
- Zero Errors: 0 false positives, 0 false negatives."

# Slide 6
Add-Slide "FPGA Implementation & Timing Closure" "Target: Xilinx PYNQ-Z2 (XC7Z020CLG400-1)

The Challenge:
- Pushing the silicon to its limits resulted in initial routing congestion and negative setup slack.
- The Fix: Removed inferred latches in clock gating cells, heavily pipelined the requantization unit, and optimized adder trees.

The Result:
- Successfully closed Setup Timing with a Worst Negative Slack (WNS) of +0.052 ns.
- Synthesized in Out-Of-Context (OOC) mode for flawless system-level integration."

# Slide 7
Add-Slide "Conclusion & Next Steps" "Project Achievements:
- Designed, verified, and successfully synthesized a complete, ASIC-ready AI accelerator from scratch.
- Met all strict timing and resource constraints for the Zynq-7020 FPGA.

Next Steps (System Integration):
- Block Design: Package the TinyNPU as Vivado IP and connect it to the Zynq ARM Processing System.
- Software Overlay: Use PYNQ's Python environment to stream real image data from the ARM core to the NPU.
- Live Ballistic Testing: Deploy the system with a high-speed camera for real-time tracking."

$path = "D:\Final year project\TinyNPU_Presentation.pptx"
$presentation.SaveAs($path)
$ppt.Quit()
