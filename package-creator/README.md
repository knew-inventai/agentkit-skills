# package-creator

引導使用者將現有內容封裝成 AgentKit 可接受的格式，產出可直接提交 PR 的完整目錄結構（`plugin.json` + 主體檔案 + `README.md`）。

## 安裝

```bash
/plugin install package-creator@agentkit-skills
```

## 適合使用的情境

- 想手動提交 PR 但不確定檔案格式的使用者
- 已有 SKILL.md / prompt / MCP config，想快速封裝成 AgentKit 套件
- 想確認自己產出的 `plugin.json` 是否符合規範

## 使用方式

安裝後說出類似以下的句子即可觸發：

- 「我想把這個 SKILL.md 發布到 AgentKit，幫我封裝」
- 「我有一個 MCP server config，怎麼提交 PR？」
- 「幫我產出 AgentKit 的 package 格式」

## 產出內容

每次執行會產出：

1. `plugin.json` — 完整 manifest
2. 主體檔案（`SKILL.md` / `PROMPT.md` / `mcp-config.json` / `plugin.json` commands）
3. `README.md` — 安裝與使用說明
4. PR 提交指引（目標 repo、branch 名稱、PR 標題與內文）
