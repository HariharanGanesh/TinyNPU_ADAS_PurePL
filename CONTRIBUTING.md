# Contributing ? TinyNPU_ADAS_PurePL IP Core

> Copyright (c) 2026 Hariharan Ganesh. All rights reserved.
> This IP is proprietary. Contributions require author authorization.

---

## Important: Contribution Policy

The TinyNPU_ADAS_PurePL IP Core is **proprietary intellectual property**. All contributions,
suggestions, and modifications are subject to review and approval by the author.

**Before contributing, you must have explicit written authorization.**
See [ACCESS.md](ACCESS.md) for the access request process.

---

## How to Report Bugs

If you have been granted authorized access and discover a bug:

1. **Check existing issues** to avoid duplicates.
2. **Open a GitHub Issue** with the label `bug`.
3. Include:
   - A clear description of the problem
   - Steps to reproduce the issue
   - Expected behavior
   - Actual behavior
   - Vivado version and simulator used
   - Relevant log excerpts or simulation output

**Note:** Only authorized users may submit bug reports that involve the RTL source.

---

## How to Suggest Improvements

1. **Open a GitHub Issue** with the label `enhancement`.
2. Describe:
   - The proposed improvement
   - The technical justification
   - Any potential impact on existing functionality
   - Whether it requires RTL modification

All suggestions are evaluated by the author. Accepted suggestions do not
automatically grant the suggester any rights over the IP.

---

## RTL Contributions

Contributions to the RTL source require:

1. **Prior written authorization** from the author
2. **Compliance with the project's coding style:**
   - Verilog-2001 synthesizable RTL
   - No FPGA-specific primitives in synthesizable files
   - All generate loop bounds via `localparam` (not `parameter`)
   - Non-blocking assignments in clocked always blocks
   - All module parameters documented
3. **Testbench coverage** for any new functionality
4. **Verification requirement:** All existing tests must continue passing
5. **Attribution retention:** Existing copyright notices must not be modified

---

## Documentation Contributions

Documentation improvements (spelling, clarity, additional examples) may be
submitted as GitHub Pull Requests without prior authorization, provided that:

- No RTL source files are modified
- No existing copyright notices are altered
- The contribution does not misrepresent the IP's capabilities

---

## Verification Expectations

Any contribution that modifies RTL must:

- Pass all 5 existing test cases in `tb_tinynpu_top.sv`
- Include a `run_all.tcl` simulation demonstrating all tests pass
- Not alter existing test case expected results without justification

---

## Code of Conduct

- Be respectful in all communications
- Do not claim authorship of any part of the original IP
- Retain all copyright and attribution notices
- Do not share or distribute the IP without authorization

---

## Contact

**Hariharan Ganesh**
Email: hariharanganesh67@gmail.com
GitHub: https://github.com/HariharanGanesh

*Copyright (c) 2026 Hariharan Ganesh. All rights reserved.*

---
