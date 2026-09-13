param([string]$TB = "tinynpu_system_tb")
$VIVADO = "D:\2025.1\Vivado\bin"
$XVLOG = "$VIVADO\xvlog.bat"
$XELAB = "$VIVADO\xelab.bat"
$XSIM = "$VIVADO\xsim.bat"

Write-Host "Compiling Core RTL..."
$CORE_RTL = @(
    "rtl\src\core\tinynpu_icg.v",
    "rtl\src\core\sram_1rw.v",
    "rtl\src\core\sram_2rw.v",
    "rtl\src\core\rst_sync.v",
    "rtl\src\activation\piecewise_sigmoid.v",
    "rtl\src\activation\sigmoid_lut.v",
    "rtl\src\activation\activation_unit.v",
    "rtl\src\axi\axi4_lite_slave.v",
    "rtl\src\axi\axis_sink.v",
    "rtl\src\axi\axis_source.v",
    "rtl\src\buffers\activation_buffer.v",
    "rtl\src\buffers\output_buffer.v",
    "rtl\src\buffers\weight_buffer.v",
    "rtl\src\control\npu_controller.v",
    "rtl\src\dma\dma_controller.v",
    "rtl\src\dw_engine\dw_line_buffer.v",
    "rtl\src\pe\processing_element.v",
    "rtl\src\pe\bbox_decoder.v",
    "rtl\src\pooling\pooling_unit.v",
    "rtl\src\quantization\requantization_unit.v",
    "rtl\src\quantization\threshold_filter.v",
    "rtl\src\systolic_array\systolic_array.v",
    "rtl\src\top\tinynpu_top.v"
)
& $XVLOG --define BEHAVIORAL_CG --nolog $CORE_RTL
if ($LASTEXITCODE -ne 0) { exit 1 }

Write-Host "Compiling Verif..."
$VERIF_RTL = @("verif\monitor\perf_monitor.v", "verif\scoreboard\hw_scoreboard.v")
& $XVLOG --nolog $VERIF_RTL
if ($LASTEXITCODE -ne 0) { exit 1 }

Write-Host "Compiling TB..."
& $XVLOG --sv --nolog "verif\tb\$TB.sv"
if ($LASTEXITCODE -ne 0) { exit 1 }

Write-Host "Elaborating..."
& $XELAB -top $TB -snapshot "${TB}_snap" --nolog -define BEHAVIORAL_CG -timescale "1ns/1ps"
if ($LASTEXITCODE -ne 0) { exit 1 }

Write-Host "Simulating..."
& $XSIM "${TB}_snap" --nolog --runall
