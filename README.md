# 劇本殺繁化助手

把簡體中文劇本殺 PDF 轉換為台灣標準繁體中文的工具。

## Pipeline

### Stage 1：簡轉繁

```
PDF 上傳
 → PyMuPDF 逐頁轉圖（解析度可調）
 → （可關閉）偵測首頁是否為含圖片之封面，若是則移除，不列入後續處理
   （純本機影像統計，比對首頁跟第二頁的墨水覆蓋率/顏色飽和度，不用
   任何付費 API；預設開啟，誤判可以直接關掉這個開關重新處理）
 → PaddleOCR 辨識（本機跑，無頁數上限，自己控制迴圈）
 → OpenCC (s2twp) 決定性簡轉繁（詞彙級，非字符對字符）
 → 分批（可調頁數，或選「整本丟」不分批）送 LLM 潤飾
   （斷句合併、標點全形化、刪頁首頁碼、修正明顯是 OCR 誤植造成的錯字
   ——但不做語氣調整或在地化，不更動原本的用詞語意；model 可選
   Gemini 3.6 Flash / 3.5 Flash Lite，或 Claude Haiku 4.5 / Opus 5
   ——Claude 會實際計費，跟 Stage 2 共用同一份 model 清單）
 → LLM 潤飾完後，再跑一次 OpenCC 做決定性校正
   （保證不留殘留簡體字，不需要為此再多打一次 API）
 → 偵測輸出被截斷（MAX_TOKENS / max_tokens）→ 視為失敗，不做無意義重試
 → API 呼叫本身失敗（網路/暫時性錯誤）→ 自動重試（次數可調）
 → 組裝輸出 .txt / .docx（下載時可切換格式，檔名沿用原始 PDF 主檔名）
```

任何一個批次不管在潤飾/校正的哪個環節出錯，都只影響那個批次（退回
純 OpenCC 結果），不會讓整份文件的輸出報銷。

### Stage 2：校對

```
Stage 1 輸出的文字（或直接上傳已經是繁體的 .docx/.txt，跳過 Stage 1）
 → 依字數分批（1000/3000/6000/10000 或全文；不是頁數，Stage 1 輸出
   已經不保留頁界）
 → 送 LLM 校對用詞/錯字/標點（model 可選 Gemini 3.6 Flash / 3.5 Flash
   Lite，或 Claude Haiku 4.5 / Opus 5——Claude 會實際計費，介面上有
   標明）
 → 要求結構化 JSON 輸出（原文/建議/上下文/原因），一樣有截斷偵測跟重試
 → 單一批次解析失敗只影響那批，不會讓整個校對任務失敗
 → 彙整成清單，介面上逐筆勾選要不要套用
 → 套用時逐批次做局部字串替換（不是全文 replace），避免同樣的詞在
   別處被誤改
 → 可以下載套用後的結果，也可以手動觸發「重新校對」再跑一輪
   （不做自動無限遞迴，避免無預警燒額度）
```

Stage 2 介面預設是鎖住的（除了「直接上傳繁體內容」以外），要等 Stage 1
跑完按下「Stage 2：開始校對」，或直接上傳繁體檔案，才會解鎖其餘設定。
一旦 Stage 1 開始處理，「直接上傳」這個選項就會被鎖住，避免兩邊來源
互相打架。

**使用量追蹤**：

- **今日使用量**（Gemini）：每次呼叫記進 `zh-cn-to-tw-backend/usage.db`，顯示
  「已用 / 每日上限」（美西時區，跟 Gemini API 官方額度重置時區一致）。
  上限數字在 `configs/config.py` 的 `RPD_LIMITS`（可用環境變數
  `GEMINI_3_6_FLASH_RPD_LIMIT` / `GEMINI_3_5_FLASH_LITE_RPD_LIMIT` 覆蓋），
  是本工具自己統計的次數，不是查詢 Google 官方即時數字。
- **Claude token 使用量**：記錄每次呼叫實際用掉的 input/output token
  數，顯示「token 數 / 換算台幣金額」。台幣是用本工具記錄的 token 數
  乘上 `configs/config.py` 的 `CLAUDE_PRICING`（Anthropic 官方牌價，
  調價要跟著更新）換算，匯率抓 `open.er-api.com` 的市場參考匯率（原本
  想抓台灣銀行牌告匯率，但那個網站有防爬蟲驗證擋掉一般後端請求，
  抓不到，改用這個沒有防爬、專門開放給程式呼叫的免費 API，數字僅供
  參考，會跟台銀牌告價有落差）。統計範圍是「累積至今」不分時間週期，
  分兩個層級：主介面顯示**當前選定劇本案**的累積用量，管理員介面顯示
  **全站**累積總量。**這跟 Claude Code/Claude.ai 的訂閱方案是兩套獨立
  帳務系統**，這個台幣金額本質上是參考估計值，不是查詢 Anthropic
  帳戶的真實帳單。

