---
name: rtl-minimalism
description: Write minimal, contract-driven RTL without unnecessary defensive logic or overengineering.
disable-model-invocation: true
---

# RTL Minimalism

Write the simplest synthesizable RTL that satisfies the specified functionality and design constraints.

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

## Preserve Correctness

- Preserve all behavior required by the specification.
- Respect reset, CDC, timing, and handshake requirements.
- Maintain correct bit widths, signedness, and sequential semantics.
- Never simplify hardware at the expense of legal-operation correctness.
- When modifying existing RTL, preserve its documented interface contract.

## Decision Rule

Before adding hardware, ask:

> What requirement under legal operation justifies this logic?

If none exists, omit it.
