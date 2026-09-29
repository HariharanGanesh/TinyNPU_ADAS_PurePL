@echo off
title TinyNPU200JPMAX / NPU300PM — Vivado GUI Launcher
color 0A
echo.
echo  ================================================
echo   TinyNPU200JPMAX / NPU300PM Project
echo   26x8 = 208 MACs (DSP48E1) @ 125 MHz
echo   ~0.052 TOPS  --  Ballistic Vision System
echo  ================================================
echo.

:: Set up Vivado environment
call D:\2025.1\Vivado\settings64.bat

:: Open the newly built project in Vivado GUI
if exist "D:\Final year project\npu200jpmax\npu200jpmax.xpr" (
    echo  [INFO] Opening TinyNPU200JPMAX project in Vivado GUI...
    echo.
    vivado "D:\Final year project\npu200jpmax\npu200jpmax.xpr"
) else (
    echo  [INFO] Project not found. Run rebuild_pmax.ps1 first.
    pause
)

echo.
echo  [Done] Vivado GUI closed.
pause
