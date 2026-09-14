# =============================================================================
# PowerShell script: run_top_sim.ps1
# Project: TinyNPU
# Description:
#   Compiles and runs the complete TinyNPU regression testbench using
#   Vivado Simulator (xsim) in batch mode.
#
#   KEY CHANGE: Adds -define BEHAVIORAL_CG to every xvlog invocation.
#   This selects the AND-gate behavioral model inside clk_gate_bufgce.v
#   instead of the real Xilinx BUFGCE primitive, which is only available
#   when the full Xilinx unisim library is compiled in.
#
#   When running inside Vivado's "Run Simulation" GUI, the unisim library
#   IS available — remove -define BEHAVIORAL_CG in that case, or let Vivado
#   handle it automatically via its IP simulation settings.
#
# Usage:
#   cd d:\Final year project\verif\tb
#   .\run_top_sim.ps1
# =============================================================================

# Prepend Vivado bin directory to system PATH
$vivado_path = "D:\2025.1\Vivado\bin"
if (Test-Path $vivado_path) {
    $env:PATH = "$vivado_path;" + $env:PATH
    Write-Host "[INFO] Added $vivado_path to PATH." -ForegroundColor Green
} else {
    Write-Host "[WARNING] Vivado path $vivado_path not found. Simulation might fail." -ForegroundColor Yellow
}

# Cleanup previous simulation build files
Write-Host "[INFO] Cleaning up old simulation files..." -ForegroundColor Cyan
Remove-Item -Path "xsim.dir", "xvlog.log", "xelab.log", "xsim.log",
            "xvlog.pb", "xelab.pb", "webtalk.log" -Recurse -Force -ErrorAction SilentlyContinue

# ─────────────────────────────────────────────────────────────────────────────
# Common xvlog flags:
#   -define BEHAVIORAL_CG   → use AND-gate model for BUFGCE (no unisim needed)
#   --work work             → compile all units into the 'work' library
# ─────────────────────────────────────────────────────────────────────────────
$xvlog_flags = @("--work", "work", "-define", "BEHAVIORAL_CG")

# 1. Analyze Verilog RTL files (dependency order — leaves before parents)
Write-Host "[INFO] Analyzing RTL Verilog files..." -ForegroundColor Cyan

& xvlog @xvlog_flags "../../rtl/pe/processing_element.v"
& xvlog @xvlog_flags "../../rtl/systolic_array/systolic_array.v"
& xvlog @xvlog_flags "../../rtl/buffers/activation_buffer.v"
& xvlog @xvlog_flags "../../rtl/buffers/weight_buffer.v"
& xvlog @xvlog_flags "../../rtl/buffers/output_buffer.v"
& xvlog @xvlog_flags "../../rtl/quantization/requantization_unit.v"
& xvlog @xvlog_flags "../../rtl/quantization/threshold_filter.v"
& xvlog @xvlog_flags "../../rtl/activation/activation_unit.v"
& xvlog @xvlog_flags "../../rtl/pooling/pooling_unit.v"
& xvlog @xvlog_flags "../../rtl/dw_engine/dw_line_buffer.v"
& xvlog @xvlog_flags "../../rtl/axi/axi4_lite_slave.v"
& xvlog @xvlog_flags "../../rtl/axi/axis_sink.v"
& xvlog @xvlog_flags "../../rtl/axi/axis_source.v"
& xvlog @xvlog_flags "../../rtl/dma/dma_controller.v"
& xvlog @xvlog_flags "../../rtl/control/npu_controller.v"
& xvlog @xvlog_flags "../../rtl/clocking/clk_gate_bufgce.v"   # NEW: clock gating wrapper
& xvlog @xvlog_flags "../../rtl/top/tinynpu_top.v"

# 2. Analyze SystemVerilog testbench
Write-Host "[INFO] Analyzing Testbench..." -ForegroundColor Cyan
& xvlog --work work -sv "tinynpu_top_tb.sv"

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Analysis (xvlog) failed! Check xvlog.log for details." -ForegroundColor Red
    Exit $LASTEXITCODE
}

# 3. Elaborate the design
Write-Host "[INFO] Elaborating Design..." -ForegroundColor Cyan
& xelab -L work work.tinynpu_top_tb -s tinynpu_top_sim

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Elaboration (xelab) failed! Check xelab.log for details." -ForegroundColor Red
    Exit $LASTEXITCODE
}

# 4. Run simulation in batch mode (-R = run to completion / $finish)
Write-Host "[INFO] Running Simulation..." -ForegroundColor Cyan
& xsim tinynpu_top_sim -R

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Simulation failed! Check xsim.log for details." -ForegroundColor Red
    Exit $LASTEXITCODE
}

Write-Host "[SUCCESS] All 9 test cases complete. Check output above for PASS/FAIL." -ForegroundColor Green
