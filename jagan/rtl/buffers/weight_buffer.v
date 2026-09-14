// =============================================================================
// Module: weight_buffer.v
// Project: TinyNPU
// Description:
//   Dual-banked Weight Buffer for TinyNPU.
//   Bank 0 and Bank 1 are independently readable and writable.
//   The DMA controller writes to the INACTIVE bank while the systolic array
//   reads from the ACTIVE bank, enabling weight double-buffering to hide
//   DRAM access latency.
//
//   bank_sel: 0 = Systolic reads Bank 0, DMA writes Bank 1
//             1 = Systolic reads Bank 1, DMA writes Bank 0
//
//   Verilog-2001 Synthesizable RTL.
// =============================================================================

`timescale 1ns / 1ps

module weight_buffer #(
    parameter DATA_WIDTH   = 8,
    parameter ARRAY_ROWS   = 8,
    parameter ARRAY_COLS   = 8,
    parameter BUFFER_DEPTH = 512,
    parameter ADDR_WIDTH   = 9
) (
    input  wire                    clk,
    input  wire                    rst_n,

    // Bank Select: 0 = compute from Bank0, DMA writes Bank1
    //              1 = compute from Bank1, DMA writes Bank0
    input  wire                    bank_sel,

    // Write Port (DMA -> Inactive Weight Bank)
    input  wire [ADDR_WIDTH-1:0]   wr_addr,
    input  wire [DATA_WIDTH-1:0]   wr_data,
    input  wire                    wr_en,

    // Tile Load Port -> Systolic Array Weight Registers
    input  wire [ADDR_WIDTH-1:0]   tile_base_addr,
    input  wire                    load_tile,
    output wire [DATA_WIDTH*ARRAY_ROWS*ARRAY_COLS-1:0] weight_data_flat,
    output reg                     weight_data_valid,
    output reg                     load_complete
);

    // =========================================================================
    // Dual BRAM Banks
    // =========================================================================
    (* ram_style = "block" *)
    reg [DATA_WIDTH-1:0] weight_mem_bank0 [0:BUFFER_DEPTH-1];
    (* ram_style = "block" *)
    reg [DATA_WIDTH-1:0] weight_mem_bank1 [0:BUFFER_DEPTH-1];

    initial begin
        $readmemh("dummy_weights.hex", weight_mem_bank0);
        $readmemh("dummy_weights.hex", weight_mem_bank1);
    end

    // =========================================================================
    // Write Logic: DMA writes to the INACTIVE bank
    // =========================================================================
    // Inactive bank = ~bank_sel
    always @(posedge clk) begin
        if (wr_en) begin
            if (bank_sel == 1'b0) begin
                // Compute reads Bank 0, so DMA writes Bank 1
                weight_mem_bank1[wr_addr] <= wr_data;
            end else begin
                // Compute reads Bank 1, so DMA writes Bank 0
                weight_mem_bank0[wr_addr] <= wr_data;
            end
        end
    end

    // =========================================================================
    // Tile Load Controller: reads from ACTIVE bank
    // =========================================================================
    reg [9:0] load_counter;
    reg       loading;

    wire [ADDR_WIDTH-1:0] rd_addr_mux = tile_base_addr + load_counter;
    reg  [DATA_WIDTH-1:0] rd_data_reg;

    // Synchronous read from active bank
    always @(posedge clk) begin
        if (bank_sel == 1'b0) begin
            rd_data_reg <= weight_mem_bank0[rd_addr_mux];
        end else begin
            rd_data_reg <= weight_mem_bank1[rd_addr_mux];
        end
    end

    // Loading FSM (unchanged logic — now operates on active bank reads)
    always @(posedge clk) begin
        if (!rst_n) begin
            loading           <= 1'b0;
            load_counter      <= 10'b0;
            weight_data_valid <= 1'b0;
            load_complete     <= 1'b0;
        end else begin
            load_complete <= 1'b0;

            if (load_tile && !loading) begin
                loading           <= 1'b1;
                load_counter      <= 10'b0;
                weight_data_valid <= 1'b0;
            end else if (loading) begin
                if (load_counter < (ARRAY_ROWS * ARRAY_COLS)) begin
                    load_counter      <= load_counter + 1'b1;
                    weight_data_valid <= (load_counter >= 10'd1);
                end else begin
                    loading           <= 1'b0;
                    load_complete     <= 1'b1;
                    weight_data_valid <= 1'b0;
                    load_counter      <= 10'b0;
                end
            end
        end
    end

    // =========================================================================
    // Demux serial reads into the 2D weight_data array
    // =========================================================================
    reg signed [DATA_WIDTH-1:0] weight_data [0:ARRAY_ROWS-1][0:ARRAY_COLS-1];

    wire [9:0] write_idx = (load_counter > 10'd0) ? (load_counter - 1'b1) : 10'd0;
    wire [4:0] write_row = write_idx / ARRAY_COLS;
    wire [3:0] write_col = write_idx % ARRAY_COLS;

    always @(posedge clk) begin
        if (loading && load_counter > 10'd0) begin
            weight_data[write_row][write_col] <= $signed(rd_data_reg);
        end
    end

    // Pack 2D weight_data -> flat output
    // Use localparams for loop bounds (Vivado requires localparam, not parameter)
    localparam GEN_WB_ROWS = ARRAY_ROWS;
    localparam GEN_WB_COLS = ARRAY_COLS;
    genvar r_pk, c_pk;
    generate
        for (r_pk = 0; r_pk < GEN_WB_ROWS; r_pk = r_pk + 1) begin : gen_pack_rows
            for (c_pk = 0; c_pk < GEN_WB_COLS; c_pk = c_pk + 1) begin : gen_pack_cols
                localparam WB_BASE = (r_pk * ARRAY_COLS + c_pk) * DATA_WIDTH;
                wire [DATA_WIDTH-1:0] wdata_slice;
                assign wdata_slice = weight_data[r_pk][c_pk];
                assign weight_data_flat[WB_BASE +: DATA_WIDTH] = wdata_slice;
            end
        end
    endgenerate

endmodule
