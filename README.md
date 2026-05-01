# agentkit-skills

AgentKit Skills 集合。每個子目錄為一個 skill package。

## 安裝（Claude Code）

```shell
/plugin marketplace add knew-inventai/agentkit-skills
/plugin install SKILL_NAME@agentkit-skills
```

## 目錄結構

```
agentkit-skills/
  .claude-plugin/
    marketplace.json    ← Claude Code marketplace 定義（自動維護）
  {skill-name}/
    plugin.json         ← Package metadata
    SKILL.md            ← Skill 主體內容
    README.md           ← 說明文件
    CHANGELOG.md        ← 版本記錄（選填）
```
