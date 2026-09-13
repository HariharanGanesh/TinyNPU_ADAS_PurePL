xvlog --sv -d BEHAVIORAL_CG -i "d:\Final year project\Shared\Common\01_RTL" "d:\Final year project\Shared\Common\01_RTL\pe\processing_element.v" "d:\Final year project\Shared\Common\02_Verification\assertions\pe_assertions.sv" "d:\Final year project\Shared\Common\02_Verification\tb\tb_pe_comprehensive.sv"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

xelab -top tb_pe_comprehensive -snapshot tb_pe_snap
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

xsim tb_pe_snap -R
