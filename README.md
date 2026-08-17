# zh-cn-to-tw

## 中文

「劇本殺繁化助手」專案總覽 repo，透過 git submodule 把各子系統掛在一起，方便一次 `clone` 齊全部程式碼。這個 repo 本身**不會被部署**——各子系統各自連到自己的 repo 做部署或本機打包（見下表），這裡純粹是本機開發時的統一入口。各子系統的技術細節、架構決策、曾經嘗試又放棄的方案，請見各自 repo 的 README（尤其是 [`zh-cn-to-tw-backend`](https://github.com/beethoreven/zh-cn-to-tw-backend) 裡最完整的專案報告）。

### 子系統

| 子系統 | Repo | 部署/產出 |
|---|---|---|
| 後端 API | [`zh-cn-to-tw-backend`](https://github.com/beethoreven/zh-cn-to-tw-backend) | Render(`https://zh-cn-to-tw-backend.onrender.com`) |
| 前端網站 | [`zh-cn-to-tw-web`](https://github.com/beethoreven/zh-cn-to-tw-web) | `main` 分支被桌面版 App 內嵌（實際功能都在這裡）；GitHub Pages 服務的是另一個獨立的 `update-page` 分支，只有一個佔位頁，兩者沒有共同檔案 |
| macOS 桌面殼 | [`zh-cn-to-tw-mac`](https://github.com/beethoreven/zh-cn-to-tw-mac) | 本機打包成 `.app` |
| 本機 OCR 服務 | [`zh-cn-to-tw-ocr-service`](https://github.com/beethoreven/zh-cn-to-tw-ocr-service) | 本機打包成獨立執行檔，內嵌進 `zh-cn-to-tw-mac` |
| Windows 桌面殼 | [`zh-cn-to-tw-windows`](https://github.com/beethoreven/zh-cn-to-tw-windows) | 本機打包成 `.exe`（規劃中，見該 repo 的 README） |

五個子系統現在都是這個 meta-repo 的 git submodule。

### 使用方式

**第一次拿到全部程式碼：**

```bash
git clone --recurse-submodules https://github.com/beethoreven/zh-cn-to-tw.git
```

用 HTTPS，不要用 SSH host alias 那種寫法——`.gitmodules` 裡四個子模組的網址本來寫死成只有原本那台開發機才有設定的 SSH host alias，換一台機器 `git submodule update --init` 會直接解不到那個主機、四個子模組全部初始化失敗（實測撞過），已經改成一般的 HTTPS 網址，搭配 `gh auth login` 的 HTTPS 認證，任何機器都能直接用。

**已經 clone 過，只是要把子模組抓齊：**

```bash
git submodule update --init --recursive
```

**更新某個子模組到它自己 repo 的最新版本：**

```bash
cd zh-cn-to-tw-backend   # 或 zh-cn-to-tw-web / zh-cn-to-tw-mac / zh-cn-to-tw-ocr-service / zh-cn-to-tw-windows
git pull origin main
cd ..
git add zh-cn-to-tw-backend
git commit -m "Update zh-cn-to-tw-backend submodule pointer"
```

最後這個 `git add` + `commit` 不能省略——沒做的話，子模組本機檔案雖然是新的，但這個 wrapper repo 記錄的「該指向哪個 commit」還是舊的，別人 `clone` 這個 repo 還是會抓到舊版本。

---

## English

The project-overview repo for the *Script Murder Mystery Traditionalization Assistant*, wiring its subsystems together via git submodules so the whole codebase can be pulled with a single `clone`. This repo itself **is never deployed** — each subsystem connects to its own repo for deployment or local packaging (see the table below); this one is purely a unified local-dev entry point. For technical details, architecture decisions, and attempted-then-abandoned approaches, see each subsystem's own README (especially the fullest project report, in [`zh-cn-to-tw-backend`](https://github.com/beethoreven/zh-cn-to-tw-backend)).

### Subsystems

| Subsystem | Repo | Deployment/Output |
|---|---|---|
| Backend API | [`zh-cn-to-tw-backend`](https://github.com/beethoreven/zh-cn-to-tw-backend) | Render (`https://zh-cn-to-tw-backend.onrender.com`) |
| Frontend | [`zh-cn-to-tw-web`](https://github.com/beethoreven/zh-cn-to-tw-web) | Its `main` branch is embedded in the desktop app (that's where the real functionality lives); GitHub Pages serves a separate `update-page` branch holding only a placeholder, with no files in common |
| macOS desktop shell | [`zh-cn-to-tw-mac`](https://github.com/beethoreven/zh-cn-to-tw-mac) | Packaged locally into a `.app` |
| Local OCR service | [`zh-cn-to-tw-ocr-service`](https://github.com/beethoreven/zh-cn-to-tw-ocr-service) | Packaged locally into a standalone executable, embedded inside `zh-cn-to-tw-mac` |
| Windows desktop shell | [`zh-cn-to-tw-windows`](https://github.com/beethoreven/zh-cn-to-tw-windows) | Packaged locally into an `.exe` (in progress, see that repo's README) |

All five subsystems are now git submodules of this meta-repo.

### Usage

**First time cloning everything:**

```bash
git clone --recurse-submodules https://github.com/beethoreven/zh-cn-to-tw.git
```

Use HTTPS, not an SSH host alias — `.gitmodules` used to hard-code each submodule's URL to an SSH host alias that only existed on one particular dev machine's `~/.ssh/config`; on any other machine, `git submodule update --init` couldn't resolve that host at all and every submodule failed to initialize (hit this for real). Fixed to plain HTTPS URLs, paired with `gh auth login`'s HTTPS auth — works on any machine.

**Already cloned, just need to fetch the submodules:**

```bash
git submodule update --init --recursive
```

**Updating a submodule to its own repo's latest version:**

```bash
cd zh-cn-to-tw-backend   # or zh-cn-to-tw-web / zh-cn-to-tw-mac / zh-cn-to-tw-ocr-service / zh-cn-to-tw-windows
git pull origin main
cd ..
git add zh-cn-to-tw-backend
git commit -m "Update zh-cn-to-tw-backend submodule pointer"
```

That final `git add` + `commit` cannot be skipped — without it, the submodule's local files are up to date, but this wrapper repo's recorded "which commit to point at" is still stale, so anyone else who `clone`s this repo will still get the old version.
