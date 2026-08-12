# zh-cn-to-tw

## 中文

「劇本殺繁化助手」專案總覽 repo，透過 git submodule 把各子系統掛在一起，方便一次 `clone` 齊全部程式碼。這個 repo 本身**不會被部署**——各子系統各自連到自己的 repo 做部署或本機打包（見下表），這裡純粹是本機開發時的統一入口。各子系統的技術細節、架構決策、曾經嘗試又放棄的方案，請見各自 repo 的 README（尤其是 [`zh-cn-to-tw-backend`](https://github.com/beethoreven/zh-cn-to-tw-backend) 裡最完整的專案報告）。

### 子系統

| 子系統 | Repo | 部署/產出 |
|---|---|---|
| 後端 API | [`zh-cn-to-tw-backend`](https://github.com/beethoreven/zh-cn-to-tw-backend) | Render(`https://zh-cn-to-tw-backend.onrender.com`) |
| 前端網站 | [`zh-cn-to-tw-web`](https://github.com/beethoreven/zh-cn-to-tw-web) | GitHub Pages(從 repo 根目錄)，也被桌面版 App 內嵌 |
| macOS 桌面殼 | `zh-cn-to-tw-mac` | 本機打包成 `.app`（目前**尚未**推上 GitHub、也不是這個 repo 的 submodule，只在本機維護，見下方說明） |
| 本機 OCR 服務 | `zh-cn-to-tw-ocr-service` | 本機打包成獨立執行檔，內嵌進 `zh-cn-to-tw-mac`（同上，**尚未**推上 GitHub、不是 submodule） |

> `zh-cn-to-tw-mac`/`zh-cn-to-tw-ocr-service` 目前只存在於這台機器上，
> 沒有連接任何 GitHub remote，也還沒用 `git submodule add` 掛進這個
> meta-repo。要讓它們比照另外兩個子系統納入管理，需要先各自建立
> GitHub repo、推上去，再回到這裡跑 `git submodule add`。

未來若加入 Windows 版（`zh-cn-to-tw-windows`）等其他子系統，會用同樣
方式以 `git submodule add` 掛進來。

### 使用方式

**第一次拿到全部程式碼（backend + web，目前唯二真正的 submodule）：**

```bash
git clone --recurse-submodules git@github.com-beethoreven:beethoreven/zh-cn-to-tw.git
```

**已經 clone 過，只是要把子模組抓齊：**

```bash
git submodule update --init --recursive
```

**更新某個子模組到它自己 repo 的最新版本：**

```bash
cd zh-cn-to-tw-backend   # 或 zh-cn-to-tw-web
git pull origin main
cd ..
git add zh-cn-to-tw-backend
git commit -m "Update zh-cn-to-tw-backend submodule pointer"
```

最後這個 `git add` + `commit` 不能省略——沒做的話，子模組本機檔案雖然是新的，但這個 wrapper repo 記錄的「該指向哪個 commit」還是舊的，別人 `clone` 這個 repo 還是會抓到舊版本。

`zh-cn-to-tw-mac`/`zh-cn-to-tw-ocr-service` 因為還不是 submodule，就是
兩個普通的本機資料夾，各自用自己的 git repo 管理，跟這個 meta-repo
沒有連動關係。

---

## English

The project-overview repo for the *Script Murder Mystery Traditionalization Assistant*, wiring its subsystems together via git submodules so the whole codebase can be pulled with a single `clone`. This repo itself **is never deployed** — each subsystem connects to its own repo for deployment or local packaging (see the table below); this one is purely a unified local-dev entry point. For technical details, architecture decisions, and attempted-then-abandoned approaches, see each subsystem's own README (especially the fullest project report, in [`zh-cn-to-tw-backend`](https://github.com/beethoreven/zh-cn-to-tw-backend)).

### Subsystems

| Subsystem | Repo | Deployment/Output |
|---|---|---|
| Backend API | [`zh-cn-to-tw-backend`](https://github.com/beethoreven/zh-cn-to-tw-backend) | Render (`https://zh-cn-to-tw-backend.onrender.com`) |
| Frontend | [`zh-cn-to-tw-web`](https://github.com/beethoreven/zh-cn-to-tw-web) | GitHub Pages (served from repo root); also embedded in the desktop app |
| macOS desktop shell | `zh-cn-to-tw-mac` | Packaged locally into a `.app` (currently **not** pushed to GitHub or a submodule of this repo, local-only — see note below) |
| Local OCR service | `zh-cn-to-tw-ocr-service` | Packaged locally into a standalone executable, embedded inside `zh-cn-to-tw-mac` (same as above: **not** on GitHub, not a submodule) |

> `zh-cn-to-tw-mac`/`zh-cn-to-tw-ocr-service` currently exist only on
> this machine — no GitHub remote is connected, and neither has been
> wired in via `git submodule add`. Bringing them under the same
> management as the other two subsystems would require creating a
> GitHub repo for each, pushing, then running `git submodule add` here.

Future subsystems (a Windows version — `zh-cn-to-tw-windows` — and
others) will be wired in the same way via `git submodule add`.

### Usage

**First time cloning everything (backend + web, currently the only real submodules):**

```bash
git clone --recurse-submodules git@github.com-beethoreven:beethoreven/zh-cn-to-tw.git
```

**Already cloned, just need to fetch the submodules:**

```bash
git submodule update --init --recursive
```

**Updating a submodule to its own repo's latest version:**

```bash
cd zh-cn-to-tw-backend   # or zh-cn-to-tw-web
git pull origin main
cd ..
git add zh-cn-to-tw-backend
git commit -m "Update zh-cn-to-tw-backend submodule pointer"
```

That final `git add` + `commit` cannot be skipped — without it, the submodule's local files are up to date, but this wrapper repo's recorded "which commit to point at" is still stale, so anyone else who `clone`s this repo will still get the old version.

`zh-cn-to-tw-mac`/`zh-cn-to-tw-ocr-service`, not being submodules yet,
are just ordinary local folders, each managed by its own git repo with
no connection back to this meta-repo.
