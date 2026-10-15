# Mac 2.0 交接報告（2026-10-15）

給在 Mac 上接手 `zh-cn-to-tw-mac` 的人／Claude session。Windows 2.0 已經發布，Mac 這邊要做的是：讓殼能載入 2.0 前端，再出 Mac 2.0。這份報告是在 Windows 機器上寫的，**Mac 的程式碼一行都沒改**，下面的 Swift 是示意、沒有編譯過。

## 一句話總結

2.0 前端拆成了 ES module，`file://` 底下載入會整頁空白。所以 Mac 殼要從 `file://` 改成自訂 scheme `zhcntotw://app` 載入網頁，打包腳本也要改成複製整個新的前端資料夾。兩包（11+、10.15）都要改、都要測。

## 要做的事（照順序）

1. `WebView.swift`：註冊自訂 scheme `zhcntotw` 的 `WKURLSchemeHandler`，從 `.app` 裡的 `Resources/web/` 供應檔案（見「1. 自訂 scheme」）。
2. `ContentView.swift`：網頁網址改成 `zhcntotw://app/index.html`，順便修「`osTier=11+` 的 + 沒編碼」（見「2. 網址」、「5. osTier 的 +」）。
3. 兩支打包腳本：改成複製 `index.html`、`assets/`、`css/`、`js/`（見「4. 打包腳本」）。**不改的話，2.0 的 App 只會拿到 `index.html`，整個壞掉。**
4. 用 2.0 前端打包、兩包都照「測試清單」測過。
5. 測完之後：合併前端、出 Mac 2.0（見「測完之後」）。

## 背景：為什麼要改

- 2.0 前端把 `script.js`／`style.css` 拆成 `js/` 底下 29 個 ES module、`css/` 底下 15 個樣式檔，頁面用 `<script type="module" src="js/main.js">` 載入。
- `file://` 頁面的 Origin 是字面上的 `"null"`，module script 一律走 CORS，會全部被擋下，整頁看起來載入了但什麼都沒有。
- 解法是換成「同樣固定、但有正常來源」的網址。來源固定，`localStorage` 裡的登入狀態才能跨次啟動保留（這是 1.x 選 `file://` 的原因，見 `ContentView.swift` 那段註解）。
  - Windows 已經改好：WebView2 虛擬主機 `https://zh-cn-to-tw.example`，見 `zh-cn-to-tw-windows/src/ZhCnToTw/MainWindow.xaml.cs` 的 `SetVirtualHostNameToFolderMapping`。
  - Mac：自訂 scheme `zhcntotw://app`。
- 來源換了，使用者從 1.x 升到 2.0 時要**重新登入一次**（舊來源存的登入讀不到）。只有這一次，之後改版來源不變。Windows 也一樣，發布說明已經寫「程式結構調整(需重新登入)」。

## 已經準備好的（Mac 不用動）

| 項目 | 狀態 |
|---|---|
| 2.0 前端 | `zh-cn-to-tw-web` 的 **`v2` 分支**（`45e1271`）。刻意還沒合併進 `main`，見「測完之後」 |
| 後端 CORS | 已放行 `zhcntotw://app`（實測 preflight 回 `access-control-allow-origin: zhcntotw://app`），`"null"` 也保留給 1.x |
| 本機 OCR 服務 CORS | 已放行 `zhcntotw://app`（`zh-cn-to-tw-ocr-service` `3746bb1`）。meta-repo 的 `build_mac_dmg.sh` 會從原始碼重新 PyInstaller，pull 到最新就會包進去 |
| 後端 Stage 2 API | 已上線（預設範本 101 條） |
| Windows 2.0 | 已發布（`zh-cn-to-tw-windows` 的 `v2.0`），下載頁「更新說明」已經有 2.0 那段 |

## 1. 自訂 scheme（`WebView.swift`）

`WebView.swift`、`ContentView.swift` 在 `Legacy/` 是符號連結，改一份兩包都會吃到。`WKURLSchemeHandler` 是 macOS 10.13 就有的 API，10.15 那包可以直接用，不用 `#available`。

在 `makeNSView` 建立 `WKWebView` **之前**註冊（之後才註冊無效）：

```swift
configuration.setURLSchemeHandler(WebAssetSchemeHandler(), forURLScheme: WebAssetSchemeHandler.scheme)
let webView = WKWebView(frame: .zero, configuration: configuration)
```

