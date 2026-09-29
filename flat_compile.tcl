# flat_compile.tcl
set proj_path "D:/Final year project/RISCV_ADAS_PURE_PL/"
open_project "${proj_path}RISCV_ADAS_PURE_PL.xpr"

# Update IP Catalog and upgrade block design IPs to pull fresh code from repo
update_ip_catalog -rebuild
upgrade_ip [get_ips *]

open_bd_design [get_files *.bd]

# Check if the connection exists, if not force it
puts "Forcing AXI connection between interconnect and TinyNPU..."
catch {delete_bd_objs [get_bd_nets -of_objects [get_bd_intf_pins axi_mem_intercon/M00_AXI]]}
catch {connect_bd_intf_net [get_bd_intf_pins axi_mem_intercon/M00_AXI] [get_bd_intf_pins tinynpu_0/s_axi]}

validate_bd_design
save_bd_design

# Force block design into Global Synthesis (no OOC)
set bd_file [get_files *.bd]
set_property synth_checkpoint_mode None $bd_file
generate_target -force all $bd_file

# Run Synthesis in the main process (No child processes spawned!)
synth_design -top npu_system_wrapper -part xc7z020clg400-1

# Run Implementation in the main process
opt_design
place_design
route_design

# Write Bitstream
write_bitstream -force "${proj_path}npu_system_wrapper.bit"

# Timing Report
report_timing_summary -file "${proj_path}reports/RISCV_ADAS_FINAL_ROUTED_Timing.rpt"

exit
