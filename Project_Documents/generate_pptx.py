"""
TinyNPU - MNC-Level PowerPoint Generator
Generates a premium 7-slide PPTX presentation using python-pptx
"""
from pptx import Presentation
from pptx.util import Inches, Pt, Emu
from pptx.dml.color import RGBColor
from pptx.enum.text import PP_ALIGN
from pptx.util import Inches, Pt
import pptx.oxml.ns as ns
from lxml import etree
import copy

# ── Color Palette ─────────────────────────────────────────────────────────────
BG_DARK     = RGBColor(0x05, 0x05, 0x10)
BG_CARD     = RGBColor(0x10, 0x12, 0x22)
ACCENT_CYAN = RGBColor(0x00, 0xE5, 0xFF)
ACCENT_BLUE = RGBColor(0x00, 0x77, 0xFF)
WHITE       = RGBColor(0xFF, 0xFF, 0xFF)
TEXT_MUTED  = RGBColor(0xA0, 0xA0, 0xC0)
TEXT_BODY   = RGBColor(0xCC, 0xCC, 0xE0)
SUCCESS     = RGBColor(0x00, 0xFF, 0x8C)
DARK_CARD   = RGBColor(0x08, 0x0A, 0x1A)

# ── Slide dimensions (Widescreen 16:9) ────────────────────────────────────────
W = Inches(13.33)
H = Inches(7.5)

prs = Presentation()
prs.slide_width  = W
prs.slide_height = H

BLANK_LAYOUT = prs.slide_layouts[6]  # totally blank

# ── Helper Functions ───────────────────────────────────────────────────────────

def add_rect(slide, l, t, w, h, fill_color=None, line_color=None, line_width_pt=None, transparency=0):
    shape = slide.shapes.add_shape(1, l, t, w, h)  # MSO_SHAPE_TYPE.RECTANGLE
    shape.line.fill.background()
    if fill_color:
        shape.fill.solid()
        shape.fill.fore_color.rgb = fill_color
    else:
        shape.fill.background()
    if line_color:
        shape.line.color.rgb = line_color
        if line_width_pt:
            shape.line.width = Pt(line_width_pt)
    else:
        shape.line.fill.background()
    return shape

def add_label(slide, text, l, t, w, h, size=18, bold=False, color=WHITE, align=PP_ALIGN.LEFT, italic=False):
    txb = slide.shapes.add_textbox(l, t, w, h)
    tf  = txb.text_frame
    tf.word_wrap = True
    p   = tf.paragraphs[0]
    p.alignment = align
    run = p.add_run()
    run.text = text
    run.font.size  = Pt(size)
    run.font.bold  = bold
    run.font.color.rgb = color
    run.font.italic = italic
    run.font.name  = "Calibri"
    return txb

def add_multiline(slide, lines, l, t, w, h, size=15, color=TEXT_BODY, spacing_pt=4):
    txb = slide.shapes.add_textbox(l, t, w, h)
    tf  = txb.text_frame
    tf.word_wrap = True
    first = True
    for line in lines:
        if first:
            p = tf.paragraphs[0]
            first = False
        else:
            p = tf.add_paragraph()
        p.space_before = Pt(spacing_pt)
        run = p.add_run()
        run.text = line
        run.font.size  = Pt(size)
        run.font.color.rgb = color
        run.font.name  = "Calibri"
    return txb

def slide_bg(slide, color=BG_DARK):
    """Fill slide background with a solid color."""
    add_rect(slide, 0, 0, W, H, fill_color=color)

def add_card(slide, l, t, w, h, border_color=None):
    """Adds a dark card with optional accent border."""
    add_rect(slide, l, t, w, h, fill_color=BG_CARD,
             line_color=border_color or RGBColor(0x25, 0x28, 0x45),
             line_width_pt=1.0)

def add_top_bar(slide, title, subtitle=None):
    """Adds a consistent top bar to content slides."""
    # Thin cyan top rule
    add_rect(slide, 0, 0, W, Inches(0.06), fill_color=ACCENT_CYAN)
    # Title
    add_label(slide, title, Inches(0.55), Inches(0.2), Inches(12), Inches(0.7),
              size=30, bold=True, color=WHITE)
    if subtitle:
        add_label(slide, subtitle, Inches(0.55), Inches(0.88), Inches(11), Inches(0.35),
                  size=14, color=TEXT_MUTED)
    # Bottom rule
    add_rect(slide, Inches(0.55), Inches(1.25), Inches(12.2), Inches(0.025),
             fill_color=RGBColor(0x25, 0x28, 0x45))

