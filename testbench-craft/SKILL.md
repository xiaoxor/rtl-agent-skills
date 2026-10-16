---
name: testbench-craft
description: >-
  Create, review, and repair Verilog/SystemVerilog RTL testbenches with strict
  clock-edge driving, race-free sampling, handshake accounting, self-checking,
  and deterministic timeouts. Invoke only when the user explicitly requests
  testbench-craft by name; ordinary RTL requests are not an invocation.
disable-model-invocation: true
user-invocable: true
---

# RTL Testbench: Race-Free, Self-Checking Verification

## Invocation and scope

- **Manual invocation only.** Apply this skill only when the user explicitly invokes `testbench-craft` (e.g. `/testbench-craft` or `$testbench-craft`, depending on the agent). Never auto-select it based on RTL files, verification topics, or installation alone.
- Build or review a testbench, not a synthesizable DUT, unless the user explicitly requests a DUT fix. Do not silently change DUT behavior to make a test pass.
- Prefer **small task-based, self-checking** Verilog/SystemVerilog testbenches. Add driver, monitor, scoreboard, transaction queues, interfaces, assertions, classes, or coverage only when complexity justifies them. Do not impose UVM.
- Respect the project's existing language level, reset polarity, clock edges, transaction protocol, simulator, file layout, and coding conventions.
- Use the simulator required by the user or project. Target multiple simulators only when requested or required by the project; do not silently introduce unsupported features. If plain Verilog is required, avoid SystemVerilog-only constructs.

## Simulator notes

Identify the simulator from the user's request or the project's run scripts/configuration before choosing simulator-specific syntax or commands. Read only its matching measured notes: [Icarus Verilog](simulators/icarus.md), [Verilator](simulators/verilator.md), [XSIM](simulators/xsim.md), or [VCS](simulators/vcs.md). For an explicit multi-simulator target, read each target's note. If the simulator cannot be determined and the work depends on tool-specific behavior, ask which simulator the user will run; continue simulator-independent inspection meanwhile.

## Workflow

1. Inspect the DUT interface, existing testbench, and project run configuration. Identify the simulator, clocks, reset semantics (async/sync, active level), input sampling edges, output update behavior, valid/ready or request/ack protocol, latency, throughput, and backpressure rules. Read the matching simulator note above. Mark unknown behavior rather than inventing it.
2. Make a **cycle contract**: when the testbench drives each input, when the DUT samples it, when a transfer counts, and when outputs may be checked. For variable latency, define the response event instead of guessing a fixed delay.
3. Pick one coherent drive/sample discipline from below. Avoid mixing conventions without an explicit reason.
4. Produce a self-checking testbench with directed corner cases, meaningful failures, a finite watchdog, and an unambiguous PASS/FAIL exit.
5. If tools are available, compile and run with the actual simulator. Diagnose warnings and failures; never claim PASS without execution. If not run, state exactly what is unverified and provide the command.
6. Review the race, protocol, reset, and completion checklists before delivering.

## Mandatory simulation scheduling rules

### A. Input drive: blocking versus nonblocking

- A testbench must **not** drive a synchronous DUT input using a blocking assignment (`=`) in an `@(posedge clk)` process if the DUT also samples that signal at that same edge. The scheduling order is unspecified: this creates a race.
- For ordinary procedural testbenches driving inputs **on the DUT sampling edge**, use nonblocking assignments (`<=`). These update in the NBA region: the DUT sees the **previous** values on that edge and the newly driven values at the **next** sampling edge.
- Alternatively, drive with blocking assignments on a **non-sampling edge** (e.g. `@(negedge clk)` for a rising-edge DUT). The inputs must remain stable across the intended sampling edge. This is often simplest and most portable for small testbenches.
- Prefer a SystemVerilog `clocking block` with explicitly documented input/output skews for complex interfaces, when the selected simulator supports it. `input #1step` samples immediately before the clocking event; `output #0` drives in the clocking output region, not before that same sampling edge. An `input #1` or `output #1` is a real-time skew affected by timescale; do not use it casually.
- Blocking assignments are correct for local procedural calculations, scoreboards, initial setup before any clock sampling, and deliberate off-edge stimulus. Nonblocking assignments are **not** required everywhere in a testbench.
- Do not drive a signal from multiple testbench processes. For each driven interface signal, give exactly one driver ownership.

**Bad (same-edge race):**

```systemverilog
@(posedge clk);
valid = 1'b1;
data  = payload;
```

**Good (same-edge NBA; transfer cannot be sampled until a later edge):**

```systemverilog
@(posedge clk);
valid <= 1'b1;
data  <= payload;
```

**Good (off-edge blocking; DUT samples at next rising edge):**

```systemverilog
@(negedge clk);
valid = 1'b1;
data  = payload;
```

### B. Sampling: distinguish old-state handshake from newly registered outputs

