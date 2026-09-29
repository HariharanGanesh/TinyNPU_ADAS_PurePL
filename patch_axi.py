import re

with open("IP/TinyNPU200/src/axi4_lite_slave.v", "r") as f:
    code = f.read()

# Add reg definitions
code = code.replace("    reg [DATA_WIDTH-1:0] reg_num_tiles;", "    reg [DATA_WIDTH-1:0] reg_num_tiles;\n    reg [DATA_WIDTH-1:0] reg_thresh_logit;\n    reg [DATA_WIDTH-1:0] reg_max_candidates;\n    reg [DATA_WIDTH-1:0] reg_clear_frame;\n    reg [DATA_WIDTH-1:0] reg_scale_id;")

# Add resets
code = code.replace("            reg_num_tiles      <= 32'd0; ", "            reg_num_tiles      <= 32'd0;\n            reg_thresh_logit   <= 32'd0;\n            reg_max_candidates <= 32'd0;\n            reg_clear_frame    <= 32'd0;\n            reg_scale_id       <= 32'd0;")

# Add write assigns
write_match = """                            ADDR_NUM_TILES:      reg_num_tiles[b*8 +: 8]      <= s_wdata[b*8 +: 8];"""
write_replace = """                            ADDR_NUM_TILES:      reg_num_tiles[b*8 +: 8]      <= s_wdata[b*8 +: 8];
                            ADDR_THRESH_LOGIT:   reg_thresh_logit[b*8 +: 8]   <= s_wdata[b*8 +: 8];
                            ADDR_MAX_CANDIDATES: reg_max_candidates[b*8 +: 8] <= s_wdata[b*8 +: 8];
                            ADDR_CLEAR_FRAME:    reg_clear_frame[b*8 +: 8]    <= s_wdata[b*8 +: 8];
                            ADDR_SCALE_ID:       reg_scale_id[b*8 +: 8]       <= s_wdata[b*8 +: 8];"""
code = code.replace(write_match, write_replace)

# Add read assigns
read_match = """                ADDR_NUM_TILES:       s_rdata <= reg_num_tiles;"""
read_replace = """                ADDR_NUM_TILES:       s_rdata <= reg_num_tiles;
                ADDR_THRESH_LOGIT:    s_rdata <= reg_thresh_logit;
                ADDR_MAX_CANDIDATES:  s_rdata <= reg_max_candidates;
                ADDR_CLEAR_FRAME:     s_rdata <= reg_clear_frame;
                ADDR_SCALE_ID:        s_rdata <= reg_scale_id;"""
code = code.replace(read_match, read_replace)

# Add output assigns
out_match = """    assign csr_num_tiles_y     = reg_num_tiles[31:16];"""
out_replace = """    assign csr_num_tiles_y     = reg_num_tiles[31:16];

    assign csr_thresh_logit   = reg_thresh_logit[7:0];
    assign csr_max_candidates = reg_max_candidates[9:0];
    assign csr_clear_frame    = reg_clear_frame[0];
    assign csr_scale_id       = reg_scale_id[15:0];"""
code = code.replace(out_match, out_replace)

with open("IP/TinyNPU200/src/axi4_lite_slave.v", "w") as f:
    f.write(code)