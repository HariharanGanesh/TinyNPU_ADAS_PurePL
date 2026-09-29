@echo off
title TinyNPU200 Simulation
echo =======================================================
echo       TinyNPU200 Testbench Simulation Runner
echo =======================================================
echo.
call D:\2025.1\Vivado\bin\vivado.bat -mode batch -source run_all.tcl
echo.
echo =======================================================
echo Simulation completed.
pause
