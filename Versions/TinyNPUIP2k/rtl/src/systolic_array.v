// =============================================================================
// Module: systolic_array.v
// Project: TinyNPU
// Description:
//   Parameterized Weight-Stationary Systolic Array.
//   Verilog-2001 Synthesizable RTL with flattened ports.
// =============================================================================

`timescale 1ns / 1ps

module systolic_array #(
    parameter ARRAY_ROWS  = 8,   // Number of PE rows
    parameter ARRAY_COLS  = 8,   // Number of PE columns
    parameter DATA_WIDTH  = 8,   // Activation/weight bit-width
    parameter ACCUM_WIDTH = 32   // Accumulator bit-width
) (
    input  wire clk,
    input  wire rst_n,

    // Flattened Weight Loading Interface: dimensions [ARRAY_ROWS][ARRAY_COLS]*DATA_WIDTH
    input  wire [DATA_WIDTH*ARRAY_ROWS*ARRAY_COLS-1:0] weight_data_flat,
    input  wire                                         weight_load,

    // Flattened Activation Input: dimensions [ARRAY_ROWS]*DATA_WIDTH
    input  wire [DATA_WIDTH*ARRAY_ROWS-1:0]             act_in_flat,
    input  wire [ARRAY_ROWS-1:0]                        act_valid_in_flat,

    // Flattened Partial Sum Output: dimensions [ARRAY_COLS]*ACCUM_WIDTH
    output wire [ACCUM_WIDTH*ARRAY_COLS-1:0]            psum_out_flat,
    output wire [ARRAY_COLS-1:0]                        psum_valid_out_flat,

    // Control
    input  wire                                         array_en,
    input  wire                                         psum_clear
);

    // Unpacked internal wires for Verilog internal 2D array representation
    wire signed [DATA_WIDTH-1:0]  weight_data   [0:ARRAY_ROWS-1][0:ARRAY_COLS-1];
    wire signed [DATA_WIDTH-1:0]  act_in        [0:ARRAY_ROWS-1];
    wire                          act_valid_in  [0:ARRAY_ROWS-1];
    wire signed [ACCUM_WIDTH-1:0] psum_out      [0:ARRAY_COLS-1];
    wire                          psum_valid_out[0:ARRAY_COLS-1];

    // Unpack flattened inputs
    genvar r_un, c_un;
    generate
        for (r_un = 0; r_un < ARRAY_ROWS; r_un = r_un + 1) begin : gen_unpack_act
            assign act_in[r_un]       = act_in_flat[r_un*DATA_WIDTH +: DATA_WIDTH];
            assign act_valid_in[r_un] = act_valid_in_flat[r_un];
            for (c_un = 0; c_un < ARRAY_COLS; c_un = c_un + 1) begin : gen_unpack_w
                assign weight_data[r_un][c_un] = weight_data_flat[(r_un*ARRAY_COLS + c_un)*DATA_WIDTH +: DATA_WIDTH];
            end
        end
    endgenerate

    // Pack flattened outputs
    genvar c_pk;
    generate
        for (c_pk = 0; c_pk < ARRAY_COLS; c_pk = c_pk + 1) begin : gen_pack_out
            assign psum_out_flat[c_pk*ACCUM_WIDTH +: ACCUM_WIDTH] = psum_out[c_pk];
            assign psum_valid_out_flat[c_pk]                       = psum_valid_out[c_pk];
        end
    endgenerate

    // Connection grid wires
    // act_wire has columns 0 to ARRAY_COLS (ARRAY_COLS + 1 columns total)
    // psum_wire has rows 0 to ARRAY_ROWS (ARRAY_ROWS + 1 rows total)
    wire signed [DATA_WIDTH-1:0]   act_wire      [0:ARRAY_ROWS-1][0:ARRAY_COLS];
    wire                          act_valid_wire[0:ARRAY_ROWS-1][0:ARRAY_COLS];
    wire signed [ACCUM_WIDTH-1:0]  psum_wire     [0:ARRAY_ROWS][0:ARRAY_COLS-1];

    // Connect leftmost activation inputs with skewing (delay row r by r cycles)
    genvar r_in;
    generate
        for (r_in = 0; r_in < ARRAY_ROWS; r_in = r_in + 1) begin : gen_left_inputs
            if (r_in == 0) begin : gen_no_delay
                assign act_wire[0][0]       = act_in[0];
                assign act_valid_wire[0][0] = act_valid_in[0];
            end else begin : gen_delay
                reg signed [DATA_WIDTH-1:0] act_delay [0:r_in-1];
                reg                         val_delay [0:r_in-1];
                integer i;
                always @(posedge clk or negedge rst_n) begin
                    if (!rst_n) begin
                        for (i = 0; i < r_in; i = i + 1) begin
                            act_delay[i] <= 0;
                            val_delay[i] <= 1'b0;
                        end
                    end else if (array_en) begin
                        act_delay[0] <= act_in[r_in];
                        val_delay[0] <= act_valid_in[r_in];
                        for (i = 1; i < r_in; i = i + 1) begin
                            act_delay[i] <= act_delay[i-1];
                            val_delay[i] <= val_delay[i-1];
                        end
                    end
                end
                assign act_wire[r_in][0]       = act_delay[r_in-1];
                assign act_valid_wire[r_in][0] = val_delay[r_in-1];
            end
        end
    endgenerate

    // Connect top partial sum boundary inputs (all zeroes for weight-stationary)
    genvar c_in;
    generate
        for (c_in = 0; c_in < ARRAY_COLS; c_in = c_in + 1) begin : gen_top_inputs
            assign psum_wire[0][c_in] = {ACCUM_WIDTH{1'b0}};
        end
    endgenerate

    // Instantiate PE Array
    genvar r, c;
    generate
        for (r = 0; r < ARRAY_ROWS; r = r + 1) begin : gen_pe_rows
            for (c = 0; c < ARRAY_COLS; c = c + 1) begin : gen_pe_cols
                processing_element #(
                    .DATA_WIDTH  (DATA_WIDTH),
                    .ACCUM_WIDTH (ACCUM_WIDTH)
                ) u_pe (
                    .clk          (clk),
                    .rst_n        (rst_n),

                    // Weight loading
                    .weight_load  (weight_load),
                    .weight_in    (weight_data[r][c]),

                    // Activation horizontal flow
                    .act_in       (act_wire[r][c]),
                    .act_out      (act_wire[r][c+1]),
                    .act_valid_in (act_valid_wire[r][c]),
                    .act_valid_out(act_valid_wire[r][c+1]),

                    // Partial sum vertical flow
                    .psum_in      (psum_wire[r][c]),
                    .psum_out     (psum_wire[r+1][c]),

                    .pe_en        (array_en),
                    .psum_clear   (psum_clear)
                );
            end
        end
    endgenerate

    // =========================================================================
    // psum_valid_out: correct pipeline-depth valid signal
    //
    // With input skewing (delay row r by r cycles) and output deskewing
    // (delay column c by ARRAY_COLS - 1 - c cycles), the total latency for
    // all columns is exactly ARRAY_ROWS + ARRAY_COLS - 1 cycles.
    //
    // We generate a shared (ARRAY_ROWS + ARRAY_COLS - 1)-stage shift register on
    // the input valid (row 0, col 0) and tap it at the final stage for the output valid.
    // =========================================================================
    reg [ARRAY_ROWS+ARRAY_COLS-2:0] psum_valid_shift;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            psum_valid_shift <= 0;
        end else if (array_en) begin
            psum_valid_shift <= {psum_valid_shift[ARRAY_ROWS+ARRAY_COLS-3:0], act_valid_wire[0][0]};
        end
    end

    // Output deskewing (delay column c by ARRAY_COLS - 1 - c cycles)
    // This aligns the outputs of all columns to the same cycle (cycle 15).
    genvar c_out;
    generate
        for (c_out = 0; c_out < ARRAY_COLS; c_out = c_out + 1) begin : gen_bottom_outputs
            localparam DELAY_DEPTH = ARRAY_COLS - 1 - c_out;
            if (DELAY_DEPTH == 0) begin : gen_no_delay
                assign psum_out[c_out] = psum_wire[ARRAY_ROWS][c_out];
            end else begin : gen_delay
                reg signed [ACCUM_WIDTH-1:0] psum_delay [0:DELAY_DEPTH-1];
                integer i;
                always @(posedge clk or negedge rst_n) begin
                    if (!rst_n) begin
                        for (i = 0; i < DELAY_DEPTH; i = i + 1) begin
                            psum_delay[i] <= 0;
                        end
                    end else if (array_en) begin
                        psum_delay[0] <= psum_wire[ARRAY_ROWS][c_out];
                        for (i = 1; i < DELAY_DEPTH; i = i + 1) begin
                            psum_delay[i] <= psum_delay[i-1];
                        end
                    end
                end
                assign psum_out[c_out] = psum_delay[DELAY_DEPTH-1];
            end
            
            // Connect output valid
            assign psum_valid_out[c_out] = psum_valid_shift[ARRAY_ROWS+ARRAY_COLS-2];
        end
    endgenerate

endmodule
