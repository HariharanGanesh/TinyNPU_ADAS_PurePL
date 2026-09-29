"""
generate_0th_review_ppt.py  —  TinyNPU300PM 0th Review Presentation Generator
Run: python generate_0th_review_ppt.py
Output: TinyNPU300PM_0th_Review.pptx (in same folder)

Requirements: pip install python-pptx
"""

import sys, os
from pathlib import Path

try:
    from pptx import Presentation
    from pptx.util import Inches, Pt
    from pptx.dml.color import RGBColor
    from pptx.enum.text import PP_ALIGN
except ImportError:
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "python-pptx"])
    from pptx import Presentation
    from pptx.util import Inches, Pt
    from pptx.dml.color import RGBColor
    from pptx.enum.text import PP_ALIGN

C_BG_MID   = RGBColor(0x0F, 0x1E, 0x3C)
C_BG_DARK  = RGBColor(0x06, 0x10, 0x26)
C_ACCENT1  = RGBColor(0x00, 0xD4, 0xFF)
C_ACCENT2  = RGBColor(0x7B, 0x2F, 0xFF)
C_ACCENT3  = RGBColor(0x00, 0xE5, 0x96)
C_WHITE    = RGBColor(0xFF, 0xFF, 0xFF)
C_LTGRAY   = RGBColor(0xB0, 0xC4, 0xDE)
C_YELLOW   = RGBColor(0xFF, 0xD7, 0x00)
C_ORANGE   = RGBColor(0xFF, 0x8C, 0x00)
C_RED_SOFT = RGBColor(0xFF, 0x45, 0x45)

SLIDE_W = Inches(13.333)
SLIDE_H = Inches(7.5)


def set_bg(slide, color):
    fill = slide.background.fill
    fill.solid()
    fill.fore_color.rgb = color


def tb(slide, text, x, y, w, h, size=14, bold=False, color=None,
       align=PP_ALIGN.LEFT, italic=False):
    color = color or C_WHITE
    tf = slide.shapes.add_textbox(x, y, w, h).text_frame
    tf.word_wrap = True
    p = tf.paragraphs[0]
    p.alignment = align
    run = p.add_run()
    run.text = text
    run.font.size = Pt(size)
    run.font.bold = bold
    run.font.italic = italic
    run.font.color.rgb = color


def rect(slide, x, y, w, h, fill, line=None, lw=Pt(1)):
    s = slide.shapes.add_shape(1, x, y, w, h)
    s.fill.solid(); s.fill.fore_color.rgb = fill
    if line:
        s.line.color.rgb = line; s.line.width = lw
    else:
        s.line.fill.background()
    return s


def lrect(slide, text, x, y, w, h, fill, tc=None, sz=12, bold=True,
          line=None, align=PP_ALIGN.CENTER):
    tc = tc or C_WHITE
    s = rect(slide, x, y, w, h, fill, line, Pt(1.2))
    tf = s.text_frame; tf.word_wrap = True
    p = tf.paragraphs[0]; p.alignment = align
    run = p.add_run(); run.text = text
    run.font.size = Pt(sz); run.font.bold = bold
    run.font.color.rgb = tc


def header(slide, title, sub=None):
    rect(slide, Inches(0), Inches(0), SLIDE_W, Inches(1.3), RGBColor(0x06, 0x0E, 0x22))
    rect(slide, Inches(0), Inches(1.3), SLIDE_W, Pt(4), C_ACCENT1)
    tb(slide, title, Inches(0.4), Inches(0.05), Inches(12), Inches(0.78),
       size=28, bold=True)
    if sub:
        tb(slide, sub, Inches(0.4), Inches(0.78), Inches(12), Inches(0.5),
           size=13, color=C_ACCENT1)


def bullet(slide, items, x, y, w, h, sz=13, color=None):
    color = color or C_WHITE
    box = slide.shapes.add_textbox(x, y, w, h)
    tf = box.text_frame; tf.word_wrap = True
    for i, item in enumerate(items):
        p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
        p.space_before = Pt(5)
        run = p.add_run()
        run.text = "▸  " + item
        run.font.size = Pt(sz)
        run.font.color.rgb = color


