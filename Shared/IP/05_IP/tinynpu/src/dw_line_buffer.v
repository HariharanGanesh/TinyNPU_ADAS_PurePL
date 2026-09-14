// =============================================================================
// Module: dw_line_buffer.v
// Project: TinyNPU
// Description:
//   Dedicated 3x3 Depthwise Convolution spatial engine using line buffers.
//   Fixed: removed illegal "automatic" keyword for Verilog-2001 compliance.
//   The 3x3 MAC tree is purely registered combinational — no automatic variables.
//   Verilog-2001 Synthesizable RTL.
// =============================================================================

`timescale 1ns / 1ps

module dw_line_buffer #(
    parameter DATA_WIDTH   = 8,
    parameter NUM_CHANNELS = 8,
    parameter ACCUM_WIDTH  = 32,
    parameter MAX_WIDTH    = 128
) (
    input  wire                               clk,
    input  wire                               rst_n,

    // Image width configuration (from FSM)
    input  wire [7:0]                         image_width,

    // Streaming input: NUM_CHANNELS pixels, one per channel per cycle
    input  wire [DATA_WIDTH*NUM_CHANNELS-1:0] act_in_flat,
    input  wire                               act_valid_in,

    // 3x3 kernel weights for each channel: NUM_CHANNELS * 9 coefficients
    input  wire [DATA_WIDTH*9*NUM_CHANNELS-1:0] weights_flat,

    // Partial sum output: NUM_CHANNELS parallel 32-bit accumulators
    output reg  [ACCUM_WIDTH*NUM_CHANNELS-1:0] psum_out_flat,
    output reg                                 psum_valid_out
);

    // Unpack inputs
    wire signed [DATA_WIDTH-1:0] act_in  [0:NUM_CHANNELS-1];
    wire signed [DATA_WIDTH-1:0] w       [0:NUM_CHANNELS-1][0:8];

    genvar c, k;
    generate
        for (c = 0; c < NUM_CHANNELS; c = c + 1) begin : gen_unpack_ch
            assign act_in[c] = $signed(act_in_flat[c*DATA_WIDTH +: DATA_WIDTH]);
            for (k = 0; k < 9; k = k + 1) begin : gen_unpack_k
                assign w[c][k] = $signed(weights_flat[(c*9 + k)*DATA_WIDTH +: DATA_WIDTH]);
            end
        end
    endgenerate

    // Sliding window registers: win[channel][row 0-2][col 0-2]
    reg signed [DATA_WIDTH-1:0] win [0:NUM_CHANNELS-1][0:2][0:2];

    // Line buffers: two rows deep, MAX_WIDTH wide, NUM_CHANNELS parallel
    // row_d1 = delayed by 1 row, row_d2 = delayed by 2 rows
    reg signed [DATA_WIDTH-1:0] row_d1 [0:NUM_CHANNELS-1][0:MAX_WIDTH-1];
    reg signed [DATA_WIDTH-1:0] row_d2 [0:NUM_CHANNELS-1][0:MAX_WIDTH-1];

    // Column pointer
    reg [7:0] col_ptr;

    // Pipeline valid registers
    reg valid_d1;
    reg valid_d2;
    
    // Multiplier pipeline registers (8-bit x 8-bit = 16-bit signed product)
    reg signed [15:0] mult_reg [0:NUM_CHANNELS-1][0:8];

    // ==========================================================================
    // Stage 1: Column pointer and line buffer update (registered)
    // ==========================================================================
    integer ch, p, q;
    always @(posedge clk) begin
        if (!rst_n) begin
            col_ptr       <= 0;
            valid_d1      <= 1'b0;
            valid_d2      <= 1'b0;
            psum_valid_out <= 1'b0;

            for (ch = 0; ch < NUM_CHANNELS; ch = ch + 1) begin
                for (p = 0; p < 3; p = p + 1) begin
                    for (q = 0; q < 3; q = q + 1) begin
                        win[ch][p][q] <= 0;
                    end
                end
            end
        end else begin
            valid_d1      <= act_valid_in;
            valid_d2      <= valid_d1;
            psum_valid_out <= valid_d2;

            if (act_valid_in) begin
                // Advance column pointer
                if (col_ptr == image_width - 1) begin
                    col_ptr <= 0;
                end else begin
                    col_ptr <= col_ptr + 1'b1;
                end

                for (ch = 0; ch < NUM_CHANNELS; ch = ch + 1) begin
                    // Write to line buffers (shift register: d1 <- current, d2 <- d1)
                    row_d2[ch][col_ptr] <= row_d1[ch][col_ptr];
                    row_d1[ch][col_ptr] <= act_in[ch];

                    // Shift the 3x3 sliding window horizontally
                    win[ch][0][0] <= win[ch][0][1];
                    win[ch][0][1] <= win[ch][0][2];
                    win[ch][0][2] <= row_d2[ch][col_ptr];

                    win[ch][1][0] <= win[ch][1][1];
                    win[ch][1][1] <= win[ch][1][2];
                    win[ch][1][2] <= row_d1[ch][col_ptr];

                    win[ch][2][0] <= win[ch][2][1];
                    win[ch][2][1] <= win[ch][2][2];
                    win[ch][2][2] <= act_in[ch];
                end
            end

            // Stage 2: Registered Multipliers
            // We register the 9 products to prevent DSP cascading, allowing
            // Vivado to use the DSP48 internal M-register.
            if (valid_d1) begin
                for (ch = 0; ch < NUM_CHANNELS; ch = ch + 1) begin
                    mult_reg[ch][0] <= $signed(win[ch][0][0]) * $signed(w[ch][0]);
                    mult_reg[ch][1] <= $signed(win[ch][0][1]) * $signed(w[ch][1]);
                    mult_reg[ch][2] <= $signed(win[ch][0][2]) * $signed(w[ch][2]);
                    mult_reg[ch][3] <= $signed(win[ch][1][0]) * $signed(w[ch][3]);
                    mult_reg[ch][4] <= $signed(win[ch][1][1]) * $signed(w[ch][4]);
                    mult_reg[ch][5] <= $signed(win[ch][1][2]) * $signed(w[ch][5]);
                    mult_reg[ch][6] <= $signed(win[ch][2][0]) * $signed(w[ch][6]);
                    mult_reg[ch][7] <= $signed(win[ch][2][1]) * $signed(w[ch][7]);
                    mult_reg[ch][8] <= $signed(win[ch][2][2]) * $signed(w[ch][8]);
                end
            end
            
            // Stage 3: Adder Tree
            // Sum the 9 registered products into the final accumulator.
            if (valid_d2) begin
                for (ch = 0; ch < NUM_CHANNELS; ch = ch + 1) begin
                    psum_out_flat[ch*ACCUM_WIDTH +: ACCUM_WIDTH] <=
                        mult_reg[ch][0] + mult_reg[ch][1] + mult_reg[ch][2] +
                        mult_reg[ch][3] + mult_reg[ch][4] + mult_reg[ch][5] +
                        mult_reg[ch][6] + mult_reg[ch][7] + mult_reg[ch][8];
                end
            end
        end
    end

endmodule
