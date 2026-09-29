$ppt = New-Object -ComObject PowerPoint.Application
$ppt.Visible = [Microsoft.Office.Core.MsoTriState]::msoTrue
$presentation = $ppt.Presentations.Add()

# Title slide (Layout 1)
$slide = $presentation.Slides.Add(1, 1)
$slide.Shapes.Title.TextFrame.TextRange.Text = "TinyNPU: 100% PL-Based Edge AI Accelerator"
$slide.Shapes.Placeholders.Item(2).TextFrame.TextRange.Text = "High-Efficiency, Board-Agnostic Silicon IP for Defense & Aerospace"

# Slide 1
$slide2 = $presentation.Slides.Add(2, 2)
$slide2.Shapes.Title.TextFrame.TextRange.Text = "Team Details"
$slide2.Shapes.Placeholders.Item(2).TextFrame.TextRange.Text = "Team: [Silicon Innovators]`nLead: [Your Name]`nSize: [E.g., 3]"

# Slide 2
$slide3 = $presentation.Slides.Add(3, 2)
$slide3.Shapes.Title.TextFrame.TextRange.Text = "Problem"
$slide3.Shapes.Placeholders.Item(2).TextFrame.TextRange.Text = "The Bottleneck: High-performance AI at the tactical edge is fundamentally constrained by SWaP limitations and rigid SoC vendor lock-in.`n`nWho Hurts the Most?: Defense contractors, aerospace agencies, autonomous systems.`n`nThe Critical Gap: Traditional architectures fail to deliver deterministic execution without massive power overhead or bulky OS.`n`nComparison: CPUs/GPUs have massive power draw and high latency jitter. Legacy NPUs have rigid PS dependency. TinyNPU has ultra-low SWaP and 100% deterministic execution."

# Slide 3
$slide4 = $presentation.Slides.Add(4, 2)
$slide4.Shapes.Title.TextFrame.TextRange.Text = "Solution - Describe your Innovation"
$slide4.Shapes.Placeholders.Item(2).TextFrame.TextRange.Text = "[Insert Block Diagram: AXI Stream Data -> 100% PL Core -> Output]`n`n100% PL-Based (Board-Agnostic): Truly synthesizable IP block. Zero reliance on hard Processing Systems (PS).`n`nHardware-Optimized Inference: Custom INT8 Quantization data paths mapped directly to native DSP slices.`n`nDeterministic Execution: Zero Operating System bloat. Guarantees microsecond-level execution consistency."

# Slide 4
$slide5 = $presentation.Slides.Add(5, 2)
$slide5.Shapes.Title.TextFrame.TextRange.Text = "Customer"
$slide5.Shapes.Placeholders.Item(2).TextFrame.TextRange.Text = "TAM / SAM (Total Addressable Market) KPIs:`n- `$38.8B | Edge AI Hardware Market (2030)`n- 18.8% | Industry CAGR`n- `$5.0B+ | Defense & Autonomous Robotics Niche`n`nCore B2B Segments:`n- Defense & Military Integrators`n- Aerospace (ISRO/DRDO Vendors)`n- Autonomous Robotics"

# Slide 5
$slide6 = $presentation.Slides.Add(6, 2)
$slide6.Shapes.Title.TextFrame.TextRange.Text = "Business"
$slide6.Shapes.Placeholders.Item(2).TextFrame.TextRange.Text = "Revenue Engine:`n1. IP Licensing: Upfront capital via sale of RTL/Bitstream.`n2. NRE (Non-Recurring Engineering): Premium consulting fees for custom tweaks.`n3. Volume Royalties: Per-chip scaling revenue.`n`nPricing Model:`n- Base IP License: `$50,000 - `$100,000 (Highly competitive B2B pricing compared to in-house custom silicon R&D)."

# Slide 6
$slide7 = $presentation.Slides.Add(7, 2)
$slide7.Shapes.Title.TextFrame.TextRange.Text = "Validation"
$slide7.Shapes.Placeholders.Item(2).TextFrame.TextRange.Text = "Validation Status: Prototype Synthesized & Silicon Proven (✅ YES)`n`nHardware Benchmarks (Zynq-7020):`n- Frequency: 125.0 MHz (Fully closed timing, +0.116ns WNS)`n- Compute: 20+ GMACs/sec (204 active DSPs)`n- DSP Utilization: 92.7% (Extreme layout efficiency)`n- HDMI Integration: 200 MHz continuous vision stream.`n`nTechnology Readiness Level:`n- Status: TRL 4 achieved. Hardware verified, Bitstream generated."

# Slide 7
$slide8 = $presentation.Slides.Add(8, 2)
$slide8.Shapes.Title.TextFrame.TextRange.Text = "IP (Intellectual Property)"
$slide8.Shapes.Placeholders.Item(2).TextFrame.TextRange.Text = "Architectural Novelty:`nThe complete decoupling of the hardware-software interface from hard processors. By confining scheduling and routing entirely within Programmable Logic, TinyNPU achieves an unprecedented balance of low latency and minimal area footprint.`n`nIP Strategy:`n- Patented? NO.`n- Current Posture: Maintained as a Trade Secret. Provisional patent filing planned."

$path = "$pwd\TinyNPU_Premium_Pitch.pptx"
$presentation.SaveAs($path)
$ppt.Quit()
