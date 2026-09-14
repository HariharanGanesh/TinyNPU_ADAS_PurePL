# =============================================================================
# PowerShell script: run_redteam_sim.ps1
# Project: TinyNPU
# Description:
#   Compiles and runs the Red-Team adversarial testbench
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

$xvlog_flags = @("--work", "work", "-define", "BEHAVIORAL_CG")

Write-Host "[INFO] Analyzing RTL Verilog files..." -ForegroundColor Cyan

& xvlog @xvlog_flags "../../rtl/pe/processing_element.v"
& xvlog @xvlog_flags "../../rtl/pe/bbox_decoder.v"
& xvlog @xvlog_flags "../../rtl/core/tinynpu_icg.v"
& xvlog @xvlog_flags "../../rtl/systolic_array/systolic_array.v"
& xvlog @xvlog_flags "../../rtl/buffers/activation_buffer.v"
& xvlog @xvlog_flags "../../rtl/buffers/weight_buffer.v"
& xvlog @xvlog_flags "../../rtl/buffers/output_buffer.v"
& xvlog @xvlog_flags "../../rtl/quantization/requantization_unit.v"
& xvlog @xvlog_flags "../../rtl/quantization/threshold_filter.v"
& xvlog @xvlog_flags "../../rtl/activation/activation_unit.v"
& xvlog @xvlog_flags "../../rtl/activation/piecewise_sigmoid.v"
& xvlog @xvlog_flags "../../rtl/pooling/pooling_unit.v"
& xvlog @xvlog_flags "../../rtl/dw_engine/dw_line_buffer.v"
& xvlog @xvlog_flags "../../rtl/axi/axi4_lite_slave.v"
& xvlog @xvlog_flags "../../rtl/axi/axis_sink.v"
& xvlog @xvlog_flags "../../rtl/axi/axis_source.v"
& xvlog @xvlog_flags "../../rtl/dma/dma_controller.v"
& xvlog @xvlog_flags "../../rtl/control/npu_controller.v"
& xvlog @xvlog_flags "../../rtl/clocking/clk_gate_bufgce.v"
& xvlog @xvlog_flags "../../rtl/top/tinynpu_top.v"

& xvlog -sv --work work "../../verif/sva/tinynpu_assertions.sv"

Write-Host "[INFO] Analyzing Testbench..." -ForegroundColor Cyan
& xvlog --work work -sv "tb_redteam_top.sv"

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Analysis (xvlog) failed! Check xvlog.log for details." -ForegroundColor Red
    Exit $LASTEXITCODE
}

Write-Host "[INFO] Elaborating Design..." -ForegroundColor Cyan
& xelab -L work work.tb_redteam_top -s tb_redteam_snap

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Elaboration (xelab) failed! Check xelab.log for details." -ForegroundColor Red
    Exit $LASTEXITCODE
}

Write-Host "[INFO] Running Simulation..." -ForegroundColor Cyan
& xsim tb_redteam_snap -R

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Simulation failed! Check xsim.log for details." -ForegroundColor Red
    Exit $LASTEXITCODE
}

Write-Host "[SUCCESS] Red-Team script complete." -ForegroundColor Green
