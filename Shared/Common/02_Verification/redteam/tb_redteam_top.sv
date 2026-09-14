`timescale 1ns / 1ps

module tb_redteam_top();

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
    logic [7:0]  s_axis_tdata = 0;
    logic        s_axis_tvalid = 0;
    wire         s_axis_tready;
    logic        s_axis_tlast = 0;

    // AXI-Stream Output (Results)
    wire [7:0]   m_axis_tdata;
    wire         m_axis_tvalid;
    logic        m_axis_tready = 1;
    wire         m_axis_tlast;

    // AXI4-Full (DMA Master)
    wire [31:0]  m_axi_araddr;
    wire [7:0]   m_axi_arlen;
    wire         m_axi_arvalid;
    logic        m_axi_arready = 0;
    logic [31:0] m_axi_rdata = 0;
    logic [1:0]  m_axi_rresp = 0;
    logic        m_axi_rlast = 0;
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
        .s_axi_awaddr(s_axi_awaddr), .s_axi_awprot(3'b0), .s_axi_awvalid(s_axi_awvalid), .s_axi_awready(s_axi_awready),
        .s_axi_wdata(s_axi_wdata), .s_axi_wstrb(4'hF), .s_axi_wvalid(s_axi_wvalid), .s_axi_wready(s_axi_wready),
        .s_axi_bresp(s_axi_bresp), .s_axi_bvalid(s_axi_bvalid), .s_axi_bready(s_axi_bready),
        .s_axi_araddr(s_axi_araddr), .s_axi_arprot(3'b0), .s_axi_arvalid(s_axi_arvalid), .s_axi_arready(s_axi_arready),
        .s_axi_rdata(s_axi_rdata), .s_axi_rresp(s_axi_rresp), .s_axi_rvalid(s_axi_rvalid), .s_axi_rready(s_axi_rready),
        
        .m_axi_awaddr(m_axi_awaddr), .m_axi_awlen(m_axi_awlen), .m_axi_awsize(), .m_axi_awburst(), .m_axi_awvalid(m_axi_awvalid), .m_axi_awready(m_axi_awready),
        .m_axi_wdata(m_axi_wdata), .m_axi_wstrb(), .m_axi_wlast(m_axi_wlast), .m_axi_wvalid(m_axi_wvalid), .m_axi_wready(m_axi_wready),
        .m_axi_bresp(m_axi_bresp), .m_axi_bvalid(m_axi_bvalid), .m_axi_bready(m_axi_bready),
        
        .m_axi_araddr(m_axi_araddr), .m_axi_arlen(m_axi_arlen), .m_axi_arsize(), .m_axi_arburst(), .m_axi_arvalid(m_axi_arvalid), .m_axi_arready(m_axi_arready),
        .m_axi_rdata(m_axi_rdata), .m_axi_rresp(m_axi_rresp), .m_axi_rlast(m_axi_rlast), .m_axi_rvalid(m_axi_rvalid), .m_axi_rready(m_axi_rready),
        
        .s_axis_tdata(s_axis_tdata), .s_axis_tvalid(s_axis_tvalid), .s_axis_tready(s_axis_tready), .s_axis_tlast(s_axis_tlast),
        .m_axis_tdata(m_axis_tdata), .m_axis_tvalid(m_axis_tvalid), .m_axis_tready(m_axis_tready), .m_axis_tlast(m_axis_tlast),
        .interrupt(interrupt)
    );

    // =========================================================================
    // AXI RAM Emulator for Weights
    // =========================================================================
    reg [31:0] dram_wgt_mem [0:511];
    
    initial begin
        $readmemh("vectors/redteam_adv_wgt_mem.hex", dram_wgt_mem);
    end

    reg [31:0] axi_rd_addr;
    reg [7:0]  axi_rd_len;
    reg [7:0]  axi_rd_count;
    
        // Simple AXI Write FSM
    always @(posedge clk) begin
        if (!rst_n) begin
            m_axi_awready <= 1'b1;
            m_axi_wready  <= 1'b1;
            m_axi_bvalid  <= 1'b0;
        end else begin
            // Accept write addresses
            if (m_axi_awvalid && m_axi_awready) begin
                m_axi_awready <= 1'b0;
            end
            // Accept write data
            if (m_axi_wvalid && m_axi_wready) begin
                if (m_axi_wlast) begin
                    m_axi_wready <= 1'b0;
                    m_axi_bvalid <= 1'b1; $display("TB: AXI Write Complete");
                end
            end
            // Send response
            if (m_axi_bvalid && m_axi_bready) begin
                m_axi_bvalid  <= 1'b0;
                m_axi_awready <= 1'b1;
                m_axi_wready  <= 1'b1;
            end
        end
    end

    // Simple AXI Read FSM
    always @(posedge clk) begin
        if (!rst_n) begin
            m_axi_arready <= 1'b1;
            m_axi_rvalid  <= 1'b0;
            m_axi_rlast   <= 1'b0;
        end else begin
            if (m_axi_arready && m_axi_arvalid) begin
                m_axi_arready <= 1'b0;
                axi_rd_addr   <= m_axi_araddr;
                axi_rd_len    <= m_axi_arlen;
                axi_rd_count  <= 0;
                m_axi_rvalid  <= 1'b1;
                m_axi_rlast   <= (m_axi_arlen == 0) ? 1'b1 : 1'b0;
                // Word address
                m_axi_rdata   <= dram_wgt_mem[(m_axi_araddr >> 2)];
            end else if (m_axi_rvalid && m_axi_rready) begin
                $display("TB: AXI Read Data = %h at addr = %h", m_axi_rdata, axi_rd_addr);
                if (axi_rd_count == axi_rd_len) begin
                    m_axi_rvalid  <= 1'b0;
                    m_axi_rlast   <= 1'b0;
                    m_axi_arready <= 1'b1;
                end else begin
                    axi_rd_count <= axi_rd_count + 1'b1;
                    axi_rd_addr  <= axi_rd_addr + 4;
                    m_axi_rdata  <= dram_wgt_mem[((axi_rd_addr + 4) >> 2)];
                    m_axi_rlast  <= (axi_rd_count + 1'b1 == axi_rd_len) ? 1'b1 : 1'b0;
                end
            end
        end
    end

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
    // Adversarial Testing Control
    // =========================================================================
    reg [7:0] act_mem [0:63];
    reg [7:0] exp_mem [0:63];
    
    initial begin
        $readmemh("vectors/redteam_adv_act_stream.hex", act_mem);
        $readmemh("vectors/redteam_adv_expected_out.hex", exp_mem);
    end

    // Stream inputs in
    task send_frame();
        int i;
        begin
            for (i=0; i<64; i++) begin
                @(posedge clk);
                s_axis_tvalid <= 1'b1;
                s_axis_tdata  <= act_mem[i];
                s_axis_tlast  <= (i == 63);
                wait(s_axis_tready);
            end
            @(posedge clk);
            s_axis_tvalid <= 1'b0;
            s_axis_tlast  <= 1'b0;
        end
    endtask

    // =========================================================================
    // Output Checking (Hostile Backpressure)
    // =========================================================================
    int errors = 0;
    int received = 0;
    reg [31:0] total_received;
    initial total_received = 0;

    always @(posedge clk) begin
        if (!rst_n) begin
            received <= 0;
            errors   <= 0;
        end else begin
            // Hostile Backpressure: toggle m_axis_tready randomly
            m_axis_tready <= ($urandom() % 100) > 30; // 30% chance of stall
            
            if (m_axis_tvalid && m_axis_tready) begin
                if (total_received >= 64) begin // Ignore first 64 bytes (dummy pass)
                    if (m_axis_tdata !== exp_mem[received]) begin
                        $display("[RED-TEAM] ERROR at index %0d: Expected %02x, Got %02x", received, exp_mem[received], m_axis_tdata);
                        errors++;
                    end else begin
                        $display("[RED-TEAM] MATCH at index %0d: %02x", received, m_axis_tdata);
                    end
                    received++;
                end else begin
                    $display("[RED-TEAM] DUMMY output byte %0d: %02x", total_received, m_axis_tdata);
                end
                total_received++;
            end
        end
    end

    // =========================================================================
    // Main Test Sequence
    // =========================================================================
    initial begin
        $display("=========================================================");
        $display("   TinyNPU Red-Team Adversarial Testbench Start");
        $display("=========================================================");
        
        wait(rst_n == 1);
        #100;

        // Load weights via DMA
        axi_write(32'h08, 32'h0000_0000); // WEIGHT_BASE = 0x0
        
        axi_write(32'h00, 32'h0000_0002); // Start weight load (bit 1)
        axi_write(32'h14, 32'h0000_0108); // Kernel=8, stride=1, padding=0, Relu
        axi_write(32'h18, 32'h0001_0001); // in=1, out=1
        axi_write(32'h1C, 32'h0008_0008); // W=8, H=8
        
        // Requantization Config
        axi_write(32'h2C, 32'h7FFFFFFF); // M0
        axi_write(32'h30, 32'h0000001E); // n_shift = 30
        
        // Disable threshold filter so we get outputs
        axi_write(32'h48, 32'h00000000); // CONF_THRESHOLD = 0
        
        // To prime the weights into Bank 0, we must run a dummy pass with bank_sel=1.
        // This will cause DMA to write to Bank 0, and Compute to read from Bank 1 (garbage).
        axi_write(32'h00, 32'h00000011); // Start NPU (Ctrl reg, bit 0=1, bit 4=1)
        
        // Wait for the dummy pass to finish (it will output 64 bytes of garbage)
        wait(total_received == 64);
        #500;
        
        // Now set bank_sel=0 and send the actual frame.
        // This will cause Compute to read from Bank 0 (which has our valid weights),
        // and DMA to write to Bank 1 (which we don't care about).
        axi_write(32'h00, 32'h00000000); // Clear ctrl reg
        
        send_frame();
        
        // Start the NPU again. This sets status_idle=0, which causes testbench axis_source
        // to send the second frame (the actual adversarial data).
        axi_write(32'h00, 32'h00000001); // Start NPU (Ctrl reg, bit 0=1)
        
        wait(received == 64);
        #500;

        $display("=========================================================");
        $display("   Test Finished.");
        $display("   Errors: %0d / 64", errors);
        if (errors > 0) $display("   STATUS: FAILED");
        else            $display("   STATUS: PASSED");
        $display("=========================================================");
        
        $finish;
    end

endmodule

