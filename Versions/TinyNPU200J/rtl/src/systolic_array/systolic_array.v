`timescale 1ns / 1ps

// Project: TinyNPU200
// Module: systolic_array
// Description:
//   TinyNPU200 - 20x8 weight-stationary systolic array. 160 PEs at 195 MHz = ~24.96 GOPS INT8
//   Uses a flattened interface for inputs and outputs. PEs are connected in a 2D mesh where
//   activations flow horizontally and partial sums flow vertically.
//
// Verilog-2001 Synthesizable RTL.
// NOTE: All generate loop bounds use localparam (not parameter) to satisfy Vivado Synth 8-196.
// NOTE: All genvar arithmetic in part-selects uses intermediate localparams.

module systolic_array #(
    parameter DATA_WIDTH = 8,
    parameter ACCUM_WIDTH = 32,
    parameter ARRAY_ROWS = 20,
    parameter ARRAY_COLS = 8
)(
    input wire clk,
    input wire reset_n,
    input wire array_en,
    input wire psum_clear,
    input wire weight_load,
    
    input wire [DATA_WIDTH*ARRAY_ROWS*ARRAY_COLS-1:0] weight_data_flat,
    input wire [DATA_WIDTH*ARRAY_ROWS-1:0] act_in_flat,
    input wire [ARRAY_ROWS-1:0] act_valid_in_flat,
    
    output wire [ACCUM_WIDTH*ARRAY_COLS-1:0] psum_out_flat,
    output wire [ARRAY_COLS-1:0] psum_valid_out_flat
);

    // Use localparams for generate loop bounds — Vivado requires localparam not parameter
    localparam TOTAL_PES   = ARRAY_ROWS * ARRAY_COLS;
    localparam GEN_ROWS    = ARRAY_ROWS;
    localparam GEN_COLS    = ARRAY_COLS;

    // Internal wires for connecting PEs
    wire signed [DATA_WIDTH-1:0]  weight_w    [0:ARRAY_ROWS-1][0:ARRAY_COLS-1];
    wire signed [DATA_WIDTH-1:0]  act_w       [0:ARRAY_ROWS-1][0:ARRAY_COLS];
    wire                          act_valid_w [0:ARRAY_ROWS-1][0:ARRAY_COLS];
    wire signed [ACCUM_WIDTH-1:0] psum_w      [0:ARRAY_ROWS][0:ARRAY_COLS-1];

    genvar r, c;
    generate
        // Unflatten row inputs — avoid genvar arithmetic in part-selects using localparam
        for (r = 0; r < GEN_ROWS; r = r + 1) begin : gen_row_inputs
            localparam R_ACT_BASE = r * DATA_WIDTH;
            wire [DATA_WIDTH-1:0] act_slice;
            assign act_slice = act_in_flat[R_ACT_BASE +: DATA_WIDTH];
            assign act_w[r][0]       = act_slice;
            assign act_valid_w[r][0] = act_valid_in_flat[r];
            
            for (c = 0; c < GEN_COLS; c = c + 1) begin : gen_weight_unflat
                localparam RC_W_BASE = (r * ARRAY_COLS + c) * DATA_WIDTH;
                wire [DATA_WIDTH-1:0] wgt_slice;
                assign wgt_slice    = weight_data_flat[RC_W_BASE +: DATA_WIDTH];
                assign weight_w[r][c] = wgt_slice;
            end
        end
        
        // Column boundary signals and output flatten
        for (c = 0; c < GEN_COLS; c = c + 1) begin : gen_col_inputs
            localparam C_PSUM_BASE = c * ACCUM_WIDTH;
            wire [ACCUM_WIDTH-1:0] col_psum_out;
            assign psum_w[0][c] = {ACCUM_WIDTH{1'b0}}; // First row psum_in = 0
            
            // Flatten output partial sums — use localparam index for LHS part-select
            assign col_psum_out = psum_w[ARRAY_ROWS][c];
            assign psum_out_flat[C_PSUM_BASE +: ACCUM_WIDTH] = col_psum_out;
            // psum_valid driven by last-row PE act_valid_out for each column
            assign psum_valid_out_flat[c] = act_valid_w[ARRAY_ROWS-1][c+1];
        end
        
        // 2D Processing Element array instantiation
        for (r = 0; r < GEN_ROWS; r = r + 1) begin : row
            for (c = 0; c < GEN_COLS; c = c + 1) begin : col
                processing_element #(
                    .DATA_WIDTH(DATA_WIDTH),
                    .ACCUM_WIDTH(ACCUM_WIDTH)
                ) pe_inst (
                    .clk(clk),
                    .reset_n(reset_n),
                    .pe_en(array_en),
                    .psum_clear(psum_clear),
                    .weight_load(weight_load),
                    
                    .weight_in(weight_w[r][c]),
                    .act_in(act_w[r][c]),
                    .act_valid_in(act_valid_w[r][c]),
                    .psum_in(psum_w[r][c]),
                    
                    .act_out(act_w[r][c+1]),
                    .act_valid_out(act_valid_w[r][c+1]),
                    .psum_out(psum_w[r+1][c])
                );
            end
        end
    endgenerate

endmodule
