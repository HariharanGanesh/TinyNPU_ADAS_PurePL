@echo off
echo =======================================================
echo  TinyNPU Bitstream Generator (Option A)
echo =======================================================
echo.
echo Launching Vivado to compile the NPU and generate the bitstream...
echo This will take 2-3 minutes.
echo.

"D:\2025.1\Vivado\bin\vivado.bat" -mode batch -source "D:\Final year project\Versions\tinynpu_pynq_system\scripts\build_and_gen_bitstream.tcl"

echo.
echo =======================================================
echo  Bitstream Generation Process Finished!
echo  Check D:\Final year project\vivado_hw_test_proj\tinynpu_hw_test.bit
echo =======================================================
pause
