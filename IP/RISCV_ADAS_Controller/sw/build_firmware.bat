@echo off
echo ===============================================================
echo  RISCV_ADAS_NPU300 - Firmware Build Script
echo  Assembles firmware.s -> firmware.hex (PicoRV32 RV32I)
echo ===============================================================
cd /d "%~dp0"

REM Try python3 first, then python
where python3 >nul 2>&1
if %errorlevel% == 0 (
    set PYTHON=python3
) else (
    set PYTHON=python
)

echo [1] Assembling firmware.s...
%PYTHON% rv32_assembler.py firmware.s firmware.hex

if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Assembly FAILED! Check firmware.s for syntax errors.
    pause
    exit /b 1
)

echo.
echo [2] Firmware built successfully!
echo     Output: firmware.hex
echo.
echo [3] Instruction count:
for /f %%A in ('find /c "" ^< firmware.hex') do echo     %%A words ^(x4 = bytes in BRAM^)
echo.
echo [NEXT] Copy firmware.hex to the Vivado project sources and rebuild bitstream.
echo        The riscv_adas_subsystem.v will load it via: $readmemh("firmware.hex", firmware_bram)
pause
