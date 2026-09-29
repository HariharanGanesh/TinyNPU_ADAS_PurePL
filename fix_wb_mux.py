import sys
content = open("IP/TinyNPU200/src/weight_buffer.v").read()
content = content.replace("wire [ADDR_WIDTH-1:0] rd_addr_mux = (array_en) ? rd_addr_reg : 0;", "wire [ADDR_WIDTH-1:0] rd_addr_mux = rd_addr_reg;")
open("IP/TinyNPU200/src/weight_buffer.v", "w").write(content)
