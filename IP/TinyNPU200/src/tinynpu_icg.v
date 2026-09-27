`timescale 1ns / 1ps

module tinynpu_icg (
    input  wire clk_in,
    input  wire en,
    output wire clk_out
);

    BUFGCE u_bufgce (
        .I(clk_in),
        .CE(en),
        .O(clk_out)
    );

endmodule
