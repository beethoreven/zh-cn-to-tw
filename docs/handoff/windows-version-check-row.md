# Windows 強制更新資料列對不上（2026-10-16，Mac 這邊發現）

給在 Windows 機器上接手 `zh-cn-to-tw-windows` 的人／Claude session。這份是 Mac 這邊在排「強制更新 ≤1.8」時查 DB 發現的，**請你確認並決定要不要改前端／殼**。

## 事實（都是實際查到的）

DB 的 `app_versions` 表目前有三列（2026-10-16 00:30 唯讀查詢）：

| os | os_version | latest | min |
|---|---|---|---|
| macos | 11+ | 2.0 | 1.4 |
| macos | 10.15 | 2.0 | 1.4 |
| **windows** | **10+** | 2.0 | 1.4 |

但 Windows 2.0 的前端送出的是：

```
GET /api/version_check?os=macos&os_version=windows&major=2&minor=0
```

（`zh-cn-to-tw-web` 的 `js/core/version.js`：`os=macos` 寫死；`os_version` 取自殼傳的 `osTier=windows`。）

所以後端查的是 `('macos', 'windows')`，**這一列不存在**，`get_policy` 回 `None` → 一律不擋。上表那一列 `('windows','10+')` 沒有任何請求會打到。**也就是 Windows 的強制更新從來沒生效過。**

## Mac 這邊已經做的

為了讓凌晨一點的強制更新對 Windows 也有效，排程腳本 `docs/handoff/force_update_2_0.py` 會 UPSERT `('macos','windows')`：latest=min=2.0。這樣**不用改任何 Windows 已發布的程式**（2.0 安裝檔照舊）就會擋到 ≤1.8。

## 要你確認的事

1. `('windows','10+')` 那一列是誰、為什麼建的？如果是原本打算讓前端送 `os=windows&os_version=10+`，那是計畫還是殘留？
2. 長期要用哪一套 key：
   - **A（現況＋Mac 的修補）**：維持 `('macos','windows')`。簡單，但 `os=macos` 對 Windows 是個誤導的歷史包袱。
   - **B**：前端改成 Windows 送 `os=windows&os_version=10+`，對上現有那一列。要改 `js/core/version.js`（Mac 殼不受影響），**而且已發布的 2.0 安裝檔還是送舊值**，所以過渡期兩列都要有。
3. 無論選哪個，`app_versions` 之後出新版要同步哪一列，寫進 `zh-cn-to-tw-windows` README 的出新版步驟。目前 CLAUDE.md 寫「`osTier=windows` 在 `app_versions` 沒有對應資料列」，凌晨之後這句要更新。

## 不要做的事

- 不要直接改 prod 的 `app_versions`：這張表由使用者自己決定門檻。上面的 UPSERT 是使用者明確授權的一次性排程。
- 不要在沒跟使用者確認前改 `version.js` 的 `os=macos`：Mac 11+ 的 `os_version=11+` 也走同一支函式。
