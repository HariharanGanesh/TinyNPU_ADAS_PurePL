// =============================================================================
// Module: npu_controller.v
// Project: TinyNPU
// Description:
//   Main Control FSM and Address Generator for TinyNPU.
//   Orchestrates weight loading, activation streaming, systolic computation,
//   output draining, and DMA store operations.
//
//   ADDITIONS:
//   1. Zero-Padding Generator: tracks spatial (x, y) coordinates and asserts
//      pad_active when the current position falls inside a padding boundary.
//      The top-level mux forces activation inputs to zero when pad_active is
//      high, eliminating the need to store padded frames in memory.
//   2. Granular Performance Counters: separate 64-bit compute_cycle_count and
//      32-bit dma_stall_count / out_stall_count for bottleneck profiling.
//   3. Cosine Similarity Mode: when csr_cosine_sim_mode is high, skips
//      weight loading (uses pre-loaded embedding templates from weight bank)
//      and bypasses padding logic for 1D vector comparison.
//
//   Verilog-2001 Synthesizable RTL.
// =============================================================================

`timescale 1ns / 1ps

module npu_controller #(
    parameter ADDR_WIDTH = 10,
    parameter DATA_WIDTH = 8,
    parameter ARRAY_ROWS = 8,
    parameter ARRAY_COLS = 8
) (
    input  wire                         clk,
    input  wire                         rst_n,

    // Control from AXI Lite CSR
    input  wire                         csr_start,
    input  wire                         csr_soft_reset,
    input  wire [7:0]                   csr_kernel_size,
    input  wire [7:0]                   csr_stride,
    input  wire [7:0]                   csr_padding,
    input  wire [1:0]                   csr_act_sel,
    input  wire [15:0]                  csr_in_channels,
    input  wire [15:0]                  csr_out_channels,
    input  wire [15:0]                  csr_input_width,
    input  wire [15:0]                  csr_input_height,
    input  wire                         csr_cosine_sim_mode, // 1=cosine/embedding mode

    // Status to CSR / top-level
    output reg                          status_idle,
    output reg                          status_busy,
    output reg                          status_done,
    output reg                          status_error,

    // Performance counters (read back via AXI-Lite)
    output reg  [63:0]                  perf_cycle_count,
    output reg  [63:0]                  perf_compute_count,
    output reg  [31:0]                  perf_dma_stall_count,
    output reg  [31:0]                  perf_out_stall_count,

    // DMA Interface Control
    output reg                          dma_start_load_wgt,
    output reg                          dma_start_load_act,
    output reg                          dma_start_store_out,
    output reg  [15:0]                  dma_transfer_size,
    input  wire                         dma_wgt_load_done,
    input  wire                         dma_act_load_done,
    input  wire                         dma_out_store_done,

    // Buffer Controls
    output reg                          wgt_buf_load_tile,
    input  wire                         wgt_buf_load_complete,

    output reg  [ADDR_WIDTH-1:0]        act_buf_rd_addr,
    output reg                          act_buf_rd_en,
    output reg                          act_buf_swap,

    // Systolic Array Control
    output reg                          array_en,
    output reg                          array_psum_clear,
    output reg                          array_weight_load,

    // Zero-Padding: forces array inputs to zero when asserted
    output reg                          pad_active,

    // Post-Processing Control
    output reg                          requant_acc_valid,
    output reg                          pool_enable,
    output reg                          out_buf_wr_en,
    input  wire                         out_buf_full,

    // AXI Stream output backpressure monitoring (for out_stall counter)
    input  wire                         m_axis_tready
);

    // FSM States
    localparam STATE_IDLE      = 3'd0;
    localparam STATE_LOAD_WGT  = 3'd1;
    localparam STATE_LOAD_ACT  = 3'd2;
    localparam STATE_SETUP_WGT = 3'd3;
    localparam STATE_COMPUTE   = 3'd4;
    localparam STATE_DRAIN     = 3'd5;
    localparam STATE_STORE_OUT = 3'd6;
    localparam STATE_DONE      = 3'd7;

    reg [3:0] state;

    // Internal Compute Counters
    reg [15:0] compute_cycles;
    reg [15:0] total_compute_steps;
    reg [15:0] drain_cycles;

    // Spatial coordinate tracking for zero-padding
    reg [15:0] curr_x;
    reg [15:0] curr_y;

    // =========================================================================
    // Performance Counters
    // =========================================================================
    always @(posedge clk) begin
        if (!rst_n || csr_soft_reset) begin
            perf_cycle_count     <= 0;
            perf_compute_count   <= 0;
            perf_dma_stall_count <= 0;
            perf_out_stall_count <= 0;
        end else begin
            // Total busy cycles
            if (status_busy)
                perf_cycle_count <= perf_cycle_count + 1'b1;

            // Active compute cycles (STATE_COMPUTE only)
            if (state == STATE_COMPUTE && array_en)
                perf_compute_count <= perf_compute_count + 1'b1;

            // DMA weight stall: waiting for DMA during weight load
            if (state == STATE_LOAD_WGT && !dma_wgt_load_done)
                perf_dma_stall_count <= perf_dma_stall_count + 1'b1;

            // Output stall: output data valid but downstream not ready
            if (out_buf_wr_en && !m_axis_tready)
                perf_out_stall_count <= perf_out_stall_count + 1'b1;
        end
    end

    // =========================================================================
    // Zero-Padding: spatial coordinate tracking
    // Only active in conv mode (not cosine sim)
    // =========================================================================
    always @(posedge clk) begin
        if (!rst_n || csr_soft_reset || state == STATE_IDLE) begin
            curr_x <= 0;
            curr_y <= 0;
        end else if (state == STATE_COMPUTE && act_buf_rd_en) begin
            // Advance coordinate each time we read a new activation
            if (curr_x < csr_input_width - 1) begin
                curr_x <= curr_x + 1'b1;
            end else begin
                curr_x <= 0;
                curr_y <= curr_y + 1'b1;
            end
        end
    end

    // pad_active: high when current coordinates fall within padding border
    // Padding border: (0 <= x < pad) or (x >= width-pad) or same for y
    wire in_x_pad = (csr_padding > 0) &&
                    ((curr_x < csr_padding) ||
                     (curr_x >= (csr_input_width - csr_padding)));
    wire in_y_pad = (csr_padding > 0) &&
                    ((curr_y < csr_padding) ||
                     (curr_y >= (csr_input_height - csr_padding)));

    always @(posedge clk) begin
        if (!rst_n || csr_soft_reset || csr_cosine_sim_mode) begin
            pad_active <= 1'b0;
        end else begin
            pad_active <= (in_x_pad || in_y_pad);
        end
    end

    // =========================================================================
    // Main FSM
    // =========================================================================
    always @(posedge clk) begin
        if (!rst_n || csr_soft_reset) begin
            state               <= STATE_IDLE;
            status_idle         <= 1'b1;
            status_busy         <= 1'b0;
            status_done         <= 1'b0;
            status_error        <= 1'b0;
            dma_start_load_wgt  <= 1'b0;
            dma_start_load_act  <= 1'b0;
            dma_start_store_out <= 1'b0;
            dma_transfer_size   <= 0;
            wgt_buf_load_tile   <= 1'b0;
            act_buf_rd_addr     <= 0;
            act_buf_rd_en       <= 1'b0;
            act_buf_swap        <= 1'b0;
            array_en            <= 1'b0;
            array_psum_clear    <= 1'b0;
            array_weight_load   <= 1'b0;
            requant_acc_valid   <= 1'b0;
            pool_enable         <= 1'b0;
            out_buf_wr_en       <= 1'b0;
            compute_cycles      <= 0;
            total_compute_steps <= 0;
            drain_cycles        <= 0;
        end else begin
            // Default: deassert single-cycle pulses
            dma_start_load_wgt  <= 1'b0;
            dma_start_load_act  <= 1'b0;
            dma_start_store_out <= 1'b0;
            wgt_buf_load_tile   <= 1'b0;
            act_buf_swap        <= 1'b0;
            array_psum_clear    <= 1'b0;
            array_weight_load   <= 1'b0;
            out_buf_wr_en       <= 1'b0;

            case (state)
                STATE_IDLE: begin
                    status_idle <= 1'b1;
                    status_busy <= 1'b0;
                    if (csr_start) begin
                        status_idle       <= 1'b0;
                        status_busy       <= 1'b1;
                        status_done       <= 1'b0;

                        if (csr_cosine_sim_mode) begin
                            // In cosine-sim mode: weights (face templates) already
                            // loaded in weight bank. Skip DMA weight load — go
                            // straight to loading the embedding activation vector.
                            dma_transfer_size  <= csr_in_channels; // embedding dimension
                            dma_start_load_act <= 1'b1;
                            state              <= STATE_LOAD_ACT;
                        end else begin
                            dma_transfer_size  <= ARRAY_ROWS * ARRAY_COLS;
                            dma_start_load_wgt <= 1'b1;
                            state              <= STATE_LOAD_WGT;
                        end
                    end
                end

                STATE_LOAD_WGT: begin
                    if (dma_wgt_load_done) begin
                        dma_transfer_size  <= csr_input_width * csr_input_height;
                        dma_start_load_act <= 1'b1;
                        state              <= STATE_LOAD_ACT;
                    end
                end

                STATE_LOAD_ACT: begin
                    if (dma_act_load_done) begin
                        act_buf_swap      <= 1'b1;
                        wgt_buf_load_tile <= 1'b1;
                        state             <= STATE_SETUP_WGT;
                    end
                end

                STATE_SETUP_WGT: begin
                    if (wgt_buf_load_complete) begin
                        array_weight_load   <= 1'b1;
                        array_psum_clear    <= 1'b1;
                        compute_cycles      <= 0;
                        total_compute_steps <= csr_kernel_size * csr_kernel_size;
                        act_buf_rd_addr     <= 0;
                        act_buf_rd_en       <= 1'b1;
                        state               <= STATE_COMPUTE;
                    end
                end

                STATE_COMPUTE: begin
                    array_en <= 1'b1;
                    if (compute_cycles + 1'b1 < total_compute_steps) begin
                        compute_cycles  <= compute_cycles + 1'b1;
                        act_buf_rd_addr <= act_buf_rd_addr + 1'b1;
                        act_buf_rd_en   <= 1'b1;
                    end else begin
                        act_buf_rd_en <= 1'b0;
                        drain_cycles  <= 0;
                        state         <= STATE_DRAIN;
                    end
                end

                STATE_DRAIN: begin
                    array_en <= 1'b1;
                    if (drain_cycles < (ARRAY_ROWS + ARRAY_COLS + 8)) begin
                        drain_cycles      <= drain_cycles + 1'b1;
                        requant_acc_valid <= 1'b1;
                        out_buf_wr_en     <= 1'b1;
                    end else begin
                        array_en            <= 1'b0;
                        requant_acc_valid   <= 1'b0;
                        dma_transfer_size   <= csr_out_channels;
                        dma_start_store_out <= 1'b1;
                        state               <= STATE_STORE_OUT;
                    end
                end

                STATE_STORE_OUT: begin
                    if (dma_out_store_done) begin
                        state <= STATE_DONE;
                    end
                end

                STATE_DONE: begin
                    status_busy <= 1'b0;
                    status_done <= 1'b1;
                    state       <= STATE_IDLE;
                end

                default: state <= STATE_IDLE;
            endcase
        end
    end

endmodule
