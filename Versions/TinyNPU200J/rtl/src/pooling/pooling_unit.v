// =============================================================================
// Module: pooling_unit.v
// Project: TinyNPU
// Description:
//   2x2 Max Pooling, Avg Pooling and bypass unit, streaming output-channel-parallel data.
//   Verilog-2001 Synthesizable RTL.
// =============================================================================

`timescale 1ns / 1ps

module pooling_unit #(
    parameter DATA_WIDTH   = 8,
    parameter NUM_CHANNELS = 8,
    parameter MAX_WIDTH    = 128
) (
    input  wire                               clk,
    input  wire                               rst_n,

    // Configuration
    input  wire [7:0]                         image_width,
    input  wire                               pool_enable,
    input  wire [1:0]                         pool_mode, // 00: bypass, 01: maxpool, 10: avgpool

    // Inputs (from Activation Unit, NUM_CHANNELS parallel)
    input  wire [DATA_WIDTH*NUM_CHANNELS-1:0] act_in_flat,
    input  wire                               act_valid_in,

    // Outputs
    output reg  [DATA_WIDTH*NUM_CHANNELS-1:0] act_out_flat,
    output reg                                act_valid_out
);

    // Unpacked input and output registers
    wire signed [DATA_WIDTH-1:0] act_in [0:NUM_CHANNELS-1];

    genvar c;
    generate
        for (c = 0; c < NUM_CHANNELS; c = c + 1) begin : gen_unpack
            assign act_in[c] = $signed(act_in_flat[c*DATA_WIDTH +: DATA_WIDTH]);
        end
    endgenerate

    // Row line buffer for 2x2 max pool
    // Stores the max of (current pixel, its horizontal neighbor) from the previous row
    // Also used for AvgPool to store the horizontal sum from the previous row
    reg signed [DATA_WIDTH+1:0] row_buf [0:NUM_CHANNELS-1][0:MAX_WIDTH/2-1];

    // Horizontal running max register (holds max of first pixel in a 2-wide pair)
    reg signed [DATA_WIDTH-1:0] horiz_max [0:NUM_CHANNELS-1];

    // AvgPool accumulation register
    reg signed [DATA_WIDTH+1:0] avg_sum [0:NUM_CHANNELS-1];

    // Column and row phase counters
    reg [7:0] col_ptr;
    reg       row_phase;  // 0 = first row of a 2-row group, 1 = second row
    reg       col_phase;  // 0 = first col of a 2-col pair, 1 = second col

    // Per-channel combinational max comparison wires
    wire signed [DATA_WIDTH-1:0] max_cur_horiz [0:NUM_CHANNELS-1];
    wire signed [DATA_WIDTH-1:0] final_max     [0:NUM_CHANNELS-1];

    genvar m;
    generate
        for (m = 0; m < NUM_CHANNELS; m = m + 1) begin : gen_max_comb
            // Max of current pixel and the horizontal running max
            assign max_cur_horiz[m] = (act_in[m] > horiz_max[m]) ? act_in[m] : horiz_max[m];
            // Max of current combined horizontal max and previous row's stored value
            assign final_max[m]     = (max_cur_horiz[m] > row_buf[m][col_ptr[7:1]]) ?
                                       max_cur_horiz[m] : row_buf[m][col_ptr[7:1]];
        end
    endgenerate

    integer ch;
    always @(posedge clk) begin
        if (!rst_n) begin
            col_ptr       <= 0;
            row_phase     <= 0;
            col_phase     <= 0;
            act_valid_out <= 1'b0;
            act_out_flat  <= 0;

            for (ch = 0; ch < NUM_CHANNELS; ch = ch + 1) begin
                horiz_max[ch] <= 0;
                avg_sum[ch]   <= 0;
            end
        end else begin
            act_valid_out <= 1'b0;

            if (act_valid_in) begin
                if (!pool_enable || pool_mode == 2'b00) begin
                    // Bypass mode: pass straight through
                    act_out_flat  <= act_in_flat;
                    act_valid_out <= 1'b1;
                end else if (pool_mode == 2'b01) begin
                    // 2x2 Max Pool
                    if (col_phase == 1'b0) begin
                        for (ch = 0; ch < NUM_CHANNELS; ch = ch + 1) begin
                            horiz_max[ch] <= act_in[ch];
                        end
                    end else begin
                        if (row_phase == 1'b0) begin
                            for (ch = 0; ch < NUM_CHANNELS; ch = ch + 1) begin
                                row_buf[ch][col_ptr[7:1]] <= max_cur_horiz[ch];
                            end
                        end else begin
                            for (ch = 0; ch < NUM_CHANNELS; ch = ch + 1) begin
                                act_out_flat[ch*DATA_WIDTH +: DATA_WIDTH] <= final_max[ch];
                            end
                            act_valid_out <= 1'b1;
                        end
                    end

                    col_phase <= ~col_phase;
                    if (col_phase == 1'b1) begin
                        col_ptr <= col_ptr + 1'b1;
                        if (col_ptr == image_width - 1) begin
                            col_ptr   <= 0;
                            row_phase <= ~row_phase;
                        end
                    end
                end else if (pool_mode == 2'b10) begin
                    // 2x2 Avg Pool
                    if (col_phase == 1'b0) begin
                        if (row_phase == 1'b0) begin
                            for (ch = 0; ch < NUM_CHANNELS; ch = ch + 1) begin
                                avg_sum[ch] <= act_in[ch];
                            end
                        end else begin
                            for (ch = 0; ch < NUM_CHANNELS; ch = ch + 1) begin
                                avg_sum[ch] <= row_buf[ch][col_ptr[7:1]] + act_in[ch];
                            end
                        end
                    end else begin
                        if (row_phase == 1'b0) begin
                            for (ch = 0; ch < NUM_CHANNELS; ch = ch + 1) begin
                                row_buf[ch][col_ptr[7:1]] <= avg_sum[ch] + act_in[ch];
                            end
                        end else begin
                            for (ch = 0; ch < NUM_CHANNELS; ch = ch + 1) begin
                                act_out_flat[ch*DATA_WIDTH +: DATA_WIDTH] <= (avg_sum[ch] + act_in[ch]) >>> 2;
                            end
                            act_valid_out <= 1'b1;
                        end
                    end

                    col_phase <= ~col_phase;
                    if (col_phase == 1'b1) begin
                        col_ptr <= col_ptr + 1'b1;
                        if (col_ptr == image_width - 1) begin
                            col_ptr   <= 0;
                            row_phase <= ~row_phase;
                        end
                    end
                end
            end
        end
    end

endmodule
