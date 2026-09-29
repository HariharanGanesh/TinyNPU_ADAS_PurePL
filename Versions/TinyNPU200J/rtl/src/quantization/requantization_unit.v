// =============================================================================
// Module: requantization_unit.v
// Project: TinyNPU v3.0
// Description:
//   Requantization Unit — converts INT32 accumulated partial sums back to INT8.
//   Verilog-2001 Synthesizable RTL with flattened ports.
//   Includes per-channel bias addition as required for BatchNorm fusion.
//
//   TIMING FIX (v3.0):
//     Pipelined the bias addition and multiplication into two separate stages
//     to break the 32-bit adder -> 32x32 multi-DSP multiplier cascade path.
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

    localparam GEN_CH = NUM_CHANNELS; // localparam required for generate loop bound
    genvar c_un;
    generate
        for (c_un = 0; c_un < GEN_CH; c_un = c_un + 1) begin : gen_unpack
            localparam M0_BASE   = c_un * SCALE_WIDTH;
            localparam NS_BASE   = c_un * SHIFT_WIDTH;
            localparam BS_BASE   = c_un * ACCUM_WIDTH;
            localparam AC_BASE   = c_un * ACCUM_WIDTH;
            wire [SCALE_WIDTH-1:0]          m0_sl;
            wire [SHIFT_WIDTH-1:0]          ns_sl;
            wire signed [ACCUM_WIDTH-1:0]   bs_sl;
            wire signed [ACCUM_WIDTH-1:0]   ac_sl;
            assign m0_sl = M0_flat[M0_BASE +: SCALE_WIDTH];
            assign ns_sl = n_shift_flat[NS_BASE +: SHIFT_WIDTH];
            assign bs_sl = $signed(bias_flat[BS_BASE +: ACCUM_WIDTH]);
            assign ac_sl = $signed(acc_in_flat[AC_BASE +: ACCUM_WIDTH]);
            assign M0[c_un]      = m0_sl;
            assign n_shift[c_un] = ns_sl;
            assign bias[c_un]    = bs_sl;
            assign acc_in[c_un]  = ac_sl;
        end
    endgenerate

    // Pack output
    genvar c_pk;
    generate
        for (c_pk = 0; c_pk < GEN_CH; c_pk = c_pk + 1) begin : gen_pack
            localparam QO_BASE = c_pk * OUT_WIDTH;
            wire [OUT_WIDTH-1:0] qo_sl;
            assign qo_sl = quant_out[c_pk];
            assign quant_out_flat[QO_BASE +: OUT_WIDTH] = qo_sl;
        end
    endgenerate

    // =========================================================================
    // Pipeline Wires & Registers
    // =========================================================================

    // Stage 1a: bias addition (INT32)
    reg signed [ACCUM_WIDTH-1:0]             acc_bias   [0:NUM_CHANNELS-1];
    reg                                      stage1a_valid;
    reg [SHIFT_WIDTH-1:0]                    n_shift_s1a [0:NUM_CHANNELS-1];

    // Stage 1b: multiplication (INT32 acc_bias * M0 -> INT64)
    reg signed [ACCUM_WIDTH + SCALE_WIDTH:0] mul_result  [0:NUM_CHANNELS-1];
    reg signed [ACCUM_WIDTH + SCALE_WIDTH:0] round_const [0:NUM_CHANNELS-1];
    reg                                      stage1b_valid;
    reg [SHIFT_WIDTH-1:0]                    n_shift_s1b [0:NUM_CHANNELS-1];

    // Stage 2: right-shift + round
    reg signed [ACCUM_WIDTH:0]               shifted_result [0:NUM_CHANNELS-1];
    reg                                      stage2_valid;

    // =========================================================================
    // Stage 1a: Bias Add (Registered)
    // =========================================================================
    integer i;
    always @(posedge clk) begin
        if (!rst_n) begin
            stage1a_valid <= 1'b0;
            for (i = 0; i < NUM_CHANNELS; i = i + 1) begin
                acc_bias[i]   <= 0;
                n_shift_s1a[i] <= 0;
            end
        end else begin
            stage1a_valid <= acc_valid;
            for (i = 0; i < NUM_CHANNELS; i = i + 1) begin
                acc_bias[i]   <= acc_in[i] + bias[i];
                n_shift_s1a[i] <= n_shift[i];
            end
        end
    end

    // =========================================================================
    // Stage 1b: Multiply & Precompute Rounding Constant (Registered)
    // =========================================================================
    localparam MUL_WIDTH = ACCUM_WIDTH + SCALE_WIDTH + 1; // 65 bits
    integer m;
    always @(posedge clk) begin
        if (!rst_n) begin
            stage1b_valid <= 1'b0;
            for (m = 0; m < NUM_CHANNELS; m = m + 1) begin
                mul_result[m]  <= 0;
                round_const[m] <= 0;
                n_shift_s1b[m] <= 0;
            end
        end else begin
            stage1b_valid <= stage1a_valid;
            for (m = 0; m < NUM_CHANNELS; m = m + 1) begin
                mul_result[m]  <= acc_bias[m] * $signed({1'b0, M0[m]});
                n_shift_s1b[m] <= n_shift_s1a[m];
                
                if (n_shift_s1a[m] == 0) begin
                    round_const[m] <= 0;
                end else begin
                    round_const[m] <= $signed({{(MUL_WIDTH-1){1'b0}},1'b1}) << (n_shift_s1a[m] - 1);
                end
            end
        end
    end

    // =========================================================================
    // Stage 2: Rounding & Right-Shift (Registered)
    // =========================================================================
    integer j;
    always @(posedge clk) begin
        if (!rst_n) begin
            stage2_valid <= 1'b0;
            for (j = 0; j < NUM_CHANNELS; j = j + 1) begin
                shifted_result[j] <= 0;
            end
        end else begin
            stage2_valid <= stage1b_valid;
            for (j = 0; j < NUM_CHANNELS; j = j + 1) begin
                if (n_shift_s1b[j] == 0) begin
                    shifted_result[j] <= mul_result[j][ACCUM_WIDTH:0];
                end else begin
                    // Rounded arithmetic right-shift
                    shifted_result[j] <= $signed(mul_result[j] + round_const[j]) >>> n_shift_s1b[j];
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
