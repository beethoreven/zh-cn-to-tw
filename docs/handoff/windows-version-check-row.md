# Windows 強制更新：最終處理方式（2026-10-16，Mac 這邊整理）

給在 Windows 機器上接手的人／Claude session。這份取代原本「要你確認」的版本：`os=macos` 已由 Windows 那邊修掉（web `08dc6ec`），下面是整件事最後怎麼收尾、你那邊還要做什麼。

## 現在的規則

| 誰在送 | 送出的值 | 對應的 `app_versions` 列 |
|---|---|---|
| Mac 11+ | `os=macos&os_version=11+` | `('macos','11+')` |
| Mac 10.15 | `os=macos&os_version=10.15` | `('macos','10.15')` |
| 修正後重新發布的 Windows 2.0 起 | `os=windows&os_version=default` | `('windows','default')` |
| Windows 1.x、第一次發布的 2.0（舊前端） | `os=macos&os_version=windows` | `('macos','windows')` |

- `('windows','10+')` 沒有任何用戶端會送，是殘留，先不動，等下面「之後拿掉」時一起刪。
- Mac 不用重包：`versionCheckKey()` 只有 `osTier === "windows"` 才改走新的 key，Mac 送出的值跟原本一樣。

## 2026-10-16 01:00 的強制更新

使用者授權、由 Mac 這台的 Claude session 排程執行 `docs/handoff/force_update_2_0.py --apply`，把上表前四列的 latest／min 都設成 2.0（`('windows','default')` 與 `('macos','windows')` 原本不存在，用 UPSERT 新增）。執行結果會另外回報給使用者；**你那邊不要再自己寫一次 DB**，`app_versions` 由使用者決定。

效果：≤1.8 的 Mac 與 Windows 會被擋下要求更新。第一次發布的 Windows 2.0 不會被擋（版號同樣是 2.0，DB 分不出兩個 2.0）。

## 之後要記得的（已寫進 meta-repo `CLAUDE.md`「待處理事項」）

- **下一次 Windows 出新版要強制更新時，兩列都要改**：`('windows','default')` 和 `('macos','windows')`。只改前者的話，停在舊前端 2.0 的人不會被擋。
- 那次強制更新生效一段時間、舊前端的人都被逼去更新之後，刪掉 `('macos','windows')` 和 `('windows','10+')`，並把那條待處理事項拿掉。
- `zh-cn-to-tw-windows` README 的出新版步驟如果有寫 `app_versions`，照上面更新。

## 你那台要手動同步的兩樣東西（不在 git 裡）

使用者要求把這次的教訓加進**全域**設定，Mac 這台已經加了，但 `~/.claude/` 不跟 repo 走，Windows 那台要自己貼：

1. **全域 `~/.claude/CLAUDE.md`**：在「開發原則」最後加上下面這一節（原文照貼）。
2. **全域 `~/.claude/skills/known-issue-check/SKILL.md`**：把下面的條目接在 Checklist 最後。Mac 這台是第 37 條；你那台的編號如果不同，改成你那份的下一號，同時把上面 CLAUDE.md 那節裡的「第 37 條」跟著改。不要動專案版（`.claude/skills/known-issue-check/`），使用者說這條只加全域。

### 1. 全域 CLAUDE.md 要加的一節

````markdown
## 改架構、跨平台時，順手修掉已知的 workaround

- 改架構、移植到新平台、重寫某個檔案之前，先找出這次會動到的地方裡，已知不合理、而且好修的 workaround：寫死的平台／版本／環境字串、註解寫著「暫時」「歷史包袱」「TODO」的寫法。
- 預設在同一個改動裡一起修掉。這時候程式本來就在改、本來就要重測、本來就要發新版，是修它最便宜的時候；等這版發出去，舊的用戶端就改不回來了，後端得長期相容。
- 真的要留，就寫明為什麼留、什麼條件下拿掉，寫在之後的 session 一定會讀到的地方（例如專案的 CLAUDE.md），不要只留一句「之後再說」。
- 細節與案例見 known-issue-check 第 37 條。

緣由：2026-10 的 zh-cn-to-tw（劇本殺繁化助手）。Windows 版剛加進來時，共用前端把版本檢查的 `os=macos` 寫死，Windows 只好改送 `os_version=windows` 避開 Mac 的資料，當時決定「Windows 還沒上線，先不改共用前端」。這個決定沒有期限，一路帶到 2.0 把前端整個拆成 ES module 都沒修。後端照「應該送的值」建了 Windows 的資料列，用戶端卻從沒送過，Windows 的強制更新從頭到尾都沒生效；修好之後，已發布的舊版還在送舊值，只能暫時同時維護兩列。
````

