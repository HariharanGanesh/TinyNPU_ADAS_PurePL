import re
text = open('IP/TinyNPU200/src/requantization_unit.v').read()
text = text.replace('quant_valid <= stage2b_valid;', 'quant_valid <= stage2b_valid;\n            $display("[REQUANT @ %0t] quant_valid=%b quant_out[0]=%h quant_out[1]=%h acc_in[0]=%h", $time, stage2b_valid, quant_out[0], quant_out[1], acc_in[0]);')
open('IP/TinyNPU200/src/requantization_unit.v', 'w').write(text)
