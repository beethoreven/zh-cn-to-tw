# zh-cn-to-tw — 給 Claude Code 的專案筆記

這份檔案是給任何一台機器上、任何一個新開的 Claude Code session 讀的——目的是讓你不用從零開始重新認識這個專案。詳細的技術決策、踩過的坑、逐項的架構理由，分散在各子 repo 自己的 README（尤其 `zh-cn-to-tw-backend`）跟下面提到的幾個 skill 裡；這份檔案負責的是「串起 meta-repo 層級才看得出來的脈絡」，不是重複那些內容。

## 這是什麼

「劇本殺繁化助手」：把簡體中文劇本殺 PDF 轉成繁體中文，跑 OCR + LLM 潤飾（Stage 1），再跑一輪 LLM 校對（Stage 2）。有瀏覽器版、macOS 桌面版兩種使用方式，Windows 桌面版開發中（Stage 1 已完成，見下面「目前線上狀態」）。

## Repo 結構

這個 repo（`zh-cn-to-tw`）本身**不會被部署**，純粹是本機開發用的統一入口，透過 git submodule 掛著五個真正做事的 repo：

| Submodule | 做什麼 | 部署/產出 |
|---|---|---|
| `zh-cn-to-tw-backend` | Flask API，OCR 以外的所有業務邏輯（LLM 呼叫、DB、auth、額度） | Render（`https://zh-cn-to-tw-backend.onrender.com`） |
| `zh-cn-to-tw-web` | 前端（vanilla JS，沒有 build 流程） | `main` 分支的內容被桌面版 App 直接內嵌打包，**不會**被 GitHub Pages 服務；GitHub Pages 服務的是完全獨立的 `update-page` 分支（orphan branch，跟 `main` 沒有共同檔案/歷史），內容是桌面版下載頁 |
| `zh-cn-to-tw-mac` | macOS 桌面殼（Swift/SwiftUI + WKWebView），內嵌 `zh-cn-to-tw-web` 的網頁 + `zh-cn-to-tw-ocr-service` 的執行檔 | 本機打包成 `.app`/`.dmg`，發布到 GitHub Releases |
| `zh-cn-to-tw-ocr-service` | 本機執行的 PaddleOCR HTTP 服務，只有桌面版會用到 | 本機用 PyInstaller 打包成獨立執行檔，內嵌進 `zh-cn-to-tw-mac` |
| `zh-cn-to-tw-windows` | Windows 桌面殼（.NET 8 WPF + WebView2），內嵌 `zh-cn-to-tw-web` 的網頁 | 規劃打包成 `.exe`，目前尚無打包腳本（見該 repo 的 README） |

`git clone` 要用 HTTPS（`https://github.com/beethoreven/zh-cn-to-tw.git`），`.gitmodules` 裡五個子模組也是 HTTPS 網址——不要改回 SSH host alias 那種寫法，那種寫法綁死特定一台機器的 `~/.ssh/config`，換機器會直接解析失敗（已經實測撞過、修過一次）。

## 為什麼架構長這樣（快速版，細節見 `zh-cn-to-tw-backend` README）

- **OCR 為什麼跑在使用者本機、不是後端**：PaddleOCR 記憶體/CPU 需求會直接把 Render 免費方案打爆（OOM、SIGILL）。桌面版把 OCR 移到本機執行；瀏覽器版目前程式碼還在但實務上不會被真的用到（GitHub Pages 只服務下載頁，不會有人從瀏覽器直接連到會觸發 OCR 的頁面）。
- **桌面版網頁用 `file://` 載入、不是本機 HTTP server**：本機 server 的 port 每次啟動都不一樣，會讓 `localStorage`（登入 session）的 origin 跟著變，等於每次開 App 都要重新登入。固定的 `file://` 路徑讓 origin 穩定。
- **登入 session 是應用程式自己發的、不是直接用 Google ID Token**：Google ID Token 只活 ~1 小時，直接拿來當長效憑證，長任務跑到一半會被登出、已經花錢算出來的結果存不進去。见 `google-auth`（使用者層級 skill，未搬進這個 repo，因為是通用模式不是這個專案專屬知識）。
- **macOS 11+ / 10.15 兩包分開版控**：`Package.swift` 的 `platforms` 是整個 SwiftPM package 共用一份，沒有 per-target 部署目標，沒辦法在同一個 target 裡同時支援 11+ 用的 `App`/`Scene`/`WindowGroup`（要 11.0+）又支援到 10.15。`zh-cn-to-tw-mac/Legacy/` 是完全獨立的第二個 SwiftPM package（部署目標 10.15），大部分原始碼用符號連結共用 `Sources/ZhCnToTw/` 同一份，只有進入點（`App.swift`）不同。10.15 那包 Stage 1 改用 Apple 原生 Vision framework 做 OCR，不透過 `zh-cn-to-tw-ocr-service`——onnxruntime（RapidOCR 依賴的推論引擎）編譯二進位檔 `minos` 寫死 11.0，10.15 上跑不動任何 Python-based OCR 引擎，這是 `otool -l` 直接查證過的硬限制，不是設計選擇。

