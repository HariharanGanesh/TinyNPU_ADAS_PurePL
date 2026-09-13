// =============================================================================
// Module: activation_unit.v
// Project: TinyNPU
// Description:
//   Post-processing activation function unit.
//   Verilog-2001 Synthesizable RTL with flattened ports.
// =============================================================================

`timescale 1ns / 1ps

module activation_unit #(
    parameter NUM_CHANNELS = 8,
    parameter DATA_WIDTH   = 8
) (
    input  wire                     clk,
    input  wire                     rst_n,

    // 2-bit activation function select:
    // 2'b00 = ReLU
    // 2'b01 = Identity (bypass)
    // 2'b10 = ReLU6
    // 2'b11 = Reserved
    input  wire [1:0]               act_sel,

    // Flattened Data Path
    input  wire [DATA_WIDTH*NUM_CHANNELS-1:0] act_in_flat,
    input  wire                               in_valid,

    output wire [DATA_WIDTH*NUM_CHANNELS-1:0] act_out_flat,
    output reg                                out_valid
);

    // Unpack inputs
    wire signed [DATA_WIDTH-1:0] act_in [0:NUM_CHANNELS-1];
    reg  signed [DATA_WIDTH-1:0] act_out[0:NUM_CHANNELS-1];

    genvar c_un;
    generate
        for (c_un = 0; c_un < NUM_CHANNELS; c_un = c_un + 1) begin : gen_unpack
            assign act_in[c_un] = $signed(act_in_flat[c_un*DATA_WIDTH +: DATA_WIDTH]);
        end
    endgenerate

    // Pack outputs
    genvar c_pk;
    generate
        for (c_pk = 0; c_pk < NUM_CHANNELS; c_pk = c_pk + 1) begin : gen_pack
            assign act_out_flat[c_pk*DATA_WIDTH +: DATA_WIDTH] = act_out[c_pk];
        end
    endgenerate

    // Constants
    localparam [7:0] RELU6_MAX = 8'd6;
    localparam [1:0] SEL_RELU     = 2'b00;
    localparam [1:0] SEL_IDENTITY = 2'b01;
    localparam [1:0] SEL_RELU6    = 2'b10;

    integer c;
    always @(posedge clk) begin
        if (!rst_n) begin
            out_valid <= 1'b0;
            for (c = 0; c < NUM_CHANNELS; c = c + 1) begin
                act_out[c] <= 0;
            end
        end else begin
            out_valid <= in_valid;
            for (c = 0; c < NUM_CHANNELS; c = c + 1) begin
                case (act_sel)
                    SEL_RELU: begin
                        act_out[c] <= (act_in[c] < 0) ? 0 : act_in[c];
                    end
                    SEL_IDENTITY: begin
                        act_out[c] <= act_in[c];
                    end
                    SEL_RELU6: begin
                        if (act_in[c] < 0) begin
                            act_out[c] <= 0;
                        end else if (act_in[c] > $signed(RELU6_MAX)) begin
                            act_out[c] <= $signed(RELU6_MAX);
                        end else begin
                            act_out[c] <= act_in[c];
                        end
                    end
                    default: begin
                        act_out[c] <= act_in[c];
                    end
                endcase
            end
        end
    end

endmodule