def add_kpi(slide, l, t, w, h, value, unit, label, sublabel="", accent=False):
    border = ACCENT_CYAN if accent else RGBColor(0x25, 0x28, 0x45)
    add_card(slide, l, t, w, h, border_color=border)
    # Value
    add_label(slide, value, l, t + Inches(0.5), w, Inches(1.2),
              size=52, bold=True, color=ACCENT_CYAN, align=PP_ALIGN.CENTER)
    # Unit
    add_label(slide, unit, l, t + Inches(1.5), w, Inches(0.4),
              size=16, bold=False, color=TEXT_MUTED, align=PP_ALIGN.CENTER)
    # Label
    add_label(slide, label, l, t + Inches(1.9), w, Inches(0.4),
              size=13, bold=True, color=WHITE, align=PP_ALIGN.CENTER)
    if sublabel:
        add_label(slide, sublabel, l + Inches(0.1), t + Inches(2.3), w - Inches(0.2), Inches(0.5),
                  size=11, color=TEXT_MUTED, align=PP_ALIGN.CENTER)

# ══════════════════════════════════════════════════════════════════════════════
# SLIDE 1 — COVER
# ══════════════════════════════════════════════════════════════════════════════
s1 = prs.slides.add_slide(BLANK_LAYOUT)
slide_bg(s1)

# Left accent bar
add_rect(s1, 0, 0, Inches(0.08), H, fill_color=ACCENT_CYAN)

# Background grid decoration (subtle horizontal lines)
for i in range(10):
    add_rect(s1, Inches(0.15), Inches(0.8 * i + 0.3), W - Inches(0.15), Inches(0.01),
             fill_color=RGBColor(0x18, 0x1A, 0x2E))

# Large stylized "npu" bg watermark
add_label(s1, "NPU", Inches(6.5), Inches(1.5), Inches(6.5), Inches(4.5),
          size=260, bold=True,
          color=RGBColor(0x10, 0x12, 0x20), align=PP_ALIGN.LEFT)

# Tag pill
add_rect(s1, Inches(0.5), Inches(1.2), Inches(2.6), Inches(0.4),
         fill_color=RGBColor(0x0A, 0x22, 0x3A),
         line_color=ACCENT_CYAN, line_width_pt=0.8)
add_label(s1, "FINAL YEAR PROJECT", Inches(0.55), Inches(1.22), Inches(2.5), Inches(0.38),
          size=10, bold=True, color=ACCENT_CYAN, align=PP_ALIGN.CENTER)

# Main title
add_label(s1, "TinyNPU", Inches(0.5), Inches(1.85), Inches(10), Inches(1.8),
          size=90, bold=True, color=WHITE, align=PP_ALIGN.LEFT)

# Subtitle
add_label(s1,
    "An ASIC-Ready INT8 Systolic AI Accelerator",
    Inches(0.5), Inches(3.55), Inches(9.5), Inches(0.7),
    size=26, bold=False, color=ACCENT_CYAN, align=PP_ALIGN.LEFT)

# Description
add_label(s1,
    "Deterministic Edge Inference  ·  Pure Hardware Architecture  ·  Zero ARM Dependencies",
    Inches(0.5), Inches(4.2), Inches(10), Inches(0.5),
    size=14, color=TEXT_MUTED, align=PP_ALIGN.LEFT)

# Bottom stats row
add_rect(s1, Inches(0.5), Inches(5.3), Inches(12.3), Inches(1.2),
         fill_color=DARK_CARD, line_color=RGBColor(0x25, 0x28, 0x45), line_width_pt=0.8)

stat_data = [
    ("117 mW",  "On-Chip Power"),
    ("195 MHz", "Achieved fMAX"),
    ("100%",    "ASIC Readiness"),
    ("Verilog-2001", "RTL Standard"),
]
for i, (val, lbl) in enumerate(stat_data):
    x = Inches(0.7 + i * 3.1)
    add_label(s1, val, x, Inches(5.45), Inches(3.0), Inches(0.5),
              size=22, bold=True, color=WHITE, align=PP_ALIGN.LEFT)
    add_label(s1, lbl, x, Inches(5.9), Inches(3.0), Inches(0.4),
              size=11, color=TEXT_MUTED, align=PP_ALIGN.LEFT)
    if i < 3:
        add_rect(s1, Inches(0.7 + i * 3.1 + 2.8), Inches(5.45), Inches(0.02), Inches(0.8),
                 fill_color=RGBColor(0x30, 0x33, 0x55))


