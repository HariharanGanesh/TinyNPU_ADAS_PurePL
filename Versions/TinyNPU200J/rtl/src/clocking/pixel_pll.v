// =============================================================================
// Module: pixel_pll.v
// Project: TinyNPU200
// Description: Xilinx MMCM wrapper generating 74.25 MHz pixel clock from 125 MHz.
// =============================================================================

`timescale 1ns / 1ps

module pixel_pll (
    input  wire clk_in1,
    output wire clk_out1,
    output wire locked
);

    wire clkfbout;
    wire clkfbin;
    wire clkout0;
    
    BUFG clkfb_buf (
        .I(clkfbout),
        .O(clkfbin)
    );

    BUFG clkout0_buf (
        .I(clkout0),
        .O(clk_out1)
    );

`ifdef SYNTHESIS
    (* DONT_TOUCH = "TRUE" *)
    MMCME2_ADV #(
        .BANDWIDTH("OPTIMIZED"),
        .CLKFBOUT_MULT_F(37.125),
        .CLKFBOUT_PHASE(0.000),
        .CLKIN1_PERIOD(8.000),
        .CLKOUT0_DIVIDE_F(15.625),
        .CLKOUT0_DUTY_CYCLE(0.500),
        .CLKOUT0_PHASE(0.000),
        .CLKOUT0_USE_FINE_PS("FALSE"),
        .DIVCLK_DIVIDE(4),
        .REF_JITTER1(0.010),
        .STARTUP_WAIT("FALSE")
    ) mmcm_inst (
        .CLKFBOUT(clkfbout),
        .CLKFBOUTB(),
        .CLKOUT0(clkout0),
        .CLKOUT0B(),
        .CLKOUT1(),
        .CLKOUT1B(),
        .CLKOUT2(),
        .CLKOUT2B(),
        .CLKOUT3(),
        .CLKOUT3B(),
        .CLKOUT4(),
        .CLKOUT5(),
        .CLKOUT6(),
        .CLKFBIN(clkfbin),
        .CLKIN1(clk_in1),
        .CLKIN2(1'b0),
        .CLKINSEL(1'b1),
        .DADDR(7'h0),
        .DCLK(1'b0),
        .DEN(1'b0),
        .DI(16'h0),
        .DO(),
        .DRDY(),
        .DWE(1'b0),
        .PSCLK(1'b0),
        .PSEN(1'b0),
        .PSINCDEC(1'b0),
        .PSDONE(),
        .LOCKED(locked),
        .CLKINSTOPPED(),
        .CLKFBSTOPPED(),
        .PWRDWN(1'b0),
        .RST(1'b0)
    );
`else
    // Behavioral simulation
    reg clk_out_reg = 0;
    initial begin
        clk_out_reg = 0;
    end
    always #6.734 clk_out_reg = ~clk_out_reg; // 74.25 MHz = 13.468 ns period => 6.734 ns half-period
    
    assign clkout0 = clk_out_reg;
    assign clkfbout = clkfbin;
    assign locked = 1'b1;
`endif

endmodule