### 2. known-issue-check 要加的條目

````markdown
### 37. A known, trivially-fixable workaround carried through an architecture change or a new platform instead of being fixed there

**Pattern**: A workaround is introduced under time pressure — a hard-coded literal, a borrowed identifier, a magic value chosen to dodge a collision — and it is *known* to be wrong at the time: the author leaves a comment calling it a "歷史包袱", a "temporary hack", a "TODO", and often writes down the correct fix right next to it. The reason for not fixing it then is usually sound in isolation ("touching shared code for a platform that hasn't shipped yet is risky"). The problem is that "not now" has no trigger attached, so it becomes "never." The workaround then survives exactly the events that should have killed it: a rewrite that touches the very file it lives in, a second platform being added, a module split, a protocol change. Each of those is the cheapest moment the fix will ever have — the code is already being changed, already being re-tested, already shipping as a new version — and each time the workaround is carried over verbatim, with its apologetic comment, because the change in front of the author is "the rewrite," not "the workaround."

The cost compounds in two ways that make it far worse than the original hack. First, **every release that ships the workaround is a release that can never be fixed retroactively**: once clients in the field send the wrong value, the server must keep honoring it until those clients are gone, so a one-line fix turns into a migration with a deprecation tail. Second, **workarounds rarely stay inert** — the code around them evolves on the assumption that the workaround is the real contract. Server-side data gets written for what the system *should* send (a policy row keyed by the correct value) while clients keep sending the workaround value, so the two never meet and a whole feature silently does nothing. Because everything returns a valid answer ("no matching row → don't block"), nothing errors, and the feature's absence is invisible until someone needs it.

**How to check**: When reviewing any architecture change, platform port, rewrite, or module split, grep the touched files for comments that apologize for the code — `workaround`, `hack`, `temporary`, `暫時`, `歷史包袱`, `寫死`, `TODO`, `FIXME`, references to "see known-issue item N" — and for hard-coded literals that identify a platform, tenant, version, or environment. For each, ask: "is this still needed, and is fixing it now cheaper than it will ever be again?" If the fix is small and the code is already changing, the default is to fix it in the same change; carrying it forward requires a stated reason and an explicit trigger for removal. Separately, for any value a client sends that the server uses as a lookup key, check that **some row/entry actually matches what shipped clients send** — not what the code comment says they should send. A key nobody sends and a value nobody matches look identical from either side alone; only putting the client's actual request next to the server's actual data reveals it. Finally, when a fix lands, check whether already-shipped clients still send the old value: if so, the server must keep supporting it, and that obligation (and the condition for dropping it) has to be written down somewhere a future session will read, or it will either be forgotten (old clients silently stop being governed) or kept forever.

**Concrete example (zh-cn-to-tw-web / zh-cn-to-tw-windows / zh-cn-to-tw-backend, 2026-08-17 → 2026-10-16)**: Item 22 records the origin: the shared frontend hard-coded `os=macos` in the version-check request, so when the Windows shell was added it sent `osTier=windows` — a value deliberately chosen to *miss* the Mac policy rows — producing `os=macos&os_version=windows`. Item 22 itself chose not to touch the shared frontend "right now" because Windows hadn't shipped yet. That deferral had no trigger. Windows then shipped 1.4, 1.5, 1.7, 1.8, and finally 2.0 — a rewrite that split the entire frontend into 29 ES modules, moved the version check into its own `js/core/version.js`, and changed both shells' page origin — and the hard-coded `os=macos` was carried into the new module verbatim with a comment calling it "寫死的歷史包袱." Meanwhile the backend's `app_versions` table had gained a `('windows','10+')` row, written for what Windows *should* send; no client ever sent it. The `version_check` endpoint answers "no matching row → `force_update: false`," so for the entire life of the Windows app forced updates were silently a no-op, and no one knew until the owner tried to force everyone off ≤1.8 and the rows were laid side by side with the actual request. Fixing it took a few lines (`versionCheckKey()` returning `{os: "windows", osVersion: "default"}` for Windows). But because 1.x and the first 2.0 build were already in the field sending the old value — and the re-released fixed 2.0 has the same version number, so the database cannot tell them apart — the server now has to maintain a second row `('macos','windows')` for the old frontend, and *both* rows must be updated on the next Windows forced update until that population has been forced off. That obligation was recorded in the meta-repo `CLAUDE.md` "待處理事項" rather than a README so every session on every machine reads it. Had the literal been fixed during the 2.0 module split — the file was being rewritten anyway — none of the deprecation tail would exist.
````
