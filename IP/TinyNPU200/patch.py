import sys
with open('src/npu_controller.v', 'r') as f:
    lines = f.readlines()

for i, line in enumerate(lines):
    if 'csr_start' in line:
        lines[i] = line + '                        ("DEBUG_NPU: STARTING INFERENCE");\n'
    elif 'dma_wgt_load_done' in line and 'begin' in line:
        lines[i] = line + '                        ("DEBUG_NPU: WGT LOAD DONE");\n'
    elif 'dma_act_load_done' in line and 'begin' in line:
        lines[i] = line + '                        ("DEBUG_NPU: ACT LOAD DONE");\n'
    elif 'drain_cycles  <= 0;' in line:
        lines[i] = line + '                        ("DEBUG_NPU: COMPUTE DONE");\n'
    elif 'STATE_STORE_OUT;' in line:
        lines[i] = line + '                        ("DEBUG_NPU: DRAIN DONE, STARTING OUT STORE");\n'
    elif 'dma_out_store_done' in line and 'begin' in line:
        lines[i] = line + '                        ("DEBUG_NPU: OUT STORE DONE");\n'
    elif 'STATE_DONE: begin' in line:
        lines[i] = line + '                    ("DEBUG_NPU: ALL TILES DONE");\n'

with open('src/npu_controller.v', 'w') as f:
    f.writelines(lines)