handler 示意（未編譯；刻意不用 `UniformTypeIdentifiers`，那是 macOS 11 才有，10.15 那包編不過）：

```swift
import WebKit

/// 用自訂 scheme zhcntotw://app/ 供應包在 .app 裡的網頁（取代 file://）。
final class WebAssetSchemeHandler: NSObject, WKURLSchemeHandler {
    static let scheme = "zhcntotw"
    static let host = "app"

    // 沿用 ContentView 用 bundlePath 純字串組路徑的做法（見那邊的註解：
    // Bundle.main.resourceURL 在這個環境下是「相對字串 + baseURL」的組合）
    private let root = URL(fileURLWithPath: (Bundle.main.bundlePath as NSString)
        .appendingPathComponent("Contents/Resources/web")).standardizedFileURL

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url, url.host == Self.host else {
            respond(urlSchemeTask, status: 404, data: Data(), mime: "text/plain; charset=utf-8")
            return
        }
        // url.path 已經解碼、而且不含 ?desktop=1&... 這些查詢參數
        var path = url.path
        if path.isEmpty || path == "/" { path = "/index.html" }
        let fileURL = root.appendingPathComponent(String(path.dropFirst())).standardizedFileURL
        // 只供應 web/ 底下的檔案，擋掉 ../ 之類跑出去的路徑
        guard fileURL.path.hasPrefix(root.path + "/"), let data = try? Data(contentsOf: fileURL) else {
            print("[web-scheme] 找不到：\(url.absoluteString)")
            respond(urlSchemeTask, status: 404, data: Data(), mime: "text/plain; charset=utf-8")
            return
        }
        respond(urlSchemeTask, status: 200, data: data, mime: Self.mimeType(for: fileURL.pathExtension))
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        // start 裡是同步讀檔、同步送完，不會有 stop 之後還在送的情況。
        // 之後如果改成非同步：stop 之後絕對不能再呼叫這個 task 的
        // didReceive/didFinish，WebKit 會丟 NSInternalInconsistencyException 讓 App 當掉。
    }

    private func respond(_ task: WKURLSchemeTask, status: Int, data: Data, mime: String) {
        let url = task.request.url ?? URL(string: "\(Self.scheme)://\(Self.host)/")!
        let headers = [
            "Content-Type": mime,
            "Content-Length": String(data.count),
            "Cache-Control": "no-cache",
        ]
        let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!
        task.didReceive(response)
        task.didReceive(data)
        task.didFinish()
    }

    // module script 一定要是 JavaScript 的 MIME type，否則 WebKit 會直接拒絕執行
    // （錯誤訊息類似 "... is not a valid JavaScript MIME type"），整頁空白
    static func mimeType(for ext: String) -> String {
        switch ext.lowercased() {
        case "html", "htm": return "text/html; charset=utf-8"
        case "js", "mjs": return "text/javascript; charset=utf-8"
        case "css": return "text/css; charset=utf-8"
        case "json": return "application/json; charset=utf-8"
        case "txt": return "text/plain; charset=utf-8"
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "svg": return "image/svg+xml"
        case "ico": return "image/x-icon"
        default: return "application/octet-stream"
        }
    }
}
```

`performLoad` 不用改：`zhcntotw://` 不是 file URL，會走下面 `webView.load(URLRequest)` 那條。`url.isFileURL` 那段可以留著（不會再進去）或刪掉。自訂 scheme 的回應每次都是 handler 現讀檔案，不會有 Windows 那種 HTTP 磁碟快取吃到舊檔的問題。

### 行為會變的地方：外部連結

`decidePolicyFor navigationAction` 用「目標 host 跟目前頁面 host 不同」判斷外部連結、改用系統瀏覽器開。在 `file://` 底下目前頁面的 host 是 `nil`，這個判斷**其實從來沒生效過**；換成 `zhcntotw://app` 之後 host 是 `app`，連到其他網域的連結會開始改用系統瀏覽器開——這是原本就想要的正確行為，只是要知道它從現在開始才真的作用。2.0 頁面目前沒有外部連結（強制更新的網址寫在 alert 的文字裡）。`blob:` 下載走 `shouldPerformDownload`，在 host 判斷之前，不受影響。

