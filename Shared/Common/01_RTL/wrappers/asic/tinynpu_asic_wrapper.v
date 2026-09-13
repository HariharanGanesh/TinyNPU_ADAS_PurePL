// -----------------------------------------------------------------------------
// IEEE Transactions on VLSI Systems - Reference Design
// -----------------------------------------------------------------------------
// File        : tinynpu_asic_wrapper.v
// Description : ASIC-specific wrapper for TinyNPU v3.0.
//               This module sits above the technology-independent `tinynpu_top`
//               and maps platform-specific constraints like DFT (Design for 
//               Testability), MBIST (Memory Built-In Self-Test), power 
//               domain sequencing, and standard cell clock gating.
//
// Power Domains Annotations:
//  - VDD_CORE: Main digital supply for standard cells and memories.
//  - VDD_IO: High-voltage supply for pads.
//
// DFT & Structural Test Hooks:
//  - JTAG / TAP interface provided for debug and MBIST trigger.
//  - Scan chains are intended to be inserted at this level, driven by scan_en.
// -----------------------------------------------------------------------------

`timescale 1ns/1ps

module tinynpu_asic_wrapper #(
    parameter AXI_DATA_WIDTH = 64,
    parameter AXI_ADDR_WIDTH = 32,
    parameter AXI_ID_WIDTH   = 4,
    parameter ARRAY_SIZE     = 16,
    parameter DATA_WIDTH     = 8,
    parameter ACC_WIDTH      = 32
)(
    // -------------------------------------------------------------------------
    // Power & Reset Sequencing
    // -------------------------------------------------------------------------
    input  wire                        clk,                 // Global System Clock
    input  wire                        rst_n,               // Asynchronous Active-Low Reset
    input  wire                        ANALOG_SUPPLY_GOOD,  // Power-on sequencing stub

    // -------------------------------------------------------------------------
    // JTAG / Debug / DFT Ports (Scan Chain Insertion Points)
    // -------------------------------------------------------------------------
    input  wire                        scan_en,
    input  wire                        scan_in,
    output wire                        scan_out,
    input  wire                        tck,
    input  wire                        tms,
    input  wire                        tdi,
    output wire                        tdo,
    
    // -------------------------------------------------------------------------
    // Test Mode Override
    // -------------------------------------------------------------------------
    input  wire                        test_mode,           // Asserted during manufacturing test

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
    // AXI4 Master Interface (Memory Access)
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
    // Interrupts
    // -------------------------------------------------------------------------
    output wire                        npu_irq
);

    // -------------------------------------------------------------------------
    // Test Ports Stubbing (To be handled by synthesis/DFT tools)
    // -------------------------------------------------------------------------
    // JTAG TDO and SCAN_OUT are driven to 0 when not used to prevent floating 
    // nodes. In a real physical design flow, DFT insertion will overwrite these.
    assign tdo      = 1'b0;
    assign scan_out = 1'b0;

    // -------------------------------------------------------------------------
    // Internal Signals
    // -------------------------------------------------------------------------
    wire rst_n_sync;
    wire internal_rst_n;
    
    wire compute_cg_en;
    wire postproc_cg_en;
    wire dma_cg_en;
    
    wire clk_compute;
    wire clk_postproc;
    wire clk_dma;
    
    // -------------------------------------------------------------------------
    // Reset Logic & Sequencing
    // -------------------------------------------------------------------------
    // Hold system in reset if analog supply is not fully ramped up
    assign internal_rst_n = rst_n & ANALOG_SUPPLY_GOOD;

    // Standard 2-FF reset synchronizer
    rst_sync u_rst_sync (
        .clk          (clk),
        .rst_n_async  (internal_rst_n),
        .rst_n_sync   (rst_n_sync)
    );

    // -------------------------------------------------------------------------
    // ASIC Clock Gating (Using Standard Foundry Cells)
    // -------------------------------------------------------------------------
    // Note: tinynpu_icg is a generic placeholder that mapped to a latch-based 
    // Integrated Clock Gating (ICG) cell from standard cell libraries 
    // (e.g., CKLNQD).
    // Test mode overrides clock gating during scan shift.
    
    tinynpu_icg u_icg_compute (
        .clk_in       (clk),
        .en           (compute_cg_en | test_mode),
        .test_en      (scan_en),
        .clk_out      (clk_compute)
    );

    tinynpu_icg u_icg_postproc (
        .clk_in       (clk),
        .en           (postproc_cg_en | test_mode),
        .test_en      (scan_en),
        .clk_out      (clk_postproc)
    );

    tinynpu_icg u_icg_dma (
        .clk_in       (clk),
        .en           (dma_cg_en | test_mode),
        .test_en      (scan_en),
        .clk_out      (clk_dma)
    );

    // -------------------------------------------------------------------------
    // MBIST Hook Annotations
    // -------------------------------------------------------------------------
    // During the backend flow, a memory BIST controller will be inserted here.
    // It intercepts the SRAM memory interfaces inside the core.
    // // MBIST_CTRL_IN:  [tck, test_mode, jtag_bist_en]
    // // MBIST_CTRL_OUT: [bist_done, bist_fail]

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
        .clk              (clk),
        .rst_n            (rst_n_sync),
        
        .clk_compute      (clk_compute),
        .clk_postproc     (clk_postproc),
        .clk_dma          (clk_dma),
        
        .compute_cg_en    (compute_cg_en),
        .postproc_cg_en   (postproc_cg_en),
        .dma_cg_en        (dma_cg_en),

        // AXI-Lite
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

        // AXI4
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

        // IRQ
        .npu_irq          (npu_irq)
    );

endmodule
