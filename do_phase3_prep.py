import os

axi_path = "IP/TinyNPU200/src/axi4_lite_slave.v"
with open(axi_path, "r", encoding="utf-8") as f:
    axi = f.read()

# I need to rewrite the Write channel handshake entirely.
# Find the write logic block to replace.

new_write_logic = """
    // =========================================================================
    // AXI4-Lite Write Handshake & Registers
    // =========================================================================
    reg aw_en;
    reg s_awready_reg;
    reg s_wready_reg;
    reg s_bvalid_reg;
    reg [ADDR_WIDTH-1:0] wr_addr;

    assign s_awready = s_awready_reg;
    assign s_wready  = s_wready_reg;
    assign s_bresp   = 2'b00;
    assign s_bvalid  = s_bvalid_reg;

    always @(posedge aclk) begin
        if (!aresetn) begin
            s_awready_reg <= 1'b0;
            aw_en <= 1'b1;
        end else begin
            if (~s_awready_reg && s_awvalid && s_wvalid && aw_en) begin
                s_awready_reg <= 1'b1;
                aw_en <= 1'b0;
            end else if (s_bready && s_bvalid_reg) begin
                aw_en <= 1'b1;
                s_awready_reg <= 1'b0;
            end else begin
                s_awready_reg <= 1'b0;
            end
        end
    end

    always @(posedge aclk) begin
        if (!aresetn) begin
            wr_addr <= 0;
        end else begin
            if (~s_awready_reg && s_awvalid && s_wvalid && aw_en) begin
                wr_addr <= s_awaddr;
            end
        end
    end

    always @(posedge aclk) begin
        if (!aresetn) begin
            s_wready_reg <= 1'b0;
        end else begin
            if (~s_wready_reg && s_wvalid && s_awvalid && aw_en) begin
                s_wready_reg <= 1'b1;
            end else begin
                s_wready_reg <= 1'b0;
            end
        end
    end

    always @(posedge aclk) begin
        if (!aresetn) begin
            s_bvalid_reg <= 1'b0;
        end else begin
            if (s_awready_reg && s_awvalid && ~s_bvalid_reg && s_wready_reg && s_wvalid) begin
                s_bvalid_reg <= 1'b1;
            end else if (s_bready && s_bvalid_reg) begin
                s_bvalid_reg <= 1'b0;
            end
        end
    end

    // Write enable
    wire slv_reg_wren = s_wready_reg && s_wvalid && s_awready_reg && s_awvalid;
"""

import re
# We need to replace the old logic:
# from:
#    assign s_awready = 1'b1;
#    assign s_wready  = 1'b1;
#    assign s_bresp   = 2'b00;
# to:
#    wire [ADDR_WIDTH-1:0] wr_addr = (s_awvalid && s_awready) ? s_awaddr : wr_addr_lat;
# which is right before `always @(posedge aclk) begin // CSR Write Logic`

old_logic_pattern = r"assign s_awready = 1'b1;[\s\S]*?wire \[ADDR_WIDTH-1:0\] wr_addr = \(s_awvalid && s_awready\) \? s_awaddr : wr_addr_lat;"
axi = re.sub(old_logic_pattern, new_write_logic, axi)

# Also need to fix the write logic block
# old: `if (s_wvalid && s_wready) begin`
# new: `if (slv_reg_wren) begin`
axi = axi.replace("if (s_wvalid && s_wready) begin", "if (slv_reg_wren) begin")

# For the read channel, let's fix it too if it's broken.
# The original read was:
#        if (!aresetn) begin
#            s_rvalid <= 1'b0;
#            s_rdata  <= 0;
#        end else if (s_arvalid && s_arready) begin
#            s_rvalid <= 1'b1;
#
# But `s_arready` was hardcoded to 1. Oh wait, where is `s_arready`?
# Let's check where it is.
