# Regression Run Instructions

Run from the `D:\Final year project` directory using Vivado `xvlog`, `xelab`, and `xsim`.

```bash
# Compile
xvlog -sv IP/TinyNPU200/src/*.v
xvlog -sv verification/tb/*.sv

# Elaborate
xelab -debug typical -top tb_processing_element -snapshot tb_pe
xelab -debug typical -top tb_axi_csr -snapshot tb_csr
# (repeat for other TBs)

# Simulate
xsim tb_pe -R
xsim tb_csr -R
```
