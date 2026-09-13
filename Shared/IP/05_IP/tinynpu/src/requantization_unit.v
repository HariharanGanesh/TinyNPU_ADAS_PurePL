// =============================================================================
// Module: requantization_unit.v
// Project: TinyNPU
// Description:
//   Requantization Unit — converts INT32 accumulated partial sums back to INT8.
//   Verilog-2001 Synthesizable RTL with flattened ports.
//   Includes per-channel bias addition as required for BatchNorm fusion.
// =============================================================================

`timescale 1ns / 1ps

module requantization_unit #(
    parameter NUM_CHANNELS = 8,    // One requantizer per array column
    parameter ACCUM_WIDTH  = 32,   // Input: INT32 from accumulator
    parameter SCALE_WIDTH  = 32,   // M0 multiplier bit-width
    parameter SHIFT_WIDTH  = 6,    // n right-shift amount (supports shifts 0–63)
    parameter OUT_WIDTH    = 8     // Output: INT8
) (
    input  wire clk,
    input  wire rst_n,

    // Flattened scale factors, shifts, and biases
    input  wire [SCALE_WIDTH*NUM_CHANNELS-1:0] M0_flat,
    input  wire [SHIFT_WIDTH*NUM_CHANNELS-1:0] n_shift_flat,
    input  wire [ACCUM_WIDTH*NUM_CHANNELS-1:0] bias_flat,

    // Data Path
    input  wire [ACCUM_WIDTH*NUM_CHANNELS-1:0] acc_in_flat,
    input  wire                                acc_valid,

    output wire [OUT_WIDTH*NUM_CHANNELS-1:0]   quant_out_flat,
    output reg                                 quant_valid
);

    // Unpack flattened ports
    wire [SCALE_WIDTH-1:0]   M0      [0:NUM_CHANNELS-1];
    wire [SHIFT_WIDTH-1:0]   n_shift [0:NUM_CHANNELS-1];
    wire signed [ACCUM_WIDTH-1:0] bias    [0:NUM_CHANNELS-1];
    wire signed [ACCUM_WIDTH-1:0] acc_in  [0:NUM_CHANNELS-1];
    reg  signed [OUT_WIDTH-1:0]   quant_out[0:NUM_CHANNELS-1];

    genvar c_un;
    generate
        for (c_un = 0; c_un < NUM_CHANNELS; c_un = c_un + 1) begin : gen_unpack
            assign M0[c_un]      = M0_flat[c_un*SCALE_WIDTH +: SCALE_WIDTH];
            assign n_shift[c_un] = n_shift_flat[c_un*SHIFT_WIDTH +: SHIFT_WIDTH];
            assign bias[c_un]    = $signed(bias_flat[c_un*ACCUM_WIDTH +: ACCUM_WIDTH]);
            assign acc_in[c_un]  = $signed(acc_in_flat[c_un*ACCUM_WIDTH +: ACCUM_WIDTH]);
        end
    endgenerate

    // Pack output
    genvar c_pk;
    generate
        for (c_pk = 0; c_pk < NUM_CHANNELS; c_pk = c_pk + 1) begin : gen_pack
            assign quant_out_flat[c_pk*OUT_WIDTH +: OUT_WIDTH] = quant_out[c_pk];
        end
    endgenerate

    // =========================================================================
    // Pipeline Wires & Registers
    // =========================================================================

    // Stage 1: bias addition and multiplication (INT32 acc_with_bias * M0 -> INT64)
    reg signed [ACCUM_WIDTH + SCALE_WIDTH:0] mul_result   [0:NUM_CHANNELS-1];
    reg                                      stage1_valid;
    reg [SHIFT_WIDTH-1:0]                    n_shift_s1   [0:NUM_CHANNELS-1];

    // Stage 2: right-shift + round
    reg signed [ACCUM_WIDTH:0]               shifted_result [0:NUM_CHANNELS-1];
    reg                                      stage2_valid;

    // =========================================================================
    // Stage 1: Bias Add & Multiply (Registered)
    // =========================================================================
    integer i;
    always @(posedge clk) begin
        if (!rst_n) begin
            stage1_valid <= 1'b0;
            for (i = 0; i < NUM_CHANNELS; i = i + 1) begin
                mul_result[i] <= 0;
                n_shift_s1[i] <= 0;
            end
        end else begin
            stage1_valid <= acc_valid;
            for (i = 0; i < NUM_CHANNELS; i = i + 1) begin
                // Perform combinational bias add first, then multiply
                mul_result[i] <= (acc_in[i] + bias[i]) * $signed({1'b0, M0[i]});
                n_shift_s1[i] <= n_shift[i];
            end
        end
    end

    // =========================================================================
    // Stage 2: Rounding & Right-Shift (Registered)
    // =========================================================================
    // The rounding constant (1 << (n-1)) must be as wide as mul_result to
    // avoid silent truncation. Use a full-width parameter-sized literal.
    localparam MUL_WIDTH = ACCUM_WIDTH + SCALE_WIDTH + 1; // 65 bits
    integer j;
    always @(posedge clk) begin
        if (!rst_n) begin
            stage2_valid <= 1'b0;
            for (j = 0; j < NUM_CHANNELS; j = j + 1) begin
                shifted_result[j] <= 0;
            end
        end else begin
            stage2_valid <= stage1_valid;
            for (j = 0; j < NUM_CHANNELS; j = j + 1) begin
                if (n_shift_s1[j] == 0) begin
                    shifted_result[j] <= mul_result[j][ACCUM_WIDTH:0];
                end else begin
                    // Rounded arithmetic right-shift
                    // Rounding: add 0.5 LSB at shift position before shifting
                    // Use {{(MUL_WIDTH-1){1'b0}},1'b1} as base for rounding constant
                    shifted_result[j] <= $signed(mul_result[j] + ($signed({{(MUL_WIDTH-1){1'b0}},1'b1}) << (n_shift_s1[j] - 1))) >>> n_shift_s1[j];
                end
            end
        end
    end

    // =========================================================================
    // Stage 3: Saturating Clamp to INT8 (Registered)
    // =========================================================================
    localparam signed [ACCUM_WIDTH:0] OUT_MAX = (1 << (OUT_WIDTH - 1)) - 1; // 127
    localparam signed [ACCUM_WIDTH:0] OUT_MIN = -(1 << (OUT_WIDTH - 1));    // -128

    integer k;
    always @(posedge clk) begin
        if (!rst_n) begin
            quant_valid <= 1'b0;
            for (k = 0; k < NUM_CHANNELS; k = k + 1) begin
                quant_out[k] <= 0;
            end
        end else begin
            quant_valid <= stage2_valid;
            for (k = 0; k < NUM_CHANNELS; k = k + 1) begin
                if (shifted_result[k] > OUT_MAX) begin
                    quant_out[k] <= OUT_MAX[OUT_WIDTH-1:0];
                end else if (shifted_result[k] < OUT_MIN) begin
                    quant_out[k] <= OUT_MIN[OUT_WIDTH-1:0];
                end else begin
                    quant_out[k] <= shifted_result[k][OUT_WIDTH-1:0];
                end
            end
        end
    end

endmodule