# ══════════════════════════════════════════════════════════════════════════════
# SLIDE 2 — PROBLEM IDENTIFICATION & RELEVANCE
# ══════════════════════════════════════════════════════════════════════════════
s2 = prs.slides.add_slide(BLANK_LAYOUT)
slide_bg(s2)
add_rect(s2, 0, 0, W, Inches(0.06), fill_color=ACCENT_BLUE)
add_top_bar(s2, "Problem Identification & Relevance",
            "Why does edge AI demand a purpose-built hardware accelerator?")

# Left card — The Technical Bottleneck
add_card(s2, Inches(0.5), Inches(1.5), Inches(5.9), Inches(5.5),
         border_color=RGBColor(0x30, 0x50, 0x80))
add_label(s2, "⚠  The Technical Bottleneck",
          Inches(0.7), Inches(1.65), Inches(5.5), Inches(0.5),
          size=17, bold=True, color=ACCENT_CYAN)
add_multiline(s2, [
    "▸  GPU-class devices draw excessive power, causing thermal throttling under sustained high-FPS inference workloads — incompatible with strict SWaP constraints.",
    "",
    "▸  Hybrid FPGA/SoC platforms offload control to ARM+Linux, introducing OS jitter and non-deterministic interrupt latency into real-time inference pipelines.",
    "",
    "▸  Most academic NPU IP cores are heavily software-assisted, making them impossible to port directly to silicon for an ASIC tapeout without significant redesign.",
], Inches(0.7), Inches(2.2), Inches(5.5), Inches(4.5), size=14, color=TEXT_BODY, spacing_pt=6)

# Right card — Why It Matters
add_card(s2, Inches(6.9), Inches(1.5), Inches(5.9), Inches(5.5),
         border_color=RGBColor(0x00, 0xA5, 0xFF))
add_label(s2, "✦  Why It Matters",
          Inches(7.1), Inches(1.65), Inches(5.5), Inches(0.5),
          size=17, bold=True, color=ACCENT_CYAN)
add_multiline(s2, [
    "▸  SWaP Constraints — Mission-critical edge platforms (drones, autonomous sensors) impose hard limits on Size, Weight, and Power. Heatsinks are not an option.",
    "",
    "▸  Determinism — Any OS interrupt or bus contention can cause a missed detection frame in high-speed visual tracking applications.",
    "",
    "▸  ASIC Scalability — A strictly pure-RTL architecture can be migrated directly from an FPGA prototype to a 7nm foundry tape-out with zero architectural changes.",
], Inches(7.1), Inches(2.2), Inches(5.5), Inches(4.5), size=14, color=TEXT_BODY, spacing_pt=6)


# ══════════════════════════════════════════════════════════════════════════════
# SLIDE 3 — OBJECTIVES & EXPECTED OUTCOMES
# ══════════════════════════════════════════════════════════════════════════════
s3 = prs.slides.add_slide(BLANK_LAYOUT)
slide_bg(s3)
add_rect(s3, 0, 0, W, Inches(0.06), fill_color=ACCENT_CYAN)
add_top_bar(s3, "Objectives & Expected Outcomes",
            "Technical goals and measurable success criteria for this project.")

# 4 objective cards in 2x2
card_data = [
    ("01", "Systolic Array Design",
     "Design an 8×8 Weight-Stationary Systolic Array optimized for INT8 quantized multiply-accumulate operations with 2-stage pipelining."),
    ("02", "Processor-Less Architecture",
     "Eliminate ALL CPU/ARM overhead by building a complete, self-sufficient verification chain entirely in pure RTL hardware logic."),
    ("03", "Power Optimization",
     "Apply Integrated Clock Gating (ICG) across all clock domains via Vivado's power_opt_design engine to minimize dynamic switching power."),
    ("04", "Silicon Verification",
     "Flash the compiled bitstream directly to FPGA and confirm functional pass/fail using dedicated hardware scoreboards and physical board LEDs."),
]
positions = [
    (Inches(0.5),  Inches(1.55)),
    (Inches(6.95), Inches(1.55)),
    (Inches(0.5),  Inches(4.1)),
    (Inches(6.95), Inches(4.1)),
]
for (lx, ly), (num, title, body) in zip(positions, card_data):
    add_card(s3, lx, ly, Inches(6.2), Inches(2.4))
    add_label(s3, num, lx + Inches(0.2), ly + Inches(0.15), Inches(0.8), Inches(0.7),
              size=36, bold=True, color=RGBColor(0x20, 0x30, 0x55))
    add_label(s3, title, lx + Inches(0.9), ly + Inches(0.2), Inches(5.1), Inches(0.5),
              size=16, bold=True, color=ACCENT_CYAN)
    add_label(s3, body,  lx + Inches(0.2), ly + Inches(0.8), Inches(5.8), Inches(1.5),
              size=13, color=TEXT_BODY)


