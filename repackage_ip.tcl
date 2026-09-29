open_project RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.xpr
update_ip_catalog -rebuild
ipx::edit_ip_in_project -upgrade true -name tinynpu_0_project -directory IP/TinyNPU200 IP/TinyNPU200/component.xml
ipx::current_core IP/TinyNPU200/component.xml
ipx::add_file src/adas_stream_aggregator.v [ipx::get_file_groups xilinx_anylanguagesynthesis -of_objects [ipx::current_core]]
ipx::add_file src/sigmoid_lut.v [ipx::get_file_groups xilinx_anylanguagesynthesis -of_objects [ipx::current_core]]
ipx::add_file src/piecewise_sigmoid.v [ipx::get_file_groups xilinx_anylanguagesynthesis -of_objects [ipx::current_core]]
ipx::update_checksums [ipx::current_core]
ipx::save_core [ipx::current_core]
close_project -delete