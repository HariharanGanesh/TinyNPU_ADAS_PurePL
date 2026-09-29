import re

npu_path = "IP/TinyNPU200/src/npu_controller.v"
with open(npu_path, "r", encoding="utf-8") as f:
    npu_code = f.read()
    
# Check ports
for line in npu_code.split('\n'):
    if 'dma' in line.lower() and ('act' in line.lower() or 'out' in line.lower()):
        print(line.strip())
