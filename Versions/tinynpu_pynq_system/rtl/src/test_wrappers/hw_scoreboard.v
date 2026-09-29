`timescale 1ns / 1ps

module hw_scoreboard #(
    parameter DATA_WIDTH = 32,      // 4 bytes per cycle
    parameter NUM_OUTPUTS = 16,     // Number of expected words
    parameter GOLDEN_FILE = "golden_output.hex"
) (
    input  wire                   clk,
    input  wire                   rst_n,
    
    // AXI-Stream Slave Interface (from NPU)
    input  wire [DATA_WIDTH-1:0]  s_axis_tdata,
    input  wire                   s_axis_tvalid,
    output wire                   s_axis_tready,
    input  wire                   s_axis_tlast,
    
    // Status
    output reg                    test_done,
    output reg                    test_pass
);

    // Expected Memory
    reg [DATA_WIDTH-1:0] expected [0:NUM_OUTPUTS-1];
    
    initial begin
        // $readmemh(GOLDEN_FILE, expected); // Uncomment when golden hex is provided
    end

    reg [15:0] recv_cnt;
    reg        mismatch_found;
    
    assign s_axis_tready = !test_done;
    
    always @(posedge clk) begin
        if (!rst_n) begin
            recv_cnt       <= 0;
            mismatch_found <= 1'b0;
            test_done      <= 1'b0;
            test_pass      <= 1'b0;
        end else if (!test_done && s_axis_tvalid && s_axis_tready) begin
            // Compare
            if (s_axis_tdata != expected[recv_cnt]) begin
                mismatch_found <= 1'b1;
            end
            
            // Advance
            if (recv_cnt == NUM_OUTPUTS - 1 || s_axis_tlast) begin
                test_done <= 1'b1;
                // If it was matching so far, and this one matches too, it's a PASS
                test_pass <= !mismatch_found && (s_axis_tdata == expected[recv_cnt]);
            end else begin
                recv_cnt <= recv_cnt + 1'b1;
            end
        end
    end

endmodule
