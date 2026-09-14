`timescale 1ns / 1ps

module tinynpu_top_tb();

    // =========================================================================
    // Clock and Reset Generation
    // =========================================================================
    logic clk;
    logic rst_n;

    initial begin
        clk = 0;
        forever #2.5 clk = ~clk; // 200 MHz
    end

    initial begin
        rst_n = 0;
        #100;
        rst_n = 1;
    end

    // =========================================================================
    // Interfaces
    // =========================================================================
    // AXI-Lite (CSRs)
    logic [31:0] s_axi_awaddr = 0;
    logic        s_axi_awvalid = 0;
    wire         s_axi_awready;
    logic [31:0] s_axi_wdata = 0;
    logic        s_axi_wvalid = 0;
    wire         s_axi_wready;
    wire  [1:0]  s_axi_bresp;
    wire         s_axi_bvalid;
    logic        s_axi_bready = 1;
    logic [31:0] s_axi_araddr = 0;
    logic        s_axi_arvalid = 0;
    wire         s_axi_arready;
    wire  [31:0] s_axi_rdata;
    wire  [1:0]  s_axi_rresp;
    wire         s_axi_rvalid;
    logic        s_axi_rready = 1;

    // AXI-Stream Input (Sensor)
    wire [7:0]   s_axis_tdata;
    wire         s_axis_tvalid;
    wire         s_axis_tready;
    wire         s_axis_tlast;

    // AXI-Stream Output (Results)
    wire [7:0]   m_axis_tdata;
    wire         m_axis_tvalid;
    logic        m_axis_tready = 1; // Always ready to receive in testbench
    wire         m_axis_tlast;

    // AXI4-Full (DMA Master) - Stubbed
    wire [31:0]  m_axi_araddr;
    wire [7:0]   m_axi_arlen;
    wire         m_axi_arvalid;
    logic        m_axi_arready = 1;
    logic [31:0] m_axi_rdata = 0;
    logic [1:0]  m_axi_rresp = 0;
    logic        m_axi_rlast = 1;
    logic        m_axi_rvalid = 0;
    wire         m_axi_rready;
    wire [31:0]  m_axi_awaddr;
    wire [7:0]   m_axi_awlen;
    wire         m_axi_awvalid;
    logic        m_axi_awready = 1;
    wire [31:0]  m_axi_wdata;
    wire         m_axi_wlast;
    wire         m_axi_wvalid;
    logic        m_axi_wready = 1;
    logic [1:0]  m_axi_bresp = 0;
    logic        m_axi_bvalid = 0;
    wire         m_axi_bready;
    
    // Interrupt
    wire         interrupt;

    // =========================================================================
    // DUT: TinyNPU
    // =========================================================================
    tinynpu_top #(
        .AXI_ADDR_WIDTH(32),
        .AXI_DATA_WIDTH(32),
        .AXIS_DATA_WIDTH(8),
        .DATA_WIDTH(8),
        .ACCUM_WIDTH(32),
        .SCALE_WIDTH(32),
        .SHIFT_WIDTH(6),
        .ARRAY_ROWS(8),
        .ARRAY_COLS(8),
        .BUFFER_DEPTH(512),
        .BUFFER_ADDR_WIDTH(9),
        .MAX_WIDTH(128),
        .TILE_SIZE(64)
    ) u_dut (
        .clk(clk),
        .rst_n(rst_n),
        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awprot(3'b0),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_awready(s_axi_awready),
        .s_axi_wdata(s_axi_wdata),
        .s_axi_wstrb(4'hF),
        .s_axi_wvalid(s_axi_wvalid),
        .s_axi_wready(s_axi_wready),
        .s_axi_bresp(s_axi_bresp),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_bready(s_axi_bready),
        .s_axi_araddr(s_axi_araddr),
        .s_axi_arprot(3'b0),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_arready(s_axi_arready),
        .s_axi_rdata(s_axi_rdata),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_rready(s_axi_rready),
        .m_axi_awaddr(m_axi_awaddr),
        .m_axi_awlen(m_axi_awlen),
        .m_axi_awsize(),
        .m_axi_awburst(),
        .m_axi_awvalid(m_axi_awvalid),
        .m_axi_awready(m_axi_awready),
        .m_axi_wdata(m_axi_wdata),
        .m_axi_wstrb(),
        .m_axi_wlast(m_axi_wlast),
        .m_axi_wvalid(m_axi_wvalid),
        .m_axi_wready(m_axi_wready),
        .m_axi_bresp(m_axi_bresp),
        .m_axi_bvalid(m_axi_bvalid),
        .m_axi_bready(m_axi_bready),
        .m_axi_araddr(m_axi_araddr),
        .m_axi_arlen(m_axi_arlen),
        .m_axi_arsize(),
        .m_axi_arburst(),
        .m_axi_arvalid(m_axi_arvalid),
        .m_axi_arready(m_axi_arready),
        .m_axi_rdata(m_axi_rdata),
        .m_axi_rresp(m_axi_rresp),
        .m_axi_rlast(m_axi_rlast),
        .m_axi_rvalid(m_axi_rvalid),
        .m_axi_rready(m_axi_rready),
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .s_axis_tlast(s_axis_tlast),
        .m_axis_tdata(m_axis_tdata),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tready(m_axis_tready),
        .m_axis_tlast(m_axis_tlast),
        .interrupt(interrupt)
    );

    // =========================================================================
    // SVA Bindings (Manual mapping here)
    // =========================================================================
    tinynpu_assertions u_sva (
        .clk(clk),
        .rst_n(rst_n),
        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_awready(s_axi_awready),
        .s_axi_wdata(s_axi_wdata),
        .s_axi_wvalid(s_axi_wvalid),
        .s_axi_wready(s_axi_wready),
        .s_axi_bresp(s_axi_bresp),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_bready(s_axi_bready),
        .s_axi_araddr(s_axi_araddr),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_arready(s_axi_arready),
        .s_axi_rdata(s_axi_rdata),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_rready(s_axi_rready),
        
        .m_axi_araddr(m_axi_araddr),
        .m_axi_arlen(m_axi_arlen),
        .m_axi_arvalid(m_axi_arvalid),
        .m_axi_arready(m_axi_arready),
        .m_axi_rdata(m_axi_rdata),
        .m_axi_rresp(m_axi_rresp),
        .m_axi_rlast(m_axi_rlast),
        .m_axi_rvalid(m_axi_rvalid),
        .m_axi_rready(m_axi_rready),
        .m_axi_awaddr(m_axi_awaddr),
        .m_axi_awlen(m_axi_awlen),
        .m_axi_awvalid(m_axi_awvalid),
        .m_axi_awready(m_axi_awready),
        .m_axi_wdata(m_axi_wdata),
        .m_axi_wlast(m_axi_wlast),
        .m_axi_wvalid(m_axi_wvalid),
        .m_axi_wready(m_axi_wready),
        .m_axi_bresp(m_axi_bresp),
        .m_axi_bvalid(m_axi_bvalid),
        .m_axi_bready(m_axi_bready),
        
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .s_axis_tlast(s_axis_tlast),
        
        .m_axis_tdata(m_axis_tdata),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tready(m_axis_tready),
        .m_axis_tlast(m_axis_tlast),
        
        .status_busy(u_dut.status_busy),
        .status_done(u_dut.status_done),
        .status_idle(u_dut.status_idle),
        .interrupt(interrupt),
        
        .array_en(u_dut.array_en),
        .array_weight_load(u_dut.array_weight_load),
        .array_psum_clear(u_dut.array_psum_clear),
        .out_buf_full(u_dut.out_buf_full),
        .out_buf_empty(u_dut.out_buf_empty),
        
        .csr_ctrl(u_dut.u_csr.reg_ctrl),
        .csr_status({28'b0, u_dut.status_error, u_dut.status_done, u_dut.status_busy, u_dut.status_idle})
    );

    // =========================================================================
    // Hardware Components (Verification IPs)
    // =========================================================================
    wire frame_start;
    wire frame_done_sensor;
    wire all_done;
    wire [15:0] frame_count;

    bram_sensor_emulator #(
        .NUM_FRAMES(1),
        .FRAME_W(8),
        .FRAME_H(8),
        .NUM_CHANNELS(1),
        .THROTTLE(1),
        .LOOP_EN(0),
        .ROM_INIT_FILE("test_sensor_data.hex") // Needs to be generated
    ) u_sensor (
        .clk(clk),
        .rst_n(rst_n),
        .m_axis_tdata(s_axis_tdata),
        .m_axis_tvalid(s_axis_tvalid),
        .m_axis_tlast(s_axis_tlast),
        .m_axis_tready(s_axis_tready),
        .frame_start(frame_start),
        .frame_done(frame_done_sensor),
        .frame_count(frame_count),
        .all_done(all_done)
    );

    wire sb_pass, sb_fail;
    wire [15:0] pass_rate, detection_accuracy;
    
    hw_scoreboard #(
        .CONF_THRESHOLD(8'd128)
    ) u_scoreboard (
        .clk(clk),
        .rst_n(rst_n),
        .m_axis_tdata(m_axis_tdata),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tready(m_axis_tready),
        .frame_done(frame_done_sensor),
        .sb_pass(sb_pass),
        .sb_fail(sb_fail),
        .sb_bytes_checked(),
        .sb_bytes_correct(),
        .sb_bytes_wrong(),
        .sb_false_positives(),
        .sb_false_negatives(),
        .sb_precision_x100(pass_rate),
        .sb_accuracy_x100(detection_accuracy)
    );

    // =========================================================================
    // AXI-Lite Helpers
    // =========================================================================
    task axi_write(input [31:0] addr, input [31:0] data);
        begin
            @(posedge clk);
            s_axi_awaddr  <= addr;
            s_axi_awvalid <= 1'b1;
            s_axi_wdata   <= data;
            s_axi_wvalid  <= 1'b1;
            
            wait(s_axi_awready && s_axi_wready);
            @(posedge clk);
            s_axi_awvalid <= 1'b0;
            s_axi_wvalid  <= 1'b0;
            
            wait(s_axi_bvalid);
            @(posedge clk);
        end
    endtask

    // =========================================================================
    // Main Test Sequence
    // =========================================================================
    initial begin
        $display("=========================================================");
        $display("   TinyNPU SystemVerilog Testbench Start");
        $display("=========================================================");
        
        wait(rst_n == 1);
        #100;

        // Start NPU
        axi_write(32'h14, 32'h00000108); // Kernel=8, stride=1, padding=0, Relu
        axi_write(32'h18, 32'h00010001); // in=1, out=1
        axi_write(32'h1C, 32'h00080008); // W=8, H=8
        
        axi_write(32'h00, 32'h00000001); // Start NPU (Ctrl reg, bit 0)

        // Wait for all frames to be processed by sensor emulator
        wait(all_done == 1'b1);
        #1000;

        $display("=========================================================");
        $display("   Test Finished. Review SVA and Scoreboard Output.");
        if (sb_fail) $display("   STATUS: FAILED");
        else         $display("   STATUS: PASSED");
        $display("=========================================================");
        
        $finish;
    end

endmodule
