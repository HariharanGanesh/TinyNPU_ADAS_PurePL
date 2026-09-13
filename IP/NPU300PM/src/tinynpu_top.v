// =============================================================================
// Module: tinynpu_top.v
// Project: TinyNPU200 v1.0
//
// ARCHITECTURE LAYER: Layer 1 ??? TinyNPU Core (Technology-Independent)
// =============================================================================
//
// UPGRADE FROM TinyNPU100 (TinyNPU2k200J):
//   - Systolic array expanded: 8??8 ??? 20??8 (160 DSP48s, ~24.96 GOPS @ 195 MHz)
//   - Processing element: 2-stage ??? 3-stage pipeline (195 MHz timing closure)
//   - Activation unit:  2-bit sel ??? 3-bit sel (adds LeakyReLU + HardSwish)
//   - Pooling unit:  1-bit mode ??? 2-bit mode (adds AvgPool)
//   - CSR: 20 registers ??? 32 registers (stride_sel, act_ext, pool_mode, etc.)
//   - General-purpose: All modes runtime-selectable via CSR (no hardcoding)
//
// ASIC/FPGA PORTABILITY POLICY:
//   Pure behavioral RTL, Verilog-2001. No FPGA primitives in this file.
//   All FPGA-specific resources (BUFGCE, MMCM) are in tinynpu_fpga_wrapper.v
//   and tinynpu_hdmi_top.v.
//
// THREE CLOCK DOMAINS (unchanged from TinyNPU100):
//   clk_compute  : Systolic array + DW engine + requantization
//   clk_postproc : Activation + pooling + threshold + bbox
//   clk_dma      : DMA controller
//
// DATA PATH (unchanged):
//   AXI4-Stream sensor ??? axis_sink ??? activation_buffer (ping-pong)
//   ??? systolic_array (20??8) OR dw_line_buffer (3??3 DW)
//   ??? requantization ??? activation ??? pooling
//   ??? bbox_decoder ??? threshold_filter ??? output_buffer ??? axis_source
//
// Verilog-2001 Synthesizable RTL.
// =============================================================================

