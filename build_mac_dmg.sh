#!/bin/bash
# meta-repo 根目錄的進入點：清掉兩個 Mac Package 的 SwiftPM .build/
# 產物，再呼叫 zh-cn-to-tw-mac/packaging/build_dmg_all.sh 做真正的
# swift build -> 組裝 .app -> 封裝 DMG（兩包）。
#
# 這支以前是一個純符號連結，直接指到 build_dmg_all.sh——符號連結
# 沒有自己的邏輯，沒辦法在「呼叫真正的 build 腳本」之前多做「先清掉
# 舊產物」這件事，只能原封不動轉發執行。現在改成一支真正的 bash
# 腳本，自己做 clean、再用 bash 呼叫資料夾裡面那支腳本。
#
# 為什麼堅持每次都要 clean：這個 repo 已經實測撞過一次「build 腳本
# 沒有真的重新編譯，卻用舊產物包出檔案時間戳記全新的 DMG」的坑（見
# zh-cn-to-tw-mac README「打包成 .dmg」段落、known-issue-check skill）
# ——那次是腳本本身完全沒呼叫 swift build 造成的，不是 SwiftPM 增量
# 編譯本身不可靠，但這個進入點就是「打包出去給人測試/發布」用的，
# 不是日常開發時快速迭代用的（日常迭代直接呼叫 build_app_*.sh 或
# swift build 本身就好）——對這個用途來說，花幾秒鐘做一次乾淨的重新
# 編譯，換取「這個結果一定跟目前原始碼一致」的保證，這筆帳划算，
# 不需要冒任何「增量編譯這次剛好沒抓到某個改動」的風險。
set -euo pipefail

export LC_ALL=C

REPO_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
CONFIG="${1:-debug}"

echo "==> 清掉舊的 SwiftPM 產物（強制 clean build）"
rm -rf "$REPO_ROOT/zh-cn-to-tw-mac/.build"
rm -rf "$REPO_ROOT/zh-cn-to-tw-mac/Legacy/.build"

echo
bash "$REPO_ROOT/zh-cn-to-tw-mac/packaging/build_dmg_all.sh" "$CONFIG"
