// -----------------------------------------------------------------------------
// File        : perf_monitor.v
// Description : Synthesizable hardware performance monitor for TinyNPU v3.0.
//               Tracks cycles, stalls, compute efficiency, and estimates GOPS.
// -----------------------------------------------------------------------------

module perf_monitor #(
    parameter ARRAY_ROWS         = 8,
    parameter ARRAY_COLS         = 8,
    parameter CLK_FREQ_MHZ       = 100,
    parameter ESTIMATED_POWER_MW = 850
)(
    input  wire        clk,
    input  wire        rst_n,

    // Control
    input  wire        csr_perf_clear,

    // Status from DUT
    input  wire        status_busy,
    input  wire        status_done,
    input  wire        status_idle,
    input  wire        status_error,

    // Activity indicators
    input  wire        array_en,
    input  wire        dma_active,

    // AXI-Stream interfaces
    input  wire        s_axis_tvalid,
    input  wire        s_axis_tready,
    input  wire        m_axis_tvalid,
    input  wire        m_axis_tready,

    // Counter outputs
    output reg  [63:0] perf_total_cycles,
    output reg  [63:0] perf_busy_cycles,
    output reg  [63:0] perf_compute_cycles,
    output reg  [31:0] perf_dma_cycles,
    output reg  [31:0] perf_in_stall_cycles,
    output reg  [31:0] perf_out_stall_cycles,
    output reg  [31:0] perf_frame_count,
    output reg  [63:0] perf_mac_ops,
    output reg  [7:0]  perf_pipeline_efficiency,

    // Derived metrics
    output reg  [31:0] perf_latency_cycles,
    output reg  [31:0] perf_fps_x100,
    output reg  [31:0] perf_gops_x100,
    output reg  [31:0] perf_mbw_x100
);

    // -------------------------------------------------------------------------
    // Internal Signals
    // -------------------------------------------------------------------------
    reg [31:0] current_frame_cycles;
    reg        last_idle;
    wire       frame_start = status_busy & last_idle;

    // -------------------------------------------------------------------------
    // Synchronous Logic
    // -------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            perf_total_cycles        <= 64'd0;
            perf_busy_cycles         <= 64'd0;
            perf_compute_cycles      <= 64'd0;
            perf_dma_cycles          <= 32'd0;
            perf_in_stall_cycles     <= 32'd0;
            perf_out_stall_cycles    <= 32'd0;
            perf_frame_count         <= 32'd0;
            perf_mac_ops             <= 64'd0;
            perf_pipeline_efficiency <= 8'd0;

            current_frame_cycles     <= 32'd0;
            last_idle                <= 1'b1;

            perf_latency_cycles      <= 32'd0;
            perf_fps_x100            <= 32'd0;
            perf_gops_x100           <= 32'd0;
            perf_mbw_x100            <= 32'd0;
        end else if (csr_perf_clear) begin
            perf_total_cycles        <= 64'd0;
            perf_busy_cycles         <= 64'd0;
            perf_compute_cycles      <= 64'd0;
            perf_dma_cycles          <= 32'd0;
            perf_in_stall_cycles     <= 32'd0;
            perf_out_stall_cycles    <= 32'd0;
            perf_frame_count         <= 32'd0;
            perf_mac_ops             <= 64'd0;
            perf_pipeline_efficiency <= 8'd0;

            current_frame_cycles     <= 32'd0;
            last_idle                <= 1'b1;

            perf_latency_cycles      <= 32'd0;
            perf_fps_x100            <= 32'd0;
            perf_gops_x100           <= 32'd0;
            perf_mbw_x100            <= 32'd0;
        end else begin
            last_idle <= status_idle;

            // Free running counter
            perf_total_cycles <= perf_total_cycles + 1'b1;

            if (status_busy) begin
                perf_busy_cycles <= perf_busy_cycles + 1'b1;
                current_frame_cycles <= current_frame_cycles + 1'b1;
            end

            if (frame_start) begin
                current_frame_cycles <= 32'd1;
            end

            if (array_en) begin
                perf_compute_cycles <= perf_compute_cycles + 1'b1;
                perf_mac_ops <= perf_mac_ops + (ARRAY_ROWS * ARRAY_COLS * 2);
            end

            if (dma_active) begin
                perf_dma_cycles <= perf_dma_cycles + 1'b1;
            end

            if (s_axis_tvalid && !s_axis_tready) begin
                perf_in_stall_cycles <= perf_in_stall_cycles + 1'b1;
            end

            if (m_axis_tvalid && !m_axis_tready) begin
                perf_out_stall_cycles <= perf_out_stall_cycles + 1'b1;
            end

            if (status_done) begin
                perf_frame_count <= perf_frame_count + 1'b1;
                perf_latency_cycles <= current_frame_cycles;

                if (perf_total_cycles > 0) begin
                    // Q0.8 fraction of busy cycles
                    perf_pipeline_efficiency <= (perf_busy_cycles * 255) / perf_total_cycles;
                end

                if (current_frame_cycles > 0) begin
                    // FPS scaled by 100
                    perf_fps_x100 <= (CLK_FREQ_MHZ * 100000000) / current_frame_cycles;
                    // GOPS scaled by 100
                    perf_gops_x100 <= (perf_mac_ops * CLK_FREQ_MHZ) / (current_frame_cycles * 10);
                end
            end
        end
    end

    // -------------------------------------------------------------------------
    // Simulation-only display block
    // -------------------------------------------------------------------------
