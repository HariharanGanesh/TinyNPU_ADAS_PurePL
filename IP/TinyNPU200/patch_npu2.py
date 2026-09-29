import sys

with open('src/npu_controller.v', 'r') as f:
    code = f.read()

code = code.replace(
    '("[NPU_CTRL @ %0t] *** INFERENCE DONE *** status_done=1", );',
    '// ("[NPU_CTRL @ %0t] *** INFERENCE DONE *** status_done=1", );'
)

with open('src/npu_controller.v', 'w') as f:
    f.write(code)

print("Patch npu_controller.v complete")
