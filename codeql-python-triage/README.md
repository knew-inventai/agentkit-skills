# codeql-python-triage

> 把 CodeQL Python alert 從盤點到清掉的完整流程 skill,內建 Level 1/2/3 分類器,避免每次都白做工。

**標籤**:`codeql` · `python` · `security` · `static-analysis` · `sarif` · `code-scanning` · `github` · `triage`

Anthropic Claude Skill,用於處理 GitHub Code Scanning 上 CodeQL Python alert 的完整工作流。**Repo-agnostic** —— 適用於任何啟用了 CodeQL 的 Python 專案,會自動偵測該專案 `.github/codeql/qlpack.yml` 並抓出 pack 名,不寫死任何專案專屬設定。

濃縮了實戰 CodeQL 修補經驗:`barrierModel` YAML 何時有效、何時被默默忽略;為何 `usedforsecurity=False` 雖是 Python 官方推薦但 CodeQL 不認;以及如何在本地真正驗證 suppression 不會被單 query 跑法誤判失敗。

## 安裝

```bash
git clone <this-skill-repo> ~/.claude/skills/codeql-python-triage
# 或:直接把這個目錄複製到 ~/.claude/skills/
```

驗證安裝:

```bash
ls ~/.claude/skills/codeql-python-triage/
# 應該列出:SKILL.md  README.md  scripts/  references/  assets/
```

必要外部工具:

```bash
brew install codeql              # CLI 2.25.x+
codeql pack download codeql/python-queries
codeql pack download codeql/python-all
brew install jq gh
gh auth login
```

## 觸發 Skill

在 Claude Code 對話中提到以下任一關鍵字,skill 會自動載入:

- "CodeQL" / "code scanning" / "GitHub Security tab"
- 規則 id 如 `py/path-injection`、`py/clear-text-storage-sensitive-data`
- "barrierModel" / "ModelsAsData" / "SARIF" / "sanitizer" / "validator"
- "# lgtm" / "suppression" / "SECURITY_SUPPRESSIONS"

Claude 會載入 `SKILL.md` 並依 5 階段流程處理。

## 手動使用(不依賴 skill 也能跑)

```bash
SKILL=~/.claude/skills/codeql-python-triage

# Phase 1:盤點某 repo 目前的 open alert
bash $SKILL/scripts/inventory.sh <owner>/<repo>

# Phase 2:對某條 rule 做 Level 分類
bash $SKILL/scripts/audit_query.sh py/path-injection
bash $SKILL/scripts/audit_query.sh py/path-injection --write    # 把結果寫進 ledger

# Phase 4:本地建 DB 並分析
bash $SKILL/scripts/build_db.sh
bash $SKILL/scripts/analyze.sh /tmp/codeql-db-py \
  codeql/python-queries:codeql-suites/python-code-scanning.qls
bash $SKILL/scripts/parse_sarif.sh /tmp/codeql-result-<ts>.sarif py/path-injection

# 維護:檢查 CodeQL 版本是否漂移
bash $SKILL/scripts/check_pack_version.sh
```

## 目錄結構

```
codeql-python-triage/
├── SKILL.md                              # skill 主入口(≤500 行)
├── README.md                             # 你正在讀這份
├── scripts/
│   ├── lib/common.sh                     # 共用 bash helper
│   ├── inventory.sh                      # gh API → alert 分組表
│   ├── audit_query.sh                    # rule → Level 1/2/3 verdict
│   ├── analyze.sh                        # codeql analyze 帶正確 pack 與 flag
│   ├── build_db.sh                       # codeql database create
│   ├── parse_sarif.sh                    # SARIF → 易讀摘要
│   └── check_pack_version.sh             # 偵測 CodeQL 版本漂移
├── references/
│   ├── rule-levels.md                    # Level 分類完整 taxonomy + QL source 佐證
│   ├── known-rules-ledger.md             # 已 audit 過的 rule 累積帳本
│   ├── codeql-cli.md                     # CLI 安裝 + flag 參考
│   ├── per-repo-setup.md                 # 各專案自己要備齊的 codeql pack / workflow 設定
│   ├── suppression-tracking.md           # # lgtm 機制與 audit 流程
│   └── workflow-architecture.md          # 建議的 codeql.yml 三 job 拆分
└── assets/
    ├── SECURITY_SUPPRESSIONS-template.md  # repo 根目錄 suppression index 模板
    ├── barrierModel-entry-template.yml    # 新增 barrier 的 YAML 模板
    ├── pr-body-template.zh-TW.md          # 繁體中文 PR 描述模板
    └── lgtm-comment-template.py           # 三段式 suppression 註解模板
```

## 更新

CodeQL CLI / pack 升版時:

```bash
bash $SKILL/scripts/check_pack_version.sh
```

若偵測到漂移,對 `references/known-rules-ledger.md` 內每條 rule 重跑 `audit_query.sh`,把日期與 Level 更新進去。**不要靜默覆寫舊紀錄** —— 保留兩列並打上 timestamp,歷史對「CodeQL 是不是改了行為?」這類除錯很重要。

## 自我冒煙測試(改完任何 script 後跑)

```bash
SKILL=~/.claude/skills/codeql-python-triage

# inventory.sh:對有 open alert 的 repo 應產出非空表格
bash $SKILL/scripts/inventory.sh <owner>/<repo> | grep -q '|.*|'

# audit_query.sh:已知 rule 應穩定分對 Level
bash $SKILL/scripts/audit_query.sh py/path-injection         | grep -q 'Level 1'
bash $SKILL/scripts/audit_query.sh py/clear-text-storage-sensitive-data | grep -q 'Level 2'
bash $SKILL/scripts/audit_query.sh py/weak-sensitive-data-hashing | grep -q 'Level 2'

# check_pack_version.sh:能正常印出 pack 版本表
bash $SKILL/scripts/check_pack_version.sh | grep -q 'codeql/python-all'
```

## 範圍與不做

**做**:

- Python CodeQL 規則,跨任何專案皆適用
- triage / 分類 / 驗證 / PR 五階段工作流
- 自動偵測專案的 data-extension pack(任何 `.github/codeql/qlpack.yml`)

**不做**(留給未來其他 skill):

- JavaScript / TypeScript / Java / Go 的 CodeQL(規則 taxonomy 與 Customizations.qll 路徑都不同)
- 寫自製 `.qll` Sanitizer 來把 Level 2 規則升級成 Level 1(過於侵入)
- Trivy 或其他非 CodeQL 的 scanner

## 設計權威來源

本 skill 撰寫時對照的 pack 版本:

- `codeql/python-all` 7.1.0
- `codeql/python-queries` 1.8.2
- CodeQL CLI 2.25.4

`references/known-rules-ledger.md` 內的所有 Level 分類,都在 2026-05-15 到 2026-05-18 之間,實際讀過對應 `Customizations.qll` 原始碼後驗證過。
