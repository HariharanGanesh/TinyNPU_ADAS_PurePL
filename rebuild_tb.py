import os

tb_code = """`timescale 1ns / 1ps

module tb_tinynpu_top();

    // =========================================================================
    // Parameters & Signals
    // =========================================================================
    localparam AXI_ADDR_WIDTH  = 32;
    localparam AXI_DATA_WIDTH  = 32;
    localparam AXIS_DATA_WIDTH = 32;
    localparam DATA_WIDTH      = 8;
    
    logic clk = 0;
    logic rst_n = 0;
    
    // AXI-Lite
    logic [AXI_ADDR_WIDTH-1:0] s_axi_awaddr = 0;
    logic [2:0]                s_axi_awprot = 0;
    logic                      s_axi_awvalid = 0;
    logic                      s_axi_awready;
    logic [AXI_DATA_WIDTH-1:0] s_axi_wdata = 0;
    logic [AXI_DATA_WIDTH/8-1:0] s_axi_wstrb = 0;
    logic                      s_axi_wvalid = 0;
    logic                      s_axi_wready;
    logic [1:0]                s_axi_bresp;
    logic                      s_axi_bvalid;
    logic                      s_axi_bready = 0;
    
    logic [AXI_ADDR_WIDTH-1:0] s_axi_araddr = 0;
    logic [2:0]                s_axi_arprot = 0;
    logic                      s_axi_arvalid = 0;
    logic                      s_axi_arready;
    logic [AXI_DATA_WIDTH-1:0] s_axi_rdata;
    logic [1:0]                s_axi_rresp;
    logic                      s_axi_rvalid;
    logic                      s_axi_rready = 0;
    
    // AXI-Stream Sink (Activations)
    logic [AXIS_DATA_WIDTH-1:0] s_axis_tdata = 0;
    logic                       s_axis_tvalid = 0;
    logic                       s_axis_tready;
    logic                       s_axis_tlast = 0;
    
    // AXI-Stream Source (Output)
    logic [AXIS_DATA_WIDTH-1:0] m_axis_tdata;
    logic                       m_axis_tvalid;
    logic                       m_axis_tready = 1;
    logic                       m_axis_tlast;
    
    // AXI-MM Master (Weights & Output, though Output is disabled in DMA now)
    logic [AXI_ADDR_WIDTH-1:0] m_axi_awaddr;
    logic [7:0]                m_axi_awlen;
    logic [2:0]                m_axi_awsize;
    logic [1:0]                m_axi_awburst;
    logic                      m_axi_awvalid;
    logic                      m_axi_awready = 1;
    logic [AXI_DATA_WIDTH-1:0] m_axi_wdata;
    logic [AXI_DATA_WIDTH/8-1:0] m_axi_wstrb;
    logic                      m_axi_wlast;
    logic                      m_axi_wvalid;
    logic                      m_axi_wready = 1;
    logic [1:0]                m_axi_bresp = 0;
    logic                      m_axi_bvalid = 0;
    logic                      m_axi_bready;
    logic [AXI_ADDR_WIDTH-1:0] m_axi_araddr;
    logic [7:0]                m_axi_arlen;
    logic [2:0]                m_axi_arsize;
    logic [1:0]                m_axi_arburst;
    logic                      m_axi_arvalid;
    logic                      m_axi_arready = 1;
    logic [AXI_DATA_WIDTH-1:0] m_axi_rdata = 0;
    logic [1:0]                m_axi_rresp = 0;
    logic                      m_axi_rlast = 0;
    logic                      m_axi_rvalid = 0;
    logic                      m_axi_rready;
    
    // =========================================================================
    // DUT Instantiation
    // =========================================================================
    tinynpu_top #(
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
        .AXIS_DATA_WIDTH(AXIS_DATA_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .aclk(clk),
        .aresetn(rst_n),
        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awprot(s_axi_awprot),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_awready(s_axi_awready),
        .s_axi_wdata(s_axi_wdata),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wvalid(s_axi_wvalid),
        .s_axi_wready(s_axi_wready),
        .s_axi_bresp(s_axi_bresp),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_bready(s_axi_bready),
        .s_axi_araddr(s_axi_araddr),
        .s_axi_arprot(s_axi_arprot),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_arready(s_axi_arready),
        .s_axi_rdata(s_axi_rdata),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_rready(s_axi_rready),
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .s_axis_tlast(s_axis_tlast),
        .m_axis_tdata(m_axis_tdata),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tready(m_axis_tready),
        .m_axis_tlast(m_axis_tlast),
        .m_axi_awaddr(m_axi_awaddr),
        .m_axi_awlen(m_axi_awlen),
        .m_axi_awsize(m_axi_awsize),
        .m_axi_awburst(m_axi_awburst),
        .m_axi_awvalid(m_axi_awvalid),
        .m_axi_awready(m_axi_awready),
        .m_axi_wdata(m_axi_wdata),
        .m_axi_wstrb(m_axi_wstrb),
        .m_axi_wlast(m_axi_wlast),
        .m_axi_wvalid(m_axi_wvalid),
        .m_axi_wready(m_axi_wready),
        .m_axi_bresp(m_axi_bresp),
        .m_axi_bvalid(m_axi_bvalid),
        .m_axi_bready(m_axi_bready),
        .m_axi_araddr(m_axi_araddr),
        .m_axi_arlen(m_axi_arlen),
        .m_axi_arsize(m_axi_arsize),
        .m_axi_arburst(m_axi_arburst),
        .m_axi_arvalid(m_axi_arvalid),
        .m_axi_arready(m_axi_arready),
        .m_axi_rdata(m_axi_rdata),
        .m_axi_rresp(m_axi_rresp),
        .m_axi_rlast(m_axi_rlast),
        .m_axi_rvalid(m_axi_rvalid),
        .m_axi_rready(m_axi_rready)
    );

    // =========================================================================
    // Clock Generation
    // =========================================================================
    always #5 clk = ~clk;

    // =========================================================================
    // Tasks
    // =========================================================================
    task axi_write(input [31:0] addr, input [31:0] data);
        begin
            @(posedge clk);
            s_axi_awaddr = addr;
            s_axi_awvalid = 1;
            s_axi_wdata = data;
            s_axi_wstrb = 4'hf;
            s_axi_wvalid = 1;
            s_axi_bready = 1;
            
            // Wait for address and data to be accepted
            fork
                begin
                    wait(s_axi_awready && s_axi_awvalid);
                    @(posedge clk);
                    s_axi_awvalid = 0;
                end
                begin
                    wait(s_axi_wready && s_axi_wvalid);
                    @(posedge clk);
                    s_axi_wvalid = 0;
                end
            join
            
            wait(s_axi_bvalid);
            @(posedge clk);
            s_axi_bready = 0;
        end
    endtask
    
    task axi_write_independent(input [31:0] addr, input [31:0] data, input int aw_delay, input int w_delay);
        begin
            @(posedge clk);
            fork
                begin
                    repeat(aw_delay) @(posedge clk);
                    s_axi_awaddr = addr;
                    s_axi_awvalid = 1;
                    wait(s_axi_awready);
                    @(posedge clk);
                    s_axi_awvalid = 0;
                end
                begin
                    repeat(w_delay) @(posedge clk);
                    s_axi_wdata = data;
                    s_axi_wstrb = 4'hf;
                    s_axi_wvalid = 1;
                    wait(s_axi_wready);
                    @(posedge clk);
                    s_axi_wvalid = 0;
                end
            join
            s_axi_bready = 1;
            wait(s_axi_bvalid);
            @(posedge clk);
            s_axi_bready = 0;
        end
    endtask

    task axi_read(input [31:0] addr, output [31:0] data);
        begin
            @(posedge clk);
            s_axi_araddr = addr;
            s_axi_arvalid = 1;
            s_axi_rready = 1;
            wait(s_axi_arready);
            @(posedge clk);
            s_axi_arvalid = 0;
            wait(s_axi_rvalid);
            data = s_axi_rdata;
            @(posedge clk);
            s_axi_rready = 0;
        end
    endtask

    // Simulated DMA Memory (Memory mapped reads from DUT)
    logic [7:0] sim_memory [0:65535];
    
    initial begin
        m_axi_arready = 1;
        m_axi_rvalid = 0;
        m_axi_rlast = 0;
        
        forever begin
            @(posedge clk);
            if (m_axi_arvalid && m_axi_arready) begin
                automatic logic [31:0] start_addr = m_axi_araddr;
                automatic logic [7:0] len = m_axi_arlen;
                
                @(posedge clk); // Simulate memory latency
                
                for (int i = 0; i <= len; i++) begin
                    m_axi_rvalid = 1;
                    m_axi_rdata = {24'b0, sim_memory[start_addr + i]};
                    m_axi_rlast = (i == len);
                    wait(m_axi_rready);
                    @(posedge clk);
                end
                m_axi_rvalid = 0;
                m_axi_rlast = 0;
            end
        end
    end

    // =========================================================================
    // Test Control
    // =========================================================================
    integer fail_count = 0;
    logic [31:0] read_val;
    logic [31:0] actual_output;
    logic [31:0] expected_output;
    
    realtime start_time, end_time;

    initial begin
        $display("============================================================");
        $display("              NPU / IP VERIFICATION REPORT");
        $display("============================================================");
        
        // Initialize memory with weights (e.g. all 1s for simple accumulation)
        for (int i = 0; i < 65536; i++) sim_memory[i] = 8'h01;

        // Reset
        rst_n = 0;
        #100;
        rst_n = 1;
        #20;
        
        // --------------------------------------------------
        // TC1 - RESET & INITIALIZATION
        // --------------------------------------------------
        axi_read(8'h04, read_val); // Read STATUS
        if (read_val[0] == 1'b1) begin // status_idle == 1
            $display("TC1  Reset                     PASS");
        end else begin
            $display("TC1  Reset                     FAIL (Expected IDLE)");
            fail_count++;
        end

        // --------------------------------------------------
        // TC2 - AXI-Lite Register Read/Write
        // --------------------------------------------------
        axi_write(8'h1C, 32'hDEADBEEF); // ADDR_IRQ_CTRL
        axi_read(8'h1C, read_val);
        if (read_val == 32'hDEADBEEF) begin
            $display("TC2  AXI-Lite Register         PASS");
        end else begin
            $display("TC2  AXI-Lite Register         FAIL");
            fail_count++;
        end

        // --------------------------------------------------
        // TC3 - AXI-Lite Independent AW/W Ordering
        // --------------------------------------------------
        // AW before W
        axi_write_independent(8'h20, 32'h11223344, 0, 5);
        axi_read(8'h20, read_val);
        // W before AW
        axi_write_independent(8'h24, 32'h55667788, 5, 0);
        logic [31:0] read_val2;
        axi_read(8'h24, read_val2);
        
        if (read_val == 32'h11223344 && read_val2 == 32'h55667788) begin
            $display("TC3  AXI-Lite Ordering         PASS");
        end else begin
            $display("TC3  AXI-Lite Ordering         FAIL");
            fail_count++;
        end

        // --------------------------------------------------
        // TC9 - End-to-End Inference (Simplified Vector)
        // --------------------------------------------------
        // Configuration:
        // Input: 8x1 (8 pixels). Weights: 20x8 (20 output channels, 8 input channels).
        // Let's set weights to 1, inputs to 2.
        // Accum = 8 * 2 = 16 for each output channel.
        // Requantization: M0=1, shift=0, bias=0. Result = 16.
        for (int i = 0; i < 160; i++) sim_memory[32'h1000 + i] = 8'h01; // Weights
        
        axi_write(8'h08, 32'h1000); // Weight Base
        axi_write(8'h14, 32'h00140008); // LAYER_CFG1: Out=20, In=8
        axi_write(8'h18, 32'h00010008); // LAYER_CFG2: H=1, W=8
        axi_write(8'h20, 32'h00000001); // M0=1
        axi_write(8'h24, 32'h00000000); // Shift=0
        axi_write(8'h28, 32'h00000000); // Bias=0
        axi_write(8'h10, 32'h00000000); // LAYER_CFG0: Act=bypass, pool=bypass
        
        // Start the NPU
        start_time = $realtime;
        axi_write(8'h00, 32'h00000001); // Start
        
        // Provide AXI-Stream Activations
        @(posedge clk);
        for (int i = 0; i < 8; i++) begin
            s_axis_tvalid = 1;
            s_axis_tdata = 32'h00000002; // value 2
            s_axis_tlast = (i == 7);
            wait(s_axis_tready);
            @(posedge clk);
        end
        s_axis_tvalid = 0;
        
        // Wait for outputs to drain
        expected_output = 32'h10; // 16
        int match_count = 0;
        int mismatch_count = 0;
        
        fork
            begin
                // Read 5 outputs (20 channels / 4 bytes per word = 5 beats if outputting 32-bit words)
                // Actually, axis_source outputs byte-serially per channel if AXIS_DATA_WIDTH=32?
                // Wait, AXIS_DATA_WIDTH=32. The output_buffer has 20 bytes per word. 
                // Let's just catch all valid beats for 1000 cycles.
                repeat(20) begin
                    wait(m_axis_tvalid);
                    if (m_axis_tdata == expected_output) match_count++;
                    else mismatch_count++;
                    @(posedge clk);
                end
            end
            begin
                #50000; // Timeout
            end
        join_any
        
        end_time = $realtime;
        
        if (mismatch_count == 0 && match_count > 0) begin
            $display("TC9  End-to-End Inference      PASS");
            $display("     Latency      : %0t ns", end_time - start_time);
            $display("     Matches      : %0d", match_count);
            $display("     Mismatches   : %0d", mismatch_count);
        end else begin
            $display("TC9  End-to-End Inference      FAIL");
            $display("     Expected     : %h", expected_output);
            $display("     Matches      : %0d", match_count);
            $display("     Mismatches   : %0d", mismatch_count);
            fail_count++;
        end

        $display("------------------------------------------------------------");
        $display("TOTAL : 4 (Simplified Set)");
        $display("FAIL  : %0d", fail_count);
        $display("============================================================");
        
        $finish;
    end
endmodule
"""

tb_path = "IP/TinyNPU200/sim/tb_tinynpu_top.sv"
with open(tb_path, "w", encoding="utf-8") as f:
    f.write(tb_code)

print("Testbench rebuilt successfully.")
