// -----------------------------------------------------------------------------
// File        : hw_scoreboard.v
// Description : Synthesizable hardware scoreboard for TinyNPU v3.0.
//               Compares DUT output against a preloaded golden memory.
// -----------------------------------------------------------------------------

module hw_scoreboard #(
    parameter GOLDEN_DEPTH   = 512,
    parameter CONF_THRESHOLD = 8'd128,
    parameter BBOX_BYTES     = 8
)(
    input  wire        clk,
    input  wire        rst_n,

    // Status from DUT
    input  wire        frame_done,

    // DUT output stream to check
    input  wire        m_axis_tvalid,
    input  wire        m_axis_tready,
    input  wire  [7:0] m_axis_tdata,

    // Counter outputs
    output reg  [31:0] sb_bytes_checked,
    output reg  [31:0] sb_bytes_correct,
    output reg  [31:0] sb_bytes_wrong,
    output reg  [31:0] sb_true_positives,
    output reg  [31:0] sb_true_negatives,
    output reg  [31:0] sb_false_positives,
    output reg  [31:0] sb_false_negatives,

    // Status outputs
    output reg         sb_pass,
    output reg         sb_fail,
    output reg  [15:0] sb_precision_x100,
    output reg  [15:0] sb_recall_x100,
    output reg  [15:0] sb_accuracy_x100
);

    // -------------------------------------------------------------------------
    // Golden Memory
    // -------------------------------------------------------------------------
    reg [7:0] golden_mem [0:GOLDEN_DEPTH-1];

`ifndef SYNTHESIS
    integer i;
    reg mem_ok;
    initial begin
        $readmemh("golden_output.hex", golden_mem);
        mem_ok = 0;
        for (i = 0; i < GOLDEN_DEPTH; i = i + 1) begin
            if (golden_mem[i] !== 8'hxx) mem_ok = 1;
        end
        if (!mem_ok) begin
            $fatal(1, "Golden memory failed to load or is all zero/xx!");
        end
    end
`endif

    // -------------------------------------------------------------------------
    // Checking Logic
    // -------------------------------------------------------------------------
    reg [31:0] ptr;
    wire [7:0] expected = golden_mem[ptr];

    wire is_valid_txn = m_axis_tvalid & m_axis_tready;
    wire is_match     = (m_axis_tdata == expected);
    wire dut_pos      = (m_axis_tdata >= CONF_THRESHOLD);
    wire exp_pos      = (expected >= CONF_THRESHOLD);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sb_bytes_checked   <= 32'd0;
            sb_bytes_correct   <= 32'd0;
            sb_bytes_wrong     <= 32'd0;
            sb_true_positives  <= 32'd0;
            sb_true_negatives  <= 32'd0;
            sb_false_positives <= 32'd0;
            sb_false_negatives <= 32'd0;
            sb_pass            <= 1'b1;
            sb_fail            <= 1'b0;
            sb_precision_x100  <= 16'd0;
            sb_recall_x100     <= 16'd0;
            sb_accuracy_x100   <= 16'd0;
            ptr                <= 32'd0;
        end else begin
            if (is_valid_txn) begin
                sb_bytes_checked <= sb_bytes_checked + 1'b1;

                if (is_match) begin
                    sb_bytes_correct <= sb_bytes_correct + 1'b1;
                end else begin
                    sb_bytes_wrong <= sb_bytes_wrong + 1'b1;
                    sb_pass <= 1'b0;
                    sb_fail <= 1'b1;
`ifndef SYNTHESIS
                    $error("Mismatch at byte address %0d: Expected %0h, Got %0h", ptr, expected, m_axis_tdata);
`endif
                end

                if (dut_pos && exp_pos)
                    sb_true_positives <= sb_true_positives + 1'b1;
                else if (!dut_pos && !exp_pos)
                    sb_true_negatives <= sb_true_negatives + 1'b1;
                else if (dut_pos && !exp_pos)
                    sb_false_positives <= sb_false_positives + 1'b1;
                else if (!dut_pos && exp_pos)
                    sb_false_negatives <= sb_false_negatives + 1'b1;

                if (ptr < GOLDEN_DEPTH - 1)
                    ptr <= ptr + 1'b1;
                else
                    ptr <= 32'd0;
            end

            // Update stats when frame_done
            if (frame_done) begin
                if ((sb_true_positives + sb_false_positives) > 0)
                    sb_precision_x100 <= (sb_true_positives * 10000) / (sb_true_positives + sb_false_positives);

                if ((sb_true_positives + sb_false_negatives) > 0)
                    sb_recall_x100 <= (sb_true_positives * 10000) / (sb_true_positives + sb_false_negatives);

                if ((sb_true_positives + sb_true_negatives + sb_false_positives + sb_false_negatives) > 0)
                    sb_accuracy_x100 <= ((sb_true_positives + sb_true_negatives) * 10000) / (sb_true_positives + sb_true_negatives + sb_false_positives + sb_false_negatives);
            end
        end
    end

    // -------------------------------------------------------------------------
    // Simulation-only display block
    // -------------------------------------------------------------------------
`ifndef SYNTHESIS
    always @(posedge clk) begin
        if (frame_done && rst_n) begin
            $display("================================================================");
            $display("TinyNPU HARDWARE SCOREBOARD REPORT");
            $display("================================================================");
            $display("Bytes Checked   : %0d", sb_bytes_checked);
            $display("Correct         : %0d  (%.2f%%)", sb_bytes_correct, (sb_bytes_correct * 100.0) / (sb_bytes_checked > 0 ? sb_bytes_checked : 1));
            $display("Wrong           : %0d", sb_bytes_wrong);
            $display("True Positives  : %0d", sb_true_positives);
            $display("True Negatives  : %0d", sb_true_negatives);
            $display("False Positives : %0d", sb_false_positives);
            $display("False Negatives : %0d", sb_false_negatives);
            $display("Precision       : %.2f%%", sb_precision_x100 / 100.0);
            $display("Recall          : %.2f%%", sb_recall_x100 / 100.0);
            $display("Detection Acc   : %.2f%%", sb_accuracy_x100 / 100.0);
            $display("OVERALL: %s", sb_fail ? "FAIL" : "PASS");
            $display("================================================================");
        end
    end
`endif

endmodule
