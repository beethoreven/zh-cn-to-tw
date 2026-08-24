---
name: update_version
description: Bump the zh-cn-to-tw macOS app's version number for one or both OS tiers (11+ and/or 10.15). Takes one argument like "1.1" (major.minor), optionally followed by a tier ("11+" or "10.15"; omitted means both). Updates the relevant Info.plist file(s) (CFBundleShortVersionString) and the matching app_versions rows (keyed by (os, os_version)) in the Neon DB via zh-cn-to-tw-backend. Use when the user says "/update_version <version>" or asks to bump/change the app version number.
---

這支是這個 repo 專屬版，跟 `~/.claude/skills/update_version/` 那個全域
版是同名 skill——在這個 repo 目錄下工作時，這支專案版優先生效；換到
別的專案，會落到全域版（單純掃描 repo 找版本欄位、逐一改成指定值，
不知道任何專案專屬的額外步驟）。這支之所以獨立存在，是因為這個專案
除了改 `Info.plist` 之外，還要同步一個全域版不可能知道的東西：Neon DB
裡 `app_versions` 表的強制更新門檻——這一步是這個專案的業務邏輯，不是
「掃檔案改版號」這種通用模式能覆蓋的，所以留在專案層維護。

把桌面版 App 的版本號改成使用者指定的新版本，同步更新兩個地方。這個
專案現在有兩個獨立版控的桌面 build（見 `zh-cn-to-tw-mac` README「版本
分流」、`zh-cn-to-tw-backend` README「版本檢查」）：

- **11+**：`zh-cn-to-tw-mac/packaging/Info.plist`，對應 DB 的
  `app_versions` 表裡 `os='macos', os_version='11+'` 那一列
- **10.15**：`zh-cn-to-tw-mac/packaging/Info-10-15.plist`，對應
  `os='macos', os_version='10.15'` 那一列（Stage 1 用 Apple 原生
  Vision framework 做 OCR，不透過 `zh-cn-to-tw-ocr-service`）

## 參數

`args` 是版本字串（`major.minor`，例如 `1.1`），可選再帶一個分流
（`11+` 或 `10.15`，中間用空白隔開，例如 `1.1 11+`）。**沒帶分流的話，
兩個分流都更新成同一個版本**——這個專案目前的設計是兩包版本號同步在
走（見兩份 README 裡「其他都跟 11+ 那包一樣」的說明），分開版本號是
少數情況，只有使用者明確只提到其中一包（例如「只更新 10.15 版」）才
只動那一包。

先驗證格式：版本號必須能拆成兩個非負整數，分流（如果有帶）必須是
`11+` 或 `10.15` 其中之一。格式不對就直接跟使用者說清楚哪裡不對，不要
用猜的補值，不要繼續往下做。

## 步驟

1. **解析版本號/分流**：把版本字串用 `.` 切開，拿到 `MAJOR`/`MINOR`
   兩個整數；決定要動的分流集合（`{"11+"}`、`{"10.15"}`，或兩者都要）。

2. **更新 Info.plist**：對每個要動的分流，編輯對應檔案的
   ```xml
   <key>CFBundleShortVersionString</key>
   <string>MAJOR.MINOR</string>
   ```
   只改這個值，不要動 `CFBundleVersion`（那是另一個獨立的內部 build
   編號，不歸這個 skill 管，除非使用者另外要求）。

3. **更新 DB**：`cd zh-cn-to-tw-backend`，用該 repo 自己的 `venv`
   （`source venv/bin/activate`，沒有的話照該 repo README 的「本機
   測試」步驟先建一個）對每個要動的分流執行：
   ```python
   from db_utils.connection import get_ready_conn
   conn, cur = get_ready_conn()
   cur.execute(
       "INSERT INTO app_versions (os, os_version, latest_major, latest_minor, min_major, min_minor) "
       "VALUES ('macos', %s, %s, %s, %s, %s) "
       "ON CONFLICT (os, os_version) DO UPDATE SET "
       "latest_major=EXCLUDED.latest_major, latest_minor=EXCLUDED.latest_minor, "
       "min_major=EXCLUDED.min_major, min_minor=EXCLUDED.min_minor",
       (TIER, MAJOR, MINOR, MAJOR, MINOR),
   )
   conn.commit()
   cur.execute("SELECT * FROM app_versions WHERE os='macos' ORDER BY os_version")
   for row in cur.fetchall():
       print(row)
   conn.close()
   ```
   用 `INSERT ... ON CONFLICT (os, os_version) DO UPDATE`（不是單純
   `UPDATE`）：某個分流第一次出真正的版本時，DB 裡可能根本還沒有那
   一列（`app_versions` 表的設計是「等實際 build 出來、定版號時再
   手動 INSERT」，見 `db_utils/schema.py` 的說明）——單純 `UPDATE`
   遇到沒有那一列的情況會靜默什麼都不做，不會報錯提醒你，等於白跑。

   `latest_*` 跟 `min_*` 兩組都設成同一個新版本——這個 skill 的預設
   語意是「這個新版本同時也是現在唯一允許的版本，等於直接強制所有
   舊版立刻更新」。如果使用者要的是「先出新版、但還不強制大家升級」
   （`min_*` 暫時維持舊值），要在動手前明確跟使用者確認，不要自己
   假設——尤其兩個分流這次的改動內容不一定同樣相關（例如某次改動只
   影響其中一個分流的功能），不要假設兩個分流的 `min_*` 一定要同步
   強制更新。

4. **回報結果**：都改完後，把每個分流的 Info.plist 新值跟 DB 查回來
   的那幾列印給使用者確認。

## 刻意不做的事

- **不會自動 commit/push**：版本號變動要不要進版控、什麼時候進，留給
  使用者自己決定這個 skill 跑完之後要不要動作。
- **不會自動重新打包 `.app`/DMG**：`build_dmg_11_plus.sh`/
  `build_dmg_10_15.sh` 本來就是動態讀對應 Info.plist 的版本號，
  不用另外同步；但改完 Info.plist 之後，舊的 `.build/` 產物（如果有）
  版本號還是舊的，要重新跑 `build_app_11_plus.sh`/
  `build_app_10_15.sh`（或 `build_dmg_all.sh` 一次兩包）才會反映
  新版本，需要的話另外提醒使用者，不要自己順手跑。
- **不會動 `CFBundleVersion`**（內部 build 編號）：那是獨立的計數用途，
  不受這個 skill 管轄。

## 前提檢查

- `zh-cn-to-tw-backend/.env` 要有 `DATABASE_URL`（本機開發用），沒有
  的話 DB 更新這步會失敗——照該 repo README 的「本機測試」章節設定。
- 這支 skill 直接改的是正式的 Neon 資料庫（本機開發、桌面版 App、
  Render 都連同一個），不是測試用的分離資料庫，改下去立刻影響所有人
  下次打 `version_check` 的結果，執行前值得跟使用者確認一次版本號
  沒打錯。
