xvlog --sv -d BEHAVIORAL_CG "d:\Final year project\Shared\Common\01_RTL\activation\piecewise_sigmoid.v" "d:\Final year project\Shared\Common\02_Verification\tb\tb_piecewise_sigmoid.sv"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

xelab -top tb_piecewise_sigmoid -snapshot tb_piecewise_sigmoid_snap
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

xsim tb_piecewise_sigmoid_snap -R
