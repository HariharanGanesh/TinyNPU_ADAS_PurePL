$ppt = New-Object -ComObject PowerPoint.Application
$ppt.Visible = [Microsoft.Office.Core.MsoTriState]::msoTrue
$presentation = $ppt.Presentations.Add()

# Title slide (Layout 1)
$slide = $presentation.Slides.Add(1, 1)
$slide.Shapes.Title.TextFrame.TextRange.Text = "TinyNPU - Board-Agnostic Edge AI Accelerator"
$slide.Shapes.Placeholders.Item(2).TextFrame.TextRange.Text = "DEEPSPRINT Hackathon`nDomain: VLSI & Semiconductor Tech"

# Slide 1
$slide2 = $presentation.Slides.Add(2, 2)
$slide2.Shapes.Title.TextFrame.TextRange.Text = "Team Details"
$slide2.Shapes.Placeholders.Item(2).TextFrame.TextRange.Text = "a. Team name: [Your Team Name]`nb. Team leader name: [Your Name]`nc. Team size: [E.g., 1 / 3 / 4]"

# Slide 2
$slide3 = $presentation.Slides.Add(3, 2)
$slide3.Shapes.Title.TextFrame.TextRange.Text = "Problem"
$slide3.Shapes.Placeholders.Item(2).TextFrame.TextRange.Text = "1. Problem Statement: Deploying AI at the edge faces a critical bottleneck: hardware is either too power-hungry or rigidly tied to specific vendor boards.`n`n2. Who has the problem?: Defense contractors, drone manufacturers, aerospace engineers.`n`n3. Current solution?: CPUs/GPUs consume too much power and suffer from OS jitter. Vendor-Locked NPUs are rigidly tied to specific SoC architectures.`n`n4. Why important?: In defense and aerospace, deterministic execution (zero-jitter) and ultra-low power are non-negotiable."

# Slide 3
$slide4 = $presentation.Slides.Add(4, 2)
$slide4.Shapes.Title.TextFrame.TextRange.Text = "Solution - Describe your Innovation"
$slide4.Shapes.Placeholders.Item(2).TextFrame.TextRange.Text = "TinyNPU: A 100% PL-Based, Board-Agnostic Neural Processing Unit`n`n* Fully Synthesizable IP: Designed 100% in Programmable Logic (PL). It can be ported to any FPGA fabric seamlessly.`n* High-Efficiency Architecture: Optimized specifically for low-latency, low-power inference at the edge.`n* Real-World Applicability: Capable of running quantized neural networks for real-time target detection."

# Slide 4
$slide5 = $presentation.Slides.Add(5, 2)
$slide5.Shapes.Title.TextFrame.TextRange.Text = "Customer"
$slide5.Shapes.Placeholders.Item(2).TextFrame.TextRange.Text = "1. Target Customer: B2B Defense technology firms, Aerospace agencies, Autonomous robotics startups, and semiconductor IP integrators.`n`n2. Market Size: The Edge AI Hardware market is projected to reach `$38.8 Billion by 2030 (CAGR of 18.8%)."

# Slide 5
$slide6 = $presentation.Slides.Add(6, 2)
$slide6.Shapes.Title.TextFrame.TextRange.Text = "Business"
$slide6.Shapes.Placeholders.Item(2).TextFrame.TextRange.Text = "1. Revenue model:`n  - IP Licensing: Licensing the TinyNPU RTL/bitstream to semiconductor firms and defense contractors.`n  - NRE (Non-Recurring Engineering): Customizing the NPU architecture.`n`n2. Selling price:`n  - Base IP License: `$50,000 - `$100,000 + royalties per chip."

# Slide 6
$slide7 = $presentation.Slides.Add(7, 2)
$slide7.Shapes.Title.TextFrame.TextRange.Text = "Validation"
$slide7.Shapes.Placeholders.Item(2).TextFrame.TextRange.Text = "1. Prototype? (Yes or No): Yes. (We have the RTL/bitstream ready and validated on FPGA fabric, benchmarking power and latency).`n`n2. TRL (Technology Readiness Level): TRL 4 (Component validation). We are actively moving towards TRL 5."

# Slide 7
$slide8 = $presentation.Slides.Add(8, 2)
$slide8.Shapes.Title.TextFrame.TextRange.Text = "IP (Intellectual Property)"
$slide8.Shapes.Placeholders.Item(2).TextFrame.TextRange.Text = "1. Novelty: The hardware-software interface is entirely decoupled from hard processors. Achieving ultra-low latency and minimal area footprint.`n`n2. Patent? (Yes or No): No (Currently maintaining as trade secret)."

$path = "$pwd\TinyNPU_DEEPSPRINT_Pitch.pptx"
$presentation.SaveAs($path)
$ppt.Quit()
