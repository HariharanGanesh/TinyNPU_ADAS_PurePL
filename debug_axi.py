import sys
content = open("rebuild_tb.py").read()
content = content.replace("m_axi_rdata = {24'b0, sim_memory[start_addr + i]};", "m_axi_rdata = {24'b0, sim_memory[start_addr + i]}; if (start_addr == 32'h1000 && i > 110) $display(\"TB AXI READ: addr=%0h data=%0h\", start_addr+i, sim_memory[start_addr+i]);")
open("rebuild_tb.py", "w").write(content)
