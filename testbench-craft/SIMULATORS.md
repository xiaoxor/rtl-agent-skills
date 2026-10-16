# Measured simulator behavior

Per-tool facts behind `SKILL.md`. Reach for this when wiring run scripts, or
when choosing clocking blocks or X checks for a specific simulator. Behavior
was measured with the versions listed at the bottom; re-probe on other
versions before relying on a difference. Experiment sources, commands, and
full logs: `tests/testbench-craft/README.md` in the rtl-agent-skills repo.

## Process exit codes

| Simulator | `$fatal(1, ...)` effect | process exit |
| --- | --- | --- |
| Icarus 13.0 | stops, prints `FATAL: <marker>` | 1 |
| Verilator 5.050 (`--binary`) | stops, prints `FATAL: <marker>` | 1 |
| XSIM 2025.2 (batch `xsim`) | stops, prints `Fatal: <marker>` | 0, even with `--onerror quit` |
| VCS W-2024.09-SP1 (`simv`) | stops, prints `Fatal: <marker>` | 0; `+error+exit` did not change this |

Automation rule (already inlined in `SKILL.md`): judge by the log — PASS
marker on successful runs, specific failure marker on intentional failures —
and let the run script own the reported exit code.

## Clocking blocks (`default input #1step`)

| Simulator | first rising-edge sample of `cb.x` |
| --- | --- |
| Icarus 13.0 | rejects the syntax at compile |
| XSIM 2025.2 | `xx` although the source register reads `0` |
| Verilator 5.050 | conforms |
| VCS W-2024.09-SP1 | conforms (pre-edge value) |

The falling-edge drive/sample template in `SKILL.md` needs no clocking block
and passes on all four tools. The time-zero X→0 write on `clk` did not
trigger spurious falling-edge work in these versions.

## Two-state and race notes

- Default Verilator is two-state: an `8'hxx` probe reads as 0, so `!==` X
  checks cannot prove absence of unknowns there; Icarus/XSIM/VCS reject it.
- The same-edge blocking-drive race produced different counts per tool
  (Icarus 4/4, Verilator 8/0, XSIM 9/0 and 1/8, VCS 9/0 current/old). No
  same-edge ordering is a portable contract.

Measured 2026-10-15/16: Icarus 13.0 and Verilator 5.050 (MSYS2 UCRT64,
Windows), XSIM 2025.2 (Vivado batch flow), VCS W-2024.09-SP1 (RHEL 8.10).
