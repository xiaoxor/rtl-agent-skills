# Verilator

Measured 2026-10-15/16 with Verilator 5.050 (`--binary --timing`) in MSYS2
UCRT64 on Windows. Re-probe other versions before relying on a tool-specific
difference. Experiment sources and full logs are in
[`tests/testbench-craft/README.md`](../../tests/testbench-craft/README.md).

- `$fatal(1, ...)` stops simulation, prints `FATAL: <marker>`, and exits with
  status 1. Check the diagnostic marker as well as the exit status.
- The tested version supports the clocking-block probe and samples
  `input #1step` at the documented pre-edge value.
- Default Verilator simulation is two-state: an X probe reads as zero, so it
  cannot prove that unknown values are absent.
- The same-edge blocking-drive race probe observed current/old values of 8/0.
  This result is not a scheduling guarantee; avoid the race.
- Initializing `clk` from X to 0 at time zero did not trigger spurious
  falling-edge work in the tested version.
