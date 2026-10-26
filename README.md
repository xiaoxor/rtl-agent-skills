# RTL Agent Skills

**English** | [简体中文](README.zh-CN.md)

Four focused skills for RTL implementation and review, RTL readability, testbench verification, and WaveDrom timing diagrams.

| Skill | Purpose |
| --- | --- |
| `rtl-minimalism` | Implement or modify RTL according to documented interface contracts without defensive hardware for illegal usage, or review RTL for unnecessary defensive logic, redundant hardware, and overengineering. Read-only when reviewing. |
| `rtl-readability` | Improve or review the structural readability of RTL by decomposing modules along hardware functional boundaries and organizing code around coherent hardware responsibilities while preserving behavior and timing. Read-only when reviewing. |
| `testbench-craft` | Create, review, or repair Verilog/SystemVerilog testbenches with race-free stimulus and sampling, protocol-aware checks, and bounded completion. |
| `wavedrom-syntax` | Create, edit, and check WaveDrom/WaveJSON timing diagrams, including signal waves, labels, timing alignment, and annotations. |

The RTL-focused skills do not impose an FSM coding style or equate fewer lines of RTL with better synthesized hardware. Required reset behavior, clock-domain crossing safety, interface protocols, timing, and throughput take precedence over simplification.

For executable Icarus Verilog / Verilator / XSIM / VCS examples and measured results, see [testbench-craft simulation checks](tests/testbench-craft/README.md).

## Install

Using the [Skills CLI](https://github.com/vercel-labs/skills):

```bash
npx skills add xiaoxor/rtl-agent-skills -g
```

Install one skill, for example:

```bash
npx skills add xiaoxor/rtl-agent-skills --skill wavedrom-syntax -g
```

Or copy the four skill directories to your agent's skills directory, for example `~/.agents/skills/` for Codex or `~/.claude/skills/` for Claude Code.

## Explicit invocation

| Agent | RTL implementation/review | RTL readability | Testbench creation/review | WaveDrom diagrams |
| --- | --- | --- | --- | --- |
| Codex | `$rtl-minimalism` | `$rtl-readability` | `$testbench-craft` | `$wavedrom-syntax` |
| Claude Code | `/rtl-minimalism` | `/rtl-readability` | `/testbench-craft` | `/wavedrom-syntax` |

Invocation settings:

- Codex: `rtl-minimalism`, `rtl-readability`, and `testbench-craft` set `policy.allow_implicit_invocation: false` in `agents/openai.yaml`. `wavedrom-syntax` does not yet include this Codex-specific setting.
- Claude Code: each `SKILL.md` sets `disable-model-invocation: true`.

Agent behavior varies by product and version. In particular, a reported Codex CLI issue has caused explicit invocation to fail when implicit invocation is disabled; test the behavior in your own version: https://github.com/openai/codex/issues/40600

## Philosophy

**Assume valid use. Implement the contract, not imagined misuse.**

Only simplify behavior outside the documented contract. Do not remove logic necessary for legal transactions, timing closure, clock-domain crossing, or other specified requirements.

## License

MIT; see [LICENSE](LICENSE).