def table(slide, hdrs, rows, x, y, w, rh=Inches(0.38), hbg=None, abg=None, sz=11):
    hbg = hbg or C_ACCENT1
    abg = abg or RGBColor(0x10, 0x22, 0x44)
    cw = w / len(hdrs)
    for ci, h in enumerate(hdrs):
        lrect(slide, h, x+cw*ci, y, cw, rh, hbg, RGBColor(0x06,0x10,0x26), sz+1, True)
    for ri, row in enumerate(rows):
        bg = abg if ri % 2 == 0 else RGBColor(0x0A, 0x1C, 0x3A)
        for ci, cell in enumerate(row):
            lrect(slide, cell, x+cw*ci, y+rh*(ri+1), cw, rh, bg, C_LTGRAY, sz, False,
                  RGBColor(0x1A, 0x35, 0x60))


def snum(slide, n):
    tb(slide, str(n), Inches(12.7), Inches(7.15), Inches(0.5), Inches(0.3),
       size=10, color=C_LTGRAY, align=PP_ALIGN.RIGHT)


# ────────────────────────────────────────────────
# SLIDE 1 — TITLE
# ────────────────────────────────────────────────
def slide1(prs):
    sl = prs.slides.add_slide(prs.slide_layouts[6])
    set_bg(sl, C_BG_MID)
    rect(sl, Inches(0), Inches(0), SLIDE_W, Inches(4.6), RGBColor(0x06, 0x10, 0x26))
    rect(sl, Inches(0), Inches(0), Pt(9), SLIDE_H, C_ACCENT1)
    rect(sl, Pt(9), Inches(0), Pt(4), SLIDE_H, C_ACCENT2)

    tb(sl, "SAVEETHA ENGINEERING COLLEGE  —  DEPARTMENT OF ELECTRONICS & COMMUNICATION ENGINEERING",
       Inches(0.9), Inches(0.28), Inches(12.1), Inches(0.38), size=10,
       color=C_LTGRAY, italic=True)

    tb(sl, "TinyNPU300PM", Inches(0.9), Inches(0.9), Inches(12), Inches(1.2),
       size=60, bold=True, color=C_WHITE)

    tb(sl, "A Custom FPGA Neural Processing Unit  •  0th Review Presentation",
       Inches(0.9), Inches(2.05), Inches(12), Inches(0.65), size=20, color=C_ACCENT1)

    rect(sl, Inches(0.9), Inches(2.78), Inches(5.5), Pt(3), C_ACCENT1)

    tb(sl, "Application Project:  ADAS_RISCV_NPU300",
       Inches(0.9), Inches(2.95), Inches(10), Inches(0.5), size=16,
       bold=True, color=C_ACCENT3)

    lrect(sl, "0th REVIEW", Inches(10.6), Inches(0.9), Inches(2.4), Inches(0.6),
          C_ACCENT2, sz=14, bold=True)

    tb(sl, "Hariharan Ganesh  |  Adharsh V", Inches(0.9), Inches(4.65),
       Inches(9), Inches(0.5), size=19, bold=True)
    tb(sl, "B.E. — Electronics & Communication Engineering",
       Inches(0.9), Inches(5.15), Inches(9), Inches(0.4), size=14, color=C_LTGRAY)
    tb(sl, "Saveetha Engineering College  |  August 2026",
       Inches(0.9), Inches(5.55), Inches(9), Inches(0.4), size=14, color=C_LTGRAY)
    tb(sl, "Under the Guidance of:  [Faculty Guide Name]",
       Inches(0.9), Inches(6.1), Inches(9), Inches(0.4), size=13,
       color=C_YELLOW, italic=True)

    rect(sl, Inches(10.6), Inches(5.3), Inches(2.4), Inches(1.9), RGBColor(0x08, 0x18, 0x38))
    tb(sl, "Tools\nVivado 2025.1\nCadence Genus\nCadence Innovus\nAntigravity IDE",
       Inches(10.72), Inches(5.35), Inches(2.2), Inches(1.8), size=10, color=C_LTGRAY)
    snum(sl, 1)


