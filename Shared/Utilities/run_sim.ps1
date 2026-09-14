# ==============================================================================
# run_sim.ps1 — TinyNPU v3.0 xsim Simulation Script
# Target:  Vivado 2025.1 xsim (Xilinx Simulator)
# Platform: PYNQ-Z2 prototype (Verification runs on any Windows host)
#
# ARCHITECTURE LAYER: Layer 3 — Verification Infrastructure
# No Python, no cocotb, no Linux dependencies. Pure HDL + xsim.
#
# Usage:
#   cd "d:\Final year project"
#   .\run_sim.ps1                          # Run default system testbench
#   .\run_sim.ps1 -TB systolic_array_tb    # Run specific module testbench
#   .\run_sim.ps1 -TB bbox_decoder_tb
#   .\run_sim.ps1 -TB dw_line_buffer_tb
# ==============================================================================

param(
    [string]$TB = "tinynpu_system_tb"
)

$VIVADO = "D:\2025.1\Vivado\bin"
$XVLOG  = "$VIVADO\xvlog.bat"
$XELAB  = "$VIVADO\xelab.bat"
$XSIM   = "$VIVADO\xsim.bat"

$SIM_DIR = "verif\tb\xsim.dir"
$LOG_DIR = "verif\tb"

Write-Host ""
Write-Host "=============================================================="
Write-Host "  TinyNPU v3.0 — HDL Simulation"
Write-Host "  Testbench: $TB"
Write-Host "  Platform:  Vivado xsim (no Python, no Linux)"
Write-Host "=============================================================="
Write-Host ""

# ------------------------------------------------------------------------------
# Step 1: Compile all Core RTL (Verilog-2001)
# ------------------------------------------------------------------------------
Write-Host "[1/4] Compiling TinyNPU Core RTL..."

$CORE_RTL = @(
    # Layer 1 Core — technology-independent
    "rtl\core\tinynpu_icg.v",
    "rtl\core\sram_1rw.v",
    "rtl\core\sram_2rw.v",
    "rtl\core\rst_sync.v",
    # Activation
    "rtl\activation\piecewise_sigmoid.v",
    "rtl\activation\sigmoid_lut.v",
    "rtl\activation\activation_unit.v",
    # AXI interfaces
    "rtl\axi\axi4_lite_slave.v",
    "rtl\axi\axis_sink.v",
    "rtl\axi\axis_source.v",
    # Buffers
    "rtl\buffers\activation_buffer.v",
    "rtl\buffers\output_buffer.v",
    "rtl\buffers\weight_buffer.v",
    # Control
    "rtl\control\npu_controller.v",
    # DMA
    "rtl\dma\dma_controller.v",
    # Depthwise engine
    "rtl\dw_engine\dw_line_buffer.v",
    # PE and Detection
    "rtl\pe\processing_element.v",
    "rtl\pe\bbox_decoder.v",
    # Pooling
    "rtl\pooling\pooling_unit.v",
    # Quantization
    "rtl\quantization\requantization_unit.v",
    "rtl\quantization\threshold_filter.v",
    # Systolic Array
    "rtl\systolic_array\systolic_array.v",
    # Top
    "rtl\top\tinynpu_top.v"
)

& $XVLOG --define BEHAVIORAL_CG --nolog $CORE_RTL
if ($LASTEXITCODE -ne 0) { Write-Error "Core RTL compile failed!"; exit 1 }

# ------------------------------------------------------------------------------
# Step 2: Compile Verification Infrastructure (Verilog-2001)
# ------------------------------------------------------------------------------
Write-Host "[2/4] Compiling Verification Infrastructure..."

$VERIF_RTL = @(
    "verif\monitor\perf_monitor.v",
    "verif\scoreboard\hw_scoreboard.v"
)

& $XVLOG --nolog $VERIF_RTL
if ($LASTEXITCODE -ne 0) { Write-Error "Verification RTL compile failed!"; exit 1 }

# ------------------------------------------------------------------------------
# Step 3: Compile the chosen SystemVerilog testbench
# ------------------------------------------------------------------------------
Write-Host "[3/4] Compiling Testbench: $TB..."

& $XVLOG --sv --nolog "verif\tb\$TB.sv"
if ($LASTEXITCODE -ne 0) { Write-Error "Testbench compile failed!"; exit 1 }

# ------------------------------------------------------------------------------
# Step 4: Elaborate and simulate
# ------------------------------------------------------------------------------
Write-Host "[4/4] Elaborating and running simulation..."

& $XELAB -top $TB -snapshot "${TB}_snap" --nolog `
    -define BEHAVIORAL_CG `
    -timescale "1ns/1ps"
if ($LASTEXITCODE -ne 0) { Write-Error "Elaboration failed!"; exit 1 }

# Run simulation (batch mode — no GUI, auto-finish on $finish)
& $XSIM "${TB}_snap" --nolog --runall

Write-Host ""
Write-Host "=============================================================="
Write-Host "  Simulation Complete. Check output above for PASS/FAIL."
Write-Host "=============================================================="
