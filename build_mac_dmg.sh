#!/bin/bash
# meta-repo 根目錄的進入點：把「發布給人用的 Mac DMG」需要的所有東西，
# 從頭乾淨重建一次——包含內嵌的 zh-cn-to-tw-ocr-service 執行檔（PyInstaller
# 打包）跟兩個 Mac Package 的 SwiftPM 產物——再呼叫
# zh-cn-to-tw-mac/packaging/build_dmg_all.sh 做 swift build -> 組裝 .app ->
# 封裝 DMG（兩包）。
#
# 這支以前是一個純符號連結，直接指到 build_dmg_all.sh——符號連結
# 沒有自己的邏輯，沒辦法在「呼叫真正的 build 腳本」之前多做「先清掉
# 舊產物」這件事，只能原封不動轉發執行。現在改成一支真正的 bash
# 腳本，自己做 clean、再用 bash 呼叫資料夾裡面那支腳本。
#
# 為什麼堅持每次都要 clean：這個 repo 已經實測撞過兩次「build 出來的
# 檔案時間戳記全新、內容卻是舊的」的坑（見 known-issue-check skill 第
# 21 條、zh-cn-to-tw-mac README「打包成 .dmg」段落）：
#
# 1. 第一次是 build_dmg_all.sh 根本沒呼叫 swift build，直接拿舊的 .app
#    重新封 DMG。已修。
# 2. 第二次（2026-08-22）是這支腳本自己：它 clean 的範圍只有 SwiftPM 的
#    .build/，完全沒碰 zh-cn-to-tw-ocr-service 的 dist/。11+ 那包 DMG
#    內嵌的是那份 PyInstaller 產出、不是原始碼，所以 ocr-service 明明
#    已經有新 commit（其中一個正是「修正偵測門檻太高導致整行文字消失」），
#    打包進去的還是五天前的舊執行檔，而且前端新加的 OCR 門檻參數會被
#    舊執行檔靜靜忽略，沒有任何錯誤。
#
# 第 2 點的教訓是：「clean build」的範圍必須涵蓋**所有會被包進產物的
# 東西**，不是只有本 repo 自己編譯的部分。任何以「已經建好的產物」形式
# 被內嵌的相依（PyInstaller 產出、預編譯的 framework、下載回來的模型檔）
# 都要嘛在這裡一起重建，要嘛明確驗證它跟目前原始碼一致——不能因為
# 「它不是我編的」就預設它是新的。
#
# 重建完 ocr-service 之後還會實際把它跑起來、打一次 /health 才算過：
# 這次踩到的另一個問題正是 PyInstaller 回報 "Build complete!"、產物卻
# 在 import 階段就 TypeError 直接崩潰（新程式碼用了 PEP 604 的
# `float | None`，打包環境是 Python 3.9）。「build 沒報錯」完全不能
# 證明產物能跑，只有真的啟動起來才算數。
set -euo pipefail

export LC_ALL=C

REPO_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
CONFIG="${1:-debug}"

OCR_SERVICE_REPO="$REPO_ROOT/zh-cn-to-tw-ocr-service"
OCR_SERVICE_BIN="$OCR_SERVICE_REPO/dist/zh-cn-to-tw-ocr-service/zh-cn-to-tw-ocr-service"

# ---------------------------------------------------------------------------
# 1. 重建內嵌的 OCR 服務執行檔（只有 11+ 那包會用到；10.15 那包走 Apple
#    Vision framework，完全不內嵌這個東西，見 build_app_10_15.sh）
# ---------------------------------------------------------------------------
echo "==> [1/3] 重新打包 zh-cn-to-tw-ocr-service（PyInstaller）"

if [ ! -d "$OCR_SERVICE_REPO" ]; then
  echo "    找不到 $OCR_SERVICE_REPO"
  echo "    這支腳本是發布用的進入點，11+ 那包一定要內嵌 OCR 服務，不能跳過。"
  echo "    請先 git submodule update --init 把這個 repo 拉下來。"
  exit 1
fi