# ══════════════════════════════════════════════════════════════════════════════
# SLIDE 4 — PROPOSED METHODOLOGY
# ══════════════════════════════════════════════════════════════════════════════
s4 = prs.slides.add_slide(BLANK_LAYOUT)
slide_bg(s4)
add_rect(s4, 0, 0, W, Inches(0.06), fill_color=ACCENT_CYAN)
add_top_bar(s4, "Proposed Methodology",
            "A four-phase rigorous ASIC physical design and verification flow.")

# Phase timeline blocks
phases = [
    ("Phase 1", "RTL Design", "2-stage MAC pipeline, multi-stage requantization units. Verilog-2001 strict compliance."),
    ("Phase 2", "HW Architecture", "Pure hardware BRAM Sensor Emulator replaces ARM processor. AXI-Stream data path."),
    ("Phase 3", "Power Synthesis", "power_opt_design infers ICG cells. BRAM EN-pin gating. ExploreWithRemap strategy."),
    ("Phase 4", "On-Silicon Test", "Bitstream flashed to PYNQ-Z2. Physical button triggers emulator. LED PASS/FAIL output."),
]

arrow_x_positions = [Inches(3.55), Inches(6.55), Inches(9.55)]
for i, (ph, title, body) in enumerate(phases):
    lx = Inches(0.4 + i * 3.2)
    ly = Inches(1.55)
    add_card(s4, lx, ly, Inches(3.0), Inches(4.8))
    # Phase number strip
    add_rect(s4, lx, ly, Inches(3.0), Inches(0.55), fill_color=ACCENT_BLUE)
    add_label(s4, ph, lx, ly + Inches(0.05), Inches(3.0), Inches(0.5),
              size=14, bold=True, color=WHITE, align=PP_ALIGN.CENTER)
    add_label(s4, title, lx + Inches(0.15), ly + Inches(0.75), Inches(2.7), Inches(0.55),
              size=17, bold=True, color=ACCENT_CYAN)
    add_label(s4, body,  lx + Inches(0.15), ly + Inches(1.4),  Inches(2.7), Inches(3.2),
              size=13, color=TEXT_BODY)

# Arrows between cards
for ax in arrow_x_positions:
    add_label(s4, "➤", ax, Inches(3.6), Inches(0.5), Inches(0.5),
              size=22, color=ACCENT_BLUE, align=PP_ALIGN.CENTER)


# ══════════════════════════════════════════════════════════════════════════════
# SLIDE 5 — SYSTEM ARCHITECTURE
# ══════════════════════════════════════════════════════════════════════════════
s5 = prs.slides.add_slide(BLANK_LAYOUT)
slide_bg(s5)
add_rect(s5, 0, 0, W, Inches(0.06), fill_color=ACCENT_CYAN)
add_top_bar(s5, "System Architecture — Data Flow",
            "Option A: Processor-less execution. Full AXI-Stream data path in pure RTL.")

# Main architecture diagram
add_rect(s5, Inches(0.5), Inches(1.55), Inches(12.3), Inches(3.6),
         fill_color=DARK_CARD, line_color=RGBColor(0x25, 0x28, 0x45), line_width_pt=0.8)

# Architecture blocks
arch_blocks = [
    (Inches(0.8),  Inches(1.85), "BRAM\nEmulator",    "Sensor Input\nHex Image Data"),
    (Inches(3.3),  Inches(1.85), "AXI-Stream\nBus",   "32-bit TDATA\nTVALID / TREADY"),
    (Inches(5.8),  Inches(1.75), "Systolic Array\n8×8 PE Grid",  "INT8 MAC\n2-Stage Pipeline"),
    (Inches(8.8),  Inches(1.85), "Requant\nUnit",     "4-Stage Pipe\nINT32→INT8"),
    (Inches(10.95),Inches(1.85), "HW\nScoreboard",   "Golden Ref\nPASS / FAIL"),
]

