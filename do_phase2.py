import os
import re

# 1. Update dma_controller.v
dma_path = "IP/TinyNPU200/src/dma_controller.v"
with open(dma_path, "r", encoding="utf-8") as f:
    dma = f.read()

# Remove activation ports and internal logic
dma = re.sub(r'input\s+wire\s+\[AXI_ADDR_WIDTH-1:0\]\s+act_base_addr,\n', '', dma)
dma = re.sub(r'input\s+wire\s+start_load_act,\n', '', dma)
dma = re.sub(r'output\s+reg\s+act_load_done,\n', '', dma)
dma = re.sub(r'output\s+reg\s+\[BUFFER_ADDR_WIDTH-1:0\]\s+act_buf_wr_addr,\n\s*output\s+reg\s+\[DATA_WIDTH-1:0\]\s+act_buf_wr_data,\n\s*output\s+reg\s+act_buf_wr_en,\n', '', dma)

dma = re.sub(r'act_load_done\s*<=\s*1\'b0;\n', '', dma)
dma = re.sub(r'act_buf_wr_addr\s*<=\s*0;\n', '', dma)
dma = re.sub(r'act_buf_wr_data\s*<=\s*0;\n', '', dma)
dma = re.sub(r'act_buf_wr_en\s*<=\s*1\'b0;\n', '', dma)

# Remove the 'else if (start_load_act)' block entirely
# Need to be careful with regex here. It's better to replace the specific block.
dma = re.sub(r'\} else if \(start_load_act\) \{[\s\S]*?\}', '', dma) # Not valid syntax, let's just use string replace

act_load_block = """                    end else if (start_load_act) begin
                        $display("[DMA_CTRL @ %0t] START_LOAD_ACT: addr=%0h size=%0d -> STATE_R_ADDR", $time, act_base_addr, transfer_size);
                        m_axi_araddr   <= act_base_addr;
                        m_axi_arlen    <= transfer_size - 1'b1;
                        m_axi_arvalid  <= 1'b1;
                        bytes_transferred <= 0;
                        channel_select <= 2'd1;
                        state          <= STATE_R_ADDR;"""
dma = dma.replace(act_load_block, "")

act_wr_block = """                        if (channel_select == 2'd0) begin
                            wgt_buf_wr_addr <= bytes_transferred[BUFFER_ADDR_WIDTH-1:0];
                            wgt_buf_wr_data <= m_axi_rdata[DATA_WIDTH-1:0];
                            wgt_buf_wr_en   <= 1'b1;
                        end else begin
                            act_buf_wr_addr <= bytes_transferred[BUFFER_ADDR_WIDTH-1:0];
                            act_buf_wr_data <= m_axi_rdata[DATA_WIDTH-1:0];
                            act_buf_wr_en   <= 1'b1;
                        end"""
act_wr_replacement = """                        wgt_buf_wr_addr <= bytes_transferred[BUFFER_ADDR_WIDTH-1:0];
                        wgt_buf_wr_data <= m_axi_rdata[DATA_WIDTH-1:0];
                        wgt_buf_wr_en   <= 1'b1;"""
dma = dma.replace(act_wr_block, act_wr_replacement)

act_done_block = """                            if (channel_select == 2'd0) begin
                                $display("[DMA_CTRL @ %0t] WGT_LOAD_DONE (bytes=%0d)", $time, bytes_transferred + 1);
                                weight_load_done <= 1'b1;
                            end else begin
                                $display("[DMA_CTRL @ %0t] ACT_LOAD_DONE (bytes=%0d)", $time, bytes_transferred + 1);
                                act_load_done    <= 1'b1;
                            end"""
act_done_replacement = """                            $display("[DMA_CTRL @ %0t] WGT_LOAD_DONE (bytes=%0d)", $time, bytes_transferred + 1);
                            weight_load_done <= 1'b1;"""
dma = dma.replace(act_done_block, act_done_replacement)

with open(dma_path, "w", encoding="utf-8") as f:
    f.write(dma)

# 2. Update npu_controller.v
ctrl_path = "IP/TinyNPU200/src/npu_controller.v"
with open(ctrl_path, "r", encoding="utf-8") as f:
    ctrl = f.read()

ctrl = re.sub(r'output\s+reg\s+dma_start_load_act,\n', '', ctrl)
ctrl = re.sub(r'input\s+wire\s+dma_act_load_done,\n', 'input  wire                         stream_act_load_done,\n', ctrl)
ctrl = re.sub(r'dma_start_load_act\s*<=\s*1\'b0;\n', '', ctrl)
ctrl = re.sub(r'dma_start_load_act\s*<=\s*1\'b1;\n', '', ctrl)
ctrl = re.sub(r'dma_act_load_done', 'stream_act_load_done', ctrl)

with open(ctrl_path, "w", encoding="utf-8") as f:
    f.write(ctrl)

# 3. Update tinynpu_top.v
top_path = "IP/TinyNPU200/src/tinynpu_top.v"
with open(top_path, "r", encoding="utf-8") as f:
    top = f.read()

# Remove start_load_act from dma instantiation
top = re.sub(r'\.act_base_addr\(csr_act_base\),\n', '', top)
top = re.sub(r'\.start_load_act\(1\'b0\),\n', '', top)
top = re.sub(r'\.act_load_done\(dma_act_load_done\),\n', '', top)

# Change controller instantiation
top = re.sub(r'wire\s+dma_start_load_act;\n', '', top)
top = re.sub(r'wire\s+dma_act_load_done;\n', '', top)
top = re.sub(r'\.dma_start_load_act\(dma_start_load_act\),\n', '', top)
top = re.sub(r'\.dma_act_load_done\(stream_tile_received\),', '.stream_act_load_done(stream_tile_received),', top)

with open(top_path, "w", encoding="utf-8") as f:
    f.write(top)

print("Phase 2 Fixes applied to RTL.")
