# Contributing — TinyNPU_ADAS_PurePL

> Copyright (c) 2026 Hariharan Ganesh. All rights reserved.  
> This IP is proprietary. All contributions require author authorization. See [ACCESS.md](ACCESS.md).

---

## Contribution Policy

**TinyNPU_ADAS_PurePL** is proprietary intellectual property. This is not an open-source project. However, constructive feedback, bug reports, and documentation improvements from authorized users are genuinely welcome.

All contributions that involve RTL source files require **explicit prior written authorization** from the author. See [ACCESS.md](ACCESS.md) for the request process.

---

## Reporting Bugs

If you have authorized access and discover a bug, please open a GitHub Issue with the label `bug`. Include:

| Field | Details |
|---|---|
| **Description** | Clear, concise problem statement |
| **Steps to Reproduce** | Exact simulation or synthesis steps |
| **Expected Behaviour** | What should happen |
| **Actual Behaviour** | What actually happened |
| **Environment** | Vivado version, simulator, OS |
| **Logs** | Relevant console output, waveform notes |

> Only authorized users may file RTL-level bug reports.

---

## Suggesting Improvements

Open a GitHub Issue with the label `enhancement`. Describe:
- The proposed improvement and its technical justification
- Potential impact on existing functionality
- Whether RTL modification is required

Accepted suggestions do not automatically grant the contributor any rights over the IP.

---

## RTL Contribution Requirements

Any authorized RTL contribution must:

1. Follow the **Verilog-2001** coding standard (synthesizable, no simulation-only constructs)
2. Use **non-blocking assignments** (`<=`) in all clocked `always` blocks
3. Use **`localparam`** for all loop bounds and constants (not `parameter`)
4. Include **no FPGA-specific primitives** in synthesizable modules
5. Add **testbench coverage** for any new logic
6. Pass **all existing testbenches** without modification
7. **Retain all copyright notices** and file headers

---

## Documentation Contributions

Documentation improvements (clarity, typos, examples) may be submitted as Pull Requests without prior authorization, provided:
- No RTL source files are modified
- No copyright notices are altered
- The contribution does not misrepresent the IP

---

## Code of Conduct

- Be professional and respectful in all communications.
- Do not claim authorship of any part of the original IP.
- Do not share or redistribute any IP files without explicit written authorization.
- Retain all copyright and attribution notices.

---

## Contact

**Hariharan Ganesh**  
📧 [hariharanganesh67@gmail.com](mailto:hariharanganesh67@gmail.com)  
🐙 [github.com/HariharanGanesh](https://github.com/HariharanGanesh)

---

*Copyright (c) 2026 Hariharan Ganesh. All rights reserved.*
