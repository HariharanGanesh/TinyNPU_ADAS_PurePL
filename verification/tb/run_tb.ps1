$ErrorActionPreference = "Stop"
$vivado_bin = "D:\2025.1\Vivado\bin"

Write-Host "Running xvlog..."
& "$vivado_bin\xvlog.bat" -sv "D:\Final year project\IP\NPU300PMADAS\src\streaming_topk.v" "D:\Final year project\IP\NPU300PMADAS\src\bbox_decoder_dfl.v" "D:\Final year project\IP\NPU300PMADAS\src\sparse_candidate_packer.v" "D:\Final year project\IP\NPU300PMADAS\src\npu_detection_head.v" "D:\Final year project\verification\tb\npu_detection_head_tb.sv"

Write-Host "Running xelab..."
& "$vivado_bin\xelab.bat" -debug typical -top npu_detection_head_tb -snapshot top_snap

Write-Host "Running xsim..."
& "$vivado_bin\xsim.bat" top_snap -R
