import sys
content = open("IP/TinyNPU200/src/processing_element.v").read()
content = content.replace("mul_s1 <= weight_reg * act_in;", "mul_s1 <= weight_reg * act_in; if (act_valid_in && weight_reg != 0) $display(\"PE: act=%0d wgt=%0d mul=%0d\", act_in, weight_reg, weight_reg * act_in);")
open("IP/TinyNPU200/src/processing_element.v", "w").write(content)
