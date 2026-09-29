import sys
content = open("rebuild_tb.py").read()
content = content.replace("m_axi_rdata = {sim_memory[start_addr + (i*4) + 3], sim_memory[start_addr + (i*4) + 2], sim_memory[start_addr + (i*4) + 1], sim_memory[start_addr + (i*4)]};", "m_axi_rdata = {24\\'b0, sim_memory[start_addr + i]};")
open("rebuild_tb.py", "w").write(content)
