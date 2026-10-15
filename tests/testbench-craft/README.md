# testbench-craft simulation checks

Small executable experiments for the scheduling and checking claims in
[`testbench-craft/SKILL.md`](../../testbench-craft/SKILL.md).
These test the described Verilog behavior and the actual Markdown template;
they do not test whether an agent consistently follows the skill.

## Run

From the repository root in **MSYS2 UCRT64 Bash** on this Windows machine:

```bash
bash tests/testbench-craft/run.sh
```

The runner requires `iverilog`, `vvp`, `verilator`, the Verilator C++ build
toolchain, and GNU `timeout`. It compiles with `iverilog -g2012` and
`verilator --binary --timing`, without HDL warning suppression flags. Each run has a
15-second host timeout, each compilation a 120-second timeout. The final exit
status is nonzero if an observed result differs from the expected result.

The runner checks both the exit status and a specific diagnostic. Deliberate
failure cases must fail for the intended reason; merely crashing or reaching
the host timeout does not count as success. Only a successful compilation is
followed by execution. The Icarus clocking-block probe is expected to fail
compilation in the tested version; this is a compatibility result, not a
passing simulation.

Generated sources, executables, and complete logs stay in ignored `.build/`:

- `results.txt`: check outcomes and final summary.
- `iverilog-version.log`, `verilator-version.log`: actual tool versions.
- `<simulator>/<case>/compile.log`: compiler output, including diagnostics.
- `<simulator>/<case>.log`: complete runtime output.

## Measured results

Tested on **2026-10-15**, Windows with MSYS2 UCRT64:

- Icarus Verilog **13.0 stable** (`v13_0`).
- Verilator **5.050**, `2026-07-01 rev vUNKNOWN-built20260702`.

| Experiment | Icarus 13.0 | Verilator 5.050 | What it checks |
| --- | --- | --- | --- |
| `tb_scheduling.sv` | PASS | PASS | An `always` driver using same-edge NBA takes effect after sampling; Active reads see old registers; off-edge blocking drive is stable at sampling. |
| `tb_nba_initial.sv` | PASS | PASS | Same-edge NBA in an `initial` process also retains the old input until NBA in these versions. |
| `tb_zero_delay.sv` | PASS | PASS | `#0` still observes the pre-NBA value; the explicitly bounded `#1` observes the updated register. |
| `tb_clocking.sv` | Compilation rejected | PASS | Clocking `input #1step` sees the pre-edge register; `output #0` is accepted on the following sampling edge. |
| `tb_race.sv` | Current/old: **4/4** | Current/old: **8/0** | Same-edge blocking stimulus races with DUT sampling. Both source-order variants produced these counts. These observations are not contractual expectations in the runner. |
| `tb_handshake.sv` | PASS | PASS | Eight accepted and eight checked transactions, six stalled input edges, seven simultaneous input/output transfers; reset discards a pending response. |
| Handshake with `+break_hold` | Expected failure, exit 1 | Expected failure, exit 1 | Payload corruption during backpressure is detected as `INPUT_HOLD`. |
| Extracted skill template + `pipeline_dut.sv` | PASS, 3 checked | PASS, 3 checked | The unmodified template runs against an identity DUT with the documented N → N+1 registered latency. |
| Template with `+corrupt` | Expected failure, exit 1 | Expected failure, exit 1 | Incorrect output is rejected as `MISMATCH`. |
| Template with `+drop` | Expected failure, exit 1 | Expected failure, exit 1 | A lost response produces `LOCAL TIMEOUT`, without printing PASS. |
| `tb_xcheck.sv` | Expected failure, exit 1 (`xx`) | PASS after X becomes zero | `!==` rejects an unknown in four-state simulation; the same check cannot establish absence of X in the default two-state run. |

Final result: **22 checks, 0 unexpected results**. The clocking compilation
rejection and the intentional runtime failures are included in this count.

The C++ build emitted `STDOUT_FILENO` / `STDERR_FILENO` redefinition warnings
from the installed `verilated.cpp` and UCRT64 `stdio.h`. Compilation and
execution completed; these diagnostics are preserved in the build logs. No HDL
warnings were observed in the successfully compiled examples. The installed
toolchain was not changed.

## Interpretation and limits

The exercised claims agree with the observed behavior. In particular, the race
probe produces different observations across the two simulators, while the
recommended drive/sample patterns give consistent checked results. Verilator
5.050 supports the tested `initial` NBA and `#0` examples, so these should not
be classified as unsupported based on assumptions about other versions.

The clocking example cannot be used with this Icarus version. The skill already
conditions clocking-block use on simulator support; its falling-edge template
works on both tools tested here. Fault injection confirms that `$fatal(1, ...)`
produces a failing process exit for these examples on both tools.

This is a targeted scheduling and template check, not proof of every statement
or a complete DUT verification environment. It does not cover XSIM, other tool
versions or options, Wishbone, asynchronous reset, multiple clocks, arbitrary
latencies, or every possible duplicate/late response. The template's response
wait checks eventual data within a bound; it does not independently assert an
exact response cycle or pipeline throughput. Adapt those checks to the actual
DUT contract, as the skill requires.