for i, (bx, by, title, sub) in enumerate(arch_blocks):
    bw = Inches(2.2) if i == 2 else Inches(1.8)
    bh = Inches(1.5) if i == 2 else Inches(1.3)
    bc = ACCENT_BLUE if i == 2 else RGBColor(0x15, 0x25, 0x40)
    add_rect(s5, bx, by, bw, bh, fill_color=bc,
             line_color=ACCENT_CYAN if i == 2 else RGBColor(0x30, 0x55, 0x80),
             line_width_pt=1.2 if i == 2 else 0.8)
    add_label(s5, title, bx, by + Inches(0.15), bw, Inches(0.7),
              size=14 if i == 2 else 12, bold=True, color=WHITE, align=PP_ALIGN.CENTER)
    add_label(s5, sub,   bx, by + Inches(0.8),  bw, Inches(0.6),
              size=10, color=ACCENT_CYAN, align=PP_ALIGN.CENTER)

# Arrows
arrow_positions = [Inches(2.65), Inches(5.18), Inches(8.07), Inches(10.45)]
for ax in arrow_positions:
    add_label(s5, "→", ax, Inches(2.2), Inches(0.5), Inches(0.5),
              size=20, color=ACCENT_CYAN, align=PP_ALIGN.CENTER)

# Labels below diagram
desc_cols = [
    (Inches(0.55), "Input Stage",  "Hardcoded hex vectors simulate MIPI CSI-2 camera feed at full 125 MHz clock speed."),
    (Inches(4.6),  "Compute Core", "Weight-stationary dataflow maximises data reuse, minimizing expensive SRAM read cycles."),
    (Inches(9.3),  "Output Stage", "Real-time compare logic drives physical board LEDs for instant Pass/Fail results."),
]
for dx, dhead, dbody in desc_cols:
    add_label(s5, dhead, dx, Inches(5.3), Inches(3.8), Inches(0.4),
              size=13, bold=True, color=ACCENT_CYAN)
    add_label(s5, dbody, dx, Inches(5.7), Inches(3.8), Inches(0.6),
              size=12, color=TEXT_MUTED)


# ══════════════════════════════════════════════════════════════════════════════
# SLIDE 6 — RESULTS DASHBOARD
# ══════════════════════════════════════════════════════════════════════════════
s6 = prs.slides.add_slide(BLANK_LAYOUT)
slide_bg(s6)
add_rect(s6, 0, 0, W, Inches(0.06), fill_color=SUCCESS)
add_top_bar(s6, "Physical Verification Results",
            "Post-route implementation metrics — Xilinx Zynq xc7z020 silicon (Vivado 2025.1)")

# 3 KPI cards
add_kpi(s6, Inches(0.5),  Inches(1.55), Inches(3.9), Inches(3.8),
        "117", "mW Total On-Chip Power", "DYNAMIC POWER",
        "Ice-cold operation. Zero thermal throttling. No heatsink required.", accent=False)

add_kpi(s6, Inches(4.7),  Inches(1.55), Inches(3.9), Inches(3.8),
        "195", "MHz Max Frequency (fMAX)", "TIMING RESULT",
        "Target: 100 MHz. Achieved: 195 MHz. WNS = -0.120 ns @ 200 MHz.", accent=True)

add_kpi(s6, Inches(8.9),  Inches(1.55), Inches(3.9), Inches(3.8),
        "0", "Synthesis Errors | 0 Latches", "ASIC RTL QUALITY",
        "Verilog-2001 strict. No combinational loops. No software dependencies.")

# Synthesis summary table
add_rect(s6, Inches(0.5), Inches(5.5), Inches(12.3), Inches(1.55),
         fill_color=DARK_CARD, line_color=RGBColor(0x25, 0x28, 0x45), line_width_pt=0.8)

tbl_cols = ["DSP48 Cells", "FF Registers", "LUT Count", "BRAM Blocks", "Clock Gating Cells", "Route Util"]
tbl_vals = ["2", "607", "775", "160", "Inferred (ICG)", "< 1%"]
add_label(s6, "SYNTHESIS RESOURCE UTILIZATION",
          Inches(0.7), Inches(5.55), Inches(6), Inches(0.4),
          size=10, bold=True, color=TEXT_MUTED)
for i, (c, v) in enumerate(zip(tbl_cols, tbl_vals)):
    cx = Inches(0.6 + i * 2.05)
    add_label(s6, v, cx, Inches(5.9), Inches(2.0), Inches(0.45),
              size=16, bold=True, color=WHITE)
    add_label(s6, c, cx, Inches(6.3), Inches(2.0), Inches(0.35),
              size=10, color=TEXT_MUTED)