## 目前線上狀態

- Backend/Web 部署在 Render/GitHub Pages，`main` 分支即時生效。
- macOS App 走 GitHub Releases 版控（`zh-cn-to-tw-mac` repo 底下，`v<版本>-11-plus`/`v<版本>-10-15` 兩個 tag，DMG 掛在對應 Release 上，檔名刻意用 ASCII，見下面「已知的坑」）。
- 下載頁 `https://beethoreven.github.io/zh-cn-to-tw-web/` 直接連到 GitHub Release 的 DMG 檔案本身（不是先連到 Release 頁面），連結網址是釘死版本號的，**每次出新版要手動同步這個頁面的連結**（`zh-cn-to-tw-web` 的 `update-page` 分支）。
- Windows 版：Stage 1 完成（WPF + WebView2 桌面殼，見 `zh-cn-to-tw-windows` 的 README）。已實測：殼能開起來、`file://` 載入前端、桌面版 Google 登入（系統瀏覽器 + loopback）、Stage 2 直接上傳繁體內容校對都正常運作。尚未開始：Stage 1 PDF/OCR 上傳（`zh-cn-to-tw-ocr-service` 還沒有 Windows 版）、Win7/CPU 架構相容性、打包成 `.exe`（`build_app_exe.bat`）、上線更新下載頁——這些是接下來 Windows 版 Stage 2/3 的範圍。

## 專案自帶的 Skills（`.claude/skills/`，跟著這個 repo 走，任何機器 clone 下來都能用）

- **`zh-en-readme`**：這個專案所有 README 的格式慣例（中文報告 + SOP，英文鏡像，一段一行不手動硬換行）。改動任何 repo 的 README 前後都套用這個格式。
- **`known-issue-check`**：累積的真實踩坑清單（目前 21 條，涵蓋 race condition、資源生命週期、CORS/origin、鎖與併發、bash 3.2 的坑、build 腳本沒真的重新編譯等），每條都有具體案例。**寫完程式碼、覺得做完之前，對照這份清單檢查一次**；找到新的一類坑，加進這份清單。
- **`update_version`**：桌面版 App 出新版本號時用，同步更新 `Info.plist`（兩個分流各一份）跟 backend DB 的 `app_versions` 表。

## 跟這個專案協作時的慣例

- **溝通一律用繁體中文**（包含過程說明、狀態更新，不只是程式碼/commit）。
- **不要主動 commit/push 本機還沒測過的改動**——包括「先 commit 在本機留紀錄」這種折衷也不要做，等使用者明確說可以了才動作。例外：改動本身就是 backend/前端已部署內容，需要上線才驗證得了的（例如 DB schema、API），這類可以直接 commit + push。
- **診斷問題要有直接證據**（實際 log、實際量測、真的重現過），不要停在「這個理論聽起來合理」就當作答案。
- 檢查「有沒有東西還在跑」，要查真正的背景任務追蹤（每次 `run_in_background` 產生的 task id），不要只查 shell 的 `ps`/`jobs`，也不要跟自己規劃用的 to-do 清單搞混——這兩個都看不到 harness 追蹤的背景任務。

## 待處理事項

- **OCR 與 Stage 2 解耦**：目前整個桌面殼是單一 binary，一個作業系統版本門檻會擋住整個 App（包含完全不需要 OCR 的 Stage 2）。已經動手拆過一次（10.15 分流），但更廣義的「哪個子系統掛了不該連坐拖累另一個」還沒有系統性檢視過，之後有機會可以順手看看還有沒有類似情況。
