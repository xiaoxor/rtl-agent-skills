# testbench-craft simulation checks

Small executable experiments for the scheduling and checking claims in
[`testbench-craft/SKILL.md`](../../testbench-craft/SKILL.md). The per-tool
behavior distilled from these runs for agents lives in the matching simulator
note: [Icarus](../../testbench-craft/simulators/icarus.md),
[Verilator](../../testbench-craft/simulators/verilator.md),
[XSIM](../../testbench-craft/simulators/xsim.md), or
[VCS](../../testbench-craft/simulators/vcs.md). This README is the dated
evidence.
These test the described Verilog behavior and the actual Markdown template;
they do not test whether an agent consistently follows the skill.

## Run

From the repository root in **MSYS2 UCRT64 Bash** on this Windows machine:

```bash
bash tests/testbench-craft/run.sh
```

With Vivado Simulator on `PATH`, run the XSIM checks from PowerShell:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/testbench-craft/run-xsim.ps1
```

The XSIM runner uses `xvlog`, `xelab`, and `xsim` in separate per-case build
directories. AMD documents this as the three-stage batch flow in [UG900](https://docs.amd.com/r/2025.2-English/ug900-vivado-logic-simulation/Running-the-Vivado-Simulator-in-Batch-Mode).
Its transcript and phase logs are kept under `.build/xsim/`.

With Synopsys VCS on `PATH` (for example after `module load vcs/W-2024.09-SP1`),
run the VCS checks from Bash:

```bash
bash tests/testbench-craft/run-vcs.sh
```

The VCS runner uses the single-command compile/elaborate/link flow (`vcs`
producing `simv`) in separate per-case build directories under `.build/vcs/`,
runs `simv -no_save`, and keeps its transcript and phase logs there.

The runner requires `iverilog`, `vvp`, `verilator`, the Verilator C++ build
toolchain, and GNU `timeout`. It compiles with `iverilog -g2012` and
`verilator --binary --timing`, without HDL warning suppression flags. Each run
has a 15-second host timeout, each compilation a 120-second timeout. The final exit
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
- `xsim/version.log`, `xsim/results.txt`, and `xsim/<case>/{compile,elaborate,runtime}.log`: XSIM versions and per-stage output.
- `vcs/version.log`, `vcs/results.txt`, and `vcs/<case>/{compile,runtime}.log`: VCS version and compile/run output.

## Measured results

Tested on Windows (**2026-10-15/16**) and Linux (**2026-10-16**):

- Icarus Verilog **13.0 stable** (`v13_0`) and Verilator **5.050**, `2026-07-01 rev vUNKNOWN-built20260702`, from MSYS2 UCRT64.
- XSIM **2025.2**, `SW Build 6299465`, from the Vivado 2025.2 PowerShell environment.
- VCS **W-2024.09-SP1_Full64**, from the Synopsys environment module on RHEL 8.10 (Linux 4.18).

| Experiment | Icarus 13.0 | Verilator 5.050 | XSIM 2025.2 | VCS W-2024.09 | What it checks |
| --- | --- | --- | --- | --- | --- |
| `tb_scheduling.sv` | PASS | PASS | PASS | PASS | An `always` driver using same-edge NBA takes effect after sampling; Active reads see old registers; off-edge blocking drive is stable at sampling. |
| `tb_nba_initial.sv` | PASS | PASS | PASS | PASS | Same-edge NBA in an `initial` process also retains the old input until NBA in these versions. |
| `tb_zero_delay.sv` | PASS | PASS | PASS | PASS | `#0` still observes the pre-NBA value; the explicitly bounded `#1` observes the updated register. |
| `tb_clocking.sv` | Compilation rejected | PASS | PASS (`cb.sampled=00` at the first edge with procedural initialization) | PASS (`cb.sampled=00` at the first edge) | Icarus rejects clocking-block syntax; the other three pass this probe. |
| `tb_race.sv` | Current/old: **4/4** | Current/old: **8/0** | Current/old: **9/0**, **1/8** | Current/old: **9/0**, **9/0** | Same-edge blocking stimulus races with DUT sampling. Both source-order variants produced these counts. These observations are not contractual expectations in the runner. |
| `tb_handshake.sv` | PASS | PASS | PASS | PASS | Eight accepted and eight checked transactions, six stalled input edges, seven simultaneous input/output transfers; reset discards a pending response. |
| Handshake with `+break_hold` | Expected failure, exit 1 | Expected failure, exit 1 | `Fatal: INPUT_HOLD` | `Fatal: INPUT_HOLD`, exit 0 | Payload corruption during backpressure is detected. |
| Extracted skill template + `pipeline_dut.sv` | PASS, 3 checked | PASS, 3 checked | PASS, 3 checked | PASS, 3 checked | The unmodified template runs against an identity DUT with the documented N → N+1 registered latency. |
| Template with `+corrupt` | Expected failure, exit 1 | Expected failure, exit 1 | `Fatal: MISMATCH` | `Fatal: MISMATCH`, exit 0 | Incorrect output is rejected. |
| Template with `+drop` | Expected failure, exit 1 | Expected failure, exit 1 | `Fatal: LOCAL TIMEOUT` | `Fatal: LOCAL TIMEOUT`, exit 0 | A lost response produces a bounded timeout, without printing PASS. |
| `tb_xcheck.sv` | Expected failure, exit 1 (`xx`) | PASS after X becomes zero | `Fatal: UNKNOWN_REJECTED` (`xx`) | `Fatal: UNKNOWN_REJECTED` (`xx`), exit 0 | `!==` rejects an unknown in the four-state XSIM/Icarus/VCS runs; the same check cannot establish absence of X in the default two-state Verilator run. |