# ══════════════════════════════════════════════════════════════════════════════
# SLIDE 7 — PROCESSING SPEED & LATENCY
# ══════════════════════════════════════════════════════════════════════════════
s7 = prs.slides.add_slide(BLANK_LAYOUT)
slide_bg(s7)
add_rect(s7, 0, 0, W, Inches(0.06), fill_color=ACCENT_BLUE)
add_top_bar(s7, "Processing Speed & Pipeline Latency",
            "Deterministic clock-cycle accurate latency — zero OS jitter, zero software overhead.")

# 4 top KPI cards
add_card(s7, Inches(0.5),  Inches(1.55), Inches(2.9), Inches(2.5), border_color=ACCENT_CYAN)
add_label(s7, "5.13", Inches(0.5), Inches(1.75), Inches(2.9), Inches(1.1),
          size=54, bold=True, color=ACCENT_CYAN, align=PP_ALIGN.CENTER)
add_label(s7, "ns  Clock Period", Inches(0.5), Inches(2.7), Inches(2.9), Inches(0.35),
          size=13, color=TEXT_MUTED, align=PP_ALIGN.CENTER)
add_label(s7, "@ 195 MHz fMAX", Inches(0.5), Inches(3.05), Inches(2.9), Inches(0.3),
          size=11, bold=True, color=WHITE, align=PP_ALIGN.CENTER)

add_card(s7, Inches(3.65), Inches(1.55), Inches(2.9), Inches(2.5))
add_label(s7, "24", Inches(3.65), Inches(1.75), Inches(2.9), Inches(1.1),
          size=54, bold=True, color=ACCENT_CYAN, align=PP_ALIGN.CENTER)
add_label(s7, "cycles  Drain Latency", Inches(3.65), Inches(2.7), Inches(2.9), Inches(0.35),
          size=13, color=TEXT_MUTED, align=PP_ALIGN.CENTER)
add_label(s7, "2-stage MAC + 4-stage Requant", Inches(3.65), Inches(3.05), Inches(2.9), Inches(0.3),
          size=11, bold=True, color=WHITE, align=PP_ALIGN.CENTER)

add_card(s7, Inches(6.8),  Inches(1.55), Inches(2.9), Inches(2.5))
add_label(s7, "+0.033", Inches(6.8), Inches(1.75), Inches(2.9), Inches(1.1),
          size=44, bold=True, color=SUCCESS, align=PP_ALIGN.CENTER)
add_label(s7, "ns  Final WNS (Timing MET)", Inches(6.8), Inches(2.7), Inches(2.9), Inches(0.35),
          size=13, color=TEXT_MUTED, align=PP_ALIGN.CENTER)
add_label(s7, "Post-route timing closure achieved", Inches(6.8), Inches(3.05), Inches(2.9), Inches(0.3),
          size=11, bold=True, color=WHITE, align=PP_ALIGN.CENTER)

add_card(s7, Inches(9.95), Inches(1.55), Inches(2.9), Inches(2.5))
add_label(s7, "100%", Inches(9.95), Inches(1.75), Inches(2.9), Inches(1.1),
          size=44, bold=True, color=ACCENT_CYAN, align=PP_ALIGN.CENTER)
add_label(s7, "Routes Complete", Inches(9.95), Inches(2.7), Inches(2.9), Inches(0.35),
          size=13, color=TEXT_MUTED, align=PP_ALIGN.CENTER)
add_label(s7, "0 failed nets. 0 node overlaps.", Inches(9.95), Inches(3.05), Inches(2.9), Inches(0.3),
          size=11, bold=True, color=WHITE, align=PP_ALIGN.CENTER)

# Pipeline latency breakdown bar
add_rect(s7, Inches(0.5), Inches(4.25), Inches(12.3), Inches(2.8),
         fill_color=DARK_CARD, line_color=RGBColor(0x25, 0x28, 0x45), line_width_pt=0.8)
add_label(s7, "PIPELINE STAGE LATENCY BREAKDOWN",
          Inches(0.7), Inches(4.33), Inches(8), Inches(0.35),
          size=10, bold=True, color=TEXT_MUTED)

