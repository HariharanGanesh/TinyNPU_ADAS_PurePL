xvlog --sv -d BEHAVIORAL_CG -i "d:\Final year project\Shared\Common\01_RTL\top" -i "d:\Final year project\Shared\Common\01_RTL\control" -i "d:\Final year project\Shared\Common\01_RTL\pe" -i "d:\Final year project\Shared\Common\01_RTL\systolic_array" -i "d:\Final year project\Shared\Common\01_RTL\buffers" -i "d:\Final year project\Shared\Common\01_RTL\quantization" -i "d:\Final year project\Shared\Common\01_RTL\activation" -i "d:\Final year project\Shared\Common\01_RTL\pooling" -i "d:\Final year project\Shared\Common\01_RTL\dw_engine" -i "d:\Final year project\Shared\Common\01_RTL\core" -i "d:\Final year project\Shared\Common\01_RTL\axi" -i "d:\Final year project\Shared\Common\01_RTL\dma" -i "d:\Final year project\Shared\Common\01_RTL\wrappers" "d:\Final year project\Shared\Common\01_RTL\*\*.v" "d:\Final year project\Shared\Common\01_RTL\*\*\*.v" "d:\Final year project\Shared\Common\02_Verification\tb\tinynpu_top_tb.sv"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

xelab -top tinynpu_top_tb -snapshot tinynpu_top_snap
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

xsim tinynpu_top_snap -R
