# TinyNPU200: Architectural Optimization & DSP Resource Strategy

This document outlines concrete, efficiency-preserving strategies to close timing on the Zynq-7020 (-1 speedgrade) at 125 MHz without sacrificing the effective throughput of the NPU. Since all 192 available DSPs are consumed by the 160 PEs and 32 Requantizers, the 72 Depthwise Convolution (DW) multipliers are spilling into fabric LUTs, causing an unbreakable 9.1 ns routing/logic delay. 

Below are three architectural techniques to resolve this while strictly maintaining or improving sustained ops/s.

---

## 1. Systolic Array DSP Time-Multiplexing (Overclocking)
**Idea in 2-3 sentences:** 
The DSP48E1 slices on a -1 speedgrade Zynq-7020 can easily operate at 250 MHz, while the surrounding NPU fabric runs at 125 MHz. By driving the Systolic Array DSPs with a 2x (250 MHz) clock, a single physical DSP can execute two MAC operations per 125 MHz fabric cycle. This functionally folds a 160-PE systolic array into just 80 physical DSPs, freeing up 80 DSPs to be assigned to the Depthwise Convolution engine.

**How it preserves efficiency:** 
The macro-architecture (125 MHz external, 160 logical PEs) remains completely unchanged. Compute throughput (GOPS) is mathematically identical.

**Implementation sketch:**
```verilog
// 250 MHz Domain (clk_2x)
always @(posedge clk_2x) begin
    // Phase 0: Compute odd logical PEs
    if (phase == 0) psum_reg <= A_odd * B_odd + psum_in;
    // Phase 1: Compute even logical PEs
    else            psum_reg <= A_even * B_even + psum_in;
end
```

**Pros / Cons / Risks:**
*   **Pros:** Radically reduces DSP utilization (frees 80 DSPs), easily solving the DW multiplier shortage. 
*   **Cons:** Requires managing a new clock domain (`clk_2x`) and carefully designing gearboxes (clock domain crossing logic) at the boundaries of the systolic array.
*   **Risks:** High fanout on the 250 MHz clock network could introduce local clock skew issues.

---

## 2. DSP Packing (Two 8x8 Multiplies in One DSP48E1)
**Idea in 2-3 sentences:** 
A single DSP48E1 features a 25x18 multiplier. By shifting one 8-bit operand into the upper 16 bits of the 25-bit `A` port, we can pack two independent 8x8 multiplications into a single DSP cycle, provided they share the second operand (`B`). In Depthwise Convolution, the static kernel weights (`w`) are naturally shared across adjacent spatial pixels.

**How it preserves efficiency:** 
Doubles the throughput of the depthwise engine per DSP. We can compute 2 spatial output pixels per cycle, or simply fold the 72 DW multipliers into 36 DSPs. 

**Implementation sketch:**
```verilog
// Pack x_pixel1 into upper bits, x_pixel0 into lower bits
wire [24:0] A_packed = {x_pixel1[7:0], 8'b0, x_pixel0[7:0]};
wire [17:0] B_shared = {10'b0, weight[7:0]};

// DSP48E1 inference
wire [42:0] P_out = A_packed * B_shared;

// Extract independent 16-bit products
wire [15:0] prod_pixel1 = P_out[31:16]; 
wire [15:0] prod_pixel0 = P_out[15:0];
```

**Pros / Cons / Risks:**
*   **Pros:** Requires no secondary clocks (stays at 125 MHz). Highly elegant use of silicon.
*   **Cons:** We still need to free up 36 DSPs from somewhere (e.g., combining this with packing the Requantizers).
*   **Risks:** Sign extension requires careful bit-masking in the DSP pre-adder.

---

## 3. Explicit 2-Stage LUT Multiplier (Manual RTL Pipelining)
**Idea in 2-3 sentences:** 
Vivado failed to retime the inferred `*` operator across the fabric logic because inferred multipliers are often synthesized as monolithic hard-macros. By manually writing a 2-stage shift-and-add radix-4 Booth multiplier in RTL, we forcefully insert a hard architectural flip-flop boundary precisely in the center of the logic cone.

**How it preserves efficiency:** 
Requires 0 additional DSPs. The DW latency increases by exactly 1 cycle, but because the engine is fully pipelined, the sustained throughput remains exactly 1 output pixel per cycle.

**Implementation sketch:**
```verilog
// Stage 1: Partial Product Generation (4ns delay)
always @(posedge clk) begin
    pp0 <= (w[0] ? x : 0);
    pp1 <= (w[1] ? x << 1 : 0);
    // ...
end

// Stage 2: Final Adder Tree (4ns delay)
always @(posedge clk) begin
    mult_out <= pp0 + pp1 + pp2 + ...;
end
```

**Pros / Cons / Risks:**
*   **Pros:** The most non-invasive solution. Requires zero changes to clocking, zero DSP reallocation, and easily achieves 125 MHz.
*   **Cons:** Consumes ~4,000 LUTs for the 72 multipliers (which we currently have space for).
*   **Risks:** Lowest risk. Guaranteed to break the 9.1 ns path into two ~4.5 ns paths.

> [!IMPORTANT]
> **Recommendation:** 
> I highly recommend starting with **Technique 3 (Explicit 2-Stage LUT Multiplier)**. It requires no changes to the Systolic Array, completely preserves your DSP budget, and fixes the timing violation purely in RTL. If you approve, I can immediately rewrite `dw_line_buffer.v` to replace the inferred multipliers with a pipelined shift-and-add module.
