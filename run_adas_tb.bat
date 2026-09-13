@echo off
set PATH=D:\2025.1\Vivado\bin;%PATH%
cd verification\tb
echo Compiling ADAS Subsystem Testbench...
xvlog -sv tb_adas_features.sv "..\..\IP\RISCV_ADAS_Controller\src\sensor_fusion.v" "..\..\IP\RISCV_ADAS_Controller\src\safety_unit.v" "..\..\IP\RISCV_ADAS_Controller\src\security_unit.v"
echo Elaborating...
xelab -debug typical -top tb_adas_features -snapshot tb_adas_features_snap
echo Running Simulation...
xsim tb_adas_features_snap -R

