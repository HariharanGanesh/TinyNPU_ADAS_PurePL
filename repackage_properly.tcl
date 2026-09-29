set core [ipx::open_core IP/TinyNPU200/component.xml]

set files_to_add {
    "src/adas_stream_aggregator.v"
    "src/npu_detection_head.v"
    "src/streaming_topk.v"
    "src/sparse_candidate_packer.v"
    "src/bbox_decoder_dfl.v"
    "src/piecewise_sigmoid.v"
    "src/sigmoid_lut.v"
}

set synth_fg [ipx::get_file_groups xilinx_anylanguagesynthesis -of_objects $core]
set sim_fg [ipx::get_file_groups xilinx_anylanguagebehavioralsimulation -of_objects $core]

foreach f $files_to_add {
    # Check if already present, if not add
    catch { ipx::add_file $f $synth_fg }
    catch { ipx::add_file $f $sim_fg }
}

ipx::update_checksums $core
ipx::save_core $core

open_project RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.xpr
update_ip_catalog -rebuild -repo_path "IP/TinyNPU200"
upgrade_ip [get_ips *tinynpu*]
reset_run npu_system_tinynpu_0_0_synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
exit