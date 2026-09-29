# 1. Update IP
set core [ipx::open_core IP/TinyNPU200/component.xml]
ipx::update_checksums $core
ipx::save_core $core

# 2. Open Project and Upgrade
catch { open_project RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.xpr }
update_ip_catalog -rebuild
catch { upgrade_ip [get_ips *dvi2rgb*] }
catch { upgrade_ip [get_ips *tinynpu*] }
generate_target all [get_files "RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.srcs/sources_1/bd/npu_system/npu_system.bd"] -force

# 3. Direct Synthesis and Implementation
synth_design -top npu_system_wrapper -part xc7z020clg400-1 -directive Default
write_checkpoint -force post_synth.dcp

opt_design -directive Explore
place_design -directive Explore
phys_opt_design -directive Explore
route_design -directive Explore
write_checkpoint -force post_route.dcp

# 4. Post-Route Hold Fix
phys_opt_design -directive Explore
route_design -preserve
write_checkpoint -force post_route_hold_fixed.dcp

write_bitstream -force npu_system_wrapper.bit
exit