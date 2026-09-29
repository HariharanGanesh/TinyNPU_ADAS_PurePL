`timescale 1ns / 1ps

module adas_stream_aggregator #(
    parameter BEATS = 67, // 2144 bits / 32 bits = 67
    parameter IN_WIDTH = 32,
    parameter OUT_WIDTH = 2144
)(
    input  wire                 clk,
    input  wire                 rst_n,
    
    input  wire                 s_axis_tvalid,
    input  wire [IN_WIDTH-1:0]  s_axis_tdata,
    output wire                 s_axis_tready,
    
    output reg                  m_adas_valid,
    output reg  [OUT_WIDTH-1:0] m_adas_data
);

    reg [6:0] beat_cnt;
    reg [OUT_WIDTH-1:0] shift_reg;
    
    assign s_axis_tready = 1'b1; // Always ready to receive
    
    always @(posedge clk) begin
        if (!rst_n) begin
            beat_cnt <= 0;
            m_adas_valid <= 0;
            m_adas_data <= 0;
            shift_reg <= 0;
        end else begin
            m_adas_valid <= 0; // default
            
            if (s_axis_tvalid && s_axis_tready) begin
                // Shift in the new data at the MSB and shift right.
                // Assuming NPU outputs class 0 first, beat 0 ends up at LSB.
                shift_reg <= {s_axis_tdata, shift_reg[OUT_WIDTH-1:IN_WIDTH]};
                
                if (beat_cnt == BEATS - 1) begin
                    m_adas_valid <= 1'b1;
                    m_adas_data <= {s_axis_tdata, shift_reg[OUT_WIDTH-1:IN_WIDTH]};
                    beat_cnt <= 0;
                end else begin
                    beat_cnt <= beat_cnt + 1;
                end
            end
        end
    end

endmodule