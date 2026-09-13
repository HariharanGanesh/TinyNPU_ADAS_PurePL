## PYNQ-Z2 Board Constraints for RISCV_ADAS_NPU300

# 125 MHz System Clock
set_property -dict { PACKAGE_PIN H16   IOSTANDARD LVCMOS33 } [get_ports { sysclk }];
create_clock -add -name sys_clk_pin -period 8.000 -waveform {0 4.000} [get_ports { sysclk }];

# External Reset (BTN0)
set_property -dict { PACKAGE_PIN D19   IOSTANDARD LVCMOS33 } [get_ports { ext_reset }];

# Dashboard Arm Switch (SW0)
set_property -dict { PACKAGE_PIN M20   IOSTANDARD LVCMOS33 } [get_ports { sw_brake_arm }];

# ADAS Safety Outputs
# LED0: Pedestrian Warning
set_property -dict { PACKAGE_PIN R14   IOSTANDARD LVCMOS33 } [get_ports { out_warning_ped }];
# LED1: Lane Departure Warning
set_property -dict { PACKAGE_PIN P14   IOSTANDARD LVCMOS33 } [get_ports { out_warning_lane }];
# LED2: Traffic Sign Warning
set_property -dict { PACKAGE_PIN N16   IOSTANDARD LVCMOS33 } [get_ports { out_warning_sign }];
# LED3: Brake Authorized (Actuation)
set_property -dict { PACKAGE_PIN M14   IOSTANDARD LVCMOS33 } [get_ports { out_brake_authorized }];

# RGB LED 4 (Red): Critical System Fault (Watchdog)
set_property -dict { PACKAGE_PIN N15   IOSTANDARD LVCMOS33 } [get_ports { out_system_fault }];

# Bypass BUFG-to-BUFG cascade routing error (from Clocking Wizard to TinyNPU clock gating cells)
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets npu_system_i/clk_wiz_0/inst/clk_out1]
