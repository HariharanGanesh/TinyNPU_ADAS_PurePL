import sys
def replace_in_file(filepath, old_text, new_text):
    content = open(filepath, "r").read()
    open(filepath, "w").write(content.replace(old_text, new_text))

replace_in_file("npu200_paper_facts.md", "(computed spatially by duplicating 8-column psums across the 14 rows, allowing hardware-efficient mapping of Depthwise Convolution)", "(computed in a single pass with exact 1-to-1 spatial mapping to the Depthwise Convolution engine)")
