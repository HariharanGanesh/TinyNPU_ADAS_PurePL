import sys
content = open("rebuild_tb.py").read()
content = content.replace("for (int i = 0; i < 65536; i++) sim_memory[i] = 8'h01;", "for (int i = 0; i < 65536; i++) sim_memory[i] = 8'h00;")
open("rebuild_tb.py", "w").write(content)
