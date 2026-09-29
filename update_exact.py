import sys
def replace_in_file(filepath, old_text, new_text):
    content = open(filepath, "r").read()
    open(filepath, "w").write(content.replace(old_text, new_text))

replace_in_file("npu200_paper_facts.md", "~35,465 (66.6% of 53,200)", "37,148 (69.8% of 53,200)")
replace_in_file("npu200_paper_facts.md", "Flip-Flops (FFs)**: 46,497 (43.70% of 106,400)", "Flip-Flops (FFs)**: 54,219 (50.9% of 106,400)")

replace_in_file("results_and_discussion.md", "35,465 | 53,200 | 66.66%", "37,148 | 53,200 | 69.82%")
replace_in_file("results_and_discussion.md", "46,497 | 106,400 | 43.70%", "54,219 | 106,400 | 50.95%")