# ────────────────────────────────────────────────
# SLIDE 2 — PROBLEM
# ────────────────────────────────────────────────
def slide2(prs):
    sl = prs.slides.add_slide(prs.slide_layouts[6])
    set_bg(sl, C_BG_MID)
    header(sl, "Problem Identification & Relevance",
           "Why do we need a custom Neural Processing Unit with ROI Preprocessing?")

    rect(sl, Inches(0.3), Inches(1.55), Inches(5.9), Inches(5.55), RGBColor(0x08,0x16,0x30))
    tb(sl, "⚠  The Challenge", Inches(0.45), Inches(1.65), Inches(5.5), Inches(0.42),
       size=15, bold=True, color=C_ORANGE)
    bullet(sl, [
        "Edge AI inference on CPUs is too slow — standard models on host controllers take tens of milliseconds",
        "Commercial accelerators require a host ARM CPU for every layer scheduling, introducing massive communication latency",
        "High-speed vision demands processing sub-regions of interest (ROIs) dynamically to bypass background pixels",
        "Zynq-7020 FPGA offers reconfigurability but requires dedicated custom silicon blocks for efficient neural networks",
        "Without hardware ROI cropping, storing full high-resolution frames wastes significant BRAM memory and bandwidth",
        "Standard designs draw excessive power; edge devices require milliwatt-scale compute power",
    ], Inches(0.45), Inches(2.12), Inches(5.55), Inches(4.7), sz=12, color=C_LTGRAY)

    rect(sl, Inches(6.45), Inches(1.55), Inches(6.55), Inches(5.55), RGBColor(0x08,0x16,0x30))
    tb(sl, "📊  Technical Relevance & Targets", Inches(6.6), Inches(1.65),
       Inches(6.3), Inches(0.42), size=15, bold=True, color=C_ACCENT1)

    rows = [
        ("ASIC Technology Node", "45 nm Standard Cell", C_ACCENT3),
        ("Target System Board", "Xilinx Zynq-7020 CLG400 (Only)", C_ACCENT1),
        ("TinyNPU Core Power (ASIC)", "2.1 mW @ 45nm", C_ACCENT3),
        ("Vivado System Power (FPGA)", "106 mW (On-Chip)", C_ORANGE),
        ("Region of Interest (ROI)", "Hardware Spatial Crop Window", C_ACCENT3),
        ("TinyNPU300PM Compute", "20 × 8 Systolic (160 MACs)", C_ACCENT3),
        ("Verification Environment", "Antigravity + Cadence NCLaunch", C_ACCENT1),
    ]
    y = Inches(2.12)
    for label, val, vc in rows:
        tb(sl, label, Inches(6.6), y, Inches(4.1), Inches(0.42), size=12, color=C_LTGRAY)
        tb(sl, val, Inches(10.75), y, Inches(2.0), Inches(0.42), size=12, bold=True,
           color=vc, align=PP_ALIGN.RIGHT)
        rect(sl, Inches(6.6), y + Inches(0.4), Inches(6.1), Pt(1), RGBColor(0x1A,0x35,0x60))
        y += Inches(0.72)

    rect(sl, Inches(0.3), Inches(7.08), SLIDE_W - Inches(0.6), Pt(3), C_ACCENT2)
    tb(sl, "Key Insight: Custom AI-assisted RTL with hardware-level ROI cropping reduces active frame memory footprint, accelerating inference to sub-millisecond intervals.",
       Inches(0.5), Inches(6.75), Inches(12.4), Inches(0.38), size=11,
       color=C_YELLOW, italic=True)
    snum(sl, 2)


# ────────────────────────────────────────────────
# SLIDE 3 — OBJECTIVES
# ────────────────────────────────────────────────
def slide3(prs):
    sl = prs.slides.add_slide(prs.slide_layouts[6])
    set_bg(sl, C_BG_MID)
    header(sl, "Objectives & Expected Outcomes",
           "Core goals covering architecture design, timing closure, ROI processing, and verification flow")

    objectives = [
        ("🎯", "Design TinyNPU300PM in AI-Assisted RTL",
         "Implement 21 vendor-neutral Verilog-2001 modules — 20×8 systolic array, depthwise engine, INT8 requantization, and dynamic spatial crop configuration registers.", C_ACCENT1),
        ("⚙️", "Achieve Timing Closure on Zynq-7020",
         "Strict Vivado timing constraints: clk_fpga_0 (125 MHz) WNS = +1.112 ns, clk_fpga_1 (200 MHz) WNS = +0.767 ns. Zero DRC violations.", C_ACCENT3),
        ("🔍", "Implement Hardware Region of Interest (ROI) Cropping",
         "Develop coordinate tracking in the AXI-Stream front-end to dynamically crop and process pixel sub-windows, cutting active BRAM demands and compute cycles.", C_ORANGE),
        ("📊", "Benchmark Power & Resources",
         "Verify ultra-low power consumption (2.1 mW core at 45nm) and minimize FPGA resource overhead (10.82% LUTs, 8.81% registers).", C_YELLOW),
        ("📝", "Two-Stage Verification Flow",
         "Execute 1st round of logic verification in Antigravity simulator; run 2nd round of detailed sign-off verification in Cadence NCLaunch.", C_ACCENT2),
    ]

    y = Inches(1.52)
    for icon, title, desc, clr in objectives:
        rect(sl, Inches(0.3), y, Inches(0.55), Inches(0.9), clr)
        tb(sl, icon, Inches(0.3), y + Inches(0.12), Inches(0.55), Inches(0.65),
           size=18, align=PP_ALIGN.CENTER)
        tb(sl, title, Inches(0.95), y + Inches(0.02), Inches(12.1), Inches(0.42),
           size=15, bold=True, color=clr)
        tb(sl, desc, Inches(0.95), y + Inches(0.44), Inches(12.1), Inches(0.52),
           size=12, color=C_LTGRAY)
        rect(sl, Inches(0.3), y + Inches(0.93), Inches(12.7), Pt(1),
             RGBColor(0x1A,0x35,0x60))
        y += Inches(1.0)
    snum(sl, 3)


