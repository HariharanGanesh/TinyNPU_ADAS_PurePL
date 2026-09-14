`timescale 1ns / 1ps

module bram_sensor_emulator #(
    parameter DATA_WIDTH = 8,      
    parameter IMAGE_SIZE = 4096,    // Total bytes (e.g., 64x64)
    parameter INIT_FILE = "test_image.hex"
) (
    input  wire                   clk,
    input  wire                   rst_n,
    input  wire                   start_stream,
    
    // AXI-Stream Master Interface
    output wire [DATA_WIDTH-1:0]  m_axis_tdata,
    output wire                   m_axis_tvalid,
    input  wire                   m_axis_tready,
    output wire                   m_axis_tlast,
    
    // Status
    output wire                   done
);

    localparam WORDS = IMAGE_SIZE / (DATA_WIDTH/8);
    
    // BRAM memory
    reg [DATA_WIDTH-1:0] rom [0:WORDS-1];
    
    initial begin
        // $readmemh(INIT_FILE, rom); // Uncomment when real hex is provided
    end
    
    // State machine
    reg [15:0] addr;
    reg        streaming;
    
    always @(posedge clk) begin
        if (!rst_n) begin
            addr      <= 0;
            streaming <= 1'b0;
        end else begin
            if (start_stream && !streaming) begin
                addr      <= 0;
                streaming <= 1'b1;
            end else if (streaming && m_axis_tready && m_axis_tvalid) begin
                if (addr == WORDS - 1) begin
                    streaming <= 1'b0;
                end else begin
                    addr <= addr + 1'b1;
                end
            end
        end
    end
    
    assign m_axis_tdata  = rom[addr];
    assign m_axis_tvalid = streaming;
    assign m_axis_tlast  = streaming && (addr == WORDS - 1);
    assign done          = (addr == WORDS - 1) && m_axis_tready && m_axis_tvalid;

endmodule
