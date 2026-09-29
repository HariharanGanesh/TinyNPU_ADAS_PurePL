module tinynpu_icg (
    input  wire clk_in,
    input  wire en,
    output wire clk_out
);

    // Use Xilinx dedicated clock routing primitive to prevent massive clock skew
    BUFGCE u_bufgce (
        .I(clk_in),
        .CE(en),
        .O(clk_out)
    );

endmodule
