@echo off
title TinyNPU2k200J - HDMI Pipeline Builder
echo ============================================================
echo  TinyNPU2k200J - Full HDMI Video Pipeline
echo  195 MHz NPU + HDMI IN/OUT + OSD Tracker + Target Lock LED
echo ============================================================
echo.
echo  Step 1: Downloading Digilent DVI2RGB / RGB2DVI IPs ... DONE
echo  Step 2: Building Block Design in Vivado...
echo.
echo  This will take 5-10 minutes. Please wait.
echo.

"D:\2025.1\Vivado\bin\vivado.bat" -mode batch -source "D:\Final year project\Versions\TinyNPU2k200J\scripts\create_hdmi_bd.tcl"

echo.
echo ============================================================
echo  Build Finished!
echo  Bitstream: D:\Final year project\vivado_2k200j_proj\tinynpu_2k200j.bit
echo  Flash this onto your PYNQ-Z2 board to run the demo!
echo ============================================================
pause
