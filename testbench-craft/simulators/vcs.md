# Synopsys VCS

Measured 2026-10-15/16 with VCS W-2024.09-SP1 (`simv`) on RHEL 8.10. Re-probe
other versions before relying on a tool-specific difference. Experiment sources
and full logs are in
[`tests/testbench-craft/README.md`](../../tests/testbench-craft/README.md).

- `$fatal(1, ...)` stops simulation and prints `Fatal: <marker>`, but `simv`
  exits 0 in the tested version; `+error+exit` did not change this. Classify
  failures from the log marker, and let the run script set its own exit status.
- The tested version supports the clocking-block probe and samples
  `input #1step` at the documented pre-edge value.
- Four-state checks such as `!==` can detect X/Z values.
- The same-edge blocking-drive race probe observed current/old values of 9/0
  in both source-order variants. This result is not a scheduling guarantee;
  avoid the race.
- Initializing `clk` from X to 0 at time zero did not trigger spurious
  falling-edge work in the tested version.
