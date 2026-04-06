# STATUS_2026-04-05_obsidian_cli_skill.md

## 本次變更
- 依本次已驗證流程，建立 `obsidian-cli-read-latest-notes` skill。
- 將 skill 安裝到全域 skill 目錄：
  - `C:\Users\pigow\.codex\skills\obsidian-cli-read-latest-notes\`
- 刪除 repo 內的本地副本，只保留全域版。
- 以 `ce:compound` 形式新增一份知識文件：
  - `docs/solutions/best-practices/obsidian-cli-read-latest-notes-2026-04-05.md`
- 將這次使用 Obsidian CLI 讀取最新 10 篇筆記的關鍵流程、判斷規則、常見失敗模式與輸出要求整理成可重用格式。

## 驗證結果
- 成功：已建立 `agents/openai.yaml`。
- 成功：`py "C:\Users\pigow\.codex\skills\.system\skill-creator\scripts\quick_validate.py" "E:\AI Training\cc-notebook\.codex\skills\obsidian-cli-read-latest-notes"` 回傳 `Skill is valid!`
- 成功：已回讀 `SKILL.md` 與 `docs/solutions/...` 內容，確認主體文字存在。
- 成功：定位並修正 `agents/openai.yaml` 的 `default_prompt`，原先因 PowerShell 對 `$obsidian` 做變數展開，導致 skill 名稱前綴遺失。
- 成功：已安裝驗證所需依賴 `PyYAML`，否則 `generate_openai_yaml.py` 與 `quick_validate.py` 會因缺少 `yaml` 模組失敗。
- 成功：全域目錄原先不存在同名 skill，已直接複製到 `C:\Users\pigow\.codex\skills\obsidian-cli-read-latest-notes\`。
- 成功：repo 內的本地副本已移除，後續只維護全域 skill。

## 若仍失敗
- 目前沒有阻擋 skill 使用的已知失敗。
- 若之後再次用 shell 生成 `default_prompt`，需要避免 PowerShell 展開 `$skill-name`。
- 若之後直接修改 repo 內文件而忘記更新全域 skill，本地文件與實際可用 skill 仍可能漂移。

## 下一步
- 若你要擴充功能，可以再加第二條分支：支援 `obsidian recents` 讀取「最近開啟」而不是「最近修改」。
- 若你要把流程更自動化，可以再補一個腳本，把「列出 + 讀取 + 摘要」整合成一條命令。
