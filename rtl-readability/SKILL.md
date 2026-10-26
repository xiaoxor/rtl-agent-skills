---
name: rtl-readability
description: Review or refactor the structural readability of synthesizable Verilog/SystemVerilog RTL by decomposing modules along hardware functional boundaries and organizing code around coherent hardware responsibilities, while preserving behavior and timing. Read-only when reviewing.
disable-model-invocation: true
---

# RTL Readability

Make the RTL's source structure reflect its hardware structure at every level. The module hierarchy should show which functional units exist and what each one owns; within a module, a reader should locate a circuit's state, update conditions, combinational logic, and interfaces without scanning unrelated circuitry.

## Priorities

1. Preserve functional behavior, cycle-level latency, throughput, reset semantics, and interface protocols.
2. Let module boundaries follow hardware function. Unrelated responsibilities do not share a module merely because they fit in one file.
3. Organize code within a module by **functional cohesion**, not merely by shared clock, reset, syntax, or assignment type.
4. Make dataflow, control flow, and the ownership of state easy to follow.
5. Favor the existing project's conventions where they remain clear.
6. Improve clarity without introducing unnecessary hardware, abstractions, or boilerplate.

Source line count is never a decomposition criterion. A 500-line S-Box can be a cohesive module; 200 lines can still mix three unrelated circuits.

## Decompose modules along functional boundaries

Decide module boundaries before implementing, and split where independent hardware functions meet.

Prefer a separate module for hardware that:

- Implements a substantial, self-contained function with a well-defined interface: an AES core, a GHASH multiplier-accumulator, a multiplier, a CRC unit.
- Handles a protocol with its own transaction rules: a Wishbone slave, an AXI adapter.
- Can be verified independently and deserves its own testbench.
- Is the same circuit instantiated more than once.
- Forms a pipeline stage or functional unit with a clean handshake boundary.

Keep logic inside the parent module when:

- Splitting would expose large amounts of internal state and control signals through the port list. Leaked internal state means the boundary is wrong. An FSM that directly micro-steps a datapath usually stays with it; an FSM coordinating several independent units is a reasonable module boundary.
- The logic is trivial: simple counters, shift registers, a few glue or combinational assignments. An extra hierarchy level costs more than it clarifies. A counter unit or small FSM may be either its own module or a clearly separated block inside the parent; decide by coupling, not by label.

Judged by these rules, an AES round function is a reasonable submodule; wrapping the individual XOR operations inside an AES datapath as modules just to shorten the parent is not.

Additional rules:

- Keep top-level modules focused on integration, coordination, and genuinely shared logic.
- Do not create wrapper modules that merely forward signals without encapsulating behavior.
- Prefer cohesive modules with simple interfaces over deep hierarchy.

### Decomposition check

Before implementing a complex RTL design, establish the hierarchy before writing the implementation:

1. Identify the top-level module's responsibility.
2. Determine which responsibilities form independently implementable and verifiable units.
3. Evaluate each candidate submodule for a clear data and control interface.
4. Decide what stays together: tightly coupled control and datapath, trivial logic.
5. Sketch the intended hierarchy, for example:

   ```
   CryptoEngine
   ├── BusInterface
   ├── RegisterFile
   ├── CryptoController
   └── CryptoDatapath
       ├── AesCore
       └── GhashCore
   ```

   This is a candidate structure to evaluate against the rules above, not a required shape.

### Implement the identified hierarchy

When planning identifies meaningful submodules, implement them as real modules. Do not merge their logic back into the parent for convenience while writing the code. If implementation reveals a concrete interface, timing, or implementation problem, adjust the hierarchy deliberately; do not silently inline the planned modules.

## Organize procedural blocks by circuit responsibility

- Give each `always_ff`, `always_comb`, or Verilog `always` block a recognizable responsibility: for example, FSM state, a counter, FIFO pointers, a register bank, or one pipeline stage.
- Prefer separate procedural blocks for independent circuits, even when they use the same clock and reset. Do not collect every register in a module into one sequential block simply because their event controls match.
- Keep tightly related state together when the shared code expresses one coherent operation, such as the data and valid registers of one pipeline stage, or registers with a common atomic update.
- Do not split every individual register into its own block as a mechanical rule. Functional ownership, not register count or block count, determines grouping.
- Keep the reset and normal update of a state group together. Preserve all enable priorities, implicit holds, and assignment semantics when regrouping.
- For combinational logic, group statements that implement one recognizable function. Separate independent decoders, next-state calculations, datapath functions, and output calculations when doing so improves navigation.

### Bad: unrelated circuits in one clocked block

