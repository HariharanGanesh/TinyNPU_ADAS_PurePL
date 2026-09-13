# ==============================================================================
# run_sim.ps1 - TinyNPU v3.0 xsim Simulation Script
# Target:  Vivado 2025.1 xsim (Xilinx Simulator)
# Platform: PYNQ-Z2 prototype (Verification runs on any Windows host)
#
# Usage:
#   .\run_sim.ps1                          # Run default system testbench
#   .\run_sim.ps1 -TB systolic_array_tb    # Run specific module testbench
# ==============================================================================

param(
    [string]$TB = "tinynpu_system_tb"
)

$VIVADO = "D:\2025.1\Vivado\bin"
$XVLOG  = "$VIVADO\xvlog.bat"
$XELAB  = "$VIVADO\xelab.bat"
$XSIM   = "$VIVADO\xsim.bat"

Write-Host "=============================================================="
Write-Host "  TinyNPU v3.0 - HDL Simulation"
Write-Host "  Testbench: $TB"
Write-Host "=============================================================="

# ------------------------------------------------------------------------------
# Step 1: Compile all Core RTL (Verilog-2001)
# ------------------------------------------------------------------------------
Write-Host "[1/4] Compiling TinyNPU Core RTL..."

$CORE_RTL = @(
    "01_RTL\core\tinynpu_icg.v",
    "01_RTL\core\sram_1rw.v",
    "01_RTL\core\sram_2rw.v",
    "01_RTL\core\rst_sync.v",
    "01_RTL\activation\piecewise_sigmoid.v",
    "01_RTL\activation\sigmoid_lut.v",
    "01_RTL\activation\activation_unit.v",
    "01_RTL\axi\axi4_lite_slave.v",
    "01_RTL\axi\axis_sink.v",
    "01_RTL\axi\axis_source.v",
    "01_RTL\buffers\activation_buffer.v",
    "01_RTL\buffers\output_buffer.v",
    "01_RTL\buffers\weight_buffer.v",
    "01_RTL\control\npu_controller.v",
    "01_RTL\dma\dma_controller.v",
    "01_RTL\dw_engine\dw_line_buffer.v",
    "01_RTL\pe\processing_element.v",
    "01_RTL\pe\bbox_decoder.v",
    "01_RTL\pooling\pooling_unit.v",
    "01_RTL\quantization\requantization_unit.v",
    "01_RTL\quantization\threshold_filter.v",
    "01_RTL\systolic_array\systolic_array.v",
    "01_RTL\top\tinynpu_top.v"
)

& $XVLOG --define BEHAVIORAL_CG --nolog $CORE_RTL
if ($LASTEXITCODE -ne 0) { Write-Error "Core RTL compile failed!"; exit 1 }

# ------------------------------------------------------------------------------
# Step 2: Compile Verification Infrastructure (Verilog-2001)
# ------------------------------------------------------------------------------
Write-Host "[2/4] Compiling Verification Infrastructure..."

$VERIF_RTL = @(
    "02_Verification\monitor\perf_monitor.v",
    "02_Verification\scoreboard\hw_scoreboard.v"
)

& $XVLOG --nolog $VERIF_RTL
if ($LASTEXITCODE -ne 0) { Write-Error "Verification RTL compile failed!"; exit 1 }

# ------------------------------------------------------------------------------
# Step 3: Compile the chosen SystemVerilog testbench
# ------------------------------------------------------------------------------
Write-Host "[3/4] Compiling Testbench: $TB..."

& $XVLOG --sv --nolog "02_Verification\tb\$TB.sv"
if ($LASTEXITCODE -ne 0) { Write-Error "Testbench compile failed!"; exit 1 }

# ------------------------------------------------------------------------------
# Step 4: Elaborate and simulate
# ------------------------------------------------------------------------------
Write-Host "[4/4] Elaborating and running simulation..."

& $XELAB -top $TB -snapshot "${TB}_snap" --nolog -define BEHAVIORAL_CG -timescale "1ns/1ps"
if ($LASTEXITCODE -ne 0) { Write-Error "Elaboration failed!"; exit 1 }

# Run simulation (batch mode - no GUI, auto-finish on finish)
& $XSIM "${TB}_snap" --nolog --runall

Write-Host "=============================================================="
Write-Host "  Simulation Complete. Check output above for PASS/FAIL."
Write-Host "=============================================================="
