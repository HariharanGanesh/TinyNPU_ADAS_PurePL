// =============================================================================
// Module: dma_controller.v
// Project: TinyNPU
// Description:
//   DMA Controller with AXI4-Full Master Interface.
//   Manages linear reads of weights and activations from external memory,
//   and linear writes of output results back to external memory.
//   Verilog-2001 Synthesizable RTL.
// =============================================================================

`timescale 1ns / 1ps

module dma_controller #(
    parameter AXI_ADDR_WIDTH = 32,
    parameter AXI_DATA_WIDTH = 32,
    parameter BUFFER_ADDR_WIDTH = 10,
    parameter DATA_WIDTH = 8
) (
    input  wire                         clk,
    input  wire                         rst_n,

    // AXI4 Master Interface
    // Write Address Channel (AW)
    output reg  [AXI_ADDR_WIDTH-1:0]    m_axi_awaddr,
    output reg  [7:0]                   m_axi_awlen,
    output wire [2:0]                   m_axi_awsize,
    output wire [1:0]                   m_axi_awburst,
    output reg                          m_axi_awvalid,
    input  wire                         m_axi_awready,

    // Write Data Channel (W)
    output wire [AXI_DATA_WIDTH-1:0]    m_axi_wdata,
    output wire [AXI_DATA_WIDTH/8-1:0]  m_axi_wstrb,
    output reg                          m_axi_wlast,
    output reg                          m_axi_wvalid,
    input  wire                         m_axi_wready,

    // Write Response Channel (B)
    input  wire [1:0]                   m_axi_bresp,
    input  wire                         m_axi_bvalid,
    output reg                          m_axi_bready,

    // Read Address Channel (AR)
    output reg  [AXI_ADDR_WIDTH-1:0]    m_axi_araddr,
    output reg  [7:0]                   m_axi_arlen,
    output wire [2:0]                   m_axi_arsize,
    output wire [1:0]                   m_axi_arburst,
    output reg                          m_axi_arvalid,
    input  wire                         m_axi_arready,

    // Read Data Channel (R)
    input  wire [AXI_DATA_WIDTH-1:0]    m_axi_rdata,
    input  wire [1:0]                   m_axi_rresp,
    input  wire                         m_axi_rlast,
    input  wire                         m_axi_rvalid,
    output reg                          m_axi_rready,

    // Control and Status
    input  wire [AXI_ADDR_WIDTH-1:0]    weight_base_addr,
    input  wire [AXI_ADDR_WIDTH-1:0]    act_base_addr,
    input  wire [AXI_ADDR_WIDTH-1:0]    out_base_addr,
    input  wire [15:0]                  transfer_size, // number of bytes to transfer

    input  wire                         start_load_weights,
    input  wire                         start_load_act,
    input  wire                         start_store_out,

    output reg                          weight_load_done,
    output reg                          act_load_done,
    output reg                          out_store_done,

    // Buffer Write Ports
    output reg  [BUFFER_ADDR_WIDTH-1:0] wgt_buf_wr_addr,
    output reg  [DATA_WIDTH-1:0]        wgt_buf_wr_data,
    output reg                          wgt_buf_wr_en,

    output reg  [BUFFER_ADDR_WIDTH-1:0] act_buf_wr_addr,
    output reg  [DATA_WIDTH-1:0]        act_buf_wr_data,
    output reg                          act_buf_wr_en,

    // Buffer Read Port (Output Buffer to DRAM)
    output reg  [BUFFER_ADDR_WIDTH-1:0] out_buf_rd_addr,
    input  wire [DATA_WIDTH-1:0]        out_buf_rd_data,
    output reg                          out_buf_rd_en
);

    // Constant mappings
    assign m_axi_awburst = 2'b01; // INCR burst
    assign m_axi_arburst = 2'b01; // INCR burst
    assign m_axi_awsize  = 3'b000; // 1 byte per transfer
    assign m_axi_arsize  = 3'b000; // 1 byte per transfer
    assign m_axi_wstrb   = 4'h1;   // only lowest byte is valid for 8-bit

    // Pack output buffer data to AXI data width
    assign m_axi_wdata = {24'b0, out_buf_rd_data};

    // States
    localparam STATE_IDLE        = 3'd0;
    localparam STATE_R_ADDR      = 3'd1;
    localparam STATE_R_DATA      = 3'd2;
    localparam STATE_W_ADDR      = 3'd3;
    localparam STATE_W_DATA      = 3'd4;
    localparam STATE_W_RESP      = 3'd5;

    reg [2:0] state;
    reg [1:0] channel_select; // 0 = Weight, 1 = Activation
    reg [15:0] bytes_transferred;

    // FSM
    always @(posedge clk) begin
        if (!rst_n) begin
            state             <= STATE_IDLE;
            m_axi_awaddr      <= 0;
            m_axi_awlen       <= 0;
            m_axi_awvalid     <= 1'b0;
            m_axi_wlast       <= 1'b0;
            m_axi_wvalid      <= 1'b0;
            m_axi_bready      <= 1'b0;
            m_axi_araddr      <= 0;
            m_axi_arlen       <= 0;
            m_axi_arvalid     <= 1'b0;
            m_axi_rready      <= 1'b0;
            weight_load_done  <= 1'b0;
            act_load_done     <= 1'b0;
            out_store_done    <= 1'b0;
            wgt_buf_wr_addr   <= 0;
            wgt_buf_wr_data   <= 0;
            wgt_buf_wr_en     <= 1'b0;
            act_buf_wr_addr   <= 0;
            act_buf_wr_data   <= 0;
            act_buf_wr_en     <= 1'b0;
            out_buf_rd_addr   <= 0;
            out_buf_rd_en     <= 1'b0;
            bytes_transferred <= 0;
            channel_select    <= 0;
        end else begin
            wgt_buf_wr_en  <= 1'b0;
            act_buf_wr_en  <= 1'b0;
            out_buf_rd_en  <= 1'b0;
            weight_load_done <= 1'b0;
            act_load_done    <= 1'b0;
            out_store_done   <= 1'b0;

            case (state)
                STATE_IDLE: begin
                    bytes_transferred <= 0;
                    if (start_load_weights) begin
                        m_axi_araddr   <= weight_base_addr;
                        m_axi_arlen    <= transfer_size - 1'b1;
                        m_axi_arvalid  <= 1'b1;
                        channel_select <= 2'd0;
                        state          <= STATE_R_ADDR;
                    end else if (start_load_act) begin
                        m_axi_araddr   <= act_base_addr;
                        m_axi_arlen    <= transfer_size - 1'b1;
                        m_axi_arvalid  <= 1'b1;
                        channel_select <= 2'd1;
                        state          <= STATE_R_ADDR;
                    end else if (start_store_out) begin
                        m_axi_awaddr   <= out_base_addr;
                        m_axi_awlen    <= transfer_size - 1'b1;
                        m_axi_awvalid  <= 1'b1;
                        state          <= STATE_W_ADDR;
                        // Fetch first word from output buffer
                        out_buf_rd_addr <= 0;
                        out_buf_rd_en   <= 1'b1;
                    end
                end

                STATE_R_ADDR: begin
                    if (m_axi_arready) begin
                        m_axi_arvalid <= 1'b0;
                        m_axi_rready  <= 1'b1;
                        state         <= STATE_R_DATA;
                    end
                end

                STATE_R_DATA: begin
                    if (m_axi_rvalid) begin
                        bytes_transferred <= bytes_transferred + 1'b1;
                        if (channel_select == 2'd0) begin
                            wgt_buf_wr_addr <= bytes_transferred[BUFFER_ADDR_WIDTH-1:0];
                            wgt_buf_wr_data <= m_axi_rdata[DATA_WIDTH-1:0];
                            wgt_buf_wr_en   <= 1'b1;
                        end else begin
                            act_buf_wr_addr <= bytes_transferred[BUFFER_ADDR_WIDTH-1:0];
                            act_buf_wr_data <= m_axi_rdata[DATA_WIDTH-1:0];
                            act_buf_wr_en   <= 1'b1;
                        end

                        if (m_axi_rlast || (bytes_transferred == transfer_size - 1'b1)) begin
                            m_axi_rready <= 1'b0;
                            if (channel_select == 2'd0) begin
                                weight_load_done <= 1'b1;
                            end else begin
                                act_load_done    <= 1'b1;
                            end
                            state <= STATE_IDLE;
                        end
                    end
                end

                STATE_W_ADDR: begin
                    if (m_axi_awready) begin
                        m_axi_awvalid <= 1'b0;
                        m_axi_wvalid  <= 1'b1;
                        state         <= STATE_W_DATA;
                        if (transfer_size == 1) begin
                            m_axi_wlast <= 1'b1;
                        end
                    end
                end

                STATE_W_DATA: begin
                    if (m_axi_wready) begin
                        bytes_transferred <= bytes_transferred + 1'b1;

                        if (bytes_transferred == transfer_size - 1'b1) begin
                            m_axi_wvalid <= 1'b0;
                            m_axi_wlast  <= 1'b0;
                            m_axi_bready <= 1'b1;
                            state        <= STATE_W_RESP;
                        end else begin
                            // Fetch next word
                            out_buf_rd_addr <= bytes_transferred + 1'b1;
                            out_buf_rd_en   <= 1'b1;
                            if (bytes_transferred == transfer_size - 2'd2) begin
                                m_axi_wlast <= 1'b1;
                            end
                        end
                    end
                end

                STATE_W_RESP: begin
                    if (m_axi_bvalid) begin
                        m_axi_bready   <= 1'b0;
                        out_store_done <= 1'b1;
                        state          <= STATE_IDLE;
                    end
                end

                default: state <= STATE_IDLE;
            endcase
        end
    end

endmodule
