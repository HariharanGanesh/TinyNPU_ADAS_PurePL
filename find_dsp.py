lines = open("util_fixed.rpt").readlines()
for line in lines:
    if "|" in line and line.strip().endswith("|"):
        parts = line.split("|")
        if len(parts) > 10:
            dsp = parts[-2].strip()
            if dsp != "0" and dsp != "DSP Blocks":
                print(line.strip())
