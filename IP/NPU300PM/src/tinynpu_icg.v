module tinynpu_icg (
    input  wire clk_in,
    input  wire en,
    output wire clk_out
);

    // Use Xilinx Zynq-7020 (7-Series) dedicated BUFGCE clock gating primitive.
    // SIM_DEVICE must be explicitly set to "7SERIES" to prevent Vivado netlist
    // correction warning [Netlist 29-345] which defaults to ULTRASCALE in newer
    // Vivado versions.
    BUFGCE #(
        .SIM_DEVICE ("7SERIES")
    ) u_bufgce (
        .I  (clk_in),
        .CE (en),
        .O  (clk_out)
    );

endmodule