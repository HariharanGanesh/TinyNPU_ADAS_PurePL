import sys

def replace_in_file(filepath, old_text, new_text):
    content = open(filepath, "r").read()
    open(filepath, "w").write(content.replace(old_text, new_text))

replace_in_file("npu200_paper_facts.md", "14 (Rows) x 8 (Cols) = 112 Processing Elements (PEs)", "14 (Rows) x 14 (Cols) = 196 Processing Elements (PEs)")
replace_in_file("npu200_paper_facts.md", "Total LUTs**: 28,913 (54.34% of 53,200)", "Total LUTs**: ~35,465 (66.6% of 53,200)")

replace_in_file("results_and_discussion.md", "14x8 systolic array (112 Processing Elements)", "14x14 systolic array (196 Processing Elements)")
replace_in_file("results_and_discussion.md", "The 14x8 systolic array's 8-bit multipliers", "The 14x14 systolic array's 8-bit multipliers")
replace_in_file("results_and_discussion.md", "28,913 | 53,200 | 54.34%", "35,465 | 53,200 | 66.66%")
replace_in_file("results_and_discussion.md", "112-PE systolic array", "196-PE systolic array")
