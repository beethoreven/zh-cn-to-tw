---
name: zh-en-readme
description: Update a repo's README.md into a bilingual (Traditional Chinese first, English second) format split into a 專案報告/Project Report and a 架設 SOP/Setup Guide section. Use when the user asks to "整理 README"、"寫雙語 README"、apply the "zh-en-readme" format, or references this pattern/skill by name.
---

把一個 repo 的 README 整理成中文在上、英文在下的雙語格式，且中文（連帶英文鏡射）內部再分成「專案報告」（為什麼、怎麼決策、踩過的坑）跟「架設 SOP」（照著做就能跑起來的步驟）兩個獨立區塊。

參考範本（已驗證過、直接照抄結構即可）：
- 子系統/實際部署的 repo：`/Users/darkather/Codebase/fireless-war/fireless-war-backend/README.md`
- meta-repo（純 submodule wrapper，本身不部署）：`/Users/darkather/Codebase/fireless-war/README.md`

在寫之前，先判斷這個 repo 是哪一種，套用對應骨架——兩種骨架的差異不只是內容多寡，標題階層也不同。

## 骨架 A：meta-repo（submodule wrapper，本身不部署）

```
# <repo 名稱>

## 中文

<一段話：這是什麼、透過 submodule 掛了哪些子系統、本身不部署、細節去看各子系統的 README>

### 子系統

| 子系統 | Repo | 部署/產出 |
|---|---|---|
...

### 使用方式

**第一次拿到全部程式碼：**
```bash
git clone --recurse-submodules <url>
```

**已經 clone 過，只是要把子模組抓齊：**
```bash
git submodule update --init --recursive
```

**更新某個子模組到它自己 repo 的最新版本：**
```bash
cd <submodule>
git pull origin main
cd ..
git add <submodule>
git commit -m "Update <submodule> submodule pointer"
```

（說明這個 git add + commit 不能省略的原因——submodule pointer 沒更新，別人 clone 還是抓到舊版本）

---

## English

(整段鏡射翻譯，標題階層一致：## English → ### Subsystems → ### Usage)
```

沒有「專案報告」/「架設 SOP」的切分——meta-repo 本身沒有值得寫技術報告的邏輯，也不需要架設步驟（子系統各自有自己的 SOP）。

## 骨架 B：子系統 / 有實際程式碼且會部署的 repo

```
# 中文

## <專案名稱> — <這支 repo 的角色，例如「後端 API」「前端」「macOS 桌面殼」>

<一兩句話說這支 repo 是做什麼的>。這份文件分成兩個獨立的部分，請依需求閱讀:

- **[專案報告](#專案報告)**：<這節在講什麼，一句話>
- **[架設 SOP](#架設-sop)**：<這節在講什麼，一句話>

這兩部分刻意分開，不要交叉閱讀；報告是背景知識，SOP 是操作手冊。

---

## 專案報告

### 這是什麼
### 系統架構          ← 如果這支 repo 是 meta-repo 的一部分，畫出 meta-repo 底下的資料夾樹狀圖，標明這支 repo 在其中的位置
### <關鍵決策 1 的標題，用問題/決策本身當標題，不要用「功能說明」當標題>
### <關鍵決策 2>
...
### 檔案結構
### 已知限制

---

# 架設 SOP / Setup Guide

## Part A. ...
### 1. ...
### 2. ...
## Part B. ...
## Part C. 環境變數總覽
...

---

# English

<整段鏡射翻譯，一字不漏對應中文版的每個章節，標題階層也一致：
# English → ## Project Report → ### What This Is → ... → # Setup Guide → ## Part A. ...>
```

## 寫「專案報告」內容時的原則

專案報告不是功能列表，是「這個決策為什麼長這樣」的記錄。每個小節優先寫進去的東西，依重要性排序：

1. **為什麼需要這個東西 / 這個決策解決了什麼問題**——不要只寫「做了什麼」，要寫「不這樣做會怎樣」。
2. **踩過的坑，含具體數字/錯誤訊息**——實測的記憶體用量、逾時秒數、錯誤字串、崩潰訊息，這些細節就是報告的價值所在，不要為了精簡而刪掉。憑空寫「效能有改善」沒有意義，要寫「從 X 降到 Y」。
3. **曾經嘗試過、後來放棄的方案，以及放棄的具體原因**——這能防止未來的人重踩同一個坑。「試過 A，因為 B 而放棄，改用 C」比只寫「用了 C」有價值得多。
4. **架構性的取捨（安全性、效能、維護成本之間的權衡）**，尤其是「刻意」的決定——用詞上明確標出「這是刻意的」，避免被誤認為疏漏。

素材來源：讀這支 repo 的 git log（尤其是 commit message 裡帶有原因說明的那些）、程式碼裡的關鍵註解、以及當前對話/記憶系統裡使用者交代過的背景。**不要在沒有實際依據的情況下編造「踩過的坑」或「實測數據」**——找不到具體依據的部分，寫功能性描述就好，不要硬套這個敘事框架。

## 寫「架設 SOP」內容時的原則

- 每一步都要是「照著打就會動」的具體指令，不是「設定好環境」這種摘要句。
- 假設讀者可能對某些基礎工具不熟（例如什麼是虛擬環境、`.env` 怎麼用）——參考骨架 B 範本 Part A 步驟 2 的寫法，一句話解釋概念，不要預設讀者已經懂。
- 環境變數要整理成表格：變數名、是否必填、說明。
- 涉及外部平台（Render、GitHub Pages 等）的步驟，寫到「哪個按鈕點下去、填什麼值」的細節，不要只寫「部署到 Render」。
- 步驟之間如果有前後依賴（例如某個 API 沒登入測不了），要點出來並給替代測試方式。

## 中英文對照規則

- 中文區塊完全寫完之後，用 `---` 分隔，再接整段英文——不要中英文逐段交錯。
- 英文是中文的完整鏡射，章節數量、標題階層、資訊密度都要對應，不是摘要版。
- 英文的標題不能直接沿用中文（例如 `## 專案報告` 對應 `## Project Report`，`# 架設 SOP / Setup Guide` 對應 `# Setup Guide`）——照抄範本裡中英文標題的對應關係。
- Anchor link（`[專案報告](#專案報告)` 這種）直接照抄範本的寫法，不要自己重新計算 GitHub 的 slug 規則。

## 套用到一個 repo 時的實際步驟

1. 讀這支 repo 現有的 README（如果有），判斷要套骨架 A 還是 B。
2. 讀 `git log --oneline`，找出值得寫進「專案報告」的關鍵決策點；必要時 `git show` 看幾個關鍵 commit 的完整說明。
3. 讀程式碼結構，確認「檔案結構」小節的內容是最新的。
4. 寫中文版全文，再逐節鏡射寫英文版。
5. 如果這支 repo 是某個 meta-repo 底下的 submodule：檢查 meta-repo 自己的 README 和其他 submodule 的 README 有沒有互相引用的地方需要同步更新（例如「完整細節見 XXX 的 README」這種交叉引用）。
6. 修改完 SOP 或已知限制之類會影響操作的內容後，可能的話實際照著 SOP 跑一次確認沒有斷掉的步驟；至少要對照現有程式碼/設定檔核對每個環境變數、每個指令是否仍然正確。
