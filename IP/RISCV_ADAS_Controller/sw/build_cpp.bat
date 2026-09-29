@echo off
set GCC_BIN=D:\Final year project\riscv-toolchain\xpack-riscv-none-elf-gcc-14.2.0-1\bin

echo Compiling C++ firmware for PicoRV32...
"%GCC_BIN%\riscv-none-elf-gcc.exe" -Os -mabi=ilp32 -march=rv32i -ffreestanding -nostdlib -Wl,-T,sections.lds start.s main.cpp -o firmware.elf -lgcc

if %errorlevel% neq 0 (
    echo Compilation FAILED!
    exit /b %errorlevel%
)

echo Converting ELF to Verilog Hex (32-bit format)...
"%GCC_BIN%\riscv-none-elf-objcopy.exe" -O verilog --verilog-data-width=4 firmware.elf firmware.hex

if %errorlevel% neq 0 (
    echo Hex generation FAILED!
    exit /b %errorlevel%
)

echo Success! firmware.hex generated.
