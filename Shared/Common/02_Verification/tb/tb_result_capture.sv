`timescale 1ns/1ps
module tb_result_capture;

    logic clk = 0;
    logic rst_n = 0;
    logic [31:0] s_axis_tdata;
    logic s_axis_tvalid = 0;
    logic s_axis_tlast = 0;
    logic s_axis_tready;

    logic [31:0] det_bbox_x, det_bbox_y, det_bbox_w, det_bbox_h;
    logic [7:0]  det_confidence;
    logic        det_valid;

    result_capture u_dut (
        .clk(clk), .rst_n(rst_n),
        .s_axis_tdata(s_axis_tdata), .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tlast(s_axis_tlast), .s_axis_tready(s_axis_tready),
        .det_bbox_x(det_bbox_x), .det_bbox_y(det_bbox_y),
        .det_bbox_w(det_bbox_w), .det_bbox_h(det_bbox_h),
        .det_confidence(det_confidence), .det_valid(det_valid)
    );

    always #5 clk = ~clk;

    initial begin
        rst_n = 0;
        #20 rst_n = 1;

        // Valid packet
        @(posedge clk);
        s_axis_tvalid <= 1; s_axis_tdata <= 10; s_axis_tlast <= 0; @(posedge clk);
        s_axis_tdata <= 20; @(posedge clk);
        s_axis_tdata <= 30; @(posedge clk);
        s_axis_tdata <= 40; @(posedge clk);
        s_axis_tdata <= 255; s_axis_tlast <= 1; @(posedge clk);
        s_axis_tvalid <= 0; s_axis_tlast <= 0;

        @(posedge clk);
        if (det_valid !== 1) $error("FAIL: det_valid should be 1");
        if (det_bbox_x !== 10) $error("FAIL: x incorrect");
        
        // Malformed packet
        @(posedge clk);
        s_axis_tvalid <= 1; s_axis_tdata <= 99; s_axis_tlast <= 1; @(posedge clk);
        s_axis_tvalid <= 0; s_axis_tlast <= 0;

        @(posedge clk);
        if (det_valid === 1) $error("FAIL: det_valid should be 0 on malformed packet");
        
        $display("Test complete.");
        $finish;
    end
endmodule