## 本機執行

### 後端

```bash
cd zh-cn-to-tw-backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env   # 填入 GEMINI_API_KEY
python3 app.py
```

後端會跑在 `http://localhost:5001`。`.env` 裡的值只是預設值，介面上
的欄位可以每次上傳/校對時個別覆蓋。

除了 `GEMINI_API_KEY`，本機測試登入功能還需要在 `.env` 補上
`GOOGLE_CLIENT_ID`（Google Cloud Console 申請的 OAuth Client ID）。
授權名單走資料庫（`users` / `permissions` 兩張表），不是環境變數——
本機第一次跑要自己往 `usage.db` 的 `users` 塞一筆自己的帳號
（`role` 填 1 代表管理員），之後就能從管理員介面維護。

### 前端

前端 `script.js` 是用瀏覽器直接打開（`file://`）還是用靜態伺服器開，
會影響後端 CORS 判斷的來源網域——後端只放行 `https://beethoreven.github.io`
跟任意 port 的 `localhost`/`127.0.0.1`，`file://` 開啟會被 CORS 擋掉，
本機測試務必用底下這種靜態伺服器方式開，不要直接用瀏覽器開檔案：

```bash
cd zh-cn-to-tw-web
python3 -m http.server 8000
```

再打開 `http://localhost:8000`。

## API 一覽

以下除了 `/api/health`（keep-alive 用，刻意公開）跟 `/auth/status`
（檢查登入狀態本身，未授權不算失敗）以外，全部都要帶
`Authorization: Bearer <Google ID Token>`，沒帶或帳號不是 `users` 表裡
啟用中（`status = 'active'`）的使用者一律回 401；`/admin/*` 另外要求
角色是管理員，否則同樣回 401。

### 登入

- `GET /api/health` — 健康檢查（公開，不需要登入）
- `GET /auth/status` — 查詢目前這個 token 有沒有效、對應 email 有沒有
  被授權、是不是管理員（回 200 + `{authorized, is_admin, email}`；
  只有 token 本身完全無效/過期才回 401）

### Stage 1

- `GET /api/options` — 前端畫設定欄位用：可選 model、各欄位上下限與說明
- `GET /api/usage` — 每個 model 今日已用次數
- `GET /api/my-projects` — 目前登入者名下的劇本案，給「本案處理劇本」
  下拉選單用
- `GET /api/usage/project/<id>` — 這個劇本案累積至今的 Claude token 用量
  與估計台幣費用（限該案負責人或管理員）
- `POST /api/jobs` — 上傳 PDF 開始處理，必帶 `project`（劇本案 ID），
  可帶 `model` / `batch_pages`（數字或 `whole`）/ `max_retry` / `dpi`
- `GET /api/jobs/<id>` — 查詢進度，`status_label` 是中文狀態文字
- `GET /api/jobs/<id>/download?format=txt|docx` — 下載結果

### Stage 2

- `GET /api/review-options` — 可選 model、批次字數/重試上下限
- `POST /api/jobs/<job_id>/review` — 對某個已完成的 Stage 1 job 開始校對
- `POST /api/jobs/direct-upload` — 直接上傳 .docx/.txt，跳過 Stage 1，
  產生一個可以直接拿去校對的 job
- `GET /api/reviews/<review_id>` — 查詢進度與 findings 清單
- `POST /api/reviews/<review_id>/apply` — body `{"selected_ids": [...]}`，
  套用勾選的建議，回傳套用後的文字
- `GET /api/reviews/<review_id>/download?format=txt|docx` — 下載套用後結果
  （還沒套用過就是原始校對前文字）
- `POST /api/reviews/<review_id>/rerun` — 對套用後的文字重新校對一輪

（`POST /api/jobs/<job_id>/review` 與 `/rerun` 都必帶 `project`）

### 管理員介面（全部要求角色是管理員）

- `GET /admin/usage/totals` — 全站累積的 Claude token 用量與估計台幣費用
- `GET /admin/users` — 所有使用者；`?role=<角色名>` 可只取某個角色
- `GET /admin/users/active-names` — 啟用中使用者的 id/姓名，給負責人下拉用
- `GET /admin/users/<id>` — 單一使用者
- `GET /admin/users/<id>/projects` — 這個人名下未結案（非 closed）的專案
- `POST /admin/users`、`PUT /admin/users/<id>` — 新建/更新使用者
- `GET /admin/permissions` — 角色清單（`?include_admin=true` 才含管理員）
- `GET /admin/permissions/<id>`、`PUT /admin/permissions/<id>` — 讀取/更新
  角色的 Opus/Haiku 使用上限
