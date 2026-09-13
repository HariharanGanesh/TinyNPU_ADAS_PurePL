# Vivado Best Practices

When working with Xilinx Vivado in batch mode or dealing with timing closures, you must strictly follow these rules:

## 1. Batch Mode Path Parsing Bug (Spaces in Directory)
Vivado's TCL batch mode parser (specifically the internal IP resolver and `open_project` / `add_files` commands) fundamentally breaks when the project directory path contains spaces (e.g., `D:\Final year project`). Standard TCL escaping techniques (`[list ...]`, `"{...}"`) will fail deep in the core engine.

**RULE**: When running Vivado in batch mode from a directory containing spaces, you MUST bypass the parser bug at the OS level using the Windows `subst` command to map the directory to a virtual drive letter (e.g., `X:\`). 

Execute your batch commands using this wrapper:
```cmd
cmd.exe /c "subst X: "C:\Path With Spaces" & X: & <vivado_call> -source "X:\script.tcl" & subst X: /D"
```

## 2. AXI Cross-Domain Hold Violations (Clock Gating Skew)
When routing signals from an AXI4-Lite CSR slave (clocked by a raw `clk`) to a module clocked by a gated clock (e.g., `clk_dma` passing through a `BUFGCE`), Vivado may fail to meet hold time due to massive Clock Path Skew (the gated destination clock arrives much later than the source clock).

**RULE**: Do NOT fix hold violations using `.xdc` `set_false_path` or `set_multicycle_path` constraints unless absolutely necessary.
Instead, structurally modify the RTL by injecting a physical 1-cycle pipeline register block into the destination module. Clock this pipeline register using the destination's delayed clock (`clk_dma`). This physical buffer absorbs the cross-tree clock skew naturally and guarantees clean physical timing constraints ($WHS \ge 0$).
