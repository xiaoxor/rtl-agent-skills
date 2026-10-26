---
name: rtl-minimalism
description: Write minimal, contract-driven RTL without unnecessary defensive logic or overengineering, or review existing RTL for the same. Read-only when reviewing.
disable-model-invocation: true
---

# RTL Minimalism

Write the simplest synthesizable RTL that satisfies the specified functionality and design constraints. When reviewing existing RTL, identify hardware complexity not justified by them.

## Interface Contract

- Assume the caller follows the documented interface protocol.
- Guarantee correct behavior for legal input sequences.
- Do not invent behavior for protocol violations or unspecified operations.
- Document caller responsibilities instead of enforcing them with additional hardware.
- Do not introduce new interface restrictions absent from the specification.

## Avoid Defensive Hardware

Unless explicitly required, do not add logic solely to handle illegal usage:

- Error detection, reporting, or recovery.
- Timeouts, retries, or automatic restarts.
- Pending-request queues or duplicate-request handling.
- Input sanitization, clamping, or redundant validation.
- Extra FSM states for protocol violations.

Prefer verification assertions over synthesized defensive logic. Place assumptions about callers in the verification environment, not in synthesized RTL.

## Avoid Overengineering

- Implement only requested functionality.
- Do not introduce speculative features or configuration parameters.
- Avoid unnecessary registers, buffers, multiplexers, and control states.
- Do not create helper modules or abstractions without a concrete benefit.
- Do not enforce a particular FSM coding style.
- Do not add pipeline stages or duplicate datapaths without a timing or throughput justification.

Minimize hardware complexity, not source-code length.

## Reset Only What Needs Reset

- Reset registers that determine control behavior: FSM state, handshake and valid/ready signals, busy or status flags, and counters used for control decisions.
- Do not reset pure datapath registers whose value is consumed only when a control signal qualifies it; under legal operation their power-up value is irrelevant.
- Reset a datapath register anyway when the specification requires a defined initial value, or when the design consumes its output without a qualifying valid signal.
- Treat reset as hardware: each reset adds routing and a multiplexer, loads the reset tree, and can burden reset-path timing.

## Preserve Correctness

- Preserve all behavior required by the specification.
- Respect reset, CDC, timing, and handshake requirements.
- Maintain correct bit widths, signedness, and sequential semantics.
- Never simplify hardware at the expense of legal-operation correctness.
- When modifying existing RTL, preserve its documented interface contract.

## Reviewing Existing RTL

Review only. Do not modify files unless explicitly requested.

- Evaluate the RTL under its documented interface contract; assume legal input sequences unless the specification requires handling violations.
- Look for the patterns above, distinguishing unnecessary defensive logic from required functional logic.
- Do not treat coding style or source-code length as evidence of hardware inefficiency.
- Do not assume that fewer registers, states, or pipeline stages always produce better hardware.
- Do not report missing resets on datapath registers as defects when control logic qualifies their first use; report resets on such registers as simplification candidates.

### Procedure

1. Identify the documented interface contract and design constraints.
2. Inspect the relevant RTL and its surrounding modules.
3. Identify potentially unnecessary hardware.
4. Determine whether each candidate serves a legal-operation, timing, or implementation requirement.
5. Report only findings supported by specific evidence.
6. Describe the simplest safe alternative.
7. Explain how to verify that legal-operation behavior is preserved.

If requirements are unavailable or ambiguous, mark findings as conditional rather than assuming the logic is unnecessary.

### Review Output

For each finding, report:

- **Location:** File and signal or code region.
- **Issue:** Unnecessary hardware or overengineering.
- **Evidence:** Why it is not required under the interface contract.
- **Recommendation:** Minimal safe simplification.
- **Confidence:** High, Medium, or Low.

Prioritize findings with clear hardware impact. Do not report subjective style preferences as defects. If no justified simplifications are found, say so.

## Decision Rule

Before adding hardware, ask:

> What requirement under legal operation justifies this logic?

If none exists, omit it.