## 2. 網址（`ContentView.swift`）

```swift
private var webURL: URL? {
    if let override = ProcessInfo.processInfo.environment["WEB_BASE_URL_OVERRIDE"],
       let url = URL(string: override) {
        return url
    }
    return URL(string: "zhcntotw://app/index.html")
}
```

`desktopURL(base:)` 照舊用 `URLComponents` 加查詢參數（`desktop`、`ocrToken`、`apiBase`、`appMajor`、`appMinor`、`osTier`），網頁讀的參數沒有變。另外見第 5 點的「+」。

## 3. 殼跟網頁的約定（沒變，但實作方式變了）

全部集中在前端的 `js/core/bridge.js`，名稱都跟 1.x 一樣：

- 網頁 → 殼的 channel：`consoleLog`（殼自己注入的腳本用）、`desktopSignIn`、`ocrService`、`activityGuard`、`legacyDownload`、`visionOcr`（只有 10.15）。
- 殼 → 網頁會呼叫的全域名稱：`handleCredentialResponse({credential})`、`showToast(message, type)`、`window.__attemptAutoSaveBeforeSleep()`、`window.__visionOcrProgress(payload)`（payload 形狀沒變）。殼直接寫入 `window.__OCR_PORT__`。
- 2.0 這些全域函式是 ES module 執行後才掛上 `window` 的（module 會延後執行），頁面載完（`didFinish`）之後一定在。殼現在都是在那之後才呼叫，沒問題；如果之後要在更早的時間點呼叫，記得這件事。

## 4. 打包腳本（兩支都要改）

`zh-cn-to-tw-mac/packaging/build_app_11_plus.sh`、`build_app_10_15.sh` 目前只複製四個檔：

```bash
for f in index.html script.js style.css favicon.png; do ...
```

2.0 沒有 `script.js`／`style.css`，`favicon.png` 也搬到 `assets/` 了，照這樣打包只會拿到 `index.html`。改成類似：

```bash
cp "$WEB_SRC_DIR/index.html" "$APP_BUNDLE/Contents/Resources/web/"
for d in assets css js; do
  cp -R "$WEB_SRC_DIR/$d" "$APP_BUNDLE/Contents/Resources/web/"
done
```

（一樣不要把 `README.md`、`.git` 帶進去。Windows 那邊的 `build_installer.bat` 是整個資料夾 `xcopy`，`.git` 是隱藏檔不會被複製。）

**合併前用 2.0 前端打包測試**：兩支腳本本來就支援 `WEB_SRC_DIR`。在 Mac 上可以這樣做：

```bash
cd zh-cn-to-tw
git pull && git submodule update --init --recursive
git -C zh-cn-to-tw-web fetch origin v2
git -C zh-cn-to-tw-web worktree add ../.web-v2 v2      # 會建在 meta-repo 根目錄的 .web-v2
WEB_SRC_DIR="$PWD/.web-v2" ./build_mac_dmg.sh
```

（`.web-v2/` 可以加進 meta-repo 的 `.git/info/exclude`，Windows 這邊也是這樣做的。）

## 5. `osTier=11+` 的「+」（疑似 1.x 就有的問題，請順便確認）

- `URLComponents` 組查詢字串時**不會**把 `+` 編碼（`+` 在 query 裡是合法字元），網址會是 `...&osTier=11+`。
- 前端用 `URLSearchParams` 讀參數，**`+` 會被解讀成空白**，讀到的是 `"11 "`（1.x 的 `script.js` 也是同一個寫法）。
- 後端實測（2026-10-15）：

  | `os_version` | 版本 1.3（低於最低需求 1.4） |
  |---|---|
  | `11%2B`（`11+`） | `force_update: true` |
  | `11%20`（`11 `） | `force_update: false`（查不到門檻，一律不擋） |
  | `10.15` | `force_update: true` |

- 也就是說，**如果**上面的推論成立，Mac 11+ 的強制更新一直沒有作用（10.15 沒有 `+`，不受影響）。我在 Windows 上沒辦法實測 Mac 實際送出的網址，請用 Web Inspector 確認：Network 裡 `version_check` 請求的 `os_version` 是 `11%2B` 還是 `11%20`。
- 修法（在 `desktopURL(base:)` 設完 `queryItems` 之後）：

  ```swift
  components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
  ```

  Windows 殼用 `Uri.EscapeDataString` 組網址，會把 `+` 編成 `%2B`，所以 Windows 沒有這個問題。

