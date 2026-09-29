# 1. Create a dummy project in memory
create_project -in_memory -part xc7z020clg400-1

# 2. Add all NPU300PM source files
read_verilog [glob "D:/Final year project/IP/NPU300PM/src/*.v"]

# 3. OVERWRITE the component.xml using package_project
ipx::package_project -root_dir "D:/Final year project/IP/NPU300PM" -vendor ai.local -library user -taxonomy /UserIP -force

set core [ipx::current_core]
set_property name tinynpu_top $core
set_property display_name "TinyNPU PMAX" $core

# Ensure AXI interfaces are correctly inferred by Vivado
ipx::infer_bus_interface aclk xilinx.com:signal:clock_rtl:1.0 $core
ipx::infer_bus_interface aresetn xilinx.com:signal:reset_rtl:1.0 $core
ipx::infer_bus_interfaces xilinx.com:interface:aximm_rtl:1.0 $core
ipx::infer_bus_interfaces xilinx.com:interface:axis_rtl:1.0 $core

ipx::update_checksums $core
ipx::check_integrity $core
ipx::save_core $core
ipx::unload_core $core

# 4. Open the main project and upgrade the IP
open_project "D:/Final year project/npu200jpmax/npu200jpmax.xpr"
update_ip_catalog -rebuild -scan_changes
upgrade_ip -vlnv ai.local:user:tinynpu_top:1.0 [get_ips npu_system_tinynpu_0_0]

# 5. Fix the DMA loopback connection just in case
open_bd_design [get_files *.bd]
catch {connect_bd_intf_net [get_bd_intf_pins axis_broadcaster_0/M01_AXIS] [get_bd_intf_pins axi_dma_0/S_AXIS_S2MM]}

# 6. Re-run target generation and synthesis
generate_target all [get_files *.bd]
export_ip_user_files -of_objects [get_ips npu_system_tinynpu_0_0] -no_script -sync -force -quiet

reset_run synth_1
launch_runs synth_1 -jobs 12
wait_on_run synth_1
puts "--- SYNTHESIS DONE ---"
