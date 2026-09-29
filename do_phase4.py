import os
import re

axi_path = "IP/TinyNPU200/src/axi4_lite_slave.v"
with open(axi_path, "r", encoding="utf-8") as f:
    content = f.read()

# Add parameter ARRAY_ROWS
content = content.replace("    parameter DATA_WIDTH = 32", "    parameter DATA_WIDTH = 32,\n    parameter ARRAY_ROWS = 20")

# Remove write logic for reg_array_rows
content = content.replace("ADDR_ARRAY_ROWS:     reg_array_rows[b*8 +: 8]     <= s_wdata[b*8 +: 8];", "// ADDR_ARRAY_ROWS is read-only")

# Modify read logic to return parameter instead of register
content = content.replace("ADDR_ARRAY_ROWS:      s_rdata <= reg_array_rows;", "ADDR_ARRAY_ROWS:      s_rdata <= ARRAY_ROWS;")

with open(axi_path, "w", encoding="utf-8") as f:
    f.write(content)

# Now update tinynpu_top.v instantiation to pass the parameter
top_path = "IP/TinyNPU200/src/tinynpu_top.v"
with open(top_path, "r", encoding="utf-8") as f:
    top = f.read()

top = top.replace("""    axi4_lite_slave #(
        .ADDR_WIDTH(8),
        .DATA_WIDTH(32)
    ) u_csr (""", """    axi4_lite_slave #(
        .ADDR_WIDTH(8),
        .DATA_WIDTH(32),
        .ARRAY_ROWS(ARRAY_ROWS)
    ) u_csr (""")
    
with open(top_path, "w", encoding="utf-8") as f:
    f.write(top)

print("Phase 4 fixes applied.")