# ────────────────────────────────────────────────
# SLIDE 4 — NPU ARCHITECTURE
# ────────────────────────────────────────────────
def slide4(prs):
    sl = prs.slides.add_slide(prs.slide_layouts[6])
    set_bg(sl, C_BG_MID)
    header(sl, "Proposed Methodology — TinyNPU300PM Architecture",
           "AI-Assisted RTL | 20×8 Systolic Array | Hardware ROI Cropping | ASIC-Ready at 45nm")

    # ── LEFT: Block diagram ──
    bx = Inches(0.3)
    # CSR top
    lrect(sl, "AXI4-Lite CSR Slave  (32 Control/Status Registers)",
          bx, Inches(1.48), Inches(4.3), Inches(0.42),
          RGBColor(0x00,0x30,0x60), sz=11, line=C_ACCENT1)

    yy = Inches(1.92)
    lrect(sl, "AXI4-Stream Input  (Video Sensor Streaming Data)",
          bx, yy, Inches(4.3), Inches(0.46), RGBColor(0x00,0x50,0x80), sz=11)
    yy += Inches(0.46)
    tb(sl, "▼", bx+Inches(1.8), yy-Inches(0.05), Inches(0.7), Inches(0.26),
       size=13, color=C_ACCENT1, align=PP_ALIGN.CENTER)
    
    # Highlight ROI crop in the streaming sink
    lrect(sl, "axis_sink  (ROI Spatial Crop Window Preprocessor)\nOnly saves pixels in [crop_x, crop_y] window to buffer",
          bx, yy, Inches(4.3), Inches(0.56), RGBColor(0x04,0x3A,0x70), sz=10, line=C_ORANGE)
    yy += Inches(0.56)

    # Parallel compute engines
    tb(sl, "▼", bx+Inches(0.5), yy-Inches(0.05), Inches(0.7), Inches(0.26),
       size=13, color=C_ACCENT1, align=PP_ALIGN.CENTER)
    tb(sl, "▼", bx+Inches(2.8), yy-Inches(0.05), Inches(0.7), Inches(0.26),
       size=13, color=C_ACCENT2, align=PP_ALIGN.CENTER)
    lrect(sl, "20×8 Systolic Array\n160 MACs | WS | INT8\nOptimized for 45nm Core",
          bx, yy, Inches(2.05), Inches(0.76),
          RGBColor(0x00,0x78,0x96), sz=9, line=C_ACCENT1)
    lrect(sl, "DW Line Buffer\nDepthwise 3×3\nDedicated Vector Engine",
          bx+Inches(2.25), yy, Inches(2.05), Inches(0.76),
          RGBColor(0x44,0x10,0x80), sz=9, line=C_ACCENT2)
    yy += Inches(0.76)

    tb(sl, "▼  merge  ▼", bx+Inches(1.3), yy-Inches(0.04), Inches(1.8), Inches(0.26),
       size=10, color=C_LTGRAY, align=PP_ALIGN.CENTER)

    stages = [
        ("Requantization Unit  (INT32→INT8 | 3-stage pipeline)", RGBColor(0x60,0x18,0x00), C_ORANGE),
        ("Activation Unit  (ReLU | LeakyReLU | HardSwish)", RGBColor(0x00,0x55,0x28), C_ACCENT3),
        ("Pooling Unit  (MaxPool / AvgPool / Bypass)", RGBColor(0x78,0x40,0x00), C_ORANGE),
        ("Threshold Filter  +  BBox Decoder", RGBColor(0x7A,0x10,0x10), C_RED_SOFT),
        ("Output Buffer  →  AXI4-Stream Output", RGBColor(0x00,0x50,0x80), C_ACCENT1),
    ]
    for stage_txt, clr, ac in stages:
        lrect(sl, stage_txt, bx, yy, Inches(4.3), Inches(0.44), clr, sz=10)
        yy += Inches(0.44)
        if stage_txt != stages[-1][0]:
            tb(sl, "▼", bx+Inches(1.8), yy-Inches(0.06), Inches(0.7), Inches(0.24),
               size=12, color=ac, align=PP_ALIGN.CENTER)

    # DMA side column
    lrect(sl, "DMA Controller\n(AXI4-Full Master)", Inches(4.85), Inches(2.6),
          Inches(1.75), Inches(0.65), RGBColor(0x18,0x18,0x55), sz=9)
    tb(sl, "▼ weights", Inches(4.85), Inches(3.28), Inches(1.75), Inches(0.28),
       size=8, color=C_LTGRAY, align=PP_ALIGN.CENTER)
    lrect(sl, "Weight Buffer\n(Dual-Bank)", Inches(4.85), Inches(3.55),
          Inches(1.75), Inches(0.65), RGBColor(0x18,0x18,0x55), sz=9)

    # Controller FSM
    lrect(sl, "NPU Controller FSM:  IDLE  →  LOAD  →  COMPUTE  →  DRAIN  →  DONE",
          Inches(0.3), Inches(7.08), Inches(6.3), Inches(0.38),
          RGBColor(0x10,0x10,0x38), tc=C_YELLOW, sz=10)

    # ── RIGHT: Spec table ──
    rx = Inches(7.0)
    tb(sl, "📐  Key Architecture Specs", rx, Inches(1.48), Inches(6.1), Inches(0.44),
       size=15, bold=True, color=C_ACCENT1)
    table(sl,
          ["Parameter", "TinyNPU300PM Value"],
          [
              ["Systolic Array Core", "20 Rows × 8 Columns = 160 MACs"],
              ["Compute Dataflow", "Weight-Stationary (WS)"],
              ["Precision", "INT8 weights & activations | INT32 accumulator"],
              ["Core Core Power", "2.1 mW synthesized in 45nm ASIC"],
              ["Region of Interest (ROI)", "Hardware spatial coordinate filter (axis_sink)"],
              ["ROI Crop Config", "Dynamic registers: crop_x, crop_y, crop_w, crop_h"],
              ["Clock Domains", "3 independent (compute / postproc / DMA)"],
              ["Activations Supported", "ReLU, LeakyReLU, HardSwish (ROM LUT)"],
              ["Pooling Support", "MaxPool, AvgPool, Bypass (2×2, Stride 2)"],
              ["Configuration Space", "32 control registers (stride, rows, activation)"],
              ["AXI Interconnect", "AXI4-Lite (control), AXI4-Stream (video in/out)"],
              ["Double Buffering", "Ping-pong double buffer for activations"],
              ["Verification Rounds", "1st: Antigravity IDE | 2nd: Cadence NCLaunch"],
          ],
          rx, Inches(1.95), Inches(6.1), rh=Inches(0.355), hbg=C_ACCENT1, sz=10)
    snum(sl, 4)


