// =============================================================================
// Module: axi4_lite_slave.v
// Project: TinyNPU200
// Description:
//   AXI4-Lite Slave — Control/Status Register (CSR) interface for TinyNPU.
//   Verilog-2001 Synthesizable RTL.
//   Extended with:
//     - Performance counters (cycle, compute, DMA stall, output stall)
//     - Confidence threshold filtering config
//     - Spatial crop window config
//     - Cosine-similarity mode control
//     - Weight bank select (for ping-pong DMA double buffering)
//     - TinyNPU200 Extended CSRs (stride, act_ext, pool, array rows, etc.)
// =============================================================================

`timescale 1ns / 1ps

module axi4_lite_slave #(
    parameter ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 32
) (
    // AXI4-Lite Global Signals
    input  wire                    aclk,
    input  wire                    aresetn,   // Active-low reset

    // Write Address Channel (AW)
    input  wire [ADDR_WIDTH-1:0]   s_awaddr,
    input  wire [2:0]              s_awprot,
    input  wire                    s_awvalid,
    output wire                    s_awready,

    // Write Data Channel (W)
    input  wire [DATA_WIDTH-1:0]   s_wdata,
    input  wire [DATA_WIDTH/8-1:0] s_wstrb,
    input  wire                    s_wvalid,
    output wire                    s_wready,

    // Write Response Channel (B)
    output wire [1:0]              s_bresp,
    output reg                     s_bvalid,
    input  wire                    s_bready,

    // Read Address Channel (AR)
    input  wire [ADDR_WIDTH-1:0]   s_araddr,
    input  wire [2:0]              s_arprot,
    input  wire                    s_arvalid,
    output wire                    s_arready,

    // Read Data Channel (R)
    output reg  [DATA_WIDTH-1:0]   s_rdata,
    output wire [1:0]              s_rresp,
    output reg                     s_rvalid,
    input  wire                    s_rready,

    // Internal CSR Outputs -> Control Signals
    output wire                    csr_start,
    output wire                    csr_soft_reset,
    output wire [31:0]             csr_weight_base,
    output wire [31:0]             csr_act_base,
    output wire [31:0]             csr_out_base,
    output wire [7:0]              csr_kernel_size,
    output wire [7:0]              csr_stride,
    output wire [7:0]              csr_padding,
    output wire [1:0]              csr_act_sel,
    output wire [15:0]             csr_in_channels,
    output wire [15:0]             csr_out_channels,
    output wire [15:0]             csr_input_width,
    output wire [15:0]             csr_input_height,
    output wire                    csr_irq_en,
    output wire [31:0]             csr_m0,
    output wire [31:0]             csr_n_shift,
    output wire [31:0]             csr_bias,
    output wire                    csr_layer_type,    // 0=standard conv, 1=depthwise
    output wire                    csr_cosine_sim_mode, // 1=cosine similarity mode
    output wire                    csr_wgt_bank_sel,  // 0=bank0, 1=bank1 for DMA writes
    // Confidence threshold for score filtering
    output wire [7:0]              csr_conf_threshold,
    // Spatial crop window
    output wire [15:0]             csr_crop_x,
    output wire [15:0]             csr_crop_y,
    output wire [15:0]             csr_crop_w,
    output wire [15:0]             csr_crop_h,

    // Status Inputs -> CSR
    input  wire                    status_idle,
    input  wire                    status_busy,
    input  wire                    status_done,
    input  wire                    status_error,

    // Performance counter inputs (driven by top-level counters)
    input  wire [63:0]             perf_cycle_count,
    input  wire [63:0]             perf_compute_count,
    input  wire [31:0]             perf_dma_stall_count,
    input  wire [31:0]             perf_out_stall_count,

    // TinyNPU200 Extended CSR Outputs
    output wire [1:0]              csr_stride_sel,    // 0=stride16, 1=stride8, 2=stride4
    output wire [2:0]              csr_act_ext,       // Extended activation: 0=ReLU,1=ID,2=ReLU6,3=LeakyReLU,4=HardSwish
    output wire [1:0]              csr_pool_mode,     // 0=bypass,1=MaxPool,2=AvgPool
    output wire [4:0]              csr_array_rows,    // Runtime row count (max 20 for TinyNPU200)
    output wire [1:0]              csr_input_fmt,     // 0=gray,1=RGB,2=YUV422,3=custom
    output wire [15:0]             csr_frame_w,       // Frame width for HDMI crop
    output wire [15:0]             csr_frame_h,       // Frame height
    // Status inputs (driven back from hardware)
    input  wire                    vid_locked,        // HDMI RX lock status
    input  wire [31:0]             tile_count         // Tiles processed
);

    // =========================================================================
    // CSR Address Definitions
    // =========================================================================
    localparam [7:0] ADDR_CTRL             = 8'h00;
    localparam [7:0] ADDR_STATUS           = 8'h04;
    localparam [7:0] ADDR_WEIGHT_BASE      = 8'h08;
    localparam [7:0] ADDR_ACT_BASE         = 8'h0C;
    localparam [7:0] ADDR_OUT_BASE         = 8'h10;
    localparam [7:0] ADDR_LAYER_CFG_0      = 8'h14;
    localparam [7:0] ADDR_LAYER_CFG_1      = 8'h18;
    localparam [7:0] ADDR_LAYER_CFG_2      = 8'h1C;
    localparam [7:0] ADDR_PERF_CYCLE_LO   = 8'h20;
    localparam [7:0] ADDR_PERF_CYCLE_HI   = 8'h24;
    localparam [7:0] ADDR_IRQ_CTRL         = 8'h28;
    localparam [7:0] ADDR_M0_CFG           = 8'h2C;
    localparam [7:0] ADDR_SHIFT_CFG        = 8'h30;
    localparam [7:0] ADDR_BIAS_CFG         = 8'h34;
    localparam [7:0] ADDR_PERF_COMPUTE_LO = 8'h38;
    localparam [7:0] ADDR_PERF_COMPUTE_HI = 8'h3C;
    localparam [7:0] ADDR_PERF_DMA_STALL  = 8'h40;
    localparam [7:0] ADDR_PERF_OUT_STALL  = 8'h44;
    localparam [7:0] ADDR_CONF_THRESHOLD  = 8'h48;
    localparam [7:0] ADDR_CROP_XY         = 8'h4C; // [31:16]=crop_y [15:0]=crop_x
    localparam [7:0] ADDR_CROP_WH         = 8'h50; // [31:16]=crop_h [15:0]=crop_w

    // TinyNPU200 Extended Registers
    // Shifted by 4 bytes relative to the prompt to avoid overlap with ADDR_CROP_WH (0x50)
    localparam [7:0] ADDR_STRIDE_SEL      = 8'h54;
    localparam [7:0] ADDR_ACT_EXT         = 8'h58;
    localparam [7:0] ADDR_POOL_MODE       = 8'h5C;
    localparam [7:0] ADDR_ARRAY_ROWS      = 8'h60;
    localparam [7:0] ADDR_INPUT_FMT       = 8'h64;
    localparam [7:0] ADDR_FRAME_W         = 8'h68;
    localparam [7:0] ADDR_FRAME_H         = 8'h6C;
    localparam [7:0] ADDR_VID_LOCKED      = 8'h70;
    localparam ADDR_TILE_COUNT      = 10'h074;
    localparam ADDR_VERSION         = 10'h078;
    localparam ADDR_FEATURE_FLAGS   = 10'h07C;
    localparam ADDR_NUM_TILES       = 10'h080;

    // =========================================================================
    // Internal Registers
    // =========================================================================
    reg [DATA_WIDTH-1:0] reg_ctrl;
    reg [DATA_WIDTH-1:0] reg_weight_base;
    reg [DATA_WIDTH-1:0] reg_act_base;
    reg [DATA_WIDTH-1:0] reg_out_base;
    reg [DATA_WIDTH-1:0] reg_layer_cfg0;
    reg [DATA_WIDTH-1:0] reg_layer_cfg1;
    reg [DATA_WIDTH-1:0] reg_layer_cfg2;
    reg [DATA_WIDTH-1:0] reg_irq_ctrl;
    reg [DATA_WIDTH-1:0] reg_m0;
    reg [DATA_WIDTH-1:0] reg_n_shift;
    reg [DATA_WIDTH-1:0] reg_bias;
    reg [DATA_WIDTH-1:0] reg_conf_threshold;
    reg [DATA_WIDTH-1:0] reg_crop_xy;
    reg [DATA_WIDTH-1:0] reg_crop_wh;

    // Extended Registers
    reg [DATA_WIDTH-1:0] reg_stride_sel;
    reg [DATA_WIDTH-1:0] reg_act_ext;
    reg [DATA_WIDTH-1:0] reg_pool_mode;
    reg [DATA_WIDTH-1:0] reg_array_rows;
    reg [DATA_WIDTH-1:0] reg_input_fmt;
    reg [DATA_WIDTH-1:0] reg_frame_w;
    reg [DATA_WIDTH-1:0] reg_frame_h;
    reg [DATA_WIDTH-1:0] reg_num_tiles;

    // Latched write address
    reg [ADDR_WIDTH-1:0] wr_addr_lat;

    // AWREADY / WREADY / ARREADY always accept immediately
    assign s_awready = 1'b1;
    assign s_wready  = 1'b1;
    assign s_arready = 1'b1;
    assign s_bresp   = 2'b00; // OKAY
    assign s_rresp   = 2'b00; // OKAY

    // Latch write address
    always @(posedge aclk) begin
        if (!aresetn) begin
            wr_addr_lat <= 0;
        end else if (s_awvalid && s_awready) begin
            wr_addr_lat <= s_awaddr;
        end
    end

    wire [ADDR_WIDTH-1:0] wr_addr = (s_awvalid && s_awready) ? s_awaddr : wr_addr_lat;

    // Write Response Channel
    always @(posedge aclk) begin
        if (!aresetn) begin
            s_bvalid <= 1'b0;
        end else if (s_wvalid && s_wready) begin
            s_bvalid <= 1'b1;
        end else if (s_bready && s_bvalid) begin
            s_bvalid <= 1'b0;
        end
    end

    // =========================================================================
    // CSR Write Logic
    // =========================================================================
    integer b;
    always @(posedge aclk) begin
        if (!aresetn) begin
            reg_ctrl           <= 0;
            reg_weight_base    <= 0;
            reg_act_base       <= 0;
            reg_out_base       <= 0;
            reg_layer_cfg0     <= 32'h03_00_01_01; // Default: ReLU, pad=0, stride=1, K=1
            reg_layer_cfg1     <= 0;
            reg_layer_cfg2     <= 0;
            reg_irq_ctrl       <= 0;
            reg_m0             <= 0;
            reg_n_shift        <= 0;
            reg_bias           <= 0;
            reg_conf_threshold <= 32'h00000020; // Default threshold = 32
            reg_crop_xy        <= 0;
            reg_crop_wh        <= 0;
            
            // Extended resets
            reg_stride_sel     <= 32'b0;
            reg_act_ext        <= 32'b0;
            reg_pool_mode      <= 32'b0;
            reg_array_rows     <= 32'd20; // reset = 20 for TinyNPU200
            reg_frame_w        <= 16'd1280;
            reg_frame_h        <= 16'd720;
            reg_num_tiles      <= 32'd0; 
        end else begin
            // START and SOFT_RESET are self-clearing single-cycle pulses
            reg_ctrl[0] <= 1'b0;
            reg_ctrl[1] <= 1'b0;

            if (s_wvalid && s_wready) begin
                for (b = 0; b < DATA_WIDTH/8; b = b + 1) begin
                    if (s_wstrb[b]) begin
                        case (wr_addr[7:0])
                            ADDR_CTRL:           reg_ctrl[b*8 +: 8]           <= s_wdata[b*8 +: 8];
                            ADDR_WEIGHT_BASE:    reg_weight_base[b*8 +: 8]    <= s_wdata[b*8 +: 8];
                            ADDR_ACT_BASE:       reg_act_base[b*8 +: 8]       <= s_wdata[b*8 +: 8];
                            ADDR_OUT_BASE:       reg_out_base[b*8 +: 8]       <= s_wdata[b*8 +: 8];
                            ADDR_LAYER_CFG_0:    reg_layer_cfg0[b*8 +: 8]     <= s_wdata[b*8 +: 8];
                            ADDR_LAYER_CFG_1:    reg_layer_cfg1[b*8 +: 8]     <= s_wdata[b*8 +: 8];
                            ADDR_LAYER_CFG_2:    reg_layer_cfg2[b*8 +: 8]     <= s_wdata[b*8 +: 8];
                            ADDR_IRQ_CTRL:       reg_irq_ctrl[b*8 +: 8]       <= s_wdata[b*8 +: 8];
                            ADDR_M0_CFG:         reg_m0[b*8 +: 8]             <= s_wdata[b*8 +: 8];
                            ADDR_SHIFT_CFG:      reg_n_shift[b*8 +: 8]        <= s_wdata[b*8 +: 8];
                            ADDR_BIAS_CFG:       reg_bias[b*8 +: 8]           <= s_wdata[b*8 +: 8];
                            ADDR_CONF_THRESHOLD: reg_conf_threshold[b*8 +: 8] <= s_wdata[b*8 +: 8];
                            ADDR_CROP_XY:        reg_crop_xy[b*8 +: 8]        <= s_wdata[b*8 +: 8];
                            ADDR_CROP_WH:        reg_crop_wh[b*8 +: 8]        <= s_wdata[b*8 +: 8];
                            // Extended registers
                            ADDR_STRIDE_SEL:     reg_stride_sel[b*8 +: 8]     <= s_wdata[b*8 +: 8];
                            ADDR_ACT_EXT:        reg_act_ext[b*8 +: 8]        <= s_wdata[b*8 +: 8];
                            ADDR_POOL_MODE:      reg_pool_mode[b*8 +: 8]      <= s_wdata[b*8 +: 8];
                            ADDR_ARRAY_ROWS:     reg_array_rows[b*8 +: 8]     <= s_wdata[b*8 +: 8];
                            ADDR_INPUT_FMT:      reg_input_fmt[b*8 +: 8]      <= s_wdata[b*8 +: 8];
                            ADDR_FRAME_W:        reg_frame_w[b*8 +: 8]        <= s_wdata[b*8 +: 8];
                            ADDR_FRAME_H:        reg_frame_h[b*8 +: 8]        <= s_wdata[b*8 +: 8];
                            ADDR_NUM_TILES:      reg_num_tiles[b*8 +: 8]      <= s_wdata[b*8 +: 8];
                            default: ; // Read-only or unmapped
                        endcase
                    end
                end
            end
        end
    end

    // =========================================================================
    // CSR Read Logic
    // =========================================================================
    always @(posedge aclk) begin
        if (!aresetn) begin
            s_rvalid <= 1'b0;
            s_rdata  <= 0;
        end else if (s_arvalid && s_arready) begin
            s_rvalid <= 1'b1;
            case (s_araddr[7:0])
                ADDR_CTRL:            s_rdata <= reg_ctrl;
                ADDR_STATUS:          s_rdata <= {28'b0, status_error, status_done, status_busy, status_idle};
                ADDR_WEIGHT_BASE:     s_rdata <= reg_weight_base;
                ADDR_ACT_BASE:        s_rdata <= reg_act_base;
                ADDR_OUT_BASE:        s_rdata <= reg_out_base;
                ADDR_LAYER_CFG_0:     s_rdata <= reg_layer_cfg0;
                ADDR_LAYER_CFG_1:     s_rdata <= reg_layer_cfg1;
                ADDR_LAYER_CFG_2:     s_rdata <= reg_layer_cfg2;
                ADDR_PERF_CYCLE_LO:   s_rdata <= perf_cycle_count[31:0];
                ADDR_PERF_CYCLE_HI:   s_rdata <= perf_cycle_count[63:32];
                ADDR_IRQ_CTRL:        s_rdata <= reg_irq_ctrl;
                ADDR_M0_CFG:          s_rdata <= reg_m0;
                ADDR_SHIFT_CFG:       s_rdata <= reg_n_shift;
                ADDR_BIAS_CFG:        s_rdata <= reg_bias;
                ADDR_PERF_COMPUTE_LO: s_rdata <= perf_compute_count[31:0];
                ADDR_PERF_COMPUTE_HI: s_rdata <= perf_compute_count[63:32];
                ADDR_PERF_DMA_STALL:  s_rdata <= perf_dma_stall_count;
                ADDR_PERF_OUT_STALL:  s_rdata <= perf_out_stall_count;
                ADDR_CONF_THRESHOLD:  s_rdata <= reg_conf_threshold;
                ADDR_CROP_XY:         s_rdata <= reg_crop_xy;
                ADDR_CROP_WH:         s_rdata <= reg_crop_wh;
                // Extended registers
                ADDR_STRIDE_SEL:      s_rdata <= reg_stride_sel;
                ADDR_ACT_EXT:         s_rdata <= reg_act_ext;
                ADDR_POOL_MODE:       s_rdata <= reg_pool_mode;
                ADDR_ARRAY_ROWS:      s_rdata <= reg_array_rows;
                ADDR_INPUT_FMT:       s_rdata <= reg_input_fmt;
                ADDR_FRAME_W:         s_rdata <= reg_frame_w;
                ADDR_FRAME_H:         s_rdata <= reg_frame_h;
                ADDR_NUM_TILES:       s_rdata <= reg_num_tiles;
                ADDR_VID_LOCKED:      s_rdata <= {31'b0, vid_locked};
                ADDR_TILE_COUNT:      s_rdata <= tile_count;
                ADDR_VERSION:         s_rdata <= 32'h02000001; // TinyNPU v2.0.1
                ADDR_FEATURE_FLAGS:   s_rdata <= 32'h0000007F; // capability bitmask
                default:              s_rdata <= 32'hDEADBEEF;
            endcase
        end else if (s_rvalid && s_rready) begin
            s_rvalid <= 1'b0;
        end
    end

    // =========================================================================
    // Output Mapping
    // =========================================================================
    assign csr_start           = reg_ctrl[0];
    assign csr_soft_reset      = reg_ctrl[1];
    assign csr_layer_type      = reg_ctrl[2];  // 0=standard, 1=depthwise
    assign csr_cosine_sim_mode = reg_ctrl[3];  // 1=cosine similarity mode
    assign csr_wgt_bank_sel    = reg_ctrl[4];  // 0=bank0 active, 1=bank1 active

    assign csr_weight_base     = reg_weight_base;
    assign csr_act_base        = reg_act_base;
    assign csr_out_base        = reg_out_base;

    assign csr_kernel_size     = reg_layer_cfg0[7:0];
    assign csr_stride          = reg_layer_cfg0[15:8];
    assign csr_padding         = reg_layer_cfg0[23:16];
    assign csr_act_sel         = reg_layer_cfg0[25:24];

    assign csr_in_channels     = reg_layer_cfg1[15:0];
    assign csr_out_channels    = reg_layer_cfg1[31:16];

    assign csr_input_width     = reg_layer_cfg2[15:0];
    assign csr_input_height    = reg_layer_cfg2[31:16];

    assign csr_irq_en          = reg_irq_ctrl[0];
    assign csr_m0              = reg_m0;
    assign csr_n_shift         = reg_n_shift;
    assign csr_bias            = reg_bias;

    assign csr_conf_threshold  = reg_conf_threshold[7:0];
    assign csr_crop_x          = reg_crop_xy[15:0];
    assign csr_crop_y          = reg_crop_xy[31:16];
    assign csr_crop_w          = reg_crop_wh[15:0];
    assign csr_crop_h          = reg_crop_wh[31:16];

    // Extended outputs
    assign csr_stride_sel      = reg_stride_sel[1:0];
    assign csr_act_ext         = reg_act_ext[2:0];
    assign csr_pool_mode       = reg_pool_mode[1:0];
    assign csr_array_rows      = reg_array_rows[4:0];
    assign csr_input_fmt       = reg_input_fmt[1:0];
    assign csr_frame_w         = reg_frame_w[15:0];
    assign csr_frame_h         = reg_frame_h[15:0];
    assign csr_num_tiles_x     = reg_num_tiles[15:0];
    assign csr_num_tiles_y     = reg_num_tiles[31:16];

endmodule
