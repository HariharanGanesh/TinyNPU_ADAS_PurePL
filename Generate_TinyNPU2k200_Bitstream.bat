@echo off
echo =======================================================
echo  TinyNPU2k200 Bitstream Generator (195 MHz PLL)
echo =======================================================
echo.
echo Launching Vivado to generate the Clocking Wizard IP
echo compile the NPU at 195 MHz, and generate the bitstream...
echo This will take 3-4 minutes.
echo.

"D:\2025.1\Vivado\bin\vivado.bat" -mode batch -source "D:\Final year project\Versions\TinyNPU2k200\scripts\build_and_gen_bitstream.tcl"

echo.
echo =======================================================
echo  Bitstream Generation Process Finished!
echo  Check D:\Final year project\vivado_hw_test_proj\tinynpu_hw_test.bit
echo =======================================================
pause