## 6. 版本號

用 meta-repo 的 `/update_version 2.0`（兩個分流），會改兩個 `Info.plist` 跟後端 `app_versions` 表。2.0 前端會送 `appMajor=2`、`appMinor=0`。

## 測試清單（11+、10.15 兩包都要）

1. 開 App 畫面正常（不是空白）。Web Inspector 的 console 沒有 module／MIME／CORS 錯誤，`location.origin` 是 `zhcntotw://app`。
   - 如果 `location.origin` 是 `"null"`、module 被當成跨來源擋下：備案是在 handler 的回應加上 `Access-Control-Allow-Origin: *`。後端跟 OCR 服務的 CORS 都還留著 `"null"`，API 本身不會被擋。
2. 登入：第一次會要求重新登入（預期）。登入後關掉 App 再開，要還是登入狀態。
3. Stage 1：11+ 走本機 OCR 服務（`fetch` 打 `http://127.0.0.1:<port>`）；10.15 走 Vision OCR（`visionOcr` channel）。
4. Stage 2：套用、下載結果、下載報告、分析報告；個人範本（開關打開才能下載、選檔）。
5. Stage 3：校對、勾選套用、重新校對、下載。
6. 1→2→3 自動串接（Stage 1 的「完成後接續」選「接 Stage 2」、Stage 2 打開「接續 Stage 3」）。
7. 下載：11+ 走 `WKDownload`；10.15 走 `legacyDownload`。
8. 工作進行中的睡眠保護（`activityGuard`）、睡前自動搶救（`__attemptAutoSaveBeforeSleep`）。
9. 用新版安裝檔覆蓋舊版之後，登入狀態還在（第二次升級起）。
10. 第 5 點的 `os_version` 是 `11%2B`。

## 測完之後

1. 把 `zh-cn-to-tw-web` 的 `v2` 合併進 `main`。合併之後 Mac、Windows 打包都直接用 `main`，不用再設 `WEB_SRC_DIR`／`WEB_REPO_OVERRIDE`。**合併一定要等 Mac 改好**：Mac 打包是從 web 的 `main` 複製網頁，Mac 殼還沒改之前合併，下一次打的 Mac 包會整頁空白。
2. meta-repo 更新 `zh-cn-to-tw-web`、`zh-cn-to-tw-mac` 的 submodule 指標並 commit。
3. `/update_version 2.0`、打兩包 DMG，在 `zh-cn-to-tw-mac` 建 Release：tag `v2.0-11-plus`／`v2.0-10-15`，檔名照舊例 `ZhCnToTw-2.0-11+.dmg`／`ZhCnToTw-2.0-10.15.dmg`（ASCII）。發布說明跟 Windows 一樣：
   1. 新增範本式套用修改，未來可直接針對一些常見錯誤一次性套用修正，同時分析套用報告確保沒有錯誤套用。
   2. 將介面改為直向流程顯示，確保後續可擴充性。
   3. 程式結構調整(需重新登入)。
4. 下載頁（`zh-cn-to-tw-web` 的 `update-page` 分支）：Mac 區塊最上面**新增**一個 2.0 的 `.version-block`（不要改寫既有的，舊版留著給人回退）。「更新說明」已經有 2.0 那段，不用動。
5. `CLAUDE.md`：「Mac 要改用自訂 scheme `zhcntotw://app`（尚未實作…）」那句改成已完成；兩邊 CORS 的 `"null"` 等 1.x 都淘汰之後才能拿掉。過程中踩到新的一類坑，記得加進 `known-issue-check`。

## 參考

- 前端 README（`v2` 分支）：「2.0：為什麼拆檔、怎麼拆」，殼跟網頁的約定、語法上限 Safari 13.0（10.15 分流）。
- `zh-cn-to-tw-windows` README：「網頁怎麼載入：2.0 起從 file:// 換成虛擬主機」，Windows 的完整做法與實測項目。
- `zh-cn-to-tw-backend` README：Stage 2「套用範本修改」的設計，以及校對 prompt 為什麼要靠 `skip_fullwidth_punct` 對 1.x 向下相容。
