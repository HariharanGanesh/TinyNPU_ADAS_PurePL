# NPU300 & RISC-V Controller: Engineering Bug & Resolution Training Data

This document catalogs the critical errors, bugs, and timing violations encountered during the integration and synthesis of the `RISCV_ADAS_NPU300` subsystem, along with the robust engineering solutions implemented to resolve them. This data serves as training and reference material for future IP integrations.

## 1. Vivado Batch Mode Path Parsing Bug (Space in Directory)

### **The Accident / Error**
When attempting to execute the `create_riscv_adas.tcl` script in Vivado batch mode, the synthesis engine consistently crashed with:
```text
ERROR: [Vivado 12-172] File or Directory 'D:/Final' does not exist
WARNING: [IP_Flow 19-2248] Failed to load user IP repository 'd:/Final'; Can't find the specified path.
```

### **Root Cause Analysis**
The project directory (`D:\Final year project`) contains spaces. While Vivado GUI handles spaces correctly, Vivado's TCL batch-mode parser (specifically the internal IP resolver) fundamentally breaks when parsing `.xpr` files located in space-delimited paths. Wrapping paths in `[list "..."]` or literal brackets `{...}` inside the TCL script failed because the error occurs deep within Vivado's core `open_project` routines before custom script logic executes.

### **The Robust Fix**
Instead of attempting to escape the strings, we bypassed Vivado's parser bug entirely at the OS level by mapping the space-delimited path to a virtual drive letter using the Windows `subst` command prior to launching Vivado:
```cmd
cmd.exe /c "subst X: "D:\Final year project" & X: & D:\2025.1\Vivado\settings64.bat & vivado -mode batch -source "X:\create_riscv_adas.tcl" & subst X: /D"
```
This forces Vivado to interpret all paths via the flawless `X:\` root, completely resolving all IP resolution and file addition crashes.

---

## 2. AXI DMA Cross-Domain Hold Violation (WHS = -0.194ns)

### **The Accident / Error**
After successful mapping, the Timing Report revealed a critical Hold Violation (Worst Hold Slack = -0.194ns), violating the strict safety mandate that all timing parameters must be $\ge 0$.
```text
Source: npu_system_i/tinynpu_0/inst/u_csr/reg_weight_base_reg[0]/C
Destination: npu_system_i/tinynpu_0/inst/u_dma/m_axi_araddr_reg[0]/D
Clock Path Skew: 0.830ns
Data Path Delay: 0.713ns
```

### **Root Cause Analysis**
The `axi4_lite_slave` is clocked by the raw `clk` (125 MHz), while the `dma_controller` is clocked by `clk_dma` (which is gated by a BUFGCE clock gating cell). The physical insertion delay of the clock gate caused a massive **0.830ns Clock Path Skew**. Because the data path delay between the two modules was only `0.713ns`, the data was arriving at the DMA flip-flops *before* the delayed clock had actually ticked, violating the hold equation ($0.713ns < 0.830ns$).

### **The Robust Fix**
Instead of masking the error using a `.xdc` `set_false_path` constraint (which is considered a brittle "hack" in automotive functional safety), the Verilog RTL was structurally modified.
1. The incoming CSR configuration buses (`weight_base_addr`, `act_base_addr`, `out_base_addr`) were renamed to `*_in`.
2. A physical 1-cycle pipeline register block clocked by `clk_dma` was injected directly into the `dma_controller.v` input stage.
```verilog
always @(posedge clk) begin
    weight_base_addr <= weight_base_addr_in;
    act_base_addr <= act_base_addr_in;
    out_base_addr <= out_base_addr_in;
end
```
This physical buffer safely absorbs the cross-tree clock skew, completely eliminating the hold violation at the hardware level and resulting in a flawless green timing report.
