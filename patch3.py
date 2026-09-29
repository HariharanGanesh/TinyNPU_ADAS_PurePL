import re
text = open('IP/TinyNPU200/src/weight_buffer.v').read()
text = text.replace('weight_data[write_row][write_col] <= $signed(rd_data_reg);', 'weight_data[write_row][write_col] <= $signed(rd_data_reg);\n              if (write_row == 0 && write_col == 0) $display("[WGT_BUF] wrote %h to [0][0]", rd_data_reg);')
open('IP/TinyNPU200/src/weight_buffer.v', 'w').write(text)
