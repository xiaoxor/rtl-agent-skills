# RTL Agent Skills

[English](README.md) | **简体中文**

面向 RTL 实现、审查和 testbench 验证的三个 **仅手动调用** 的 AI Agent Skill。

| Skill | 用途 |
| --- | --- |
| `rtl-minimalism` | 编写或修改 RTL 时，以接口契约为依据，不为非法使用方式添加无需求支撑的防御性硬件。 |
| `rtl-overengineering-review` | 审查 RTL 中有证据支持的冗余防御逻辑、不必要硬件和过度设计；默认只报告，不修改文件。 |
| `testbench-craft` | 创建、审查或修复 Verilog/SystemVerilog testbench，遵循无竞争的激励与采样、协议检查和有界结束规则。 |

两个面向 RTL 精简的 Skill 不强制 FSM 编码风格，也不会把“RTL 代码行数更少”当作综合结果更好的证据。规格要求的复位行为、跨时钟域安全、接口协议、时序和吞吐率要求始终优先。

## 安装

使用 [Skills CLI](https://github.com/vercel-labs/skills)：

```bash
npx skills add xiaoxor/rtl-agent-skills -g
```

只安装其中一个，例如：

```bash
npx skills add xiaoxor/rtl-agent-skills --skill testbench-craft -g
```

也可将三个 Skill 目录手动复制到 Agent 的 Skill 目录，例如 Codex 的 `~/.agents/skills/` 或 Claude Code 的 `~/.claude/skills/`。

## 手动调用

| Agent | RTL 设计与修改 | RTL 过度设计审查 | Testbench 创建与审查 |
| --- | --- | --- | --- |
| Codex | `$rtl-minimalism` | `$rtl-overengineering-review` | `$testbench-craft` |
| Claude Code | `/rtl-minimalism` | `/rtl-overengineering-review` | `/testbench-craft` |

所有 Skill 均配置为仅显式调用：

- **Codex**：每个 Skill 的 `agents/openai.yaml` 设置 `policy.allow_implicit_invocation: false`。
- **Claude Code**：每个 `SKILL.md` 设置 `disable-model-invocation: true`。

不同产品和版本对配置的支持可能不同。曾有 Codex CLI 问题报告称，关闭隐式调用会同时影响显式调用，请在自己使用的版本中验证：[相关问题](https://github.com/openai/codex/issues/40600)。

## 设计理念

**假设调用方遵守接口契约；实现规定行为，而不是想象中的错误使用场景。**

只考虑移除那些在已约定的合法操作下不需要的额外逻辑。不要删除正常事务、时序收敛、跨时钟域处理以及其他规格要求所必需的逻辑。

## 许可证

MIT，详见 [LICENSE](LICENSE)。
