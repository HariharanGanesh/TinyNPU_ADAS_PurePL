import os
import re

axi_path = "IP/TinyNPU200/src/axi4_lite_slave.v"
with open(axi_path, "r", encoding="utf-8") as f:
    content = f.read()

# Replace the handshakes
old_handshakes = """    // AWREADY / WREADY / ARREADY always accept immediately
    assign s_awready = 1'b1;
    assign s_wready  = 1'b1;
    assign s_arready = 1'b1;
    assign s_bresp   = 2'b00; // OKAY
    assign s_rresp   = 2'b00; // OKAY

    // Write Response Channel
    always @(posedge aclk) begin
        if (!aresetn) begin
            s_bvalid <= 1'b0;
        end else if (s_awvalid && s_awready) begin
            s_bvalid <= 1'b1;
        end else if (s_bvalid && s_bready) begin
            s_bvalid <= 1'b0;
        end
    end

    always @(posedge aclk) begin
        if (!aresetn) begin
            wr_addr_lat <= 0;
        end else if (s_awvalid && s_awready) begin
            wr_addr_lat <= s_awaddr;
        end
    end

    wire [ADDR_WIDTH-1:0] wr_addr = (s_awvalid && s_awready) ? s_awaddr : wr_addr_lat;"""

new_handshakes = """    // =========================================================================
    // AXI4-Lite Handshake Registers
    // =========================================================================
    reg [ADDR_WIDTH-1:0] axi_awaddr;
    reg axi_awready;
    reg axi_wready;
    reg [1:0] axi_bresp;
    reg axi_bvalid;
    reg [ADDR_WIDTH-1:0] axi_araddr;
    reg axi_arready;
    reg [1:0] axi_rresp;

    assign s_awready = axi_awready;
    assign s_wready  = axi_wready;
    assign s_bresp   = axi_bresp;
    assign s_bvalid  = axi_bvalid;
    assign s_arready = axi_arready;
    assign s_rresp   = axi_rresp;

    // AWREADY and AWADDR
    always @(posedge aclk) begin
        if (!aresetn) begin
            axi_awready <= 1'b0;
            axi_awaddr <= 0;
        end else begin
            if (~axi_awready && s_awvalid && s_wvalid) begin
                axi_awready <= 1'b1;
                axi_awaddr  <= s_awaddr;
            end else begin
                axi_awready <= 1'b0;
            end
        end
    end

    // WREADY
    always @(posedge aclk) begin
        if (!aresetn) begin
            axi_wready <= 1'b0;
        end else begin
            if (~axi_wready && s_wvalid && s_awvalid) begin
                axi_wready <= 1'b1;
            end else begin
                axi_wready <= 1'b0;
            end
        end
    end

    // BVALID and BRESP
    always @(posedge aclk) begin
        if (!aresetn) begin
            axi_bvalid <= 1'b0;
            axi_bresp  <= 2'b00;
        end else begin
            if (axi_awready && s_awvalid && ~axi_bvalid && axi_wready && s_wvalid) begin
                axi_bvalid <= 1'b1;
                axi_bresp  <= 2'b00;
            end else if (s_bready && axi_bvalid) begin
                axi_bvalid <= 1'b0;
            end
        end
    end

    // ARREADY and ARADDR
    always @(posedge aclk) begin
        if (!aresetn) begin
            axi_arready <= 1'b0;
            axi_araddr  <= 0;
        end else begin
            if (~axi_arready && s_arvalid) begin
                axi_arready <= 1'b1;
                axi_araddr  <= s_araddr;
            end else begin
                axi_arready <= 1'b0;
            end
        end
    end

    wire slv_reg_wren = axi_wready && s_wvalid && axi_awready && s_awvalid;
    wire slv_reg_rden = axi_arready & s_arvalid & ~s_rvalid;
    
    wire [ADDR_WIDTH-1:0] wr_addr = axi_awaddr;"""

content = content.replace(old_handshakes, new_handshakes)

# Replace write condition
content = content.replace("if (s_wvalid && s_wready) begin", "if (slv_reg_wren) begin")

# Replace read condition
old_read = """        end else if (s_arvalid && s_arready) begin
            s_rvalid <= 1'b1;
            case (s_araddr[7:0])"""
new_read = """        end else if (s_rvalid && s_rready) begin
            s_rvalid <= 1'b0;
        end else if (slv_reg_rden) begin
            s_rvalid <= 1'b1;
            axi_rresp <= 2'b00;
            case (axi_araddr[7:0])"""
content = content.replace(old_read, new_read)

# Remove the old rvalid clear logic which was below the case block
old_rclear = """            endcase
        end else if (s_rvalid && s_rready) begin
            s_rvalid <= 1'b0;
        end"""
new_rclear = """            endcase
        end"""
content = content.replace(old_rclear, new_rclear)

with open(axi_path, "w", encoding="utf-8") as f:
    f.write(content)

print("Phase 3 applied cleanly.")
