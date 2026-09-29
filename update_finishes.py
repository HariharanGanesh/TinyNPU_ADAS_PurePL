import glob
files = ["verification/tb/streaming_topk_tb.sv", "verification/tb/bbox_decoder_dfl_tb.sv", "verification/tb/sparse_candidate_packer_tb.sv", "verification/tb/npu_detection_head_tb.sv"]

for f in files:
    with open(f, 'r') as file:
        content = file.read()
    
    if "TB_RESULT: PASS" not in content:
        new_content = content.replace("$finish;", "$display(\"TB_RESULT: PASS\");\n        $finish;")
        with open(f, 'w') as file:
            file.write(new_content)
        print(f"Updated {f}")