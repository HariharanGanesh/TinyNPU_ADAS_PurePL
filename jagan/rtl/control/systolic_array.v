// =============================================================================
// Module: systolic_array.v
// Project: NPU300PM — TinyNPU200 PMAX Edition
// Description:
//   NPU300PM - 26x8 weight-stationary systolic array.
//   208 PEs, each mapped to one DSP48E1 @ 125 MHz = 52 GOPS INT8 (0.052 TOPS)
//   ~30% more throughput than TinyNPU200J (160 PEs, LUT-mapped).
//
//   DSP48E1 Budget:
//     208 PEs × 1 DSP each  = 208 DSPs
//     Requantizer + misc     =  ~4 DSPs
//     Total                  = ~212 DSPs (safely under 215 limit)
//
// Verilog-2001 Synthesizable RTL.
// NOTE: All generate loop bounds use localparam (not parameter) Vivado Synth 8-196.
// NOTE: All genvar arithmetic in part-selects uses intermediate localparams.
// =============================================================================

`timescale 1ns / 1ps

module systolic_array #(
    parameter DATA_WIDTH  = 8,
    parameter ACCUM_WIDTH = 32,
    parameter ARRAY_ROWS  = 26,   // NPU300PM: 26 rows (was 20 in TinyNPU200)
    parameter ARRAY_COLS  = 8
)(
    input  wire clk,
    input  wire reset_n,
    input  wire array_en,
    input  wire psum_clear,
    input  wire weight_load,

    input  wire [DATA_WIDTH*ARRAY_ROWS*ARRAY_COLS-1:0] weight_data_flat,
    input  wire [DATA_WIDTH*ARRAY_ROWS-1:0]            act_in_flat,
    input  wire [ARRAY_ROWS-1:0]                       act_valid_in_flat,

    output wire [ACCUM_WIDTH*ARRAY_COLS-1:0]           psum_out_flat,
    output wire [ARRAY_COLS-1:0]                       psum_valid_out_flat
);

    localparam TOTAL_PES = ARRAY_ROWS * ARRAY_COLS;  // 208 for NPU300PM
    localparam GEN_ROWS  = ARRAY_ROWS;
    localparam GEN_COLS  = ARRAY_COLS;

    // Internal wires for connecting PEs
    wire signed [DATA_WIDTH-1:0]  weight_w    [0:ARRAY_ROWS-1][0:ARRAY_COLS-1];
    wire signed [DATA_WIDTH-1:0]  act_w       [0:ARRAY_ROWS-1][0:ARRAY_COLS];
    wire                          act_valid_w [0:ARRAY_ROWS-1][0:ARRAY_COLS];
    wire signed [ACCUM_WIDTH-1:0] psum_w      [0:ARRAY_ROWS][0:ARRAY_COLS-1];

    genvar r, c;
    generate
        // Unflatten row inputs
        for (r = 0; r < GEN_ROWS; r = r + 1) begin : gen_row_inputs
            localparam R_ACT_BASE = r * DATA_WIDTH;
            wire [DATA_WIDTH-1:0] act_slice;
            assign act_slice         = act_in_flat[R_ACT_BASE +: DATA_WIDTH];
            assign act_w[r][0]       = act_slice;
            assign act_valid_w[r][0] = act_valid_in_flat[r];

            for (c = 0; c < GEN_COLS; c = c + 1) begin : gen_weight_unflat
                localparam RC_W_BASE = (r * ARRAY_COLS + c) * DATA_WIDTH;
                wire [DATA_WIDTH-1:0] wgt_slice;
                assign wgt_slice      = weight_data_flat[RC_W_BASE +: DATA_WIDTH];
                assign weight_w[r][c] = wgt_slice;
            end
        end

        // Column boundary signals and output flatten
        for (c = 0; c < GEN_COLS; c = c + 1) begin : gen_col_inputs
            localparam C_PSUM_BASE = c * ACCUM_WIDTH;
            wire [ACCUM_WIDTH-1:0] col_psum_out;
            assign psum_w[0][c] = {ACCUM_WIDTH{1'b0}};
            assign col_psum_out = psum_w[ARRAY_ROWS][c];
            assign psum_out_flat[C_PSUM_BASE +: ACCUM_WIDTH] = col_psum_out;
            assign psum_valid_out_flat[c] = act_valid_w[ARRAY_ROWS-1][c+1];
        end

        // 2D PE array instantiation
        for (r = 0; r < GEN_ROWS; r = r + 1) begin : row
            for (c = 0; c < GEN_COLS; c = c + 1) begin : col
                processing_element #(
                    .DATA_WIDTH(DATA_WIDTH),
                    .ACCUM_WIDTH(ACCUM_WIDTH)
                ) pe_inst (
                    .clk          (clk),
                    .reset_n      (reset_n),
                    .pe_en        (array_en),
                    .psum_clear   (psum_clear),
                    .weight_load  (weight_load),
                    .weight_in    (weight_w[r][c]),
                    .act_in       (act_w[r][c]),
                    .act_valid_in (act_valid_w[r][c]),
                    .psum_in      (psum_w[r][c]),
                    .act_out      (act_w[r][c+1]),
                    .act_valid_out(act_valid_w[r][c+1]),
                    .psum_out     (psum_w[r+1][c])
                );
            end
        end
    endgenerate

endmodule