```systemverilog
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state_q <= IDLE;
        count_q <= '0;
        data_q  <= '0;
    end else begin
        if (state_en) state_q <= state_d;
        if (count_en) count_q <= count_q + 1'b1;
        if (data_en)  data_q  <= data_in;
    end
end
```

### Better: independently owned circuits

```systemverilog
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        state_q <= IDLE;
    else if (state_en)
        state_q <= state_d;
end

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        count_q <= '0;
    else if (count_en)
        count_q <= count_q + 1'b1;
end

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        data_q <= '0;
    else if (data_en)
        data_q <= data_in;
end
```

### Good: related pipeline registers together

```systemverilog
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        data_s2_q  <= '0;
        valid_s2_q <= 1'b0;
    end else begin
        data_s2_q  <= data_s1_q;
        valid_s2_q <= valid_s1_q;
    end
end
```

These are grouping examples, not mandatory coding templates. An FSM may use one, two, or three processes if the chosen form clearly communicates the hardware.

## Make signal roles and relationships clear

- Prefer names that reveal function: state, counter, request, grant, enable, valid, ready, pointer, index, and pipeline stage.
- Distinguish a one-cycle pulse from a level signal and registered values from their combinational next values when that distinction matters.
- Group declarations and logic by feature or datapath stage so that related code stays nearby. Use short section comments only where they help navigation.
- Make widths, signedness, constants, and truncation points understandable.
- Name intermediate results or predicates when an expression is difficult to parse or when the name clarifies a real operation. Keep straightforward expressions inline.

## Express control and dataflow visibly

- Keep priority and exclusivity evident in `if`/`else` and `case` structures. Do not rewrite priority logic as parallel conditions without proof of equivalence.
- Make FSM transitions, counter terminal conditions, handshake events, and valid/data alignment easy to locate.
- Keep logic for one pipeline stage identifiable. Do not merge independent stages just to reduce process count.
- Prefer explicit, readable module and generate-block organization over deeply nested control flow when it materially helps comprehension.
- Comment *why*: protocol assumptions, special latency relationships, arithmetic invariants, and surprising design choices. Avoid comments that simply narrate obvious assignments.

## Preserve the circuit during refactoring

- Do not change clocks, reset polarity or synchronicity, reset values, enables, signal widths, assignment priorities, or nonblocking/blocking semantics merely for style.
- Do not add registers, pipeline stages, handshakes, state encoding changes, or new latency to improve appearance.
- Do not remove logic as part of a readability refactor, even when it appears redundant or unnecessary. Report suspected overengineering for a separate review instead.
- Do not move a register into another clock domain or give the same signal multiple procedural drivers.
- When extracting a submodule, keep the parent's external interface and port semantics unchanged, and place the new module's ports at the functional boundary, not at signals that are only meaningful as the parent's internal state.
- Be careful when splitting a process containing cross-register dependencies, multiple assignments to the same register, or mixed blocking and nonblocking assignments. Establish the original scheduling and priority semantics before changing it.
- Keep synthesis/PPA implications in mind. Module extraction changes the elaborated hierarchy and parameter plumbing even when the logic is identical. Do not promise identical gate-level implementation from a source-only rewrite; use available lint, simulation, equivalence, or synthesis checks proportionate to the change.
- Preserve required behavioral details even when they look verbose. Readability never overrides correctness.

## Workflow

1. Read the modules and nearby project conventions. Identify functional units, their owned state, and their data/control dependencies.
2. For implementation tasks, run the decomposition check and fix the intended hierarchy before writing code. For review or refactoring tasks, first assess whether the hierarchy matches hardware function: unrelated responsibilities concentrated in one module, or wrappers without behavior.
3. Identify concrete readability problems: unrelated state in one process, intertwined functions, obscure names, excessive nesting, poorly aligned pipeline code, or comments that obscure intent.
4. Propose the smallest coherent regrouping. Prefer a few purposeful modules and blocks over both a monolithic module and one-block-per-register fragmentation.
5. When asked to review, report findings and illustrative changes without editing. When asked to refactor or implement, edit the RTL.
6. Check preservation of cycle-level behavior, reset behavior, update priority, and interfaces. Run existing relevant checks when available; state clearly which checks were not run.

## Review output

For each material finding, report its location, the circuits currently mixed or obscured, why comprehension suffers, and a specific regrouping, extraction, or naming suggestion. Rank module-boundary and structural-cohesion issues ahead of cosmetic formatting. Avoid requesting changes that do not yield a tangible readability benefit. If the existing structure is already clear, say so instead of proposing changes.
