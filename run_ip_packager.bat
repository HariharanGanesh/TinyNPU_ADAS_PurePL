@echo off
set VIVADO_SETTINGS=D:\2025.1\Vivado\settings64.bat
call "%VIVADO_SETTINGS%"
cd /d "D:\Final year project"
vivado -mode batch -source "Versions\TinyNPU200J\scripts\package_ip200.tcl"