`ifndef SYNTHESIS
    real total_cyc_r;
    real busy_cyc_r;
    real comp_cyc_r;
    real dma_cyc_r;
    real fps_r;
    real gops_r;
    real latency_us_r;
    real gops_w_r;

    always @(posedge clk) begin
        if (status_done && rst_n && !csr_perf_clear) begin
            total_cyc_r = perf_total_cycles;
            busy_cyc_r = perf_busy_cycles;
            comp_cyc_r = perf_compute_cycles;
            dma_cyc_r = perf_dma_cycles;

            latency_us_r = current_frame_cycles / (CLK_FREQ_MHZ * 1.0);
            fps_r = 1000000.0 / latency_us_r;
            gops_r = (perf_mac_ops * 1.0 / current_frame_cycles) * (CLK_FREQ_MHZ / 1000.0);
            gops_w_r = gops_r / (ESTIMATED_POWER_MW / 1000.0);

            $display("================================================================");
            $display("TinyNPU PERFORMANCE REPORT — Frame #%0d", perf_frame_count + 1);
            $display("================================================================");
            $display("Total Cycles    : %0d", perf_total_cycles);
            $display("Busy Cycles     : %0d  (%.1f%%)", perf_busy_cycles, (busy_cyc_r/total_cyc_r)*100.0);
            $display("Compute Cycles  : %0d  (%.1f%%)", perf_compute_cycles, (comp_cyc_r/total_cyc_r)*100.0);
            $display("DMA Cycles      : %0d  (%.1f%%)", perf_dma_cycles, (dma_cyc_r/total_cyc_r)*100.0);
            $display("Input Stalls    : %0d", perf_in_stall_cycles);
            $display("Output Stalls   : %0d", perf_out_stall_cycles);
            $display("MAC Ops (est)   : %0d", perf_mac_ops);
            $display("Latency         : %.1f us", latency_us_r);
            $display("Throughput      : %.1f FPS", fps_r);
            $display("GOPS (est)      : %.2f GOPS", gops_r);
            $display("GOPS/W (est)    : %.2f GOPS/W @ %0d mW", gops_w_r, ESTIMATED_POWER_MW);
            $display("Pipeline Eff.   : %.1f%%", (perf_pipeline_efficiency * 100.0) / 255.0);
            $display("================================================================");
        end
    end
`endif

endmodule
