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

    // 3-bit activation function select:
    // 3'b000 = ReLU
    // 3'b001 = Identity (bypass)
    // 3'b010 = ReLU6
    // 3'b011 = Leaky ReLU
    // 3'b100 = HardSwish
    // 3'b101-111 = Identity (default)
    input  wire [2:0]               act_sel,

    // Flattened Data Path
    input  wire [DATA_WIDTH*NUM_CHANNELS-1:0] act_in_flat,
    input  wire                               in_valid,

    output wire [DATA_WIDTH*NUM_CHANNELS-1:0] act_out_flat,
    output reg                                out_valid
);

    // Unpack inputs
    wire signed [DATA_WIDTH-1:0] act_in [0:NUM_CHANNELS-1];
    reg  signed [DATA_WIDTH-1:0] act_out[0:NUM_CHANNELS-1];

    localparam GEN_CH = NUM_CHANNELS; // localparam required for generate loop bound
    genvar c_un;
    generate
        for (c_un = 0; c_un < GEN_CH; c_un = c_un + 1) begin : gen_unpack
            localparam UN_BASE = c_un * DATA_WIDTH;
            wire [DATA_WIDTH-1:0] un_slice;
            assign un_slice = act_in_flat[UN_BASE +: DATA_WIDTH];
            assign act_in[c_un] = $signed(un_slice);
        end
    endgenerate

    // Pack outputs
    genvar c_pk;
    generate
        for (c_pk = 0; c_pk < GEN_CH; c_pk = c_pk + 1) begin : gen_pack
            localparam PK_BASE = c_pk * DATA_WIDTH;
            wire [DATA_WIDTH-1:0] pk_slice;
            assign pk_slice = act_out[c_pk];
            assign act_out_flat[PK_BASE +: DATA_WIDTH] = pk_slice;
        end
    endgenerate

    // HardSwish LUTs
    wire signed [DATA_WIDTH-1:0] hswish_out [0:NUM_CHANNELS-1];
    genvar ch;
    generate
        for (ch=0; ch < GEN_CH; ch=ch+1) begin : gen_hswish
            hardswish_lut u_hswish (.din(act_in[ch]), .dout(hswish_out[ch]));
        end
    endgenerate

    // Constants
    localparam [7:0] RELU6_MAX    = 8'd6;
    localparam [2:0] SEL_RELU     = 3'b000;
    localparam [2:0] SEL_IDENTITY = 3'b001;
    localparam [2:0] SEL_RELU6    = 3'b010;
    localparam [2:0] SEL_LEAKY    = 3'b011;
    localparam [2:0] SEL_HSWISH   = 3'b100;

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
                    SEL_LEAKY: begin
                        if (act_in[c] >= 0) begin
                            act_out[c] <= act_in[c];
                        end else begin
                            act_out[c] <= $signed(act_in[c]) >>> 3;
                        end
                    end
                    SEL_HSWISH: begin
                        act_out[c] <= hswish_out[c];
                    end
                    default: begin
                        act_out[c] <= act_in[c];
                    end
                endcase
            end
        end
    end

endmodule
