xvlog --sv -d BEHAVIORAL_CG "d:\Final year project\Shared\Common\rtl\frontend\result_capture.v" "d:\Final year project\Shared\Common\02_Verification\tb\tb_result_capture.sv"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

xelab -top tb_result_capture -snapshot tb_result_capture_snap
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

xsim tb_result_capture_snap -R
