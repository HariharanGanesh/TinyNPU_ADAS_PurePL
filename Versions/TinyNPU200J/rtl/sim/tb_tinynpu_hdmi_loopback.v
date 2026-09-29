`timescale 1ns / 1ps

// ============================================================================
// TinyNPU200 Pure RTL Simulation Testbench (HDMI Loopback Top)
// 
// This testbench instantiates the full hardware top-wrapper (tinynpu_hdmi_top)
// and provides the necessary clock and reset stimulus.
// Note: Simulating full TMDS PHY (dvi2rgb / rgb2dvi) requires Digilent IP
// simulation models. This TB drives dummy TMDS inputs to allow pure RTL 
// elaboration and basic clocking validation.
// ============================================================================

module tb_tinynpu_hdmi_loopback;

    // ------------------------------------------------------------------------
    // Testbench Signals
    // ------------------------------------------------------------------------
    reg        sys_clk;
    reg        sys_rst_n;

    // Dummy TMDS Inputs (Simulating HDMI Source)
    reg        hdmi_rx_clk_p;
    wire       hdmi_rx_clk_n = ~hdmi_rx_clk_p;
    reg  [2:0] hdmi_rx_data_p;
    wire [2:0] hdmi_rx_data_n = ~hdmi_rx_data_p;

    // TMDS Outputs (HDMI Sink)
    wire       hdmi_tx_clk_p;
    wire       hdmi_tx_clk_n;
    wire [2:0] hdmi_tx_data_p;
    wire [2:0] hdmi_tx_data_n;

    wire [3:0] led;

    // ------------------------------------------------------------------------
    // Clock Generation
    // ------------------------------------------------------------------------
    // 125 MHz system clock (8.0 ns period)
    initial begin
        sys_clk = 0;
        forever #4.0 sys_clk = ~sys_clk;
    end

    // 74.25 MHz HDMI Pixel Clock equivalent TMDS clock
    // (TMDS bit clock is usually 10x, but for simple clock detection we toggle)
    initial begin
        hdmi_rx_clk_p = 0;
        forever #6.734 hdmi_rx_clk_p = ~hdmi_rx_clk_p; 
    end

    // ------------------------------------------------------------------------
    // Stimulus
    // ------------------------------------------------------------------------
    initial begin
        $display("==========================================================");
        $display("Starting TinyNPU200 Pure RTL Sim (HDMI Loopback)");
        $display("==========================================================");

        // Initialize signals
        sys_rst_n = 0;
        hdmi_rx_data_p = 3'b000;

        // Apply reset
        #100;
        sys_rst_n = 1;
        $display("[%0t] System Reset Released", $time);

        // Wait for PLL locks
        #5000;
        $display("[%0t] Simulating dummy TMDS data stream...", $time);
        
        // Drive some dummy TMDS transitions to prevent Vivado from optimizing out
        repeat(1000) begin
            @(posedge hdmi_rx_clk_p);
            hdmi_rx_data_p <= $random;
        end

        $display("[%0t] Simulation Finished.", $time);
        $finish;
    end

    // ------------------------------------------------------------------------
    // Device Under Test (DUT)
    // ------------------------------------------------------------------------
    tinynpu_hdmi_top u_dut (
        .sys_clk        (sys_clk),
        .sys_rst_n      (sys_rst_n),

        .hdmi_rx_clk_p  (hdmi_rx_clk_p),
        .hdmi_rx_clk_n  (hdmi_rx_clk_n),
        .hdmi_rx_data_p (hdmi_rx_data_p),
        .hdmi_rx_data_n (hdmi_rx_data_n),

        .hdmi_tx_clk_p  (hdmi_tx_clk_p),
        .hdmi_tx_clk_n  (hdmi_tx_clk_n),
        .hdmi_tx_data_p (hdmi_tx_data_p),
        .hdmi_tx_data_n (hdmi_tx_data_n),

        .led            (led)
    );

endmodule
