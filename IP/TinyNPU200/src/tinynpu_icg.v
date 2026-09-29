`timescale 1ns / 1ps

module tinynpu_icg (
    input  wire clk_in,
    input  wire en,
    output wire clk_out
);

    // BUFGCE removed to fix hold timing violations caused by clock skew.
    // In FPGAs, clock gating is best handled by CE pins on registers.
    assign clk_out = clk_in;

endmodule
