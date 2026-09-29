import sys
content = open("IP/TinyNPU200/src/weight_buffer.v").read()
content = content.replace("weight_data[write_row][write_col] <= $signed(rd_data_reg);", "weight_data[write_row][write_col] <= $signed(rd_data_reg); if (rd_data_reg != 0) $display(\"WB_LOAD: idx=%0d row=%0d col=%0d data=%0d\", write_idx, write_row, write_col, rd_data_reg);")
open("IP/TinyNPU200/src/weight_buffer.v", "w").write(content)
