// -----------------------------------------------------------------------------
// File        : tinynpu_icg.v
// Description : Generic, ASIC-ready Integrated Clock Gate (ICG) cell.
//               This module implements a standard latch-based ICG.
//               A latch-based ICG is the industry standard for ASIC design
//               because it provides glitch-free clock gating. By capturing the
//               enable signal ('en') when the clock is low, it prevents any
//               glitches on the enable signal from propagating to the output
//               clock. This improves power efficiency, reduces area compared
//               to flip-flop based gates, and ensures high immunity to glitches.
//               For FPGA targets, a wrapper should map this to a BUFGCE.
// -----------------------------------------------------------------------------

`timescale 1ns / 1ps

module tinynpu_icg (
    input  wire clk_in,
    input  wire en,
    output wire clk_out
);

`ifdef BEHAVIORAL_CG
    // Behavioral simulation model: simple AND gate.
    // Use this for simulations to avoid latch-related warnings.
    assign clk_out = clk_in & en;
`else
    // Synthesis model: latch-based ICG (negative-level transparent latch)
    // The enable signal is captured when clk_in is 0 to prevent glitches.
    reg en_latched;

    always @(clk_in or en) begin
        if (!clk_in) begin
            en_latched <= en;
        end
    end

    assign clk_out = clk_in & en_latched;
`endif

endmodule
