`timescale 1ns/1ps

module tb_top_integration;
    parameter AXI_ADDR_WIDTH  = 32;
    parameter AXI_DATA_WIDTH  = 32;
    parameter AXIS_DATA_WIDTH = 32;

    logic aclk;
    logic aresetn;

    // AXI4-Lite Slave Interface
    logic [AXI_ADDR_WIDTH-1:0]    s_axi_awaddr;
    logic [2:0]                   s_axi_awprot;
    logic                         s_axi_awvalid;
    logic                         s_axi_awready;
    logic [AXI_DATA_WIDTH-1:0]    s_axi_wdata;
    logic [AXI_DATA_WIDTH/8-1:0]  s_axi_wstrb;
    logic                         s_axi_wvalid;
    logic                         s_axi_wready;
    logic [1:0]                   s_axi_bresp;
    logic                         s_axi_bvalid;
    logic                         s_axi_bready;
    logic [AXI_ADDR_WIDTH-1:0]    s_axi_araddr;
    logic [2:0]                   s_axi_arprot;
    logic                         s_axi_arvalid;
    logic                         s_axi_arready;
    logic [AXI_DATA_WIDTH-1:0]    s_axi_rdata;
    logic [1:0]                   s_axi_rresp;
    logic                         s_axi_rvalid;
    logic                         s_axi_rready;

    // AXI4-Full Master Interface
    logic [AXI_ADDR_WIDTH-1:0]    m_axi_awaddr;
    logic [7:0]                   m_axi_awlen;
    logic [2:0]                   m_axi_awsize;
    logic [1:0]                   m_axi_awburst;
    logic                         m_axi_awvalid;
    logic                         m_axi_awready;
    logic [AXI_DATA_WIDTH-1:0]    m_axi_wdata;
    logic [AXI_DATA_WIDTH/8-1:0]  m_axi_wstrb;
    logic                         m_axi_wlast;
    logic                         m_axi_wvalid;
    logic                         m_axi_wready;
    logic [1:0]                   m_axi_bresp;
    logic                         m_axi_bvalid;
    logic                         m_axi_bready;
    logic [AXI_ADDR_WIDTH-1:0]    m_axi_araddr;
    logic [7:0]                   m_axi_arlen;
    logic [2:0]                   m_axi_arsize;
    logic [1:0]                   m_axi_arburst;
    logic                         m_axi_arvalid;
    logic                         m_axi_arready;
    logic [AXI_DATA_WIDTH-1:0]    m_axi_rdata;
    logic [1:0]                   m_axi_rresp;
    logic                         m_axi_rlast;
    logic                         m_axi_rvalid;
    logic                         m_axi_rready;

    // AXI4-Stream Sink Interface
    logic [AXIS_DATA_WIDTH-1:0]   s_axis_tdata;
    logic                         s_axis_tvalid;
    logic                         s_axis_tready;
    logic                         s_axis_tlast;

    // AXI4-Stream Source Interface
    logic [AXIS_DATA_WIDTH-1:0]   m_axis_tdata;
    logic                         m_axis_tvalid;
    logic                         m_axis_tready;
    logic                         m_axis_tlast;

    logic vid_locked_in;
    logic [31:0] tile_count_in;
    logic interrupt;

    tinynpu_top #(
        .AXI_ADDR_WIDTH(32),
        .AXI_DATA_WIDTH(32),
        .AXIS_DATA_WIDTH(32),
        .DATA_WIDTH(8),
        .ACCUM_WIDTH(32),
        .SCALE_WIDTH(32),
        .SHIFT_WIDTH(6),
        .ARRAY_ROWS(20),
        .ARRAY_COLS(8),
        .BUFFER_DEPTH(1024),
        .BUFFER_ADDR_WIDTH(10),
        .MAX_WIDTH(128),
        .TILE_SIZE(160)
    ) dut (
        .aclk(aclk),
        .aresetn(aresetn),
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
        .m_axi_rready(m_axi_rready),
        
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .s_axis_tlast(s_axis_tlast),
        
        .m_axis_tdata(m_axis_tdata),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tready(m_axis_tready),
        .m_axis_tlast(m_axis_tlast),
        
        .vid_locked_in(vid_locked_in),
        .tile_count_in(tile_count_in),
        .interrupt(interrupt)
    );

    // Clock
    always #5 aclk = ~aclk;

    // AXI4-Lite Write Task
    task axi_write(input logic [31:0] addr, input logic [31:0] data);
        @(posedge aclk);
        s_axi_awaddr = addr;
        s_axi_awvalid = 1;
        s_axi_wdata = data;
        s_axi_wstrb = 4'hF;
        s_axi_wvalid = 1;
        
        fork
            begin
                wait(s_axi_awready);
                @(posedge aclk);
                s_axi_awvalid = 0;
            end
            begin
                wait(s_axi_wready);
                @(posedge aclk);
                s_axi_wvalid = 0;
            end
        join
        
        s_axi_bready = 1;
        wait(s_axi_bvalid);
        @(posedge aclk);
        s_axi_bready = 0;
    endtask

    // Memory Model for DMA
    logic [7:0] mem [0:65535];
    int mem_read_ptr = 0;
    logic [7:0] m_axi_arlen_cnt;
    
    initial begin
        // Initialize mem with some weights (e.g. all 1s)
        for(int i=0; i<65536; i++) mem[i] = 1;
        
        m_axi_arready = 0;
        m_axi_rvalid = 0;
        m_axi_rdata = 0;
        m_axi_rlast = 0;
        
        m_axi_awready = 1;
        m_axi_wready = 1;
        m_axi_bvalid = 0;
        
        forever begin
            @(posedge aclk);
            if (m_axi_arvalid && !m_axi_arready) begin
                m_axi_arready = 1;
                mem_read_ptr = m_axi_araddr;
                m_axi_arlen_cnt = m_axi_arlen;
            end else if (m_axi_arready) begin
                m_axi_arready = 0;
                
                for(int i=0; i<=m_axi_arlen_cnt; i++) begin
                    m_axi_rvalid = 1;
                    m_axi_rdata = {mem[mem_read_ptr+3], mem[mem_read_ptr+2], mem[mem_read_ptr+1], mem[mem_read_ptr]};
                    m_axi_rlast = (i == m_axi_arlen_cnt);
                    wait(m_axi_rready);
                    @(posedge aclk);
                    mem_read_ptr += 4;
                end
                m_axi_rvalid = 0;
                m_axi_rlast = 0;
            end
            
            if (m_axi_awvalid) m_axi_awready = 1;
            if (m_axi_wvalid && m_axi_wlast) begin
                @(posedge aclk);
                m_axi_bvalid = 1;
                wait(m_axi_bready);
                @(posedge aclk);
                m_axi_bvalid = 0;
            end
        end
    end

    // Test sequence
    initial begin
        aclk = 0;
        aresetn = 0;
        s_axi_awaddr = 0; s_axi_awvalid = 0; s_axi_wdata = 0; s_axi_wstrb = 0; s_axi_wvalid = 0; s_axi_bready = 0;
        s_axi_araddr = 0; s_axi_arvalid = 0; s_axi_rready = 0;
        s_axis_tdata = 0; s_axis_tvalid = 0; s_axis_tlast = 0;
        m_axis_tready = 1;
        vid_locked_in = 1; tile_count_in = 0;

        #100 aresetn = 1;
        #100;
        
        // 1. Configure via AXI4-Lite CSR
        axi_write(32'h08, 32'h1000); // WEIGHT_BASE
        axi_write(32'h14, 32'h00000002); // LAYER_CFG_0 (e.g. tiles = 2)
        axi_write(32'h60, 32'h00000014); // ARRAY_ROWS = 20
        axi_write(32'h80, 32'h00000002); // NUM_TILES = 2
        
        // Setup quantization: M0=1, N_SHIFT=0, BIAS=5
        axi_write(32'h2C, 32'h00000001); // M0 = 1
        axi_write(32'h30, 32'h00000000); // N_SHIFT = 0
        axi_write(32'h34, 32'h00000005); // BIAS = 5
        
        axi_write(32'h00, 32'h01); // Start (CTRL[0]=1)
        
        // Wait for weight load to finish (DMA reads from our memory model)
        // Since dummy_weights are all 0, weights = 0.
        // Psum = 0 * act = 0. Output = (0 * 1 >> 0) + 5 = 5.
        // So expected m_axis_tdata = 0x05050505
        
        #1000;
        s_axis_tvalid = 1;
        s_axis_tdata = 32'h01010101; // Send dummy activations
        
        for (int i=0; i<160; i++) begin
            s_axis_tlast = (i == 159);
            @(posedge aclk);
            wait(s_axis_tready);
        end
        s_axis_tvalid = 0;
        s_axis_tlast = 0;
        
        // Wait for some output and verify bit-exactly
        wait(m_axis_tvalid);
        @(posedge aclk);
        
        if (m_axis_tdata === 32'h05050505) begin
            $display("TB_RESULT: PASS");
        end else begin
            $display("TB_RESULT: FAIL - Expected 05050505, Got %h", m_axis_tdata);
        end
        
        $finish;
    end
endmodule