Final result: **22 checks, 0 unexpected results**. The clocking compilation
rejection and the intentional runtime failures are included in this count.

The XSIM run performed **11 checks, 0 unexpected results**. For successful
cases, XSIM returned exit 0 and printed the expected PASS marker. For deliberate
`$fatal` cases, it also returned exit 0, printed `Fatal: ...`, and ended the
simulation. The XSIM runner therefore classifies expected errors from their
specific log markers; its own exit status reports whether the experiment
matched its expectation.

The VCS run performed **11 checks, 0 unexpected results**, with no compile
warnings. Successful cases returned exit 0 with the expected PASS marker.
Deliberate `$fatal` cases printed `Fatal: "<file>", <line>: ...` followed by the
formatted message, ended the simulation, and — like XSIM — returned process
exit code 0 from `simv`. The VCS runner therefore classifies expected failures
from their log markers rather than the simulator exit status, and runs `simv
-no_save` to avoid the ASLR save/restore re-execution notice.

The C++ build emitted `STDOUT_FILENO` / `STDERR_FILENO` redefinition warnings
from the installed `verilated.cpp` and UCRT64 `stdio.h`. Compilation and
execution completed; these diagnostics are preserved in the build logs. No HDL
warnings were observed in the successfully compiled examples. The installed
toolchain was not changed.

## Interpretation and limits

The exercised claims agree with the observed behavior. In particular, the race
probe produces different observations across the four simulators, while the
recommended drive/sample patterns give consistent checked results. Verilator
5.050 supports the tested `initial` NBA and `#0` examples, so these should not
be classified as unsupported based on assumptions about other versions.

Icarus rejects the clocking-block syntax; Verilator, XSIM, and VCS pass the
clocking probe with explicit procedural initialization. A follow-up XSIM 2025.2
isolation run reproduced `cb.sampled=xx` when `sampled` used a declaration
initializer, while the source register read `00`; moving only `sampled = 0`
into an `initial begin` block made it pass, while moving only `clk = 0` did not.
This suggests a version-specific XSIM clocking-sample issue. The skill
conditions clocking-block use on simulator support; its falling-edge template
works in all four tools. Fault injection confirms that `$fatal(1, ...)`
produces a failing process exit in Icarus and Verilator for these examples.

The same `$fatal` exit-code behavior differs in XSIM 2025.2 and VCS W-2024.09:
the runtime log contains `Fatal:` but the process exits 0 (in XSIM even with
`--onerror quit`). Both runners therefore check the fatal message and the
case-specific marker. The clocking block compiles in XSIM. Keep TB variables
used by clocking-block sampling procedurally initialized in the owning
`initial` process; declaration initialization of `sampled` triggered the issue
described in [`simulators/xsim.md`](../../testbench-craft/simulators/xsim.md)
in the tested version.

This is a targeted scheduling and template check, not proof of every statement
or a complete DUT verification environment. It does not cover other tool versions or options, Wishbone, asynchronous reset, multiple clocks, arbitrary
latencies, or every possible duplicate/late response. The template's response
wait checks eventual data within a bound; it does not independently assert an
exact response cycle or pipeline throughput. Adapt those checks to the actual
DUT contract, as the skill requires.