- An `@(posedge clk)` testbench process runs in the Active region and ordinarily sees the **pre-NBA** values of DUT registers. This is often exactly what is needed to determine whether a `valid && ready` transfer occurred **at that edge**, assuming the protocol uses pre-edge values.
- **Never** assume that reading a newly updated DUT register immediately after `@(posedge clk)` sees its just-computed value. For registered outputs from that edge, observe after NBA settling, or inspect them on a subsequent safe sampling edge, with cycle alignment explicitly defined.
- Do not use `#0` as a way to wait for NBA: `#0` moves to the Inactive region, which is still before NBA.
- A carefully chosen small positive sampling delay may be used in a conventional non-clocking-block TB, but must be compatible with `timeunit/timeprecision`, must not cross a later event, and must be explained; it is **not** a universal fix. Prefer a clocking block or clear next-edge sampling where feasible.
- A `clocking block` with default `input #1step` observes values from before the event, **not** the newly registered values written by NBA at that event. Choose an appropriate observation strategy for the actual interface contract.
- Keep independent stimulus/expected values in TB variables or queues. Never use a changing DUT input as the expected value when a delayed output arrives.

### C. Reset, initialization, and X handling

- Use explicit procedural initialization for testbench variables: declare them without inline initializers and assign their time-zero values with blocking assignments in the owning `initial begin ... end` process, before stimulus waits or the first active sampling edge.
- When procedurally initializing `clk` from `X` to `0`, account for a possible time-zero `negedge` in falling-edge-sensitive logic. Confirm that this transition cannot trigger unintended DUT or testbench work in the selected simulator.
- Initialize driven inputs to safe values **before** the first active sampling edge.
- Hold reset for enough clock edges for the DUT's documented reset behavior. For rising-edge DUTs, prefer release on `negedge clk` (or an appropriately scheduled clocking-block drive), not `rst_n = 1` directly in an `@(posedge clk)` process.
- Do not check outputs until reset completion is well-defined. Flush pending expected transactions across reset if the DUT discards in-flight work.
- In four-state simulation, prefer case inequality (`!==`) for exact known-value comparisons where X/Z must fail. Do not assume two-state Verilator simulation can prove absence of unknowns.

### D. Protocol-aware driver/monitor

- For ready/valid, count a transfer **only when both are asserted at the same active sampling edge**. A valid assertion scheduled by NBA at an edge does not create a transfer at that edge.
- While `valid && !ready` at a sampling edge, keep `valid` asserted and payload stable through the next sampling opportunity. Change or deassert them only after an accepted transfer (according to the protocol).
- Track each transaction exactly once; no duplicated transfers, dropped results, or one-cycle shifts. Use a transaction index/ID when needed.
- For Wishbone Classic, use the interface's specified `CYC`, `STB`, `ACK`, `WE`, address, and data sampling rules; hold request signals stable until acknowledged. Do not generalize ready/valid assumptions to Wishbone.
- A monitor is passive. If its observation is used for handshake accounting, sample the actual edge values; if it checks new registered results, use the separately defined post-NBA strategy.

### E. Timeouts, failures, and completion

- Every wait for a response, busy clear, ready/ack, or valid output must be bounded: either a **local cycle limit** or an explicit global watchdog. Prefer both for complex designs.
- Use `$fatal(1, ...)` on mismatch, timeout, protocol violation, or incomplete tests; do not print PASS after an error. Do not rely on `$error` followed by `$finish` to establish a failing process exit across tools.
- Judge a test by its log as well as the simulator exit code. Require a PASS marker on successful runs and the specific failure marker on intentional ones; let the run script own the reported exit code.
- Never use unbounded `wait(...)`, `forever` polling, or `fork...join_any` without a clearly terminating watchdog and cleanup.
- Before reporting PASS, ensure at least one intended transaction was checked, all issued transactions were accounted for, expected queues are empty, and no monitors/scoreboards report outstanding failures.
- Put diagnostic context in failures: clock/cycle, transaction index, input, expected, actual, and handshake state when relevant.
- Waveform generation should be optional; don't enable massive traces by default.

## Default template: portable, non-overlapping-cycle valid/result DUT

This illustrative **SystemVerilog** skeleton assumes:
- A rising-edge DUT samples `in_valid` and `in_data` on an edge; no `in_ready` backpressure.
- An input accepted on edge `N` produces `out_valid`/`out_data` in registers after edge `N+1` (one further registered stage).
- The TB sends **one transaction at a time**, so checking at the following safe falling edge does not overlap a new output update.
- `reference()` below is a placeholder; replace with an independently derived reference model and the real DUT ports. Do not copy assumed latency into a real design without verifying it.

