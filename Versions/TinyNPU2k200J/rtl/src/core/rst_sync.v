// -----------------------------------------------------------------------------
// File        : rst_sync.v
// Description : Synchronous reset synchronizer.
//               This module implements a standard FF chain synchronizer for
//               asynchronous reset inputs. The output deasserts synchronously
//               to the clock edge, while asserting immediately upon async reset.
//               A 2-stage (or more) synchronizer is the industry standard to 
//               prevent metastability issues during reset deassertion.
//               DFT Implications: During scan testing (DFT), it is common to
//               bypass or override this synchronizer so the reset can be 
//               controlled directly from a top-level pin.
// -----------------------------------------------------------------------------

module rst_sync #(
    parameter SYNC_STAGES = 2
) (
    input  wire clk,
    input  wire async_rst_n,
    output wire sync_rst_n
);

    // Synchronizer registers
    reg [SYNC_STAGES-1:0] sync_reg;

    always @(posedge clk or negedge async_rst_n) begin
        if (!async_rst_n) begin
            // Asynchronous assert
            sync_reg <= {SYNC_STAGES{1'b0}};
        end else begin
            // Synchronous deassert
            sync_reg <= {sync_reg[SYNC_STAGES-2:0], 1'b1};
        end
    end

    assign sync_rst_n = sync_reg[SYNC_STAGES-1];

endmodule