# ────────────────────────────────────────────────
# SLIDE 5 — ADAS SOC INTEGRATION
# ────────────────────────────────────────────────
def slide5(prs):
    sl = prs.slides.add_slide(prs.slide_layouts[6])
    set_bg(sl, C_BG_MID)
    header(sl, "Application — ADAS_RISCV_NPU300",
           "Zynq-7020 SoC Integration: PicoRV32 RISC-V + NPU300PM + Safety Monitoring + ROI Feedback")

    y0 = Inches(1.5)

    # Video streaming source
    lrect(sl, "Video Stream Source\nCustom Deep Learning Model\nPedestrian | Lane | Sign | Obstacle",
          Inches(0.15), y0, Inches(2.4), Inches(1.1), RGBColor(0x00,0x30,0x58), sz=10)
    tb(sl, "AXI-Stream\nVideo Data\n──►", Inches(2.6), y0+Inches(0.35), Inches(0.75), Inches(0.55),
       size=10, color=C_YELLOW, align=PP_ALIGN.CENTER)

    # FPGA boundary
    fx = Inches(3.4)
    fw = Inches(7.55)
    rect(sl, fx, y0-Inches(0.05), fw, Inches(5.05), RGBColor(0x06,0x12,0x28))
    tb(sl, "Zynq-7020 CLG400 SoC Platform  —  125 MHz / 200 MHz",
       fx+Inches(0.1), y0-Inches(0.04), fw-Inches(0.2), Inches(0.3),
       size=10, color=C_ACCENT1, bold=True)

    fpga_blks = [
        (Inches(0.12), Inches(0.32), Inches(2.15), Inches(0.68),
         "UART Rx / Tx\n(ASCII Command Protocol)", RGBColor(0x1E,0x1E,0x50)),
        (Inches(2.4), Inches(0.32), Inches(2.3), Inches(0.68),
         "PicoRV32 RISC-V\nSystem Controller", RGBColor(0x00,0x40,0x85)),
        (Inches(4.85), Inches(0.32), Inches(2.5), Inches(0.68),
         "NPU300PM Accelerator\n20×8 Systolic Array (160 MACs)", RGBColor(0x00,0x58,0x72)),
        (Inches(0.12), Inches(1.18), Inches(2.15), Inches(0.68),
         "Sensor Fusion Unit\n(Combines camera flags)", RGBColor(0x45,0x20,0x00)),
        (Inches(2.4), Inches(1.18), Inches(2.3), Inches(0.68),
         "AI Decision Unit\n(Decision Threshold FSM)", RGBColor(0x00,0x52,0x28)),
        (Inches(4.85), Inches(1.18), Inches(2.5), Inches(0.68),
         "Safety Watchdog\nWatchdog 100ms | Brake Control", RGBColor(0x62,0x10,0x10)),
        (Inches(0.12), Inches(2.05), Inches(3.6), Inches(0.65),
         "Security Interlock Unit  (Brake Interlock FSM)", RGBColor(0x40,0x00,0x60)),
        (Inches(3.85), Inches(2.05), Inches(3.5), Inches(0.65),
         "Supporter Module  (BRAM | LED Controller)", RGBColor(0x1A,0x28,0x50)),
    ]
    for dx, dy, w, h, txt, clr in fpga_blks:
        lrect(sl, txt, fx+dx, y0+dy, w, h, clr, sz=9, line=RGBColor(0x1A,0x40,0x70))

    # AXI bus
    by = y0 + Inches(3.0)
    rect(sl, fx+Inches(0.1), by, fw-Inches(0.25), Inches(0.3), RGBColor(0x00,0x38,0x6E))
    tb(sl, "AXI4-Lite Internal Bus  +  Interrupt Controller",
       fx+Inches(0.2), by+Inches(0.04), fw-Inches(0.5), Inches(0.22),
       size=9, color=C_ACCENT1, align=PP_ALIGN.CENTER, bold=True)

    # Processing System
    lrect(sl, "Zynq 7020 PS (ARM Cortex-A9)\n(Initiates DMA, Handles Interrupts, Coordinates ROI Crop Config)",
          fx+Inches(0.12), y0+Inches(3.4), Inches(7.3), Inches(0.6),
          RGBColor(0x18,0x18,0x40), sz=9)

    # LED outputs
    ox = Inches(11.15)
    tb(sl, "Status outputs", ox, y0, Inches(2.0), Inches(0.28),
       size=11, bold=True, color=C_ACCENT1)
    leds = [
        ("LED0", "System Active", C_ACCENT3),
        ("LED1", "Pedestrian Warn", C_ORANGE),
        ("LED2", "Lane Departure", C_YELLOW),
        ("LED3", "Traffic Sign", C_ACCENT1),
        ("LED4", "Collision Warn", C_RED_SOFT),
        ("LED5", "Emergency Brake", C_ACCENT2),
    ]
    for i, (n, d, c) in enumerate(leds):
        ly = y0 + Inches(0.3) + i*Inches(0.5)
        rect(sl, ox, ly, Inches(0.3), Inches(0.3), c)
        tb(sl, f"{n}: {d}", ox+Inches(0.36), ly-Inches(0.02),
           Inches(2.0), Inches(0.34), size=10, color=C_LTGRAY)

    lrect(sl, "Custom DL Model\nInference Pipeline\nThrough AXI-Stream",
          ox, y0+Inches(3.4), Inches(2.1), Inches(0.6),
          RGBColor(0x18,0x18,0x40), sz=9)

    # Bottom table
    tb(sl, "📋  ADAS Control System Verification & ROI Loop", Inches(0.3), Inches(6.55), Inches(5), Inches(0.35),
       size=13, bold=True, color=C_ACCENT1)
    table(sl,
          ["System Feature", "Implementation", "Role in Performance Study"],
          [
              ["1st Round of Verification", "Antigravity IDE & Simulator", "Pre-synthesis logic correction, FSM transition verification, and register mappings."],
              ["2nd Round of Verification", "Cadence NCLaunch (ncsim 15.20)", "Detailed sign-off simulation of 28/28 verification test scenarios with zero failures."],
              ["Region of Interest (ROI)", "Dynamic AXI-Lite Crop Registers", "ARM CPU updates crop registers based on detections to isolate targets in subsequent video frames."],
          ],
          Inches(0.3), Inches(6.9), Inches(12.7), rh=Inches(0.31),
          hbg=C_ACCENT2, sz=9.5)
    snum(sl, 5)


