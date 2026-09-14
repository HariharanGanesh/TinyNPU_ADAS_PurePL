`timescale 1ns / 1ps

module tb_soc_top;

    reg clk;
    reg rst_n;
    
    // Clocks
    initial begin
        clk = 0;
        forever #4 clk = ~clk; // 125 MHz
    end
    
    // Reset
    initial begin
        rst_n = 0;
        #100;
        rst_n = 1;
    end
    
    // ADAS Subsystem
    wire sw_brake_arm = 1'b1;
    wire out_warning_ped;
    wire out_warning_lane;
    wire out_warning_sign;
    wire out_brake_authorized;
    wire out_system_fault;
    
    // AXI4-Lite Interconnect (RISC-V Master -> NPU Slave)
    wire [31:0] axi_awaddr;
    wire [2:0]  axi_awprot;
    wire        axi_awvalid;
    wire        axi_awready;
    wire [31:0] axi_wdata;
    wire [3:0]  axi_wstrb;
    wire        axi_wvalid;
    wire        axi_wready;
    wire [1:0]  axi_bresp;
    wire        axi_bvalid;
    wire        axi_bready;
    wire [31:0] axi_araddr;
    wire [2:0]  axi_arprot;
    wire        axi_arvalid;
    wire        axi_arready;
    wire [31:0] axi_rdata;
    wire [1:0]  axi_rresp;
    wire        axi_rvalid;
    wire        axi_rready;
    
    riscv_adas_subsystem u_riscv (
        .clk(clk),
        .rst_n(rst_n),
        .sw_brake_arm(sw_brake_arm),
        .out_warning_ped(out_warning_ped),
        .out_warning_lane(out_warning_lane),
        .out_warning_sign(out_warning_sign),
        .out_brake_authorized(out_brake_authorized),
        .out_system_fault(out_system_fault),
        
        .m_axi_awvalid(axi_awvalid),
        .m_axi_awready(axi_awready),
        .m_axi_awaddr(axi_awaddr),
        .m_axi_awprot(axi_awprot),
        .m_axi_wvalid(axi_wvalid),
        .m_axi_wready(axi_wready),
        .m_axi_wdata(axi_wdata),
        .m_axi_wstrb(axi_wstrb),
        .m_axi_bvalid(axi_bvalid),
        .m_axi_bready(axi_bready),
        .m_axi_arvalid(axi_arvalid),
        .m_axi_arready(axi_arready),
        .m_axi_araddr(axi_araddr),
        .m_axi_arprot(axi_arprot),
        .m_axi_rvalid(axi_rvalid),
        .m_axi_rready(axi_rready),
        .m_axi_rdata(axi_rdata)
    );
    
    // TinyNPU
    // Dummy AXI Stream Master (Sensor)
    reg         s_axis_tvalid = 0;
    reg  [63:0] s_axis_tdata = 0;
    reg         s_axis_tlast = 0;
    wire        s_axis_tready;
    
    // Generate Sensor Data when NPU is ready
    always @(posedge clk) begin
        if (!rst_n) begin
            s_axis_tvalid <= 0;
            s_axis_tdata <= 0;
            s_axis_tlast <= 0;
        end else if (s_axis_tready) begin
            // Whenever NPU is ready, feed it some dummy data
            s_axis_tvalid <= 1;
            s_axis_tdata <= s_axis_tdata + 1; // Incrementing pattern
            // Don't assert tlast for this simple test, the NPU relies on its own counters
        end
    end
    
    // Dummy AXI Stream Slave (Output)
    wire        m_axis_tvalid;
    wire [63:0] m_axis_tdata;
    wire        m_axis_tlast;
    reg         m_axis_tready = 1;
    
    // Dummy AXI Full Master (DMA)
    wire [31:0] m_axi_awaddr_dma;
    wire [7:0]  m_axi_awlen;
    wire [2:0]  m_axi_awsize;
    wire [1:0]  m_axi_awburst;
    wire        m_axi_awvalid_dma;
    reg         m_axi_awready_dma = 1;
    wire [31:0] m_axi_wdata_dma;
    wire [3:0]  m_axi_wstrb_dma;
    wire        m_axi_wlast;
    wire        m_axi_wvalid_dma;
    reg         m_axi_wready_dma = 1;
    reg  [1:0]  m_axi_bresp_dma = 0;
    reg         m_axi_bvalid_dma = 0;
    wire        m_axi_bready_dma;
    
    wire [31:0] m_axi_araddr_dma;
    wire [7:0]  m_axi_arlen;
    wire [2:0]  m_axi_arsize;
    wire [1:0]  m_axi_arburst;
    wire        m_axi_arvalid_dma;
    reg         m_axi_arready_dma = 1;
    reg  [31:0] m_axi_rdata_dma = 0;
    reg  [1:0]  m_axi_rresp_dma = 0;
    reg         m_axi_rlast = 0;
    reg         m_axi_rvalid_dma = 0;
    wire        m_axi_rready_dma;
    
    tinynpu_top u_npu (
        .clk(clk),
        .rst_n(rst_n),
        
        .s_axi_awaddr(axi_awaddr),
        .s_axi_awprot(axi_awprot),
        .s_axi_awvalid(axi_awvalid),
        .s_axi_awready(axi_awready),
        .s_axi_wdata(axi_wdata),
        .s_axi_wstrb(axi_wstrb),
        .s_axi_wvalid(axi_wvalid),
        .s_axi_wready(axi_wready),
        .s_axi_bresp(axi_bresp),
        .s_axi_bvalid(axi_bvalid),
        .s_axi_bready(axi_bready),
        .s_axi_araddr(axi_araddr),
        .s_axi_arprot(axi_arprot),
        .s_axi_arvalid(axi_arvalid),
        .s_axi_arready(axi_arready),
        .s_axi_rdata(axi_rdata),
        .s_axi_rresp(axi_rresp),
        .s_axi_rvalid(axi_rvalid),
        .s_axi_rready(axi_rready),
        
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tlast(s_axis_tlast),
        .s_axis_tready(s_axis_tready),
        
        .m_axis_tdata(m_axis_tdata),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tlast(m_axis_tlast),
        .m_axis_tready(m_axis_tready),
        
        .m_axi_awaddr(m_axi_awaddr_dma),
        .m_axi_awlen(m_axi_awlen),
        .m_axi_awsize(m_axi_awsize),
        .m_axi_awburst(m_axi_awburst),
        .m_axi_awvalid(m_axi_awvalid_dma),
        .m_axi_awready(m_axi_awready_dma),
        .m_axi_wdata(m_axi_wdata_dma),
        .m_axi_wstrb(m_axi_wstrb_dma),
        .m_axi_wlast(m_axi_wlast),
        .m_axi_wvalid(m_axi_wvalid_dma),
        .m_axi_wready(m_axi_wready_dma),
        .m_axi_bresp(m_axi_bresp_dma),
        .m_axi_bvalid(m_axi_bvalid_dma),
        .m_axi_bready(m_axi_bready_dma),
        .m_axi_araddr(m_axi_araddr_dma),
        .m_axi_arlen(m_axi_arlen),
        .m_axi_arsize(m_axi_arsize),
        .m_axi_arburst(m_axi_arburst),
        .m_axi_arvalid(m_axi_arvalid_dma),
        .m_axi_arready(m_axi_arready_dma),
        .m_axi_rdata(m_axi_rdata_dma),
        .m_axi_rresp(m_axi_rresp_dma),
        .m_axi_rlast(m_axi_rlast),
        .m_axi_rvalid(m_axi_rvalid_dma),
        .m_axi_rready(m_axi_rready_dma),
        
        .interrupt()
    );
    
    // Provide DMA write responses
    always @(posedge clk) begin
        if (m_axi_wvalid_dma && m_axi_wready_dma && m_axi_wlast) begin
            m_axi_bvalid_dma <= 1;
        end else if (m_axi_bready_dma) begin
            m_axi_bvalid_dma <= 0;
        end
    end
    
    // Provide DMA read responses
    always @(posedge clk) begin
        if (m_axi_arvalid_dma && m_axi_arready_dma) begin
            m_axi_rvalid_dma <= 1;
            m_axi_rlast <= 1;
            // Dummy weight data
            m_axi_rdata_dma <= 32'h01010101; 
        end else if (m_axi_rready_dma) begin
            m_axi_rvalid_dma <= 0;
            m_axi_rlast <= 0;
        end
    end

    initial begin
        $display("========================================");
        $display("   RISCV ADAS NPU SYSTEM SIMULATION     ");
        $display("========================================");
        #10000;
        $display("Simulation timeout.");
        $finish;
    end

endmodule
