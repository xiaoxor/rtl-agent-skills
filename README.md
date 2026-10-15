# RTL Agent Skills

**English** | [简体中文](README.zh-CN.md)

Three focused, manually invoked skills for RTL implementation, review, and testbench verification.

| Skill | Purpose |
| --- | --- |
| `rtl-minimalism` | Implement or modify RTL according to documented interface contracts without adding defensive hardware for illegal usage. |
| `rtl-overengineering-review` | Review RTL for demonstrably unnecessary defensive logic, redundant hardware, and overengineering. Read-only by default. |
| `testbench-craft` | Create, review, or repair Verilog/SystemVerilog testbenches with race-free stimulus and sampling, protocol-aware checks, and bounded completion. |

The two RTL-focused skills do not impose an FSM coding style or equate fewer lines of RTL with better synthesized hardware. Required reset behavior, clock-domain crossing safety, interface protocols, timing, and throughput take precedence over simplification.

For executable Icarus Verilog / Verilator / XSIM examples and measured results, see [testbench-craft simulation checks](tests/testbench-craft/README.md).

## Install

Using the [Skills CLI](https://github.com/vercel-labs/skills):

```bash
npx skills add xiaoxor/rtl-agent-skills -g
```

Install one skill, for example:

```bash
npx skills add xiaoxor/rtl-agent-skills --skill testbench-craft -g
```

Or copy the three skill directories to your agent's skills directory, for example `~/.agents/skills/` for Codex or `~/.claude/skills/` for Claude Code.

## Explicit invocation

| Agent | RTL implementation | RTL review | Testbench creation/review |
| --- | --- | --- | --- |
| Codex | `$rtl-minimalism` | `$rtl-overengineering-review` | `$testbench-craft` |
| Claude Code | `/rtl-minimalism` | `/rtl-overengineering-review` | `/testbench-craft` |

All skills are configured for explicit invocation only:

- Codex: each skill's `agents/openai.yaml` sets `policy.allow_implicit_invocation: false`.
- Claude Code: each `SKILL.md` sets `disable-model-invocation: true`.

Agent behavior varies by product and version. In particular, a reported Codex CLI issue has caused explicit invocation to fail when implicit invocation is disabled; test the behavior in your own version: https://github.com/openai/codex/issues/40600

## Philosophy

**Assume valid use. Implement the contract, not imagined misuse.**

Only simplify behavior outside the documented contract. Do not remove logic necessary for legal transactions, timing closure, clock-domain crossing, or other specified requirements.

## License

MIT; see [LICENSE](LICENSE).
