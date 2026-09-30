import sys

def replace_in_file(filepath, old_text, new_text):
    content = open(filepath, "r").read()
    open(filepath, "w").write(content.replace(old_text, new_text))

replace_in_file("npu200_paper_facts.md", "Target: 125 MHz (8.000 ns period)", "Target: 123.45 MHz (8.100 ns period)")
replace_in_file("npu200_paper_facts.md", "Post-Route WNS: -0.051 ns", "Post-Route WNS: +0.002 ns (0 Failing Endpoints)")
replace_in_file("npu200_paper_facts.md", "Achieved Fmax**: 124.2 MHz", "Achieved Fmax**: 123.48 MHz")
replace_in_file("npu200_paper_facts.md", "28,913 (54.34% of 53,200)", "29,236 (54.95% of 53,200)")
replace_in_file("npu200_paper_facts.md", "46,497 (43.70% of 106,400)", "46,572 (43.77% of 106,400)")
replace_in_file("npu200_paper_facts.md", "~0.926 W (Dynamic: 0.810 W, Static: 0.116 W at 124.2 MHz)", "~1.052 W (Dynamic: 0.934 W, Static: 0.119 W at 123.4 MHz)")
replace_in_file("npu200_paper_facts.md", "WNS of -0.051 ns (max 124.2 MHz) with no failing endpoints at 124 MHz", "WNS of +0.002 ns (max 123.48 MHz) with 0 failing endpoints")

replace_in_file("results_and_discussion.md", "28,913 | 53,200 | 54.34%", "29,236 | 53,200 | 54.95%")
replace_in_file("results_and_discussion.md", "46,497 | 106,400 | 43.70%", "46,572 | 106,400 | 43.77%")
replace_in_file("results_and_discussion.md", "8.0 ns clock period (125 MHz target)", "8.1 ns clock period (123.45 MHz target)")
replace_in_file("results_and_discussion.md", "WNS) of just -0.051 ns, yielding an effective Maximum Operating Frequency ($F_{max}$) of **124.2 MHz**", "WNS) of +0.002 ns, yielding an effective Maximum Operating Frequency ($F_{max}$) of **123.48 MHz**")
replace_in_file("results_and_discussion.md", "At 124.2 MHz", "At 123.48 MHz")
replace_in_file("results_and_discussion.md", "approximately 0.93 W", "approximately 1.05 W")
