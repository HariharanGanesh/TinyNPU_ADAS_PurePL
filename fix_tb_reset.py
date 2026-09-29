import sys
content = open("rebuild_tb.py").read()
content = content.replace("// ==== Test Case 9: End-to-End Inference ====", """// ==== Test Case 9: End-to-End Inference ====
        $display("Resetting NPU before TC9...");
        rst_n = 0;
        #100;
        rst_n = 1;
        #100;
""")
open("rebuild_tb.py", "w").write(content)