pipe_stages = [
    ("AXI-Stream\nInput", "1 cycle", 1.2),
    ("Activation\nBuffer Write", "1 cycle", 1.2),
    ("Systolic Array\nMAC Stage 1", "1 cycle", 1.4),
    ("Systolic Array\nMAC Stage 2", "1 cycle", 1.4),
    ("Requant\n4-Stage Pipe", "4 cycles", 2.5),
    ("Output\nScoreboard", "1 cycle", 1.2),
]
bar_colors = [RGBColor(0x00,0x55,0x88), RGBColor(0x00,0x66,0xAA), ACCENT_BLUE,
              ACCENT_BLUE, RGBColor(0x00,0x88,0xCC), RGBColor(0x00,0x44,0x77)]
x_cursor = Inches(0.65)
for i, (stage, cyc, width_in) in enumerate(pipe_stages):
    w_bar = Inches(width_in)
    add_rect(s7, x_cursor, Inches(4.75), w_bar - Inches(0.08), Inches(0.85),
             fill_color=bar_colors[i],
             line_color=ACCENT_CYAN, line_width_pt=0.5)
    add_label(s7, stage, x_cursor, Inches(4.78), w_bar - Inches(0.08), Inches(0.5),
              size=9, bold=True, color=WHITE, align=PP_ALIGN.CENTER)
    add_label(s7, cyc, x_cursor, Inches(5.55), w_bar - Inches(0.08), Inches(0.35),
              size=10, color=ACCENT_CYAN, align=PP_ALIGN.CENTER)
    x_cursor += w_bar

add_label(s7, "Total end-to-end pipeline latency: ~9 clock cycles  @195 MHz = ~46 ns  |  Deterministic. No OS jitter. No interrupt-driven delays.",
          Inches(0.65), Inches(6.6), Inches(12.0), Inches(0.4),
          size=12, color=TEXT_MUTED)


# ══════════════════════════════════════════════════════════════════════════════
# SLIDE 8 — TIMING CLOSURE JOURNEY
# ══════════════════════════════════════════════════════════════════════════════
s8 = prs.slides.add_slide(BLANK_LAYOUT)
slide_bg(s8)
add_rect(s8, 0, 0, W, Inches(0.06), fill_color=ACCENT_CYAN)
add_top_bar(s8, "Timing Closure Journey",
            "Systematic diagnosis and resolution of setup violations — from WNS -1.285 ns to +0.033 ns PASS.")

# Journey steps
steps = [
    ("-1.285 ns", "Initial Build",
     "11 LUT levels in one combinational cycle inside frame_gen.v comparison logic. Critical path too long.",
     "Pipelined the comparison into 2 register stages to break the long logic chain.",
     False),
    ("-0.602 ns", "After RTL Fix",
     "Routing introduced additional hold slack issues. Physical optimization had not been applied.",
     "Ran AggressiveExplore phys_opt_design strategy to retime and restructure the placed netlist.",
     False),
    ("-0.176 ns", "After phys_opt",
     "Clock domain skew discovered: u_pooling (ICG gated clock, +3.35 ns delay) drives u_threshold_filter (ungated clock).",
     "Changed threshold_filter to use clk_postproc — same domain, eliminating the inter-domain skew.",
     False),
    ("+0.033 ns", "FINAL — MET",
     "Vivado used cached old netlist. Directly patched .gen/ipshared/bd96/src/tinynpu_top.v to force resynthesis.",
     "Timing closure achieved. WNS positive. All 472 endpoints passing. Hold slack 0.172 ns.",
     True),
]

for i, (wns, title, problem, fix, is_pass) in enumerate(steps):
    ly = Inches(1.5 + i * 1.35)
    # Step connector line
    if i < 3:
        add_rect(s8, Inches(1.08), ly + Inches(1.28), Inches(0.04), Inches(0.1),
                 fill_color=RGBColor(0x30, 0x40, 0x60))

    # Circle indicator
    dot_color = SUCCESS if is_pass else RGBColor(0x00, 0x66, 0xAA)
    add_rect(s8, Inches(0.8), ly + Inches(0.3), Inches(0.55), Inches(0.55),
             fill_color=dot_color, line_color=dot_color)

    # WNS badge
    badge_col = RGBColor(0x00, 0x28, 0x15) if is_pass else RGBColor(0x20, 0x08, 0x08)
    badge_border = SUCCESS if is_pass else RGBColor(0xFF, 0x44, 0x44)
    add_rect(s8, Inches(1.5), ly + Inches(0.2), Inches(1.5), Inches(0.6),
             fill_color=badge_col, line_color=badge_border, line_width_pt=1.0)
    add_label(s8, wns, Inches(1.5), ly + Inches(0.25), Inches(1.5), Inches(0.5),
              size=16, bold=True,
              color=SUCCESS if is_pass else RGBColor(0xFF, 0x55, 0x55),
              align=PP_ALIGN.CENTER)

    # Step title
    add_label(s8, title, Inches(3.2), ly + Inches(0.18), Inches(2.5), Inches(0.45),
              size=15, bold=True, color=WHITE)

    # Problem
    add_label(s8, "ROOT CAUSE: " + problem,
              Inches(5.8), ly + Inches(0.1), Inches(4.0), Inches(0.55),
              size=11, color=TEXT_MUTED)

    # Fix
    add_label(s8, "FIX: " + fix,
              Inches(5.8), ly + Inches(0.65), Inches(7.0), Inches(0.55),
              size=11, color=ACCENT_CYAN if is_pass else TEXT_BODY)

