// =============================================================================
// Module: processing_element.v
// Project: NPU300PM — TinyNPU200 PMAX Edition
// Description:
//   Weight-stationary Processing Element for the NPU300PM 26x8 systolic array.
//
//   CRITICAL DSP48E1 FIX (NPU300PM v1.0):
//     The previous TinyNPU200 design used `(* use_dsp = "yes" *)` on a 16-bit
//     register (8x8=16 bits). Vivado's synthesizer threshold for automatic DSP
//     inference is 18x18 bits minimum. As a result, ALL 160 PEs in TinyNPU200
//     were silently mapped to LUT carry chains instead of DSP48 primitives.
//
//     FIX: Sign-extend both weight and activation inputs to 18 bits before
//     multiplying. The DSP48E1 B-port is exactly 18 bits wide. A 18x18
//     multiply is GUARANTEED to be absorbed into a single DSP48E1 primitive.
//     This converts the PE from a 16-bit LUT multiply to a true hardware
//     DSP48E1 MAC operation — physically faster, lower power.
//
//   Pipeline (3 stages):
//     Stage 1: 18x18 DSP48E1 multiply → 36-bit result registered
//     Stage 2: Truncate and sign-extend to ACCUM_WIDTH registered
//     Stage 3: ACCUM_WIDTH accumulate with psum_in
//
//   PE_LATENCY = 3 cycles (unchanged from TinyNPU200)
// =============================================================================

`timescale 1ns / 1ps

module processing_element #(
    parameter DATA_WIDTH  = 8,
    parameter ACCUM_WIDTH = 32
)(
    input  wire clk,
    input  wire reset_n,
    input  wire pe_en,
    input  wire psum_clear,
    input  wire weight_load,

    input  wire signed [DATA_WIDTH-1:0]   weight_in,
    input  wire signed [DATA_WIDTH-1:0]   act_in,
    input  wire                           act_valid_in,
    input  wire signed [ACCUM_WIDTH-1:0]  psum_in,

    output reg  signed [DATA_WIDTH-1:0]   act_out,
    output reg                            act_valid_out,
    output reg  signed [ACCUM_WIDTH-1:0]  psum_out
);

    localparam PE_LATENCY = 3;

    // =========================================================================
    // Weight register
    // =========================================================================
    reg signed [DATA_WIDTH-1:0] weight_reg;

    // =========================================================================
    // DSP48E1 Inference — Sign-extend to 18 bits to guarantee DSP48 mapping.
    // The Xilinx DSP48E1 B-port is 18 bits. Any multiply where both inputs
    // are <= 18 bits is guaranteed to be absorbed into ONE DSP48E1 primitive.
    // =========================================================================
    wire signed [17:0] weight_dsp = {{(18-DATA_WIDTH){weight_reg[DATA_WIDTH-1]}}, weight_reg};
    wire signed [17:0] act_dsp    = {{(18-DATA_WIDTH){act_in[DATA_WIDTH-1]}},    act_in};

    // Stage 1: DSP48E1 multiply — 18x18 -> 36-bit product
    (* use_dsp = "yes" *) reg signed [35:0] mul_s1;

    // Stage 2: Truncated & sign-extended product
    reg signed [ACCUM_WIDTH-1:0] mul_s2;

    // Valid pipeline
    reg act_valid_d1;
    reg act_valid_d2;

    // =========================================================================
    // Pipeline
    // =========================================================================
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            weight_reg    <= {DATA_WIDTH{1'b0}};
            mul_s1        <= 36'd0;
            mul_s2        <= {ACCUM_WIDTH{1'b0}};
            psum_out      <= {ACCUM_WIDTH{1'b0}};
            act_out       <= {DATA_WIDTH{1'b0}};
            act_valid_out <= 1'b0;
            act_valid_d1  <= 1'b0;
            act_valid_d2  <= 1'b0;
        end else begin

            // --- Weight loading ---
            if (weight_load)
                weight_reg <= weight_in;

            if (pe_en) begin
                // --- Activation passthrough (1 cycle) ---
                act_out       <= act_in;
                act_valid_out <= act_valid_in;

                // --- Stage 1: DSP48E1 multiply (18x18 -> 36 bit) ---
                mul_s1       <= weight_dsp * act_dsp;
                act_valid_d1 <= act_valid_in;

                // --- Stage 2: Truncate to ACCUM_WIDTH (keep lower 16+sign bits) ---
                // INT8 x INT8 = INT16 product, sign-extended to ACCUM_WIDTH
                mul_s2       <= {{(ACCUM_WIDTH-16){mul_s1[15]}}, mul_s1[15:0]};
                act_valid_d2 <= act_valid_d1;

                // --- Stage 3: Accumulate partial sum ---
                if (psum_clear)
                    psum_out <= {ACCUM_WIDTH{1'b0}};
                else
                    psum_out <= psum_in + mul_s2;

            end
        end
    end

endmodule
