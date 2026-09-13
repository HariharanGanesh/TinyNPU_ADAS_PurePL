`timescale 1ns/1ps

module bbox_decoder_dfl_tb;
    
    // Parameters
    parameter DATA_WIDTH = 8;
    parameter REG_MAX    = 16;
    parameter BINS       = REG_MAX + 1;
    
    // Signals
    logic clk;
    logic rst_n;
    logic enable;
    logic [BINS*DATA_WIDTH-1:0] dist_l_in;
    
    // Outputs
    logic [15:0] decoded_l;
    logic valid_out;

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // DUT Instantiation
    bbox_decoder_dfl #(
        .DATA_WIDTH(DATA_WIDTH),
        .REG_MAX(REG_MAX),
        .BINS(BINS)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable),
        .dist_l_in(dist_l_in),
        .decoded_l(decoded_l),
        .valid_out(valid_out)
    );

    // =========================================================================
    // Assertions (POV 5 - SVA)
    // =========================================================================
    // 1. Validate that enable propagates to valid_out after 1 cycle (pipeline depth)
    property p_valid_latency;
        @(posedge clk) disable iff(!rst_n)
        enable |=> valid_out;
    endproperty
    assert property(p_valid_latency) else $error("POV 5: valid_out pipeline latency violation!");
    
    // 2. Disabled module does not emit valid
    property p_no_enable_no_valid;
        @(posedge clk) disable iff(!rst_n)
        (!enable) |=> (!valid_out);
    endproperty
    assert property(p_no_enable_no_valid) else $error("POV 5: Decoder emitted valid data without enable!");

    // =========================================================================
    // Test Sequence
    // =========================================================================
    initial begin
        $display("========================================");
        $display("Starting DFL BBox Decoder Tests");
        $display("========================================");
        
        // POV 4 - Reset
        rst_n = 0;
        enable = 0;
        dist_l_in = '0;
        
        #20 rst_n = 1;
        
        // ---------------------------------------------------------------------
        // POV 1 & 7 - Functional & Arithmetic
        // ---------------------------------------------------------------------
        // We will drive a sharp distribution peaking at index 5.
        // Index 5 should yield approximately distance = 5.
        @(posedge clk);
        enable <= 1;
        // set all to deeply negative
        for (int i=0; i<BINS; i++) dist_l_in[i*DATA_WIDTH +: DATA_WIDTH] = -128;
        // Set bin 5 to maximum (127), bin 4 to 0, bin 6 to 0.
        dist_l_in[5*DATA_WIDTH +: DATA_WIDTH] = 127;
        
        @(posedge clk);
        enable <= 0;
        
        // Wait 1 cycle for pipeline to resolve (since we deasserted enable, the output from previous cycle is available now)
        #1;
        if (!valid_out) $error("POV 1: valid_out failed to assert.");
        if (decoded_l < 4 || decoded_l > 6) $error("POV 7: Arithmetic error in DFL summation. Expected ~5, got %d", decoded_l);

        // ---------------------------------------------------------------------
        // POV 8 - Fault Injection
        // ---------------------------------------------------------------------
        // What if we inject garbage and don't assert enable?
        @(posedge clk);
        enable <= 0;
        for (int i=0; i<BINS; i++) dist_l_in[i*DATA_WIDTH +: DATA_WIDTH] = 8'hFF; // Chaos
        
        @(posedge clk);
        #1;
        if (valid_out) $error("POV 8: Fault injection triggered a valid output when enable was low!");
        
        $display("========================================");
        $display("DFL BBox Decoder Tests Completed.");
        $display("========================================");
        $finish;
    end

endmodule