# ────────────────────────────────────────────────
# SLIDE 6 — RESULTS
# ────────────────────────────────────────────────
def slide6(prs):
    sl = prs.slides.add_slide(prs.slide_layouts[6])
    set_bg(sl, C_BG_MID)
    header(sl, "Results & Implementation Data",
           "True, proven parameters verified on Zynq-7020 and Cadence ASIC Flow")

    panels = [
        (Inches(0.3), "🖥  Verification Flow",
         [("1st Round", "Antigravity IDE"),
          ("2nd Round", "Cadence NCLaunch 15.20"),
          ("Sim Time", "2,357,600 ns"),
          ("Scenarios", "28 / 28 Passed ✅"),
          ("Failures", "0")], C_ACCENT3),
        (Inches(4.6), "⚡  Zynq-7020 Implementation",
         [("Target Device", "xc7z020clg400-1"),
          ("Clock 0 (Sys)", "125 MHz (WNS = +1.112 ns)"),
          ("Clock 1 (NPU)", "200 MHz (WNS = +0.767 ns)"),
          ("Slice LUTs", "5,756 / 53,200 (10.82%)"),
          ("Slice Registers", "9,379 / 106,400 (8.81%)")], C_ACCENT1),
        (Inches(8.9), "🔬  ASIC Core Results (45nm)",
         [("Technology Node", "45 nm Cell Library"),
          ("TinyNPU Power", "2.1 mW core power"),
          ("Genus Cells", "5,848 cells"),
          ("Total Area", "55,402.8 µm²"),
          ("PnR Timing (Setup)", "WNS = +0.328 ns ✅")], C_ACCENT2),
    ]
    for px, ptitle, pitems, pc in panels:
        rect(sl, px, Inches(1.48), Inches(4.05), Inches(3.3), RGBColor(0x08,0x14,0x2C))
        rect(sl, px, Inches(1.48), Inches(4.05), Inches(0.38), pc)
        tb(sl, ptitle, px+Inches(0.1), Inches(1.5), Inches(3.85), Inches(0.34),
           size=12, bold=True, color=RGBColor(0x06,0x10,0x26))
        y2 = Inches(1.92)
        for k, v in pitems:
            tb(sl, k, px+Inches(0.1), y2, Inches(2.1), Inches(0.38), size=11, color=C_LTGRAY)
            tb(sl, v, px+Inches(2.15), y2, Inches(1.8), Inches(0.38), size=11,
               bold=True, color=C_WHITE, align=PP_ALIGN.RIGHT)
            y2 += Inches(0.46)

    # Resource breakdown details
    tb(sl, "🔧  Additional FPGA Hardware Utilisation Parameters (Zynq-7020)", Inches(0.3), Inches(4.85),
       Inches(12.7), Inches(0.38), size=13, bold=True, color=C_ORANGE)
    table(sl,
          ["FPGA Resource", "Used", "Available", "Utilisation %"],
          [
              ["Block RAM Tile", "3 Tiles (RAMB36E1)", "140 Tiles", "2.14 %"],
              ["DSP48E1 Slice", "1 Slice", "220 Slices", "0.45 %"],
              ["Bonded IOB", "24 Pins", "125 Pins", "19.20 %"],
              ["Total On-Chip Power (Vivado)", "106 mW", "Zynq Thermal Margin", "Within budget"],
          ],
          Inches(0.3), Inches(5.25), Inches(12.7), rh=Inches(0.38),
          hbg=C_ORANGE, sz=10)

    tb(sl, "Note: All parameters are extracted directly from the synthesized and implemented Vivado v2025.1 reports for Zynq-7020.",
       Inches(0.3), Inches(6.92), Inches(12.7), Inches(0.38),
       size=11, color=C_ACCENT3, bold=True, italic=True)
    snum(sl, 6)


