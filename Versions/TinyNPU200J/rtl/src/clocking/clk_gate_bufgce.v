// =============================================================================
// Module: clk_gate_bufgce.v
// Project: TinyNPU
// Description:
//   Xilinx BUFGCE-based clock gating cell wrapper.
//
//   TWO IMPLEMENTATIONS:
//   --------------------
//   1. SYNTHESIS (default): Uses the real Xilinx BUFGCE primitive on the
//      global clock spine. Glitch-free, no routing fabric pollution.
//
//   2. SIMULATION (`define SIMULATION or `define BEHAVIORAL_CG):
//      Behavioral model — simple AND gate. Adequate for functional verification
//      because all enable signals are registered (glitch-free by design).
//      This avoids requiring the Xilinx unisims library in standalone sim.
//
//   HOW TO CHOOSE:
//   - In Vivado xsim with Xilinx IP libraries compiled: neither define needed.
//     Vivado automatically provides the BUFGCE model.
//   - In standalone ModelSim / Questa / Icarus / Xcelium without Xilinx libs:
//     compile with: +define+BEHAVIORAL_CG (Questa/ModelSim)
//                or -D BEHAVIORAL_CG     (Icarus)
//     or add to your run_top_sim.ps1: -define BEHAVIORAL_CG
//
//   WHY THIS MATTERS:
//   BUFGCE is a Xilinx-specific global clock primitive. It does not exist
//   in standard Verilog simulation libraries. If a simulator cannot resolve
//   the BUFGCE module, you get: "ERROR: module 'BUFGCE' not bound".
//   The behavioral model bypasses this while keeping synthesis correct.
//
//   Verilog-2001 Synthesizable RTL.
// =============================================================================

`timescale 1ns / 1ps

`ifndef SYNTHESIS
// =============================================================================
// SIMULATION BEHAVIORAL MODEL
// Simple AND gate. Safe because all CE signals are registered FSM outputs
// (no glitches). Used when Xilinx unisims library is not available.
// =============================================================================
module clk_gate_bufgce (
    input  wire clk_in,
    input  wire ce,
    output wire clk_out
);
    // AND model: clock passes only when ce=1.
    // In a real BUFGCE the enable is latched on clock-LOW to prevent glitches.
    // Since our CE signals are registered outputs of npu_controller FSM,
    // they are already glitch-free — this model is accurate for simulation.
    assign clk_out = clk_in & ce;
endmodule

`else
// =============================================================================
// SYNTHESIS IMPLEMENTATION — Xilinx BUFGCE Primitive
// =============================================================================
(* DONT_TOUCH = "TRUE" *)  // Prevent Vivado from merging or removing this instance
module clk_gate_bufgce (
    input  wire clk_in,   // Ungated clock from MMCM/PLL output
    input  wire ce,       // Clock enable (active-high, must be glitch-free)
    output wire clk_out   // Gated clock (on global clock spine, no fabric routing)
);

    // Xilinx 7-series / Zynq-7000 BUFGCE primitive
    // I  = clock input  (from IBUFG or MMCM output, already on global spine)
    // CE = clock enable (internally latched on clock-LOW — glitch immune)
    // O  = gated clock  (on global clock network — no skew vs other domains)
    BUFGCE #(
        .SIM_DEVICE ("7SERIES")  // Target: Zynq-7020 (Artix-7 PL fabric) on PYNQ-Z2
    ) u_bufgce (
        .I  (clk_in),
        .CE (ce),
        .O  (clk_out)
    );

endmodule
`endif
