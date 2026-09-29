// =============================================================================
// SystemVerilog Assertions — Processing Element Protocol Checker
// Project: TinyNPU
// Description:
//   Embedded SVA (SystemVerilog Assertion) properties and sequences for the
//   processing_element module. These assertions are compiled into simulation
//   to catch bugs at the point of occurrence, not downstream.
//
//   Usage:
//   Include this file in your testbench or bind it to the DUT:
//       bind processing_element pe_assertions #(
//           .DATA_WIDTH(8), .ACCUM_WIDTH(32)
//       ) pe_assert_inst (.*);
//
//   All assertions are gated by `!SYNTHESIS to exclude from synthesis.
// =============================================================================

`timescale 1ns / 1ps

module pe_assertions #(
    parameter int DATA_WIDTH  = 8,
    parameter int ACCUM_WIDTH = 32
) (
    input logic                          clk,
    input logic                          rst_n,
    input logic                          weight_load,
    input logic signed [DATA_WIDTH-1:0]  weight_in,
    input logic signed [DATA_WIDTH-1:0]  act_in,
    input logic signed [DATA_WIDTH-1:0]  act_out,
    input logic                          act_valid_in,
    input logic                          act_valid_out,
    input logic signed [ACCUM_WIDTH-1:0] psum_in,
    input logic signed [ACCUM_WIDTH-1:0] psum_out,
    input logic                          pe_en
);

`ifndef SYNTHESIS

    // =========================================================================
    // Assertion 1: Reset Behavior
    //   After reset de-assertion, psum_out and act_out must be 0 on the
    //   FIRST active clock edge after reset.
    // =========================================================================
    property rst_clears_outputs;
        @(posedge clk)
        $rose(rst_n) |=> (psum_out == '0 && act_out == '0 && act_valid_out == 1'b0);
    endproperty

    A_RST_CLEARS : assert property (rst_clears_outputs)
        else $error("PE: Outputs not cleared after reset de-assertion at time %0t", $time);

    // =========================================================================
    // Assertion 2: Stall Holds Outputs
    //   When pe_en is de-asserted, psum_out must remain unchanged.
    // =========================================================================
    property stall_holds_psum;
        @(posedge clk) disable iff (!rst_n)
        !pe_en |=> ($stable(psum_out));
    endproperty

    A_STALL_HOLDS_PSUM : assert property (stall_holds_psum)
        else $error("PE: psum_out changed during stall (pe_en=0) at time %0t", $time);

    property stall_holds_act;
        @(posedge clk) disable iff (!rst_n)
        !pe_en |=> ($stable(act_out) && $stable(act_valid_out));
    endproperty

    A_STALL_HOLDS_ACT : assert property (stall_holds_act)
        else $error("PE: act_out changed during stall (pe_en=0) at time %0t", $time);

    // =========================================================================
    // Assertion 3: act_valid_out tracks act_valid_in with 1-cycle latency
    //   When pe_en is high, act_valid_out next cycle = act_valid_in this cycle
    // =========================================================================
    property valid_propagates;
        @(posedge clk) disable iff (!rst_n)
        pe_en |=> (act_valid_out == $past(act_valid_in));
    endproperty

    A_VALID_PROPAGATES : assert property (valid_propagates)
        else $error("PE: act_valid_out does not match delayed act_valid_in at time %0t", $time);

    // =========================================================================
    // Assertion 4: act_out tracks act_in with 1-cycle latency (when enabled)
    // =========================================================================
    property act_passthrough;
        @(posedge clk) disable iff (!rst_n)
        pe_en |=> (act_out == $past(act_in));
    endproperty

    A_ACT_PASSTHROUGH : assert property (act_passthrough)
        else $error("PE: act_out does not match delayed act_in at time %0t", $time);

    // =========================================================================
    // Assertion 5: MAC correctness (combinational, checked every cycle)
    //   psum_out == psum_in + weight_reg × act_in (the PREVIOUS cycle's values)
    //   This is a strong functional assertion that catches any MAC error.
    //
    //   Note: weight_reg is internal; we check by verifying the delta.
    //   This assertion checks that psum changes by exactly (weight × act) per cycle.
    //
    //   Limitation: This assertion cannot directly observe weight_reg.
    //   It is left as a reminder — a full check requires weight_reg exposure.
    // =========================================================================
    // (Cannot assert MAC without internal signal access — see bind-based TB instead)

    // =========================================================================
    // Assertion 6: No X/Z on outputs during valid computation
    // =========================================================================
    property no_x_on_psum;
        @(posedge clk) disable iff (!rst_n)
        pe_en && act_valid_in |-> !$isunknown(psum_out);
    endproperty

    A_NO_X_PSUM : assert property (no_x_on_psum)
        else $error("PE: psum_out contains X/Z during valid computation at time %0t", $time);

    property no_x_on_act_out;
        @(posedge clk) disable iff (!rst_n)
        act_valid_in |-> !$isunknown(act_out);
    endproperty

    A_NO_X_ACT : assert property (no_x_on_act_out)
        else $error("PE: act_out contains X/Z at time %0t", $time);

    // =========================================================================
    // Coverage Points
    //   These track design coverage during simulation to ensure testbench
    //   exercises all interesting scenarios.
    // =========================================================================

    // Cover: both operands at max positive value
    COV_MAX_POS: cover property (
        @(posedge clk) disable iff (!rst_n)
        pe_en && (act_in == {1'b0, {(DATA_WIDTH-1){1'b1}}})   // act = +127
              && weight_load
    );

    // Cover: both operands at min negative value
    COV_MAX_NEG: cover property (
        @(posedge clk) disable iff (!rst_n)
        pe_en && (act_in == {1'b1, {(DATA_WIDTH-1){1'b0}}})   // act = -128
              && weight_load
    );

    // Cover: stall for at least 3 consecutive cycles
    COV_LONG_STALL: cover property (
        @(posedge clk) disable iff (!rst_n)
        !pe_en ##1 !pe_en ##1 !pe_en
    );

    // Cover: weight reload during pipeline (between tiles)
    COV_WEIGHT_RELOAD: cover property (
        @(posedge clk) disable iff (!rst_n)
        weight_load && !act_valid_in
    );

    // Cover: valid computation followed by stall
    COV_COMPUTE_THEN_STALL: cover property (
        @(posedge clk) disable iff (!rst_n)
        (pe_en && act_valid_in) ##1 !pe_en
    );

`endif // SYNTHESIS

endmodule : pe_assertions
