// =============================================================================
// Module: processing_element.v
// Project: TinyNPU
// Description:
//   Single Processing Element (PE) for the weight-stationary systolic array.
//   Verilog-2001 Synthesizable RTL.
// =============================================================================

`timescale 1ns / 1ps

module processing_element #(
    parameter DATA_WIDTH  = 8,   // Activation and weight bit-width
    parameter ACCUM_WIDTH = 32   // Partial sum accumulator bit-width
) (
    input  wire                    clk,
    input  wire                    rst_n,

    // Weight Loading
    input  wire                    weight_load,
    input  wire signed [DATA_WIDTH-1:0] weight_in,

    // Activation Datapath (horizontal flow)
    input  wire signed [DATA_WIDTH-1:0] act_in,
    output reg signed [DATA_WIDTH-1:0]  act_out,
    input  wire                    act_valid_in,
    output reg                     act_valid_out,

    // Partial Sum Datapath (vertical flow)
    input  wire signed [ACCUM_WIDTH-1:0] psum_in,
    output reg signed [ACCUM_WIDTH-1:0]  psum_out,

    // PE Control
    input  wire                    pe_en,
    input  wire                    psum_clear  // Synchronous accumulator clear
);

    // =========================================================================
    // Internal Signals
    // =========================================================================
    reg signed [DATA_WIDTH-1:0] weight_reg;
    wire signed [2*DATA_WIDTH-1:0] mul_result;
    wire signed [ACCUM_WIDTH-1:0] mul_result_extended;

    // =========================================================================
    // Weight Register
    // =========================================================================
    always @(posedge clk) begin
        if (!rst_n) begin
            weight_reg <= 0;
        end else if (weight_load) begin
            weight_reg <= weight_in;
        end
    end

    // =========================================================================
    // Multiply & Sign-Extend
    // =========================================================================
    assign mul_result = weight_reg * act_in;
    // Manual sign extension for Verilog-2001 compatibility
    assign mul_result_extended = $signed(mul_result);

    // =========================================================================
    // Partial Sum Accumulation - Registered
    // Gate accumulation on act_valid_in so that during the drain phase
    // (when act_rd_en is deasserted and act_valid_in=0) the PE simply
    // passes psum_in downstream without corrupting it with stale act_in data.
    // =========================================================================
    always @(posedge clk) begin
        if (!rst_n || psum_clear) begin
            psum_out <= 0;
        end else if (pe_en && act_valid_in) begin
            // Accumulate: add this PE's contribution
            psum_out <= psum_in + mul_result_extended;
        end else if (pe_en) begin
            // Drain phase: pass partial sum through without accumulating
            psum_out <= psum_in;
        end
    end

    // =========================================================================
    // Activation Pass-Through - Registered
    // =========================================================================
    always @(posedge clk) begin
        if (!rst_n) begin
            act_out       <= 0;
            act_valid_out <= 1'b0;
        end else if (pe_en) begin
            act_out       <= act_in;
            act_valid_out <= act_valid_in;
        end
    end

endmodule
