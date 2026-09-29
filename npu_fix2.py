import os

npu = "IP/TinyNPU200/src/npu_controller.v"
with open(npu, "r", encoding="utf-8") as f:
    code = f.read()

# I removed the ports, so just remove the usages.
code = code.replace("dma_start_store_out <= 1'b1;", "// dma_start_store_out removed")
code = code.replace("dma_start_store_out <= 1'b0;", "// dma_start_store_out removed")
code = code.replace("if (dma_out_store_done) begin", "if (1'b1) begin // dma_out_store_done removed")

with open(npu, "w", encoding="utf-8") as f:
    f.write(code)
    
print("NPU fixed.")
