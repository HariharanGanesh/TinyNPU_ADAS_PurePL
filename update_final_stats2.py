import sys

def replace_in_file(filepath, old_text, new_text):
    content = open(filepath, "r").read()
    open(filepath, "w").write(content.replace(old_text, new_text))

replace_in_file("results_and_discussion.md", "WNS) of just -0.051 ns, yielding an effective Maximum Operating Frequency ($F_{max}$) of **124.2 MHz**", "WNS) of +0.002 ns, yielding an effective Maximum Operating Frequency ($F_{max}$) of **123.48 MHz**")
