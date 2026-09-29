import glob

for f in glob.glob("verification/tb/*.sv") + glob.glob("verification/tb/*.v"):
    with open(f, 'r') as file:
        content = file.read()
    
    new_content = content.replace("RESULT: PASS", "TB_RESULT: PASS").replace("RESULT: FAIL", "TB_RESULT: FAIL")
    
    if new_content != content:
        with open(f, 'w') as file:
            file.write(new_content)
        print(f"Updated {f}")