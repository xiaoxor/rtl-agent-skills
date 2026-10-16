# Icarus Verilog

Measured 2026-10-15/16 with Icarus 13.0 stable (`v13_0`) in MSYS2 UCRT64 on
Windows. Re-probe other versions before relying on a tool-specific difference.
Experiment sources and full logs are in
[`tests/testbench-craft/README.md`](../../tests/testbench-craft/README.md).

- `$fatal(1, ...)` stops simulation, prints `FATAL: <marker>`, and exits with
  status 1. Check the diagnostic marker as well as the exit status.
- The tested version rejects SystemVerilog `clocking block` syntax at compile
  time.
- The default simulation is four-state; `!==` can detect X/Z values.
- The same-edge blocking-drive race probe observed current/old values of 4/4.
  This result is not a scheduling guarantee; avoid the race.
- Initializing `clk` from X to 0 at time zero did not trigger spurious
  falling-edge work in the tested version.
