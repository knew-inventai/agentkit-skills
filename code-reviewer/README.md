# code-reviewer

自動 code review skill，分析程式碼中的 bug、安全問題與改善建議。

## 使用方式

### Claude Code（marketplace）

```shell
/plugin install code-reviewer@agentkit-skills
/code-reviewer
```

### 手動安裝（curl）

```bash
# Claude Code 全域
curl -fsSL https://raw.githubusercontent.com/knew-inventai/agentkit-skills/main/code-reviewer/SKILL.md \
  --create-dirs -o ~/.claude/skills/code-reviewer/SKILL.md

# Cursor 專案
curl -fsSL https://raw.githubusercontent.com/knew-inventai/agentkit-skills/main/code-reviewer/SKILL.md \
  --create-dirs -o .cursor/rules/code-reviewer.mdc
```

## 版本歷史

- **v1.0.0**：初始版本
