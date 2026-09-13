# run_soc_sim.ps1
$ErrorActionPreference = "Stop"

# 1. Add Vivado to PATH
if ($env:PATH -notmatch "Vivado\\bin") {
    $env:PATH += ";D:\2025.1\Vivado\bin"
    Write-Host "[INFO] Added D:\2025.1\Vivado\bin to PATH."
}

$WorkspaceDir = "D:\Final year project"
$IpDir = "$WorkspaceDir\IP\RISCV_ADAS_Controller"
$VerifDir = "$WorkspaceDir\Shared\Common\02_Verification\soc_tb"
$RtlDir = "$WorkspaceDir\Shared\Common\rtl"

# 2. Skip compilation (using pre-assembled firmware.hex)
Write-Host "[INFO] Using pre-assembled firmware.hex..."
if (-Not (Test-Path "$VerifDir\firmware.hex")) {
    Write-Host "[ERROR] firmware.hex not found!" -ForegroundColor Red
    exit 1
}

# 3. Clean up
cd $VerifDir
Write-Host "[INFO] Cleaning up old simulation files..."
Remove-Item -Force -Recurse xsim.dir -ErrorAction Ignore
Remove-Item -Force *.log, *.pb, *.jou -ErrorAction Ignore

# 4. Analyze RTL (TinyNPU)
Write-Host "[INFO] Analyzing TinyNPU RTL..."
$tinynpu_files = @(
    "$RtlDir\pe\processing_element.v",
    "$RtlDir\pe\bbox_decoder.v",
    "$RtlDir\core\tinynpu_icg.v",
    "$RtlDir\systolic_array\systolic_array.v",
    "$RtlDir\buffers\activation_buffer.v",
    "$RtlDir\buffers\weight_buffer.v",
    "$RtlDir\buffers\output_buffer.v",
    "$RtlDir\quantization\requantization_unit.v",
    "$RtlDir\quantization\threshold_filter.v",
    "$RtlDir\activation\activation_unit.v",
    "$RtlDir\activation\piecewise_sigmoid.v",
    "$RtlDir\pooling\pooling_unit.v",
    "$RtlDir\dw_engine\dw_line_buffer.v",
    "$RtlDir\axi\axi4_lite_slave.v",
    "$RtlDir\axi\axis_sink.v",
    "$RtlDir\axi\axis_source.v",
    "$RtlDir\dma\dma_controller.v",
    "$RtlDir\control\npu_controller.v",
    "$RtlDir\clocking\clk_gate_bufgce.v",
    "$RtlDir\top\tinynpu_top.v"
)

foreach ($file in $tinynpu_files) {
    xvlog --sv $file
    if ($LASTEXITCODE -ne 0) { Write-Host "[ERROR] Analysis failed for $file"; exit 1 }
}

# 5. Analyze ADAS IP
Write-Host "[INFO] Analyzing RISC-V ADAS RTL..."
$adas_files = @(
    "$IpDir\src\picorv32.v",
    "$IpDir\src\sensor_fusion.v",
    "$IpDir\src\safety_unit.v",
    "$IpDir\src\security_unit.v",
    "$IpDir\src\riscv_adas_subsystem.v"
)

foreach ($file in $adas_files) {
    # If the file is missing, the script will naturally fail. We assume it's there.
    xvlog --sv $file
    if ($LASTEXITCODE -ne 0) { Write-Host "[ERROR] Analysis failed for $file"; exit 1 }
}

# 6. Analyze Testbench
Write-Host "[INFO] Analyzing Testbench..."
xvlog --sv tb_soc_top.sv
if ($LASTEXITCODE -ne 0) { Write-Host "[ERROR] Analysis failed for Testbench"; exit 1 }

# 7. Elaborate
Write-Host "[INFO] Elaborating Design..."
xelab -L work work.tb_soc_top -s tb_soc_snap
if ($LASTEXITCODE -ne 0) { Write-Host "[ERROR] Elaboration failed"; exit 1 }

# 8. Simulate
Write-Host "[INFO] Running Simulation..."
xsim tb_soc_snap -R
if ($LASTEXITCODE -ne 0) { Write-Host "[ERROR] Simulation failed"; exit 1 }

Write-Host "[SUCCESS] RISCV_ADAS_NPU Verification Completed!" -ForegroundColor Green