# Final result banner
add_rect(s8, Inches(0.5), Inches(7.0), Inches(12.3), Inches(0.38),
         fill_color=RGBColor(0x00, 0x22, 0x12), line_color=SUCCESS, line_width_pt=1.0)
add_label(s8, "TIMING CLOSED  |  WNS = +0.033 ns  |  TNS = 0.000 ns  |  2/472 endpoints resolved  |  Hold Slack = 0.172 ns  |  FPGA SILICON VERIFIED",
          Inches(0.7), Inches(7.03), Inches(12.0), Inches(0.35),
          size=11, bold=True, color=SUCCESS, align=PP_ALIGN.CENTER)


s9 = prs.slides.add_slide(BLANK_LAYOUT)
slide_bg(s9)
add_rect(s9, 0, 0, W, Inches(0.06), fill_color=ACCENT_CYAN)
add_top_bar(s9, "References & Future Scope",
            "Academic grounding and planned architectural extensions.")

# References card
add_card(s9, Inches(0.5), Inches(1.55), Inches(6.0), Inches(5.5),
         border_color=RGBColor(0x30, 0x50, 0x80))
add_label(s9, "REFERENCES", Inches(0.7), Inches(1.7), Inches(5.5), Inches(0.45),
          size=13, bold=True, color=ACCENT_CYAN)
add_multiline(s9, [
    '[1]  Jouppi, N.P., et al. (2017). "In-Datacenter Performance Analysis of a Tensor Processing Unit." ISCA.',
    '',
    '[2]  Chen, Y., et al. (2016). "Eyeriss: An Energy-Efficient Reconfigurable Accelerator for Deep CNNs." IEEE JSSC.',
    '',
    '[3]  Du, Z., et al. (2015). "ShiDianNao: Shifting Vision Processing Closer to the Sensor." ISCA.',
    '',
    '[4]  Xilinx Inc. (2025). Vivado Design Suite User Guide: Power Analysis and Optimization. UG907.',
    '',
    '[5]  IEEE Std 1364-2001. IEEE Standard for Verilog Hardware Description Language.',
], Inches(0.7), Inches(2.2), Inches(5.6), Inches(4.5), size=12, color=TEXT_BODY, spacing_pt=5)

# Future scope card
add_card(s9, Inches(6.9), Inches(1.55), Inches(5.9), Inches(5.5),
         border_color=RGBColor(0x00, 0xA5, 0xFF))
add_label(s9, "FUTURE SCOPE", Inches(7.1), Inches(1.7), Inches(5.5), Inches(0.45),
          size=13, bold=True, color=ACCENT_CYAN)
add_multiline(s9, [
    '> JTAG-to-AXI Video Streaming — Inject stored video frame-by-frame directly into the NPU data path via JTAG debug cable, with zero software on the chip.',
    '',
    '> SRAM Macro Migration — Replace FPGA BRAM primitives with TSMC/GlobalFoundries standard-cell SRAM macros to prepare the design for full ASIC tapeout.',
    '',
    '> DVFS Control Logic — Implement dynamic voltage and frequency scaling FSMs for sub-50mW idle power states during between-frame blanking intervals.',
    '',
    '> Depthwise Separable Conv — Extend the systolic array with a DW convolution engine lane for MobileNet/YOLOv8 nano-scale layer support.',
], Inches(7.1), Inches(2.2), Inches(5.5), Inches(4.5), size=12, color=TEXT_BODY, spacing_pt=5)


# ── Save ──────────────────────────────────────────────────────────────────────
out_path = r"D:\Final year project\Project_Documents\TinyNPU_MNC_Presentation.pptx"
prs.save(out_path)
print("[DONE] Saved: " + out_path)
