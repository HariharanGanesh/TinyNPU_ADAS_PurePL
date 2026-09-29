import sys
content = open("rebuild_tb.py").read()
content = content.replace("axi_write(8'h04, 32'h00000000);", """axi_write(8'h04, 32'h00000000);
        wait(tb_tinynpu_top.u_dut.u_csr.reg_status[0] == 1);
""")
open("rebuild_tb.py", "w").write(content)
