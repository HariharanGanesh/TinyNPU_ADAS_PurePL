set fd [open "IP/TinyNPU200/src/piecewise_sigmoid.v" w]
puts $fd {`timescale 1ns / 1ps
module piecewise_sigmoid (
    input  wire [7:0]  x_in,
    output wire [7:0]  sigmoid_out
);
    wire [8:0] x_ext = {1'b0, x_in};
    reg  [7:0] out_r;

    always @(*) begin
        if (x_in <= 8'd64) begin
            out_r = 8'h00;
        end else if (x_in <= 8'd96) begin
            out_r = ((x_in - 8'd64) * 8'd15) >> 4;
        end else if (x_in <= 8'd128) begin
            out_r = 8'd30 + ((x_in - 8'd96) * 8'd3);
        end else if (x_in <= 8'd160) begin
            out_r = 8'd128 + ((x_in - 8'd128) * 8'd3);
        end else if (x_in <= 8'd192) begin
            out_r = 8'd225 + (((x_in - 8'd160) * 8'd15) >> 4);
        end else begin
            out_r = 8'hFF;
        end
    end
    assign sigmoid_out = out_r;
endmodule
}
close $fd

set core [ipx::open_core IP/TinyNPU200/component.xml]
set synth_fg [ipx::get_file_groups xilinx_anylanguagesynthesis -of_objects $core]
set sim_fg [ipx::get_file_groups xilinx_anylanguagebehavioralsimulation -of_objects $core]
catch { ipx::add_file src/piecewise_sigmoid.v $synth_fg }
catch { ipx::add_file src/piecewise_sigmoid.v $sim_fg }
ipx::update_checksums $core
ipx::save_core $core

open_project RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.xpr
update_ip_catalog -rebuild -repo_path "IP/TinyNPU200"
upgrade_ip [get_ips *tinynpu*]
generate_target all [get_files "RISCV_ADAS_PURE_PL/RISCV_ADAS_PURE_PL.srcs/sources_1/bd/npu_system/npu_system.bd"] -force

launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
exit