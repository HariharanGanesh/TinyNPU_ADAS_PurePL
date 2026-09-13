`timescale 1ns/1ps

module tb_axis_sink;
    logic clk; logic reset_n;
    logic [31:0] s_axis_tdata; logic s_axis_tvalid; logic s_axis_tready; logic s_axis_tlast;
    logic crop_en; logic [15:0] crop_x; logic [15:0] crop_y; logic [15:0] crop_w; logic [15:0] crop_h;
    logic [15:0] frame_w; logic [15:0] frame_h;
    logic buf_full; logic [31:0] buf_wdata; logic buf_we; logic [15:0] buf_waddr;
    logic frame_done;

    // DUT
    axis_sink dut (
        .clk(clk), .rst_n(reset_n),
        .s_axis_tdata(s_axis_tdata), .s_axis_tvalid(s_axis_tvalid), .s_axis_tready(s_axis_tready), .s_axis_tlast(s_axis_tlast),
        .crop_en(crop_en), .crop_x(crop_x), .crop_y(crop_y), .crop_w(crop_w), .crop_h(crop_h),
         
        .buf_swap_ack(1'b0), .buf_full(buf_full), .buf_wr_data(buf_wdata), .buf_wr_en(buf_we), .buf_wr_addr(buf_waddr),
        .frame_done(frame_done)
    );

    always #5 clk = ~clk;

    int tests_passed = 0; int tests_failed = 0;

    initial begin
        clk = 0; reset_n = 0; s_axis_tvalid = 0; s_axis_tlast = 0; s_axis_tdata = 0;
        crop_en = 0; crop_x = 0; crop_y = 0; crop_w = 64; crop_h = 64; frame_w = 64; frame_h = 64;
        buf_full = 0;
        
        #20 reset_n = 1;
        
        // TC01: Normal streaming
        @(posedge clk); #1;
        s_axis_tdata = 32'hAAAA_BBBB; s_axis_tvalid = 1;
        wait(s_axis_tready);
        @(posedge clk); #1;
        if (buf_we) begin $display("[PASS] TC01: Buffer written"); tests_passed++; end
        else begin $error("[FAIL] TC01"); tests_failed++; end
        s_axis_tvalid = 0;

        // TC04: Back-pressure
        buf_full = 1;
        @(posedge clk); #1;
        if (!s_axis_tready) begin $display("[PASS] TC04: Backpressure honored"); tests_passed++; end
        else begin $error("[FAIL] TC04"); tests_failed++; end
        buf_full = 0;

        // TC05: tlast assertion
        @(posedge clk); #1;
        s_axis_tvalid = 1; s_axis_tlast = 1;
        wait(s_axis_tready);
        @(posedge clk); #1;
        s_axis_tvalid = 0; s_axis_tlast = 0;
        if (frame_done) begin $display("[PASS] TC05: frame_done pulsed"); tests_passed++; end
        else begin $error("[FAIL] TC05"); tests_failed++; end

        $display("==========================================");
        $display("REGRESSION SUMMARY: %0d/%0d tests passed", tests_passed, tests_passed + tests_failed);
        if (tests_failed == 0) $display("RESULT: PASS");
        else $display("RESULT: FAIL");
        $display("==========================================");
        $finish;
    end

    // SVA
    property backpressure_check;
        @(posedge clk) buf_full |=> !s_axis_tready;
    endproperty
    assert property(backpressure_check) else $error("SVA failed");

endmodule
