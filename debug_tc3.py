import sys
content = open("rebuild_tb.py").read()
content = content.replace("if (read_val == 32'h11223344 && read_val2 == 32'h55667788) begin", """$display("TC3 read_val=%0h read_val2=%0h", read_val, read_val2);
          if (read_val == 32'h11223344 && read_val2 == 32'h55667788) begin""")
open("rebuild_tb.py", "w").write(content)
