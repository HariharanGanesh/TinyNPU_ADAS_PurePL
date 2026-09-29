import os
import re

npu = "IP/TinyNPU200/src/npu_controller.v"
with open(npu, "r", encoding="utf-8") as f:
    code = f.read()

# Remove dma_start_store_out and dma_out_store_done from ports
code = re.sub(r'output\s+reg\s+dma_start_store_out,\n', '', code)
code = re.sub(r'input\s+wire\s+dma_out_store_done,\n', '', code)

# Fix STATE_STORE_OUT: Instead of waiting, just jump to STATE_DONE or skip it.
# Actually, the FSM looks like:
#                STATE_STORE_OUT: begin
#                    if (dma_out_store_done) begin
#                        dma_start_store_out <= 1'b0;
#                        state <= STATE_DONE;
#                    end else begin
#                        dma_start_store_out <= 1'b1;
#                    end
#                end
old_store = """                STATE_STORE_OUT: begin
                    if (dma_out_store_done) begin
                        dma_start_store_out <= 1'b0;
                        state <= STATE_DONE;
                    end else begin
                        dma_start_store_out <= 1'b1;
                    end
                end"""
new_store = """                STATE_STORE_OUT: begin
                    // Skipping DMA store, output handled by AXI-Stream source
                    state <= STATE_DONE;
                end"""

code = code.replace(old_store, new_store)

# Also remove dma_start_store_out <= 0 from STATE_IDLE or anywhere else
code = re.sub(r'dma_start_store_out\s*<=\s*1\'b0;\n', '', code)

with open(npu, "w", encoding="utf-8") as f:
    f.write(code)

# Now fix tinynpu_top.v to remove the floating connections
top = "IP/TinyNPU200/src/tinynpu_top.v"
with open(top, "r", encoding="utf-8") as f:
    code = f.read()

code = re.sub(r'wire\s+dma_start_store_out;\n', '', code)
code = re.sub(r'wire\s+dma_out_store_done;\n', '', code)
code = re.sub(r'\.out_base_addr\(csr_out_base\),\n', '', code)
code = re.sub(r'\.start_store_out\(dma_start_store_out\),\n', '', code)
code = re.sub(r'\.out_store_done\(dma_out_store_done\),\n', '', code)
code = re.sub(r'\.dma_start_store_out\(dma_start_store_out\),\n', '', code)
code = re.sub(r'\.dma_out_store_done\(dma_out_store_done\),\n', '', code)

with open(top, "w", encoding="utf-8") as f:
    f.write(code)

print("NPU controller and TOP fixed")
