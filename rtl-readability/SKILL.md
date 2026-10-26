---
name: rtl-readability
description: Review or refactor the structural readability of synthesizable Verilog/SystemVerilog RTL by organizing code around coherent hardware responsibilities while preserving behavior and timing. Read-only when reviewing.
disable-model-invocation: true
---

# RTL Readability

Make the RTL's source structure reflect its hardware structure. A reader should be able to locate a circuit's state, update conditions, combinational logic, and interfaces without scanning unrelated circuitry.

## Priorities

1. Preserve functional behavior, cycle-level latency, throughput, reset semantics, and interface protocols.
2. Organize code by **functional cohesion**, not merely by shared clock, reset, syntax, or assignment type.
3. Make dataflow, control flow, and the ownership of state easy to follow.
4. Favor the existing project's conventions where they remain clear.
5. Improve clarity without introducing unnecessary hardware, abstractions, or boilerplate.

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
- Be careful when splitting a process containing cross-register dependencies, multiple assignments to the same register, or mixed blocking and nonblocking assignments. Establish the original scheduling and priority semantics before changing it.
- Keep synthesis/PPA implications in mind. Do not promise identical gate-level implementation from a source-only rewrite; use available lint, simulation, equivalence, or synthesis checks proportionate to the change.
- Preserve required behavioral details even when they look verbose. Readability never overrides correctness.

## Workflow

1. Read the module and nearby project conventions. Identify functional units, their owned state, and their data/control dependencies.
2. Identify concrete readability problems: unrelated state in one process, intertwined functions, obscure names, excessive nesting, poorly aligned pipeline code, or comments that obscure intent.
3. Propose the smallest coherent regrouping. Prefer a few purposeful blocks over both a monolithic block and one block per register.
4. When asked to review, report findings and illustrative changes without editing. When asked to refactor or implement, edit the RTL.
5. Check preservation of cycle-level behavior, reset behavior, update priority, and interfaces. Run existing relevant checks when available; state clearly which checks were not run.

## Review output

For each material finding, report its location, the circuits currently mixed or obscured, why comprehension suffers, and a specific regrouping or naming suggestion. Rank structural-cohesion issues ahead of cosmetic formatting. Avoid requesting changes that do not yield a tangible readability benefit. If the module's structure is already clear, say so instead of proposing changes.
