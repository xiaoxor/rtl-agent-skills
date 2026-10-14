---
name: rtl-overengineering-review
description: Review RTL for unnecessary defensive logic, redundant hardware, and overengineering without modifying code.
disable-model-invocation: true
---

# RTL Overengineering Review

Identify hardware complexity not justified by the specified functionality or design constraints.

Review only. Do not modify files unless explicitly requested.

## Review Principles

- Evaluate RTL under its documented interface contract.
- Assume legal input sequences unless the specification requires handling violations.
- Distinguish unnecessary defensive logic from required functional logic.
- Do not treat coding style or source-code length as evidence of hardware inefficiency.
- Do not assume that fewer registers, states, or pipeline stages always produce better hardware.

## What to Look For

### Defensive Logic

- Error detection or recovery for prohibited operations.
- Timeout or retry mechanisms absent from the specification.
- Request buffering added solely for illegal transactions.
- Redundant input validation or sanitization.
- FSM states dedicated to unspecified protocol violations.

### Unnecessary Hardware

- Registers that do not serve a functional or timing purpose.
- Redundant control signals, comparators, or multiplexers.
- Unnecessary FSM states or transitions.
- Unused or unjustified configuration parameters.
- Speculative features and overly generic abstractions.
- Pipeline stages or duplicated datapaths without a demonstrated requirement.

## Review Procedure

1. Identify the documented interface contract and design constraints.
2. Inspect the relevant RTL and its surrounding modules.
3. Identify potentially unnecessary hardware.
4. Determine whether each candidate serves a legal-operation, timing, or implementation requirement.
5. Report only findings supported by specific evidence.
6. Describe the simplest safe alternative.
7. Explain how to verify that legal-operation behavior is preserved.

If requirements are unavailable or ambiguous, mark findings as conditional rather than assuming the logic is unnecessary.

## Output Format

For each finding, report:

- **Location:** File and signal or code region.
- **Issue:** Unnecessary hardware or overengineering.
- **Evidence:** Why it is not required under the interface contract.
- **Recommendation:** Minimal safe simplification.
- **Confidence:** High, Medium, or Low.

Prioritize findings with clear hardware impact.

Do not report subjective style preferences as defects.

If no justified simplifications are found, say so.
