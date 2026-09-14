// -----------------------------------------------------------------------------
// IEEE Transactions on VLSI Systems - Reference Design
// -----------------------------------------------------------------------------
// File        : tinynpu_fpga_wrapper.v
// Description : Xilinx FPGA-specific wrapper for TinyNPU targeting PYNQ-Z2
//               (XC7Z020CLG400-1).
//
// Architecture Note (3-Layer Integration):
// This file represents the platform-specific integration layer (Layer 3) that 
// sits above the technology-independent TinyNPU core (Layer 2). 
//
// Why this architecture?
// 1. Core Portability: By keeping all FPGA primitives (like BUFGCE) out of 
//    `tinynpu_top`, the core RTL remains completely portable across varying 
//    technologies (FPGA/ASIC).
// 2. Clear Boundaries: Clock and reset synchronization logic is inherently 
//    platform-dependent. The Zynq PS (Processing System) provides a global 
//    reset and clock, which requires specialized handling for setup/hold and 
//    fanout in the Programmable Logic (PL).
// 3. Easy Migration: To migrate this design to an ASIC flow, one simply drops
//    this file and substitutes `tinynpu_asic_wrapper.v` without modifying the 
//    proven TinyNPU core.
// -----------------------------------------------------------------------------

`timescale 1ns/1ps

module tinynpu_fpga_wrapper #(
    parameter AXI_DATA_WIDTH = 64,
    parameter AXI_ADDR_WIDTH = 32,
    parameter AXI_ID_WIDTH   = 4,
    parameter ARRAY_SIZE     = 16,
    parameter AXIS_DATA_WIDTH = 32,
    parameter DATA_WIDTH     = 8,
    parameter ACC_WIDTH      = 32
)(
    // -------------------------------------------------------------------------
    // Zynq PS Clocks and Resets
    // -------------------------------------------------------------------------
    input  wire                        clk,           // PL Fabric Clock from PS (FCLK_CLK0)
    input  wire                        rst_n,         // PL Reset from PS (FCLK_RESET0_N)
    
    // -------------------------------------------------------------------------
    // AXI-Lite Slave Interface (Control/Status)
    // -------------------------------------------------------------------------
    input  wire [AXI_ADDR_WIDTH-1:0]   s_axi_awaddr,
    input  wire                        s_axi_awvalid,
    output wire                        s_axi_awready,
    input  wire [AXI_DATA_WIDTH-1:0]   s_axi_wdata,
    input  wire [AXI_DATA_WIDTH/8-1:0] s_axi_wstrb,
    input  wire                        s_axi_wvalid,
    output wire                        s_axi_wready,
    output wire [1:0]                  s_axi_bresp,
    output wire                        s_axi_bvalid,
    input  wire                        s_axi_bready,
    input  wire [AXI_ADDR_WIDTH-1:0]   s_axi_araddr,
    input  wire                        s_axi_arvalid,
    output wire                        s_axi_arready,
    output wire [AXI_DATA_WIDTH-1:0]   s_axi_rdata,
    output wire [1:0]                  s_axi_rresp,
    output wire                        s_axi_rvalid,
    input  wire                        s_axi_rready,

    // -------------------------------------------------------------------------
    // AXI4 Master Interface (Memory Access to PS DDR)
    // -------------------------------------------------------------------------
    output wire [AXI_ID_WIDTH-1:0]     m_axi_awid,
    output wire [AXI_ADDR_WIDTH-1:0]   m_axi_awaddr,
    output wire [7:0]                  m_axi_awlen,
    output wire [2:0]                  m_axi_awsize,
    output wire [1:0]                  m_axi_awburst,
    output wire                        m_axi_awvalid,
    input  wire                        m_axi_awready,
    output wire [AXI_DATA_WIDTH-1:0]   m_axi_wdata,
    output wire [AXI_DATA_WIDTH/8-1:0] m_axi_wstrb,
    output wire                        m_axi_wlast,
    output wire                        m_axi_wvalid,
    input  wire                        m_axi_wready,
    input  wire [AXI_ID_WIDTH-1:0]     m_axi_bid,
    input  wire [1:0]                  m_axi_bresp,
    input  wire                        m_axi_bvalid,
    output wire                        m_axi_bready,
    output wire [AXI_ID_WIDTH-1:0]     m_axi_arid,
    output wire [AXI_ADDR_WIDTH-1:0]   m_axi_araddr,
    output wire [7:0]                  m_axi_arlen,
    output wire [2:0]                  m_axi_arsize,
    output wire [1:0]                  m_axi_arburst,
    output wire                        m_axi_arvalid,
    input  wire                        m_axi_arready,
    input  wire [AXI_ID_WIDTH-1:0]     m_axi_rid,
    input  wire [AXI_DATA_WIDTH-1:0]   m_axi_rdata,
    input  wire [1:0]                  m_axi_rresp,
    input  wire                        m_axi_rlast,
    input  wire                        m_axi_rvalid,
    output wire                        m_axi_rready,

    // -------------------------------------------------------------------------
    // Interrupts to Zynq PS
    // -------------------------------------------------------------------------
    output wire                        npu_irq
);

    // -------------------------------------------------------------------------
    // Internal Signals
    // -------------------------------------------------------------------------
    wire rst_n_sync;
    
    // Clock domain enable signals generated by the core
    wire compute_cg_en;
    wire postproc_cg_en;
    wire dma_cg_en;
    
    // Gated clocks for the respective domains
    wire clk_compute;
    wire clk_postproc;
    wire clk_dma;

    // -------------------------------------------------------------------------
    // Reset Synchronization
    // -------------------------------------------------------------------------
    // Synchronize the external Zynq PS asynchronous reset to the local clock 
    // domain using a 2-stage flip-flop synchronizer to avoid metastability.
    rst_sync u_rst_sync (
        .clk          (clk),
        .rst_n_async  (rst_n),
        .rst_n_sync   (rst_n_sync)
    );

    // -------------------------------------------------------------------------
    // Clock Gating (FPGA Specific via BUFGCE)
    // -------------------------------------------------------------------------
    // Instantiates Xilinx BUFGCE wrappers. Using standard clock gating cells
    // prevents the synthesis tool from relying on inefficient LUT-based gating.
    
    clk_gate_bufgce u_icg_compute (
        .clk_in       (clk),
        .en           (compute_cg_en),
        .clk_out      (clk_compute)
    );

    clk_gate_bufgce u_icg_postproc (
        .clk_in       (clk),
        .en           (postproc_cg_en),
        .clk_out      (clk_postproc)
    );

    clk_gate_bufgce u_icg_dma (
        .clk_in       (clk),
        .en           (dma_cg_en),
        .clk_out      (clk_dma)
    );

    // -------------------------------------------------------------------------
    // Core Instantiation
    // -------------------------------------------------------------------------
    // Technology-independent TinyNPU core logic.
    tinynpu_top #(
        .AXI_DATA_WIDTH (AXI_DATA_WIDTH),
        .AXI_ADDR_WIDTH (AXI_ADDR_WIDTH),
        .AXI_ID_WIDTH   (AXI_ID_WIDTH),
        .ARRAY_SIZE     (ARRAY_SIZE),
        .DATA_WIDTH     (DATA_WIDTH),
        .ACC_WIDTH      (ACC_WIDTH)
    ) u_tinynpu_core (
        // Global Clock and Reset
        .clk              (clk),
        .rst_n            (rst_n_sync),
        
        // Gated Clocks (inputs to core)
        .clk_compute      (clk_compute),
        .clk_postproc     (clk_postproc),
        .clk_dma          (clk_dma),
        
        // Clock Gating Enables (outputs from core)
        .compute_cg_en    (compute_cg_en),
        .postproc_cg_en   (postproc_cg_en),
        .dma_cg_en        (dma_cg_en),

        // AXI-Lite Slave
        .s_axi_awaddr     (s_axi_awaddr),
        .s_axi_awvalid    (s_axi_awvalid),
        .s_axi_awready    (s_axi_awready),
        .s_axi_wdata      (s_axi_wdata),
        .s_axi_wstrb      (s_axi_wstrb),
        .s_axi_wvalid     (s_axi_wvalid),
        .s_axi_wready     (s_axi_wready),
        .s_axi_bresp      (s_axi_bresp),
        .s_axi_bvalid     (s_axi_bvalid),
        .s_axi_bready     (s_axi_bready),
        .s_axi_araddr     (s_axi_araddr),
        .s_axi_arvalid    (s_axi_arvalid),
        .s_axi_arready    (s_axi_arready),
        .s_axi_rdata      (s_axi_rdata),
        .s_axi_rresp      (s_axi_rresp),
        .s_axi_rvalid     (s_axi_rvalid),
        .s_axi_rready     (s_axi_rready),

        // AXI4 Master
        .m_axi_awid       (m_axi_awid),
        .m_axi_awaddr     (m_axi_awaddr),
        .m_axi_awlen      (m_axi_awlen),
        .m_axi_awsize     (m_axi_awsize),
        .m_axi_awburst    (m_axi_awburst),
        .m_axi_awvalid    (m_axi_awvalid),
        .m_axi_awready    (m_axi_awready),
        .m_axi_wdata      (m_axi_wdata),
        .m_axi_wstrb      (m_axi_wstrb),
        .m_axi_wlast      (m_axi_wlast),
        .m_axi_wvalid     (m_axi_wvalid),
        .m_axi_wready     (m_axi_wready),
        .m_axi_bid        (m_axi_bid),
        .m_axi_bresp      (m_axi_bresp),
        .m_axi_bvalid     (m_axi_bvalid),
        .m_axi_bready     (m_axi_bready),
        .m_axi_arid       (m_axi_arid),
        .m_axi_araddr     (m_axi_araddr),
        .m_axi_arlen      (m_axi_arlen),
        .m_axi_arsize     (m_axi_arsize),
        .m_axi_arburst    (m_axi_arburst),
        .m_axi_arvalid    (m_axi_arvalid),
        .m_axi_arready    (m_axi_arready),
        .m_axi_rid        (m_axi_rid),
        .m_axi_rdata      (m_axi_rdata),
        .m_axi_rresp      (m_axi_rresp),
        .m_axi_rlast      (m_axi_rlast),
        .m_axi_rvalid     (m_axi_rvalid),
        .m_axi_rready     (m_axi_rready),

        // Interrupts
        .npu_irq          (npu_irq)
    );

endmodule

