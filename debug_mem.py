import sys
content = open("rebuild_tb.py").read()
content = content.replace("for (int i = 0; i < 112; i++) sim_memory[32'h1000 + i] = 8'h01; // Weights", """for (int i = 0; i < 112; i++) sim_memory[32'h1000 + i] = 8'h01; // Weights
        $display("sim_memory[1111]=%0h, sim_memory[1112]=%0h", sim_memory[32'h1111], sim_memory[32'h1112]);""")
open("rebuild_tb.py", "w").write(content)
