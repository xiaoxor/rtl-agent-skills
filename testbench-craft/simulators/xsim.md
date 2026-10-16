# XSIM

Measured 2026-10-15/16 with XSIM 2025.2 in the Vivado batch flow. Re-probe
other versions before relying on a tool-specific difference. Experiment sources
and full logs are in
[`tests/testbench-craft/README.md`](../../tests/testbench-craft/README.md).

- `$fatal(1, ...)` stops simulation and prints `Fatal: <marker>`, but batch
  `xsim` exits 0, even with `--onerror quit`. Classify failures from the log
  marker, and let the run script set its own exit status.
- In XSIM 2025.2, the clocking-block probe compiled but its first
  `input #1step` sample was `xx` when `sampled` was initialized with a
  declaration initializer (`reg [7:0] data = 0, sampled = 0;`), even though
  the source register read `00`. An isolation run showed that moving only
  `sampled = 0` into an explicit `initial begin ... end` made the probe pass;
  moving only `clk = 0` did not. This looks like a possible version-specific
  XSIM clocking-sample/scheduling bug; it is an observed workaround, not a
  confirmed AMD issue. Initialize testbench variables procedurally in their
  owning `initial` process, before waits or sampling edges.
- Four-state checks such as `!==` can detect X/Z values.
- The same-edge blocking-drive race probe observed current/old values of 9/0
  and 1/8 in its two source-order variants. These results are not scheduling
  guarantees; avoid the race.
- Initializing `clk` from X to 0 at time zero did not trigger spurious
  falling-edge work in the tested version.
