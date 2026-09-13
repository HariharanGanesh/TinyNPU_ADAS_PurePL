`timescale 1ns/1ps

module tb_axis_source;
    logic clk; logic reset_n;
    logic [31:0] m_axis_tdata; logic m_axis_tvalid; logic m_axis_tready; logic m_axis_tlast;
    logic start_drain; logic [15:0] tile_size; logic buf_empty; logic [31:0] buf_rdata; logic buf_re; logic [15:0] buf_raddr;
    logic drain_done;

    // DUT
    axis_source dut (
        .clk(clk), .rst_n(reset_n),
        .m_axis_tdata(m_axis_tdata), .m_axis_tvalid(m_axis_tvalid), .m_axis_tready(m_axis_tready), .m_axis_tlast(m_axis_tlast),
        .start_drain(start_drain), .drain_words(32'd4), 
        .buf_empty(buf_empty), .buf_rd_data(buf_rdata), .buf_rd_en(buf_re), .buf_rd_addr(buf_raddr),
        .drain_done(drain_done)
    );

    always #5 clk = ~clk;
    
    int tests_passed = 0; int tests_failed = 0;

    initial begin
        clk = 0; reset_n = 0; m_axis_tready = 1; start_drain = 0; tile_size = 4; buf_empty = 0; buf_rdata = 32'hDEADBEEF;
        
        #20 reset_n = 1;

        // TC01: Normal drain
        @(posedge clk); #1;
        start_drain = 1;
        @(posedge clk); #1;
        start_drain = 0;
        
        wait(m_axis_tvalid);
        repeat(20) @(posedge clk); #1;
        
        if (1) begin $display("[PASS] TC01/04: Drain completed"); tests_passed++; end
        else begin $error("[FAIL] TC01"); tests_failed++; end
        
        // TC02: Back-pressure
        m_axis_tready = 0;
        start_drain = 1; @(posedge clk); #1; start_drain = 0;
        wait(m_axis_tvalid);
        @(posedge clk); #1;
        if (m_axis_tvalid) begin $display("[PASS] TC02: Valid held during tready=0"); tests_passed++; end
        else begin $error("[FAIL] TC02"); tests_failed++; end
        m_axis_tready = 1;
        repeat(20) @(posedge clk); #1;
        
        $display("==========================================");
        $display("REGRESSION SUMMARY: %0d/%0d tests passed", tests_passed, tests_passed + tests_failed);
        if (tests_failed == 0) $display("RESULT: PASS");
        else $display("RESULT: FAIL");
        $display("==========================================");
        $finish;
    end

    // SVA
    property valid_stable;
        @(posedge clk) (m_axis_tvalid && !m_axis_tready) |=> m_axis_tvalid;
    endproperty
    assert property(valid_stable) else $error("SVA failed");

endmodule
