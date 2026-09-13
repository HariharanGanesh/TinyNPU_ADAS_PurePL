# Verification Test Plan: TinyNPU200A

## 1. Systolic Array (`systolic_array.v`)
| Feature/Mode | Technique | Pass/Fail Criteria |
| --- | --- | --- |
| TC01: Zero activation input | Directed | All psum outputs = 0 |
| TC02: Zero weight input | Directed | All psum outputs = 0 |
| TC03: Identity-like matrix | Directed | Single column result matches expected |
| TC04: Max positive INT8 | Directed | No overflow in 32-bit accum (127*127*20) |
| TC05: Max negative INT8 | Directed | Signed result matches expected (-128*127*20) |
| TC06: Back-to-back streaming | Directed | Psum calculated correctly for consecutive tiles |
| TC07: Reset mid-computation | Directed | Clean restart, no X, correctly resumes |
| TC08: Weight reload | Directed | New weights affect subsequent computations |

## 2. AXI4-Lite CSR (`axi4_lite_slave.v`)
| Feature/Mode | Technique | Pass/Fail Criteria |
| --- | --- | --- |
| TC01: Write CTRL / Read STATUS | Directed | Write CTRL[start]=1, read STATUS.idle=0 |
| TC02: Reset values | Directed | Read all CSRs at reset, check expected defaults |
| TC03: Read/Write all CSRs | Directed | Data written is read back exactly |
| TC04: Read-only registers | Directed | Write to 0x48 ignored, reads back default |
| TC05: Illegal address | Directed | Address 0xFF00 yields SLVERR (2'b10) |
| TC06: Back-to-back transactions | Directed | Write then read without gaps |
| TC07: Reset during transaction | Directed | Clean recovery after reset mid-transaction |
| TC08: Simultaneous read/write | Directed | Both transactions complete correctly |

## 3. AXI4-Stream Sink (`axis_sink.v`)
| Feature/Mode | Technique | Pass/Fail Criteria |
| --- | --- | --- |
| TC01: Normal streaming | Directed | Buffer write address increments |
| TC02: Crop window enabled | Directed | Only cropped pixels stored |
| TC03: Crop disabled | Directed | All pixels stored |
| TC04: Back-pressure | SVA / Directed | `s_axis_tready` deasserts when `buf_full`=1 |
| TC05: Frame boundary (`tlast`) | Directed | `frame_done` pulses |
| TC06: Back-to-back frames | Directed | Processes multiple frames cleanly |

## 4. AXI4-Stream Source (`axis_source.v`)
| Feature/Mode | Technique | Pass/Fail Criteria |
| --- | --- | --- |
| TC01: Normal drain | Directed | `m_axis_tdata` outputs sequence |
| TC02: Back-pressure | SVA / Directed | `m_axis_tvalid` held when `tready`=0 |
| TC03: `tlast` assertion | Directed | Asserted on final byte |
| TC04: `drain_done` pulse | Directed | Pulses after complete tile drain |
| TC05: Empty buffer drain | Directed | No spurious output when `buf_empty`=1 |

## 5. Processing Element (`processing_element.v`)
| Feature/Mode | Technique | Pass/Fail Criteria |
| --- | --- | --- |
| TC01: Basic multiply | Directed | 1 * 1 = 1 |
| TC02: Max positive INT8 | Directed | 127 * 127 = 16129 |
| TC03: Mixed sign | Directed | -128 * 127 = -16256 |
| TC04: Max negative INT8 | Directed | -128 * -128 = 16384 |
| TC05: Weight load sequence | Directed | New weight takes effect properly |
| TC06: Accumulator clear | Directed | Psum resets when `psum_clear`=1 |
| TC07: Pipeline latency | SVA / Directed | Exactly 3 cycles latency |
| TC08: PE enable | Directed | No accumulation when `pe_en`=0 |

## 6. Top-Level Integration (`tinynpu_top.v`)
| Feature/Mode | Technique | Pass/Fail Criteria |
| --- | --- | --- |
| TC01: CSR Configuration | Directed | Registers set, start triggered |
| TC02: Weight DMA | Directed | AXI memory model responds, DMA completes |
| TC03: Activation streaming | Directed | Valid stream sent |
| TC04: Output collection | Directed | Valid stream received |
| TC05: Reset during inference | Directed | Clean recovery |
| TC06: Missing weights error | Directed | Graceful stall / error flag |

## Coverage Goals
- 100% Code Coverage (Line, Toggle, Conditional/Branch).
- 100% Assertion Coverage.
- Exhaustive boundary tests for PE arithmetic.
