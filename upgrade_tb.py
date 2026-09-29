import sys

filepath = "rebuild_tb.py"
content = open(filepath, "r").read()
content = content.replace("for (int i = 0; i < 112; i++) sim_memory[32'h1000 + i] = 8'h01; // Weights", "for (int i = 0; i < 196; i++) sim_memory[32'h1000 + i] = 8'h01; // Weights (14x14)")
open(filepath, "w").write(content)
