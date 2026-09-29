import sys

with open('src/npu_controller.v', 'r') as f:
    code = f.read()

# Fix ports
code = code.replace(
    '    input  wire                         stream_act_load_done,',
    '    output reg                          dma_start_load_act,\n    input  wire                         dma_act_load_done,\n    output reg                          dma_start_store_out,\n    input  wire                         dma_out_store_done,'
)

# Fix FSM default state
code = code.replace(
    '            dma_start_load_wgt  <= 1\'b0;\n                                    dma_transfer_size   <= 0;',
    '            dma_start_load_wgt  <= 1\'b0;\n            dma_start_load_act  <= 1\'b0;\n            dma_start_store_out <= 1\'b0;\n            dma_transfer_size   <= 0;'
)
code = code.replace(
    '            dma_start_load_wgt  <= 1\'b0;\n                                    wgt_buf_load_tile   <= 1\'b0;',
    '            dma_start_load_wgt  <= 1\'b0;\n            dma_start_load_act  <= 1\'b0;\n            dma_start_store_out <= 1\'b0;\n            wgt_buf_load_tile   <= 1\'b0;'
)

# Fix STATE_IDLE
code = code.replace(
    '                            dma_transfer_size  <= csr_in_channels; // embedding dimension\n                                                        state              <= STATE_LOAD_ACT;',
    '                            dma_transfer_size  <= csr_in_channels; // embedding dimension\n                            dma_start_load_act <= 1\'b1;\n                            state              <= STATE_LOAD_ACT;'
)

# Fix STATE_LOAD_WGT
code = code.replace(
    '                        dma_transfer_size  <= csr_input_width * csr_input_height;\n                                                state              <= STATE_LOAD_ACT;',
    '                        dma_transfer_size  <= csr_input_width * csr_input_height;\n                        dma_start_load_act <= 1\'b1;\n                        state              <= STATE_LOAD_ACT;'
)

# Fix STATE_LOAD_ACT condition
code = code.replace('if (stream_act_load_done) begin', 'if (dma_act_load_done) begin')

# Fix STATE_DRAIN
code = code.replace(
    '                        dma_transfer_size   <= csr_out_channels;\n                        // dma_start_store_out removed',
    '                        dma_transfer_size   <= csr_out_channels;\n                        dma_start_store_out <= 1\'b1;'
)

# Fix STATE_STORE_OUT
code = code.replace(
    'if (1\'b1) begin // dma_out_store_done removed',
    'if (dma_out_store_done) begin'
)
code = code.replace(
    '                                tile_y             <= tile_y + 16\'d1;\n                                dma_transfer_size  <= csr_input_width * csr_input_height;\n                                state              <= STATE_LOAD_ACT;',
    '                                tile_y             <= tile_y + 16\'d1;\n                                dma_transfer_size  <= csr_input_width * csr_input_height;\n                                dma_start_load_act <= 1\'b1;\n                                state              <= STATE_LOAD_ACT;'
)
code = code.replace(
    '                            tile_x             <= tile_x + 16\'d1;\n                            dma_transfer_size  <= csr_input_width * csr_input_height;\n                            state              <= STATE_LOAD_ACT;',
    '                            tile_x             <= tile_x + 16\'d1;\n                            dma_transfer_size  <= csr_input_width * csr_input_height;\n                            dma_start_load_act <= 1\'b1;\n                            state              <= STATE_LOAD_ACT;'
)


with open('src/npu_controller.v', 'w') as f:
    f.write(code)

print("Patch complete")