# ────────────────────────────────────────────────
# SLIDE 7 — REFERENCES
# ────────────────────────────────────────────────
def slide7(prs):
    sl = prs.slides.add_slide(prs.slide_layouts[6])
    set_bg(sl, C_BG_MID)
    header(sl, "References",
           "IEEE Publications supporting TinyNPU300PM design and reconfigurability decisions")

    refs = [
        ("[1]", "K. Yoshioka et al.", "\"A 340-µW TinyML Using LUT-Based Reservoir Computing on Low-Cost FPGAs,\"", "IEEE Embedded Systems Letters, 2025."),
        ("[2]", "D. Kanna N et al.", "\"CNN Accelerator For Edge Inference,\"", "Proc. IEEE ICNGCS, 2025."),
        ("[3]", "S. Ravi et al.", "\"Energy-Efficient VLSI Architectures for On-Device Deep Learning,\"", "Proc. IEEE ICDICI, 2025."),
        ("[4]", "A. Jose et al.", "\"FPGA Implementation of CNN Accelerator with Pruning for ADAS,\"", "Proc. IEEE I2CT, 2024."),
        ("[5]", "Arunkumar K et al.", "\"Hardware-Accelerated Edge Detection and Pixel Enhancement on PYNQ-Z2,\"", "Proc. IEEE ICICNIS, 2025."),
        ("[6]", "A. Kumar K et al.", "\"Implementation of an Ultra-Low Power CNN Accelerator on PYNQ Z2,\"", "Proc. IEEE ISAECT, 2025."),
        ("[7]", "Nivitha G et al.", "\"Low-Power VLSI Design for Edge AI Accelerators in IoT Devices,\"", "Proc. IEEE ICOEI, 2026."),
        ("[8]", "A. Jose et al.", "\"Novel FPGA based Systolic Array Design for Dynamic Workflows,\"", "Proc. IEEE ICTEST, 2025."),
        ("[9]", "TinyNPU Team", "\"TinyNPU Foundations: Technical Onboarding Document,\"", "Project Documentation, 2026."),
    ]

    y = Inches(1.5)
    for i, (num, author, title, venue) in enumerate(refs):
        if i % 2 == 0:
            rect(sl, Inches(0.3), y-Inches(0.03), Inches(12.7), Inches(0.54),
                 RGBColor(0x0A,0x1A,0x35))
        tb(sl, num, Inches(0.35), y, Inches(0.52), Inches(0.46), size=12,
           bold=True, color=C_ACCENT1)
        tb(sl, author, Inches(0.88), y, Inches(2.1), Inches(0.46), size=11,
           bold=True, color=C_WHITE)
        tb(sl, title, Inches(3.05), y, Inches(6.1), Inches(0.46), size=11,
           color=C_LTGRAY, italic=True)
        tb(sl, venue, Inches(9.2), y, Inches(3.85), Inches(0.46), size=11,
           color=C_ACCENT3)
        y += Inches(0.54)

    rect(sl, Inches(0.3), Inches(7.1), Inches(12.7), Pt(2), C_ACCENT2)
    tb(sl, "Note: All references listed are verified IEEE / joint-IEEE publications. Literature review is in Project_Documents/References/.",
       Inches(0.3), Inches(6.82), Inches(12.7), Inches(0.32), size=10,
       color=C_YELLOW, italic=True)
    snum(sl, 7)


# ────────────────────────────────────────────────
# MAIN
# ────────────────────────────────────────────────
def main():
    prs = Presentation()
    prs.slide_width  = SLIDE_W
    prs.slide_height = SLIDE_H

    print("Building TinyNPU300PM 0th Review Presentation...")
    slide1(prs);  print("  ✓ Slide 1 — Title")
    slide2(prs);  print("  ✓ Slide 2 — Problem Identification & Relevance")
    slide3(prs);  print("  ✓ Slide 3 — Objectives & Expected Outcomes")
    slide4(prs);  print("  ✓ Slide 4 — TinyNPU300PM Architecture")
    slide5(prs);  print("  ✓ Slide 5 — ADAS_RISCV_NPU300 Application")
    slide6(prs);  print("  ✓ Slide 6 — Results & Output Data")
    slide7(prs);  print("  ✓ Slide 7 — References")

    out = Path(__file__).parent / "TinyNPU300PM_0th_Review.pptx"
    prs.save(str(out))
    print(f"\n✅  Saved: {out}")

if __name__ == "__main__":
    main()