```systemverilog
`timescale 1ns/1ps
module tb_dut;
    localparam integer MAX_CYCLES = 1000;
    reg clk;
    reg rst_n;
    reg in_valid;
    reg [7:0] in_data;
    wire out_valid;
    wire [7:0] out_data;
    integer cycles;
    integer checked;

    always #5 clk = ~clk;

    // Replace with actual DUT instance and actual port names.
    dut u_dut (
        .clk(clk), .rst_n(rst_n),
        .in_valid(in_valid), .in_data(in_data),
        .out_valid(out_valid), .out_data(out_data)
    );

    // Independent golden function. Replace this illustrative identity.
    function automatic [7:0] reference(input [7:0] x);
        reference = x;
    endfunction

    // Global bounded cycle watchdog. Reset independent for simplicity.
    always @(posedge clk) begin
        cycles = cycles + 1;
        if (cycles > MAX_CYCLES)
            $fatal(1, "GLOBAL TIMEOUT: cycles=%0d checked=%0d", cycles, checked);
    end

    task automatic run_one(input [7:0] x);
        reg [7:0] expected;
        integer waited;
        begin
            expected = reference(x);
            // Drive only on falling edge; stable before next rising edge.
            @(negedge clk);
            in_data  = x;
            in_valid = 1'b1;
            // Accepted on next rising edge (no ready/backpressure).
            @(posedge clk);
            @(negedge clk);
            in_valid = 1'b0;

            // Check stable registered outputs at falling edges, after NBA.
            // Since there is no overlapping traffic, a single result
            // corresponds to this input. For pipelines, use a scoreboard.
            waited = 0;
            while (out_valid !== 1'b1) begin
                if (waited >= 20)
                    $fatal(1, "LOCAL TIMEOUT: input=%02h", x);
                @(negedge clk);
                waited = waited + 1;
            end
            if (out_data !== expected)
                $fatal(1, "MISMATCH: input=%02h expected=%02h actual=%02h",
                       x, expected, out_data);
            checked = checked + 1;
            // Leave an idle cycle before the next single-flight transaction.
            @(negedge clk);
        end
    endtask

    initial begin
        // Initialize signals before the first sampling edge.
        clk = 1'b0;
        rst_n = 1'b0;
        in_valid = 1'b0;
        in_data = 8'h00;
        cycles = 0;
        checked = 0;
        repeat (4) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;
        run_one(8'h00);
        run_one(8'h01);
        run_one(8'hff);
        if (checked != 3)
            $fatal(1, "INCOMPLETE: checked=%0d", checked);
        $display("PASS: %0d transactions checked", checked);
        $finish;
    end
endmodule
```

**Template caveats:** This skeleton is instructional, not drop-in for arbitrary RTL. Adapt wait conditions, reference logic, reset effects, outstanding transactions, response pulse shape, and latency before running. Its falling-edge observation is valid only if the DUT's output is stable there. The cycle count is a watchdog, not an expected latency guarantee.

## Mandatory test coverage (scale to DUT)

- Reset asserted/deasserted; reset while idle and, if supported, while busy.
- Minimal/maximal operands and important boundary values; deterministic seeds for random tests.
- Back-to-back requests, idle gaps, stalls/backpressure, and output-consumer stalls when the protocol supports them.
- Latency and throughput: explicitly check acceptance vs completion, especially at pipeline fill/drain.
- Overflow, underflow, invalid requests, and simultaneous events if documented.
- No double-acceptance, missing result, stale response, or premature PASS.

## Review checklist (must explicitly inspect)

- [ ] Inputs are **not** driven with blocking assignments on the DUT's active sampling edge.
- [ ] Each NBA-driven input is understood to take effect **after** its triggering edge.
- [ ] Reset release cannot race an active sampling edge.
- [ ] Handshakes are counted using values present **at** the sampling edge.
- [ ] Registered outputs are checked after their relevant NBA updates, not accidentally in the Active region.
- [ ] No `#0` is used as an NBA barrier; any `#delay` has documented timing precision.
- [ ] Reference results are preserved and aligned with accepted transactions.
- [ ] Backpressure correctly holds payload and avoids duplicate accepts.
- [ ] Every unbounded-looking wait is covered by local/global termination.
- [ ] Any mismatch, timeout, or incomplete accounting terminates with `$fatal`.
- [ ] No unsupported simulator feature is assumed; compile/run results are reported truthfully.

## Delivery format

1. State the inferred timing contract briefly (sampling edges, handshake, output visibility).
2. Provide or edit the actual testbench and any necessary run command.
3. Describe the chosen race-avoidance method and output sampling strategy.
4. Report tests run and their real results, or state clearly that execution was unavailable.
5. Note remaining interface assumptions and unsupported coverage; do not fabricate success.

## Attribution

Inspired by `tb-best-practices` in Gateflow-Plugin:
https://github.com/codejunkie99/Gateflow-Plugin/tree/main/plugins/gateflow/skills/tb-best-practices
This skill significantly revises its drive/sampling rules and templates.
