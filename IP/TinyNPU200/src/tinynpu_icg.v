`timescale 1ns / 1ps

module tinynpu_icg (
    input  wire clk_in,
    input  wire en,
    output wire clk_out
);

    reg en_latch;
    always @(clk_in or en) begin
        if (!clk_in) begin
            en_latch = en;
        end
    end

    assign clk_out = clk_in & en_latch;

endmodule