if [ ! -x "$OCR_SERVICE_REPO/venv/bin/pyinstaller" ]; then
  echo "    找不到 $OCR_SERVICE_REPO/venv/bin/pyinstaller"
  echo "    請照 zh-cn-to-tw-ocr-service README「打包成獨立執行檔」章節先建好那個 repo 自己的 venv。"
  echo "    （刻意不自動幫忙建：打包環境的 Python 版本會直接影響產物能不能跑，"
  echo "      這件事應該由維護者明確決定，不是腳本偷偷替你決定。）"
  exit 1
fi

# build/ 是 PyInstaller 的中繼快取，dist/ 是產物，兩個都清掉才是真的
# 從頭重建——只清 dist/ 的話 PyInstaller 會拿 build/ 裡的快取回填。
rm -rf "$OCR_SERVICE_REPO/build" "$OCR_SERVICE_REPO/dist"
(
  cd "$OCR_SERVICE_REPO"
  ./venv/bin/pyinstaller packaging/ocr_service.spec --noconfirm
)

if [ ! -x "$OCR_SERVICE_BIN" ]; then
  echo "    PyInstaller 跑完了，但找不到預期的執行檔：$OCR_SERVICE_BIN"
  exit 1
fi

# ---------------------------------------------------------------------------
# 2. 冒煙測試：真的把它跑起來，確認不是「build 成功但一啟動就掛」
# ---------------------------------------------------------------------------
echo
echo "==> [2/3] 冒煙測試：啟動剛打包好的 OCR 服務，確認它真的跑得起來"

SMOKE_LOG="$(mktemp -t ocr-smoke)"
"$OCR_SERVICE_BIN" > "$SMOKE_LOG" 2>&1 &
SMOKE_PID=$!

# 不管後面成功失敗、或使用者中途 Ctrl-C，都要把這個測試用的 process 收掉，
# 不要留一個佔著 port 的孤兒在背景。
cleanup_smoke() {
  if kill -0 "$SMOKE_PID" 2>/dev/null; then
    kill "$SMOKE_PID" 2>/dev/null || true
    wait "$SMOKE_PID" 2>/dev/null || true
  fi
  rm -f "$SMOKE_LOG"
}
trap cleanup_smoke EXIT INT TERM

# 模型載入需要時間，最多等 60 秒；每秒檢查一次 process 還在不在（提早
# 崩潰就不用再等下去了）跟有沒有印出 port。
SMOKE_PORT=""
for _ in $(seq 1 60); do
  if ! kill -0 "$SMOKE_PID" 2>/dev/null; then
    echo "    OCR 服務啟動後隨即結束，這份打包產物是壞的。輸出："
    sed 's/^/      /' "$SMOKE_LOG"
    exit 1
  fi
  SMOKE_PORT="$(sed -n 's/^OCR_SERVICE_PORT=\([0-9][0-9]*\).*/\1/p' "$SMOKE_LOG" | head -1)"
  [ -n "$SMOKE_PORT" ] && break
  sleep 1
done

if [ -z "$SMOKE_PORT" ]; then
  echo "    等了 60 秒仍沒看到 OCR_SERVICE_PORT，判定啟動失敗。輸出："
  sed 's/^/      /' "$SMOKE_LOG"
  exit 1
fi

if ! curl -sf "http://127.0.0.1:$SMOKE_PORT/health" > /dev/null; then
  echo "    服務有起來（port $SMOKE_PORT）但 /health 沒有正常回應，判定這份產物有問題。輸出："
  sed 's/^/      /' "$SMOKE_LOG"
  exit 1
fi

echo "    OK：服務在 port $SMOKE_PORT 正常啟動，/health 回應正常"
cleanup_smoke
trap - EXIT INT TERM

# ---------------------------------------------------------------------------
# 3. 清掉 SwiftPM 產物，交給 mac repo 自己的腳本做 build + 封裝
# ---------------------------------------------------------------------------
echo
echo "==> [3/3] 清掉舊的 SwiftPM 產物，開始 build 兩包 DMG"
rm -rf "$REPO_ROOT/zh-cn-to-tw-mac/.build"
rm -rf "$REPO_ROOT/zh-cn-to-tw-mac/Legacy/.build"

echo
bash "$REPO_ROOT/zh-cn-to-tw-mac/packaging/build_dmg_all.sh" "$CONFIG"