- `GET /admin/projects`、`GET /admin/projects/<id>` — 專案清單/單一專案
- `POST /admin/projects`、`PUT /admin/projects/<id>` — 新建/更新專案

## 已知限制

- `usage.db` 記的是「本工具打了幾次」，不是 Google 官方額度的即時數字；
  真正的額度請去 [AI Studio Rate Limit](https://aistudio.google.com/rate-limit) 查，
  數字對不上時以 AI Studio 為準，調整 `RPD_LIMITS` 即可。
- Stage 2 的「套用」是逐批次做局部字串替換，如果同一批次內同樣的錯字
  重複出現兩次以上，目前只會替換第一次出現的位置。
- 同時開多個分頁處理不同檔案：job/review 狀態各自獨立、上傳檔名不會
  衝突，可以放心同時跑；但 OCR 呼叫會排隊序列（同一個 PaddleOCR
  instance 加了鎖，避免多執行緒同時呼叫的未知風險），所以兩份文件的
  OCR 階段會互相等待、變慢，不是真正平行；Gemini 呼叫則不受此限，
  可以同時發出，但兩邊共用同一組帳號額度，會比單開一份更快用完
  當日 RPD。

## 目前進度

- [x] Stage 1：PDF 上傳 → OCR → 簡轉繁 → 潤飾 → 驗證/重試 → 輸出 txt/docx
  - [x] 介面可調 model（Gemini 3.6 Flash / 3.5 Flash Lite，或 Claude
    Haiku 4.5 / Opus 5——跟 Stage 2 共用同一份清單）/ 批次頁數（含整本
    丟）/ 重試次數 / DPI
  - [x] SQLite 使用量記錄 + 介面顯示今日用量（僅 Gemini 有 RPD 上限）
  - [x] 輸出截斷偵測，避免靜默接受不完整結果
  - [x] 任一批次潤飾/校正失敗都不影響整份輸出
- [x] Stage 2：二次校對（用詞/錯字），結構化清單 + 一鍵套用，手動觸發
  重新校對；也可以直接上傳已經是繁體的 .docx/.txt 跳過 Stage 1
  - [x] Model 可選 Gemini 或 Claude Haiku/Opus（會計費）
  - [x] Stage 2 介面預設鎖住，Stage 1 完成或直接上傳成功才解鎖
  - [x] Claude token 用量（token 數 + 估計台幣費用），依劇本案分別統計
- [x] 最左側獨立一欄「阿舍老師的叮嚀」內容區塊：純文字，內容來源是
  `zh-cn-to-tw-web/teacher-notice.txt`（純靜態檔案，前端直接讀，不經過
  後端 API、不需要登入），跟著前端程式碼進版控，要改內容直接編輯這個
  檔案再 push，不需要動程式碼或另外做後台介面
- [x] Stage 1 新增「偵測首頁是否為封面」開關（預設開啟），純本機影像
  統計（`ocr_utils/cover_detect.py`），偵測到就自動移除首頁、不列入
  OCR 與後續處理，不需要任何付費 API
- [x] Stage 3：登入權限。Google Identity Services + 後端授權（沿用
  fireless-war 的模式，`auth_utils/auth.py` 驗證 ID Token，`whitelist.py`
  查 `users`/`permissions` 兩張表判斷是否啟用、是否為管理員，帶 30 秒
  TTL 快取避免每次輪詢都打一次 DB），前端把 token 存進 localStorage
  （跟 fireless-war-web 不同的地方——重新整理、開新分頁都不會登出，
  只有明確登出才清除），沒登入或未授權時整頁（含純顯示區塊）都鎖住並
  跳 toast；後端每支會實際處理資料的路由都掛 `require_auth` 裝飾器，
  `/admin/*` 掛 `require_admin`，前端鎖只是視覺提示，真正擋掉未授權
  存取的是後端。
  - [x] 管理員介面：使用者管理 / 權限管理 / 專案管理三個頁籤，可新建與
    編輯使用者、調整角色的 Opus/Haiku 使用上限、維護劇本案與負責人
  - [x] 使用者登入後要先選定「本案處理劇本」並按確定，下方 Stage 1/2
    才會解鎖；之後每次呼叫 model 都會把該案 ID 記進 `usage_log.project`
  - [ ] 權限分級：低權限使用者每日可用的 Gemini 3.6 Flash 次數要能限制
    （預設 20 次），使用者名單跟每人的次數上限都要能在後台設定，不是
    寫死在程式碼裡
  - [ ] 超過權限額度時，使用者仍然可以在介面上選這個 model，但按下開始
    處理時要用 toast 擋下並顯示「超過權限內可使用之 Model 限量，請改用
    其他 Model」，不能真的送出去消耗額度
