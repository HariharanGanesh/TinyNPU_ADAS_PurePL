import sys
content = open("IP/TinyNPU200/src/processing_element.v").read()
content = content.replace("mul_s1 <= weight_reg * act_in; if (act_valid_in && weight_reg != 0) $display(\"PE: act=%0d wgt=%0d mul=%0d\", act_in, weight_reg, weight_reg * act_in);", "mul_s1 <= weight_reg * act_in;")
open("IP/TinyNPU200/src/processing_element.v", "w").write(content)

content2 = open("IP/TinyNPU200/src/weight_buffer.v").read()
content2 = content2.replace("weight_data[write_row][write_col] <= $signed(rd_data_reg);", "weight_data[write_row][write_col] <= $signed(rd_data_reg); if (rd_data_reg != 0) $display(\"WGT_LOAD: row=%0d col=%0d data=%0d\", write_row, write_col, rd_data_reg);")
open("IP/TinyNPU200/src/weight_buffer.v", "w").write(content2)
