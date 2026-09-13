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

# 4. Open the RISCV ADAS project and upgrade the IP
open_project "D:/Final year project/RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.xpr"
update_ip_catalog -rebuild -scan_changes

# Get the IP instance in the BD (we saw it was named npu_system_tinynpu_0_0)
open_bd_design [get_files *.bd]
upgrade_ip -vlnv ai.local:user:tinynpu_top:1.0 [get_ips *tinynpu*]

# 5. Re-run target generation
generate_target all [get_files *.bd]
export_ip_user_files -of_objects [get_ips *tinynpu*] -no_script -sync -force -quiet

# 6. Force an Absolute Clean Build
puts "--- RESETTING SYNTHESIS (NO INCREMENTAL) ---"
reset_run synth_1

# Disable incremental synthesis if it was set
catch {set_property AUTO_INCREMENTAL_CHECKPOINT 0 [get_runs synth_1]}

launch_runs synth_1 -jobs 6
wait_on_run synth_1
puts "--- SYNTHESIS DONE ---"
exit
