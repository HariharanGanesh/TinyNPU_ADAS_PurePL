$html = @"
<html>
<head><style>body { font-family: Arial; line-height: 1.5; } h1 { color: #2E74B5; font-size: 16pt; margin-bottom: 2px;} h2 { color: #2E74B5; font-size: 14pt; } p { font-size: 11pt; margin-top: 2px;}</style></head>
<body>
<h1>Proposal Title</h1>
<p><strong>TinyNPU: 100% PL-Based Deterministic Edge AI Accelerator for Real-Time Drone Tracking</strong></p>

<h1>Track 1, 2 or 3 (Application Domain)</h1>
<p><strong>Track 1 - FPGA</strong><br/>
(Application Domain: Defence & Security)</p>

<h1>Abstract</h1>
<p>Deploying high-performance Artificial Intelligence at the tactical edge is fundamentally constrained by Size, Weight, and Power (SWaP) limitations and rigid System-on-Chip (SoC) vendor lock-in. Traditional CPU/GPU solutions suffer from massive power draw and latency jitter due to Operating System overhead, while standard Neural Processing Units (NPUs) rely heavily on hard Processing Systems (PS). This proposal introduces <strong>TinyNPU</strong>, a 100% Programmable Logic (PL)-based, board-agnostic AI accelerator. Validated on the Zynq-7020 architecture, the TinyNPU utilizes a custom 20x8 INT8 Systolic Array and a dedicated Depthwise Convolution Engine to deliver over 20 GMACs/sec at 125 MHz. Achieving an unprecedented 92.7% DSP packing efficiency with fully closed timing, TinyNPU guarantees 100% deterministic, microsecond-latency execution for mission-critical Real-Time Drone Tracking.</p>

<h1>Main Idea</h1>
<p>The core innovation is the architectural decoupling of the NPU from the hard ARM Processing System (PS). TinyNPU is designed purely in hardware description language (RTL) to be instantiated directly in the FPGA fabric (PL).</p>
<p><strong>Key Implementation Details:</strong></p>
<ul>
    <li><strong>Compute Core:</strong> A 20x8 Systolic Array optimized for INT8 quantization, yielding 160 MAC operations per clock cycle.</li>
    <li><strong>Depthwise Engine (dw_engine):</strong> A custom hardware block explicitly designed to accelerate MobileNet/TinyYOLO topologies, which standard systolic arrays struggle with.</li>
    <li><strong>Data Path:</strong> Standard AXI-4 and AXI-Stream interfaces allow direct peripheral integration (e.g., HDMI RX to NPU to HDMI TX) without PS memory bottlenecks.</li>
    <li><strong>Proven Hardware:</strong> Synthesized and implemented with 204/220 DSPs (92.73% utilization) and 63.55% LUT utilization, passing timing closure (+0.116 ns WNS) at a 125 MHz core clock.</li>
</ul>

<h2>System-Level Block Diagram</h2>
<p><em>(Please insert a block diagram image here showing AXI-Stream inputs feeding into the 20x8 array and outputting to HDMI).</em></p>

<h1>Application</h1>
<p><strong>1. Real-Time Drone Tracking (Primary)</strong><br/>
In combat and security scenarios, detecting hostile drones requires zero-latency processing. TinyNPU processes high-framerate video feeds directly at the edge, utilizing a quantized MobileNetV2-SSD topology to draw bounding boxes around UAVs in real-time without relying on cloud connectivity.</p>

<p><strong>2. Autonomous Navigation in High-Density Environments</strong><br/>
Because TinyNPU is board-agnostic, it can be embedded into custom ASICs for UAVs to perform real-time obstacle avoidance and vehicle detection in fog or dust, where power budgets cannot support standard GPUs.</p>

<h2>Proposed Solution Flowchart</h2>
<p><em>(Insert Flowchart Here: Camera -> AXI Stream -> Pre-process -> TinyNPU MACs -> Post-Process -> HDMI Out)</em></p>

<h1>Value Add</h1>
<ul>
    <li><strong>100% Deterministic Execution:</strong> By eliminating the Operating System (Linux) overhead, TinyNPU guarantees zero latency jitter. A frame will always take the exact same number of clock cycles to process.</li>
    <li><strong>Unprecedented Resource Packing:</strong> Squeezing 92.7% DSP utilization out of a Zynq-7020 while maintaining a 125 MHz clock (+0.116 WNS) is a highly complex routing achievement, maximizing silicon efficiency.</li>
    <li><strong>Sovereign IP Integration:</strong> As a board-agnostic, PL-only design, defense contractors can securely embed the TinyNPU RTL directly into classified custom silicon, avoiding vendor lock-in.</li>
    <li><strong>Ultra-Low SWaP:</strong> Delivers real-time inference without the thermal output or massive power draw of embedded GPUs.</li>
</ul>

<h1>References</h1>
<ol>
    <li>Howard, A. G., et al. (2017). "MobileNets: Efficient Convolutional Neural Networks for Mobile Vision Applications." arXiv preprint arXiv:1704.04861.</li>
    <li>Xilinx Inc. (2020). Zynq-7000 SoC Data Sheet: DC and AC Switching Characteristics.</li>
    <li>Jouppi, N. P., et al. (2017). "In-Datacenter Performance Analysis of a Tensor Processing Unit." Proceedings of the 44th Annual International Symposium on Computer Architecture.</li>
</ol>
</body>
</html>
"@

$tempHtml = "$pwd\temp_proposal.html"
$html | Out-File -Encoding UTF8 $tempHtml

$word = New-Object -ComObject Word.Application
$word.Visible = $false
$doc = $word.Documents.Open($tempHtml)

$docxPath = "$pwd\TinyNPU_Hackathon_Proposal.docx"
# 16 = wdFormatDocumentDefault
$doc.SaveAs([ref]$docxPath, [ref]16)
$doc.Close()
$word.Quit()
Remove-Item $tempHtml