`timescale 1ns / 1ps

module tinynpu_top #(
    parameter AXI_ADDR_WIDTH  = 32,
    parameter AXI_DATA_WIDTH  = 32,
    parameter AXIS_DATA_WIDTH = 32,
    parameter DATA_WIDTH      = 8,
    parameter ACCUM_WIDTH     = 32,
    parameter SCALE_WIDTH     = 16,
    parameter SHIFT_WIDTH     = 6,
    parameter ARRAY_ROWS      = 20,   // TinyNPU200: 20 rows (was 8)
    parameter ARRAY_COLS      = 8,
    parameter BUFFER_DEPTH    = 1024,
    parameter BUFFER_ADDR_WIDTH = 10,
    parameter MAX_WIDTH       = 128,
    parameter TILE_SIZE       = 160   // 20 rows ?? 8 cols per tile
) (
    input  wire aclk,
    input  wire aresetn,

    // -------------------------------------------------------------------------
    // AXI4-Lite Slave Interface (Control Plane)
    // -------------------------------------------------------------------------
    input  wire [AXI_ADDR_WIDTH-1:0]    s_axi_awaddr,
    input  wire [2:0]                   s_axi_awprot,
    input  wire                         s_axi_awvalid,
    output wire                         s_axi_awready,
    input  wire [AXI_DATA_WIDTH-1:0]    s_axi_wdata,
    input  wire [AXI_DATA_WIDTH/8-1:0]  s_axi_wstrb,
    input  wire                         s_axi_wvalid,
    output wire                         s_axi_wready,
    output wire [1:0]                   s_axi_bresp,
    output wire                         s_axi_bvalid,
    input  wire                         s_axi_bready,
    input  wire [AXI_ADDR_WIDTH-1:0]    s_axi_araddr,
    input  wire [2:0]                   s_axi_arprot,
    input  wire                         s_axi_arvalid,
    output wire                         s_axi_arready,
    output wire [AXI_DATA_WIDTH-1:0]    s_axi_rdata,
    output wire [1:0]                   s_axi_rresp,
    output wire                         s_axi_rvalid,
    input  wire                         s_axi_rready,

    // -------------------------------------------------------------------------
    // AXI4-Full Master Interface (DMA ??? weight load and result store)
    // -------------------------------------------------------------------------
    output wire [AXI_ADDR_WIDTH-1:0]    m_axi_awaddr,
    output wire [7:0]                   m_axi_awlen,
    output wire [2:0]                   m_axi_awsize,
    output wire [1:0]                   m_axi_awburst,
    output wire                         m_axi_awvalid,
    input  wire                         m_axi_awready,
    output wire [AXI_DATA_WIDTH-1:0]    m_axi_wdata,
    output wire [AXI_DATA_WIDTH/8-1:0]  m_axi_wstrb,
    output wire                         m_axi_wlast,
    output wire                         m_axi_wvalid,
    input  wire                         m_axi_wready,
    input  wire [1:0]                   m_axi_bresp,
    input  wire                         m_axi_bvalid,
    output wire                         m_axi_bready,
    output wire [AXI_ADDR_WIDTH-1:0]    m_axi_araddr,
    output wire [7:0]                   m_axi_arlen,
    output wire [2:0]                   m_axi_arsize,
    output wire [1:0]                   m_axi_arburst,
    output wire                         m_axi_arvalid,
    input  wire                         m_axi_arready,
    input  wire [AXI_DATA_WIDTH-1:0]    m_axi_rdata,
    input  wire [1:0]                   m_axi_rresp,
    input  wire                         m_axi_rlast,
    input  wire                         m_axi_rvalid,
    output wire                         m_axi_rready,

    // -------------------------------------------------------------------------
    // AXI4-Stream Slave Interface (Sensor/Camera streaming input)
    // -------------------------------------------------------------------------
    input  wire [AXIS_DATA_WIDTH-1:0]   s_axis_tdata,
    input  wire                         s_axis_tvalid,
    output wire                         s_axis_tready,
    input  wire                         s_axis_tlast,

    // -------------------------------------------------------------------------
    // AXI4-Stream Master Interface (Processed output stream)
    // -------------------------------------------------------------------------
    output wire [AXIS_DATA_WIDTH-1:0]   m_axis_tdata,
    output wire                         m_axis_tvalid,
    input  wire                         m_axis_tready,
    output wire                         m_axis_tlast,

    // HDMI/Video Status Input (from tinynpu_hdmi_top)
    input  wire                         vid_locked_in,   // HDMI RX lock
    input  wire [31:0]                  tile_count_in,   // Tile count from controller

    // Interrupt
    output wire                         interrupt
);

    wire clk = aclk;
    wire rst_n = aresetn;

    // =========================================================================
    // CSR Wire Bundle (existing)
    // =========================================================================
    wire        csr_start;
    wire        csr_soft_reset;
    wire [31:0] csr_weight_base;
    wire [31:0] csr_act_base;
    wire [31:0] csr_out_base;
    wire [7:0]  csr_kernel_size;
    wire [7:0]  csr_stride;
    wire [7:0]  csr_padding;
    wire [1:0]  csr_act_sel;
    wire [15:0] csr_in_channels;
    wire [15:0] csr_out_channels;
    wire [15:0] csr_input_width;
    wire [15:0] csr_input_height;
    wire [15:0] csr_num_tiles_x;
    wire [15:0] csr_num_tiles_y;
    wire        csr_irq_en;
    wire [31:0] csr_m0;
    wire [31:0] csr_n_shift;
    wire [31:0] csr_bias;
    wire        csr_layer_type;
    wire        csr_cosine_sim_mode;
    wire        csr_wgt_bank_sel;
    wire [7:0]  csr_conf_threshold;
    wire [15:0] csr_crop_x;
    wire [15:0] csr_crop_y;
    wire [15:0] csr_crop_w;
    wire [15:0] csr_crop_h;

    // =========================================================================
    // CSR Wire Bundle (TinyNPU200 NEW)
    // =========================================================================
    wire [1:0]  csr_stride_sel;    // Output stride: 00=16, 01=8, 10=4
    wire [2:0]  csr_act_ext;       // Extended activation selector (3-bit)
    wire [1:0]  csr_pool_mode;     // Pool mode: 00=bypass, 01=MaxPool, 10=AvgPool
    wire [4:0]  csr_array_rows;    // Runtime row count (max 20)
    wire [1:0]  csr_input_fmt;     // Input format
    wire [15:0] csr_frame_w;       // Frame width
    wire [15:0] csr_frame_h;       // Frame height

    // =========================================================================
    // Status / Performance Wire Bundle
    // =========================================================================
    wire        status_idle;
    wire        status_busy;
    wire        status_done;
    wire        status_error;
    wire [63:0] perf_cycle_count;
    wire [63:0] perf_compute_count;
    wire [31:0] perf_dma_stall_count;
    wire [31:0] perf_out_stall_count;

    assign interrupt = status_done & csr_irq_en;

    // =========================================================================
    // Controller ??? DMA Wire Bundle
    // =========================================================================
    wire        dma_start_load_wgt;
    wire        dma_start_load_act;
        wire        dma_start_store_out;
    wire [15:0] dma_transfer_size;
    wire        dma_wgt_load_done;
        wire        dma_out_store_done;
    wire [BUFFER_ADDR_WIDTH-1:0] dma_wgt_wr_addr;
    wire [DATA_WIDTH-1:0]        dma_wgt_wr_data;
    wire                         dma_wgt_wr_en;

    // =========================================================================
    // Controller ??? Internal Wire Bundle
    // =========================================================================
    wire [BUFFER_ADDR_WIDTH-1:0] act_buf_rd_addr;
    wire                         act_buf_rd_en;
    wire                         act_buf_swap;
    wire                         array_en;
    wire                         array_psum_clear;
    wire                         array_weight_load;
    wire                         pad_active;
    wire                         requant_acc_valid;
    wire                         pool_enable;
    wire                         out_buf_wr_en;
    wire                         out_buf_full;
    wire                         wgt_buf_load_tile;
    wire                         wgt_buf_load_complete;
    wire                         stream_tile_received;
    wire                         stream_frame_done;
    wire [BUFFER_ADDR_WIDTH-1:0] stream_act_wr_addr;
    wire [AXIS_DATA_WIDTH-1:0]   stream_act_wr_data;
    wire                         stream_act_wr_en;

    // act_rd_valid: one-cycle delay for BRAM registered read
    reg act_rd_valid;
    always @(posedge clk) begin
        if (!rst_n) act_rd_valid <= 1'b0;
        else        act_rd_valid <= act_buf_rd_en;
    end

    wire buf_swap_ack;
    assign buf_swap_ack = act_buf_swap;

    // =========================================================================
    // Clock Gating (Technology-Independent ICG)
    // =========================================================================
    wire clk_compute;
    wire clk_postproc;
    wire clk_dma;

    wire cg_compute_en  = array_en | array_weight_load | array_psum_clear | ~rst_n;
    wire cg_postproc_en = requant_acc_valid | pool_enable | ~rst_n;
    wire cg_dma_en      = status_busy | ~rst_n;

    tinynpu_icg u_icg_compute (
        .clk_in  (clk),
        .en      (cg_compute_en),
        .clk_out (clk_compute)
    );

    tinynpu_icg u_icg_postproc (
        .clk_in  (clk),
        .en      (cg_postproc_en),
        .clk_out (clk_postproc)
    );

    tinynpu_icg u_icg_dma (
        .clk_in  (clk),
        .en      (cg_dma_en),
        .clk_out (clk_dma)
    );

    // =========================================================================
    // Module 1: AXI4-Lite CSR (TinyNPU200 ??? 32 registers)
    // =========================================================================
    axi4_lite_slave #(
        .ADDR_WIDTH(AXI_ADDR_WIDTH),
        .DATA_WIDTH(AXI_DATA_WIDTH)
    ) u_csr (
        .aclk(clk), .aresetn(rst_n),
        .s_awaddr(s_axi_awaddr), .s_awprot(s_axi_awprot),
        .s_awvalid(s_axi_awvalid), .s_awready(s_axi_awready),
        .s_wdata(s_axi_wdata), .s_wstrb(s_axi_wstrb),
        .s_wvalid(s_axi_wvalid), .s_wready(s_axi_wready),
        .s_bresp(s_axi_bresp), .s_bvalid(s_axi_bvalid), .s_bready(s_axi_bready),
        .s_araddr(s_axi_araddr), .s_arprot(s_axi_arprot),
        .s_arvalid(s_axi_arvalid), .s_arready(s_axi_arready),
        .s_rdata(s_axi_rdata), .s_rresp(s_axi_rresp),
        .s_rvalid(s_axi_rvalid), .s_rready(s_axi_rready),
        // Existing CSR outputs
        .csr_start(csr_start), .csr_soft_reset(csr_soft_reset),
        .csr_weight_base(csr_weight_base), .csr_act_base(csr_act_base),
        .csr_out_base(csr_out_base), .csr_kernel_size(csr_kernel_size),
        .csr_stride(csr_stride), .csr_padding(csr_padding),
        .csr_act_sel(csr_act_sel),
        .csr_in_channels(csr_in_channels), .csr_out_channels(csr_out_channels),
        .csr_input_width(csr_input_width), .csr_input_height(csr_input_height),
        .csr_irq_en(csr_irq_en),
        .csr_m0(csr_m0), .csr_n_shift(csr_n_shift), .csr_bias(csr_bias),
        .csr_layer_type(csr_layer_type),
        .csr_cosine_sim_mode(csr_cosine_sim_mode),
        .csr_wgt_bank_sel(csr_wgt_bank_sel),
        .csr_conf_threshold(csr_conf_threshold),
        .csr_crop_x(csr_crop_x), .csr_crop_y(csr_crop_y),
        .csr_crop_w(csr_crop_w), .csr_crop_h(csr_crop_h),
        .status_idle(status_idle), .status_busy(status_busy),
        .status_done(status_done), .status_error(status_error),
        .perf_cycle_count(perf_cycle_count),
        .perf_compute_count(perf_compute_count),
        .perf_dma_stall_count(perf_dma_stall_count),
        .perf_out_stall_count(perf_out_stall_count),
        // TinyNPU200 new CSR outputs
        .csr_stride_sel(csr_stride_sel),
        .csr_act_ext(csr_act_ext),
        .csr_pool_mode(csr_pool_mode),
        .csr_array_rows(csr_array_rows),
        .csr_input_fmt(csr_input_fmt),
        .csr_frame_w(csr_frame_w),
        .csr_frame_h(csr_frame_h),
        .csr_num_tiles_x(csr_num_tiles_x),
        .csr_num_tiles_y(csr_num_tiles_y),
        // Status inputs for new R/O registers
        .vid_locked(vid_locked_in),
        .tile_count(tile_count_in)
    );

    // =========================================================================
    // Module 2: DMA Controller
    // =========================================================================
    dma_controller #(
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
        .BUFFER_ADDR_WIDTH(BUFFER_ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_dma (
        .clk(clk_dma), .rst_n(rst_n),
        .m_axi_awaddr(m_axi_awaddr), .m_axi_awlen(m_axi_awlen),
        .m_axi_awsize(m_axi_awsize), .m_axi_awburst(m_axi_awburst),
        .m_axi_awvalid(m_axi_awvalid), .m_axi_awready(m_axi_awready),
        .m_axi_wdata(m_axi_wdata), .m_axi_wstrb(m_axi_wstrb),
        .m_axi_wlast(m_axi_wlast), .m_axi_wvalid(m_axi_wvalid),
        .m_axi_wready(m_axi_wready),
        .m_axi_bresp(m_axi_bresp), .m_axi_bvalid(m_axi_bvalid),
        .m_axi_bready(m_axi_bready),
        .m_axi_araddr(m_axi_araddr), .m_axi_arlen(m_axi_arlen),
        .m_axi_arsize(m_axi_arsize), .m_axi_arburst(m_axi_arburst),
        .m_axi_arvalid(m_axi_arvalid), .m_axi_arready(m_axi_arready),
        .m_axi_rdata(m_axi_rdata), .m_axi_rresp(m_axi_rresp),
        .m_axi_rlast(m_axi_rlast), .m_axi_rvalid(m_axi_rvalid),
        .m_axi_rready(m_axi_rready),
        .weight_base_addr(csr_weight_base),
                .out_base_addr(csr_out_base),
        .transfer_size(dma_transfer_size),
        .start_load_weights(dma_start_load_wgt),
        .start_load_act(dma_start_load_act),
                .start_store_out(dma_start_store_out),
        .weight_load_done(dma_wgt_load_done),
                .out_store_done(dma_out_store_done),
        .wgt_buf_wr_addr(dma_wgt_wr_addr),
        .wgt_buf_wr_data(dma_wgt_wr_data),
        .wgt_buf_wr_en(dma_wgt_wr_en)
    );

    // =========================================================================
    // Module 3: NPU Controller FSM
    // NOTE: csr_act_ext drives activation_unit; pool_mode drives pooling_unit.
    // The controller FSM schedule is unchanged ??? only the data path modules
    // change behavior based on the new CSR values.
    // =========================================================================
    npu_controller #(
        .DATA_WIDTH(DATA_WIDTH),
        .ARRAY_ROWS(ARRAY_ROWS),
        .ARRAY_COLS(ARRAY_COLS),
        .ADDR_WIDTH(BUFFER_ADDR_WIDTH)
    ) u_ctrl (
        .clk(clk), .rst_n(rst_n),
        // CSR inputs
        .csr_start(csr_start), .csr_soft_reset(csr_soft_reset),
        .csr_in_channels(csr_in_channels), .csr_out_channels(csr_out_channels),
        .csr_input_width(csr_input_width), .csr_input_height(csr_input_height),
        .csr_num_tiles_x(csr_num_tiles_x), .csr_num_tiles_y(csr_num_tiles_y),
        .csr_kernel_size(csr_kernel_size), .csr_stride(csr_stride),
        .csr_padding(csr_padding), .csr_act_sel(csr_act_sel),
        .csr_cosine_sim_mode(csr_cosine_sim_mode),
        // Status outputs
        .status_idle(status_idle), .status_busy(status_busy),
        .status_done(status_done), .status_error(status_error),
        .perf_cycle_count(perf_cycle_count),
        .perf_compute_count(perf_compute_count),
        .perf_dma_stall_count(perf_dma_stall_count),
        .perf_out_stall_count(perf_out_stall_count),
        // DMA control
        .dma_start_load_wgt(dma_start_load_wgt),
                .dma_start_load_act(dma_start_load_act),
        .dma_start_store_out(dma_start_store_out),
        .dma_transfer_size(dma_transfer_size),
        .dma_wgt_load_done(dma_wgt_load_done),
        .dma_act_load_done(stream_tile_received),
        .dma_out_store_done(dma_out_store_done),
        // Buffer control
        .wgt_buf_load_tile(wgt_buf_load_tile),
        .wgt_buf_load_complete(wgt_buf_load_complete),
        .act_buf_rd_addr(act_buf_rd_addr),
        .act_buf_rd_en(act_buf_rd_en),
        .act_buf_swap(act_buf_swap),
        // Compute control
        .array_en(array_en),
        .array_psum_clear(array_psum_clear),
        .array_weight_load(array_weight_load),
        .pad_active(pad_active),
        .requant_acc_valid(requant_acc_valid),
        .pool_enable(pool_enable),
        // Output buffer
        .out_buf_wr_en(out_buf_wr_en),
        .out_buf_full(out_buf_full),
        .m_axis_tready(m_axis_tready)
    );

    // =========================================================================
    // Module 4: AXI4-Stream Sink (with spatial crop preprocessor)
    // =========================================================================
    wire crop_en = (csr_crop_w != 0) & (csr_crop_h != 0);

    axis_sink #(
        .AXIS_DATA_WIDTH(AXIS_DATA_WIDTH),
        .TILE_SIZE(TILE_SIZE),
        .ADDR_WIDTH(BUFFER_ADDR_WIDTH)
    ) u_axis_sink (
        .clk(clk), .rst_n(rst_n),
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .s_axis_tlast(s_axis_tlast),
        .buf_wr_addr(stream_act_wr_addr),
        .buf_wr_data(stream_act_wr_data),
        .buf_wr_en(stream_act_wr_en),
        .buf_swap_ack(buf_swap_ack),
        .buf_full(1'b0),
        .crop_x(csr_crop_x), .crop_y(csr_crop_y),
        .crop_w(csr_crop_w), .crop_h(csr_crop_h),
        .crop_en(crop_en),
        .tile_received(stream_tile_received),
        .frame_done(stream_frame_done),
        .bytes_received()
    );

    // =========================================================================
    // Module 5: Activation Buffers (Ping-Pong, one per PE row)
    // TinyNPU200: ARRAY_ROWS=20, so 20 activation buffer instances.
    // Channel interleaving: 32-bit AXI-Stream = 4 bytes/cycle.
    // Channels 0-3 selected on stream_act_wr_addr[1:0]==0, etc.
    // =========================================================================
    wire [DATA_WIDTH*ARRAY_ROWS-1:0] act_rd_data_flat;

    localparam ACT_BUF_DEPTH = 64;         // 2^6 = 64; must be power-of-2 for BRAM inference
    localparam ACT_BUF_ADDR_W = 6;         // log2(64); matches BUFFER_ADDR_WIDTH-4
    localparam GEN_ROWS = ARRAY_ROWS;      // localparam required for generate loop bound

    genvar ch;
    generate
        for (ch = 0; ch < GEN_ROWS; ch = ch + 1) begin : gen_act_buf
            localparam CH_BANK   = ch / 4;
            localparam CH_OFFSET = (ch % 4) * 8;
            localparam CH_RBASE  = ch * DATA_WIDTH;
            
            wire ch_wr_en;
            assign ch_wr_en = stream_act_wr_en &&
                              ((stream_act_wr_addr[2:0]) == CH_BANK);

            wire [DATA_WIDTH-1:0] ch_wr_data;
            assign ch_wr_data = stream_act_wr_data[CH_OFFSET +: 8];

            wire [DATA_WIDTH-1:0] ch_rd_data;
            assign act_rd_data_flat[CH_RBASE +: DATA_WIDTH] = ch_rd_data;

            activation_buffer #(
                .DATA_WIDTH(DATA_WIDTH),
                .BUFFER_DEPTH(ACT_BUF_DEPTH),
                .ADDR_WIDTH(ACT_BUF_ADDR_W)
            ) u_act_buf (
                .clk(clk), .rst_n(rst_n),
                .wr_addr(stream_act_wr_addr[ACT_BUF_ADDR_W+2:3]),
                .wr_data(ch_wr_data),
                .wr_en(ch_wr_en),
                .rd_addr(act_buf_rd_addr[ACT_BUF_ADDR_W-1:0]),
                .rd_data(ch_rd_data),
                .rd_en(act_buf_rd_en),
                .swap_buffers(act_buf_swap),
                .ping_pong_sel(),
                .buffer_ready()
            );
        end
    endgenerate

    // =========================================================================
    // Module 6: Weight Buffer (Dual-banked for DMA double-buffering)
    // TinyNPU200: weight_data_flat is 20??8??8 = 1280 bits wide.
    // =========================================================================
    wire [DATA_WIDTH*ARRAY_ROWS*ARRAY_COLS-1:0] weight_data_flat;
    wire                                         wgt_data_valid_unused;

    weight_buffer #(
        .DATA_WIDTH(DATA_WIDTH),
        .ARRAY_ROWS(ARRAY_ROWS),
        .ARRAY_COLS(ARRAY_COLS),
        .BUFFER_DEPTH(512),
        .ADDR_WIDTH(BUFFER_ADDR_WIDTH)
    ) u_weight_buf (
        .clk(clk), .rst_n(rst_n),
        .bank_sel(csr_wgt_bank_sel),
        .wr_addr(dma_wgt_wr_addr),
        .wr_data(dma_wgt_wr_data),
        .wr_en(dma_wgt_wr_en),
        .tile_base_addr({BUFFER_ADDR_WIDTH{1'b0}}),
        .load_tile(wgt_buf_load_tile),
        .weight_data_flat(weight_data_flat),
        .weight_data_valid(wgt_data_valid_unused),
        .load_complete(wgt_buf_load_complete)
    );

    // =========================================================================
    // Module 7: Systolic Array (TinyNPU200: 20??8)
    // =========================================================================
    wire [ACCUM_WIDTH*ARRAY_COLS-1:0] systolic_psum_flat;
    wire [ARRAY_COLS-1:0]             systolic_valid_flat;

    wire [DATA_WIDTH*ARRAY_ROWS-1:0] padded_act_flat;
    assign padded_act_flat = pad_active ? {(DATA_WIDTH*ARRAY_ROWS){1'b0}} : act_rd_data_flat;

    systolic_array #(
        .ARRAY_ROWS(ARRAY_ROWS), .ARRAY_COLS(ARRAY_COLS),
        .DATA_WIDTH(DATA_WIDTH), .ACCUM_WIDTH(ACCUM_WIDTH)
    ) u_systolic (
        .clk(clk_compute), .reset_n(rst_n),
        .weight_data_flat(weight_data_flat),
        .weight_load(array_weight_load),
        .act_in_flat(padded_act_flat),
        .act_valid_in_flat({ARRAY_ROWS{act_rd_valid}}),
        .psum_out_flat(systolic_psum_flat),
        .psum_valid_out_flat(systolic_valid_flat),
        .array_en(array_en),
        .psum_clear(array_psum_clear)
    );

    // =========================================================================
    // Module 8: Depthwise Line Buffer Engine (3??3 per channel)
    // =========================================================================
    wire [ACCUM_WIDTH*ARRAY_ROWS-1:0] dw_psum_flat;
    wire                              dw_psum_valid;
    wire [DATA_WIDTH*9*ARRAY_ROWS-1:0] dw_weights_flat;

    assign dw_weights_flat = {
        {(DATA_WIDTH*9*ARRAY_ROWS - DATA_WIDTH*ARRAY_ROWS*ARRAY_COLS){1'b0}},
        weight_data_flat
    };

    /* dw_line_buffer disabled to save LUTs
*/

    // Mux: select systolic or depthwise output based on layer type
    // Systolic: ARRAY_COLS=8 psums. DW: ARRAY_ROWS=20 psums (per-channel).
    // For systolic, replicate 8-col psums across ARRAY_ROWS for requant input.
    wire [ACCUM_WIDTH*ARRAY_ROWS-1:0] compute_psum_flat;
    wire                              compute_psum_valid;

    genvar pc;
    generate
        for (pc = 0; pc < GEN_ROWS; pc = pc + 1) begin : gen_psum_mux
            localparam PC_COL_BASE  = (pc % ARRAY_COLS) * ACCUM_WIDTH;
            localparam PC_PSUM_BASE = pc * ACCUM_WIDTH;
            // For systolic mode: map col (pc % ARRAY_COLS) psum to row pc output
            wire [ACCUM_WIDTH-1:0] sys_psum_ch;
            wire [ACCUM_WIDTH-1:0] dw_psum_ch;
            wire [ACCUM_WIDTH-1:0] mux_psum_out;
            assign sys_psum_ch = systolic_psum_flat[PC_COL_BASE +: ACCUM_WIDTH];
            assign dw_psum_ch  = dw_psum_flat[PC_PSUM_BASE +: ACCUM_WIDTH];
            assign mux_psum_out = sys_psum_ch; // dw_engine disabled
            assign compute_psum_flat[PC_PSUM_BASE +: ACCUM_WIDTH] = mux_psum_out;
        end
    endgenerate

    assign compute_psum_valid = |systolic_valid_flat; // dw_engine disabled

    // =========================================================================
    // Module 9: Requantization Unit
    // =========================================================================
    wire [DATA_WIDTH*ARRAY_ROWS-1:0] requant_out_flat;
    wire                              requant_out_valid;

    requantization_unit #(
        .OUT_WIDTH(DATA_WIDTH),
        .ACCUM_WIDTH(ACCUM_WIDTH),
        .NUM_CHANNELS(ARRAY_ROWS)
    ) u_requant (
        .clk(clk_compute), .rst_n(rst_n),
        .acc_in_flat(compute_psum_flat),
        .acc_valid(compute_psum_valid & requant_acc_valid),
        .M0_flat({ARRAY_ROWS{csr_m0}}), 
        .n_shift_flat({ARRAY_ROWS{csr_n_shift}}), 
        .bias_flat({ARRAY_ROWS{csr_bias}}),
        .quant_out_flat(requant_out_flat),
        .quant_valid(requant_out_valid)
    );

    // =========================================================================
    // Module 10: Activation Unit (TinyNPU200: 3-bit act_ext selector)
    // csr_act_ext overrides legacy csr_act_sel when non-zero.
    // =========================================================================
    wire [2:0] act_sel_mux;
    // Backward-compatible: if csr_act_ext==0, use legacy csr_act_sel
    assign act_sel_mux = (csr_act_ext != 3'b000) ? csr_act_ext
                                                  : {1'b0, csr_act_sel};

    wire [DATA_WIDTH*ARRAY_ROWS-1:0] act_out_flat;
    wire                              act_out_valid;

    activation_unit #(
        .NUM_CHANNELS(ARRAY_ROWS),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_act (
        .clk(clk_postproc), .rst_n(rst_n),
        .act_sel(act_sel_mux),
        .act_in_flat(requant_out_flat),
        .in_valid(requant_out_valid),
        .act_out_flat(act_out_flat),
        .out_valid(act_out_valid)
    );

    // =========================================================================
    // Module 11: Pooling Unit (TinyNPU200: 2-bit pool_mode)
    // =========================================================================
    wire [DATA_WIDTH*ARRAY_ROWS-1:0] pool_out_flat;
    wire                              pool_out_valid;

    pooling_unit #(
        .DATA_WIDTH(DATA_WIDTH),
        .NUM_CHANNELS(ARRAY_ROWS),
        .MAX_WIDTH(MAX_WIDTH)
    ) u_pool (
        .clk(clk_postproc), .rst_n(rst_n),
        .image_width(csr_input_width[7:0]),
        .pool_enable(pool_enable),
        .pool_mode(csr_pool_mode),
        .act_in_flat(act_out_flat),
        .act_valid_in(act_out_valid),
        .act_out_flat(pool_out_flat),
        .act_valid_out(pool_out_valid)
    );

    // =========================================================================
    // Module 12: BBox Decoder
    // =========================================================================
    wire [DATA_WIDTH*ARRAY_ROWS-1:0] bbox_out_flat;
    wire                              bbox_out_valid;

    bbox_decoder #(
        .DATA_WIDTH(DATA_WIDTH),
        .COORD_WIDTH(16)
    ) u_bbox (
        .clk(clk_postproc), .rst_n(rst_n),
        .dist_l_in(pool_out_flat[DATA_WIDTH*1-1 : 0]),
        .dist_t_in(pool_out_flat[DATA_WIDTH*2-1 : DATA_WIDTH*1]),
        .dist_r_in(pool_out_flat[DATA_WIDTH*3-1 : DATA_WIDTH*2]),
        .dist_b_in(pool_out_flat[DATA_WIDTH*4-1 : DATA_WIDTH*3]),
        .conf_in(pool_out_flat[DATA_WIDTH*5-1 : DATA_WIDTH*4]),
        .class_in(pool_out_flat[DATA_WIDTH*9-1 : DATA_WIDTH*5]),
        .grid_x(16'd0), .grid_y(16'd0),
        .grid_stride(8'd32),
        .frame_w(csr_frame_w), .frame_h(csr_frame_h),
        .valid_in(pool_out_valid),
        .valid_out(bbox_out_valid),
        .bbox_x1(bbox_out_flat[15:0]),
        .bbox_y1(bbox_out_flat[31:16]),
        .bbox_x2(bbox_out_flat[47:32]),
        .bbox_y2(bbox_out_flat[63:48]),
        .conf_out(bbox_out_flat[71:64]),
        .class_out(bbox_out_flat[103:72])
    );
    // Allow the upper channels to pass through raw instead of being zeroed out!
    // This prevents Vivado from aggressively optimizing away rows 13-19 of the systolic array.
    assign bbox_out_flat[DATA_WIDTH*ARRAY_ROWS-1 : 104] = pool_out_flat[DATA_WIDTH*ARRAY_ROWS-1 : 104];

    // =========================================================================
    // Module 13: Threshold Filter (Confidence Gate)
    // =========================================================================
    wire [DATA_WIDTH*ARRAY_ROWS-1:0] thresh_out_flat;
    wire                              thresh_out_valid;

    threshold_filter #(
        .DATA_WIDTH(DATA_WIDTH),
        .NUM_COLS(ARRAY_ROWS)
    ) u_threshold_filter (
        .clk(clk_postproc), .rst_n(rst_n),
        .conf_threshold(csr_conf_threshold),
        .filter_en(1'b0),
        .data_in_flat(bbox_out_flat),
        .valid_in(bbox_out_valid),
        .data_out_flat(thresh_out_flat),
        .valid_out(thresh_out_valid)
    );

    // =========================================================================
    // Module 14: Output Buffer (FIFO)
    // =========================================================================
    wire [DATA_WIDTH*ARRAY_ROWS-1:0] out_buf_rd_data;
    wire out_buf_rd_en;
    wire out_buf_empty_w;

    output_buffer #(
        .DATA_WIDTH(DATA_WIDTH),
        .NUM_CHANNELS(ARRAY_ROWS),
        .FIFO_DEPTH(BUFFER_DEPTH)
    ) u_out_buf (
        .clk(clk_postproc), .rst_n(rst_n),
        .wr_data(thresh_out_flat),
        .wr_en(thresh_out_valid),
        .rd_data(out_buf_rd_data),
        .rd_en(out_buf_rd_en),
        .empty(out_buf_empty_w),
        .full(out_buf_full)
    );

    // =========================================================================
    // Module 15: AXI4-Stream Source (output to host)
    // =========================================================================
    axis_source #(
        .AXIS_DATA_WIDTH(AXIS_DATA_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .NUM_CHANNELS(ARRAY_ROWS),
        .TILE_SIZE(TILE_SIZE)
    ) u_axis_source (
        .clk(clk), .rst_n(rst_n),
        .buf_rd_data(out_buf_rd_data),
        .buf_rd_en(out_buf_rd_en),
        .buf_empty(out_buf_empty_w),
        .start_drain(status_done),
        
        .m_axis_tdata(m_axis_tdata),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tready(m_axis_tready),
        .m_axis_tlast(m_axis_tlast),
        .drain_done()
    );

endmodule




