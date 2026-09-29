// =============================================================================
// Module: pl_top.v  
// Project: TinyNPU — PL-Only Top Level (No PS in critical path)
// Description:
//   Complete PL-side inference pipeline:
//
//   frame_gen → [tinynpu_top] → result_buffer → GPIO output
//
//   The PS ARM connects ONLY for:
//     - AXI-Lite config (one-time setup, not time-critical)
//     - Reading detection results from result_buffer
//
//   Critical latency path is ENTIRELY in PL:
//     frame_gen → NPU → bbox_decoder → threshold_filter → result_buffer
//
//   Target: <10µs end-to-end @ 100MHz
//
// Ports exposed to PS via AXI-Lite:
//   - NPU config registers (forwarded to tinynpu_top.s_axi)
//   - frame_gen enable/single_shot control
//   - Detection result readout
//
// Verilog-2001. ASIC-portable.
// =============================================================================

`timescale 1ns / 1ps

module pl_top #(
    parameter IMG_WIDTH  = 160,
    parameter IMG_HEIGHT = 160,
    parameter CHANNELS   = 1,
    parameter NUM_CLASSES = 1    // 1 = bullet/projectile only
) (
    // Clock & Reset (from PS FCLK or external PLL)
    input  wire        clk,
    input  wire        rst_n,

    // ---- AXI-Lite from PS (config only, not in critical path) ----
    // NPU AXI-Lite (forwarded to tinynpu_top)
    input  wire [31:0] s_axi_awaddr,
    input  wire        s_axi_awvalid,
    output wire        s_axi_awready,
    input  wire [31:0] s_axi_wdata,
    input  wire [3:0]  s_axi_wstrb,
    input  wire        s_axi_wvalid,
    output wire        s_axi_wready,
    output wire [1:0]  s_axi_bresp,
    output wire        s_axi_bvalid,
    input  wire        s_axi_bready,
    input  wire [31:0] s_axi_araddr,
    input  wire        s_axi_arvalid,
    output wire        s_axi_arready,
    output wire [31:0] s_axi_rdata,
    output wire [1:0]  s_axi_rresp,
    output wire        s_axi_rvalid,
    input  wire        s_axi_rready,

    // ---- PL Control (from PS GPIO or internal logic) ----
    input  wire        gen_enable,      // 1 = stream frames continuously
    input  wire        gen_single_shot, // Pulse = send one frame

    // ---- Detection Results (to PS via AXI or direct BRAM) ----
    output wire [31:0] det_bbox_x,      // Bounding box X (fixed point)
    output wire [31:0] det_bbox_y,      // Bounding box Y
    output wire [31:0] det_bbox_w,      // Width
    output wire [31:0] det_bbox_h,      // Height
    output wire [7:0]  det_confidence,  // Detection confidence (UINT8)
    output wire        det_valid,       // 1 = new detection available
    output wire [31:0] det_latency_cycles, // Latency in clock cycles

    // ---- Status ----
    output wire [31:0] frame_count,
    output wire        interrupt         // Pulse to PS IRQ when detection found
);

    // =========================================================================
    // Internal wires
    // =========================================================================

    // frame_gen → NPU AXI-Stream
    wire [7:0]  gen_tdata;
    wire        gen_tvalid;
    wire        gen_tlast;
    wire        gen_tready;
    wire        frame_done_pulse;

    // NPU → output AXI-Stream
    wire [31:0] npu_m_axis_tdata;
    wire        npu_m_axis_tvalid;
    wire        npu_m_axis_tlast;
    wire        npu_m_axis_tready;

    // NPU AXI master (weight fetch — connects to internal BRAM or DDR)
    wire [31:0] npu_m_axi_araddr;
    wire        npu_m_axi_arvalid;
    wire        npu_m_axi_arready;
    wire [31:0] npu_m_axi_rdata;
    wire [1:0]  npu_m_axi_rresp;
    wire        npu_m_axi_rvalid;
    wire        npu_m_axi_rready;
    wire [31:0] npu_m_axi_awaddr;
    wire        npu_m_axi_awvalid;
    wire        npu_m_axi_awready;
    wire [31:0] npu_m_axi_wdata;
    wire [3:0]  npu_m_axi_wstrb;
    wire        npu_m_axi_wvalid;
    wire        npu_m_axi_wready;
    wire [1:0]  npu_m_axi_bresp;
    wire        npu_m_axi_bvalid;
    wire        npu_m_axi_bready;

    // Latency timer
    reg [31:0]  latency_timer;
    reg         timer_running;
    reg [31:0]  latency_captured;

    // =========================================================================
    // STEP 1: Frame Generator (PL-side, no PS needed)
    // =========================================================================
    frame_gen #(
        .IMG_WIDTH  (IMG_WIDTH),
        .IMG_HEIGHT (IMG_HEIGHT),
        .CHANNELS   (CHANNELS),
        .BAR_WIDTH  (16),
        .BAR_SPEED  (2)
    ) u_frame_gen (
        .clk            (clk),
        .rst_n          (rst_n),
        .enable         (gen_enable),
        .single_shot    (gen_single_shot),
        .m_axis_tdata   (gen_tdata),
        .m_axis_tvalid  (gen_tvalid),
        .m_axis_tlast   (gen_tlast),
        .m_axis_tready  (gen_tready),
        .frame_count    (frame_count),
        .frame_done     (frame_done_pulse)
    );

    // =========================================================================
    // STEP 2: TinyNPU Core
    // =========================================================================
    tinynpu_top u_npu (
        .clk            (clk),
        .rst_n          (rst_n),

        // AXI-Lite control (from PS, for config only)
        .s_axi_awaddr   (s_axi_awaddr),
        .s_axi_awvalid  (s_axi_awvalid),
        .s_axi_awready  (s_axi_awready),
        .s_axi_wdata    (s_axi_wdata),
        .s_axi_wstrb    (s_axi_wstrb),
        .s_axi_wvalid   (s_axi_wvalid),
        .s_axi_wready   (s_axi_wready),
        .s_axi_bresp    (s_axi_bresp),
        .s_axi_bvalid   (s_axi_bvalid),
        .s_axi_bready   (s_axi_bready),
        .s_axi_araddr   (s_axi_araddr),
        .s_axi_arvalid  (s_axi_arvalid),
        .s_axi_arready  (s_axi_arready),
        .s_axi_rdata    (s_axi_rdata),
        .s_axi_rresp    (s_axi_rresp),
        .s_axi_rvalid   (s_axi_rvalid),
        .s_axi_rready   (s_axi_rready),

        // AXI-Stream input: from frame_gen (PL direct, no DMA)
        .s_axis_tdata   (gen_tdata),
        .s_axis_tvalid  (gen_tvalid),
        .s_axis_tlast   (gen_tlast),
        .s_axis_tready  (gen_tready),

        // AXI-Stream output: detection results
        .m_axis_tdata   (npu_m_axis_tdata),
        .m_axis_tvalid  (npu_m_axis_tvalid),
        .m_axis_tlast   (npu_m_axis_tlast),
        .m_axis_tready  (npu_m_axis_tready),

        // AXI master: weight memory access
        .m_axi_araddr   (npu_m_axi_araddr),
        .m_axi_arvalid  (npu_m_axi_arvalid),
        .m_axi_arready  (npu_m_axi_arready),
        .m_axi_rdata    (npu_m_axi_rdata),
        .m_axi_rresp    (npu_m_axi_rresp),
        .m_axi_rvalid   (npu_m_axi_rvalid),
        .m_axi_rready   (npu_m_axi_rready),
        .m_axi_awaddr   (npu_m_axi_awaddr),
        .m_axi_awvalid  (npu_m_axi_awvalid),
        .m_axi_awready  (npu_m_axi_awready),
        .m_axi_wdata    (npu_m_axi_wdata),
        .m_axi_wstrb    (npu_m_axi_wstrb),
        .m_axi_wvalid   (npu_m_axi_wvalid),
        .m_axi_wready   (npu_m_axi_wready),
        .m_axi_bresp    (npu_m_axi_bresp),
        .m_axi_bvalid   (npu_m_axi_bvalid),
        .m_axi_bready   (npu_m_axi_bready),

        .interrupt      (interrupt)
    );

    // =========================================================================
    // STEP 3: Result Capture — parse NPU output stream
    //         NPU outputs: [x(32), y(32), w(32), h(32), conf(8)] = 17 bytes
    // =========================================================================
    result_capture u_result (
        .clk             (clk),
        .rst_n           (rst_n),
        .s_axis_tdata    (npu_m_axis_tdata),
        .s_axis_tvalid   (npu_m_axis_tvalid),
        .s_axis_tlast    (npu_m_axis_tlast),
        .s_axis_tready   (npu_m_axis_tready),
        .det_bbox_x      (det_bbox_x),
        .det_bbox_y      (det_bbox_y),
        .det_bbox_w      (det_bbox_w),
        .det_bbox_h      (det_bbox_h),
        .det_confidence  (det_confidence),
        .det_valid       (det_valid)
    );

    // =========================================================================
    // STEP 4: Hardware Latency Timer (cycle-accurate)
    // =========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            latency_timer    <= 0;
            timer_running    <= 0;
            latency_captured <= 0;
        end else begin
            // Start timer when frame begins (first pixel)
            if (gen_tvalid && gen_tready && (frame_count != 0 || gen_tvalid))
                timer_running <= 1;

            // Stop timer when detection result arrives
            if (det_valid) begin
                latency_captured <= latency_timer;
                latency_timer    <= 0;
                timer_running    <= 0;
            end else if (timer_running) begin
                latency_timer <= latency_timer + 1;
            end
        end
    end

    assign det_latency_cycles = latency_captured;

endmodule
