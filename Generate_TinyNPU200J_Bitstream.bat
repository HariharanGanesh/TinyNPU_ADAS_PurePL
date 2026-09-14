@echo off
REM ============================================================
REM  TinyNPU200J — One-Click Bitstream Generator
REM  Target: PYNQ-Z2 (XC7Z020CLG400-1)
REM  Clock:  195 MHz | Array: 20x8 INT8 | ~24.96 GOPS
REM ============================================================
echo.
echo  ============================================================
echo   TinyNPU200 Bitstream Generation
echo   Target: PYNQ-Z2 (xc7z020clg400-1)
echo   Clock:  195 MHz
echo   Array:  20 x 8 INT8 Systolic (160 DSPs, ~24.96 GOPS)
echo  ============================================================
echo.

REM ── Step 1: Source Vivado 2025.1 environment ─────────────────
set VIVADO_SETTINGS=D:\2025.1\Vivado\settings64.bat

if not exist "%VIVADO_SETTINGS%" (
    echo ERROR: Vivado 2025.1 not found at:
    echo   %VIVADO_SETTINGS%
    echo.
    echo Please verify your Xilinx installation path and update
    echo the VIVADO_SETTINGS variable in this .bat file.
    pause
    exit /b 1
)

echo [%TIME%] Sourcing Vivado 2025.1 environment...
call "%VIVADO_SETTINGS%"

REM ── Step 2: Confirm vivado.bat is now reachable ───────────────
where vivado >nul 2>&1
if errorlevel 1 (
    echo ERROR: vivado.exe still not found after sourcing settings.
    echo Check your Vivado installation integrity.
    pause
    exit /b 1
)

REM ── Step 3: Create Logs directory if missing ──────────────────
if not exist "D:\Final year project\Logs" mkdir "D:\Final year project\Logs"

cd /d "D:\Final year project"

echo [%TIME%] Starting Vivado batch build...
echo.
vivado -mode batch ^
    -source "Versions\TinyNPU200J\scripts\build_npu200j.tcl" ^
    -log    "Logs\npu200j_build.log" ^
    -journal "Logs\npu200j_build.jou"

if errorlevel 1 (
    echo.
    echo  ============================================================
    echo   BUILD FAILED
    echo   Check log: D:\Final year project\Logs\npu200j_build.log
    echo  ============================================================
    pause
    exit /b 1
)

echo.
echo  ============================================================
echo   SUCCESS: TinyNPU200 Bitstream generated!
echo   Bitstream: D:\Final year project\TinyNPU200.bit
echo   Log:       D:\Final year project\Logs\npu200j_build.log
echo  ============================================================
echo.
pause
