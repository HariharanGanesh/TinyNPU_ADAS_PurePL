import sys

def replace_in_file(filepath, old_text, new_text):
    content = open(filepath, "r").read()
    open(filepath, "w").write(content.replace(old_text, new_text))

replace_in_file("npu200_paper_facts.md", "~0.550 W (estimated at 124.2 MHz)", "~0.926 W (Dynamic: 0.810 W, Static: 0.116 W at 124.2 MHz)")
replace_in_file("results_and_discussion.md", "estimated at approximately 0.55 W", "estimated at approximately 0.93 W")

