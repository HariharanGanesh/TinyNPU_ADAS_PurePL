import sys
content = open("rebuild_tb.py").read()
content = content.replace("m_axi_rdata = {24\\'b0, sim_memory[start_addr + i]};", "m_axi_rdata = {24'b0, sim_memory[start_addr + i]};")
open("rebuild_tb.py", "w").write(content)
