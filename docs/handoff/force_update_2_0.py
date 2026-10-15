"""把 Mac 11+、Mac 10.15、Windows 三個分流的強制更新門檻都設成 2.0。

用法（在 zh-cn-to-tw-backend 目錄、啟用 venv 之後）：
    python ../docs/handoff/force_update_2_0.py            # 只顯示目前資料，不寫入
    python ../docs/handoff/force_update_2_0.py --apply    # 寫入 latest=min=2.0

Windows 殼回報 os=macos、os_version=windows（見 web 的 js/core/version.js），
所以資料列是 ('macos', 'windows')。這一列在 2.0 之前不存在，所以用 UPSERT。
"""
import os
import sys

# 腳本放在 docs/ 底下，sys.path[0] 是腳本所在目錄，找不到 backend 的
# db_utils；把目前工作目錄（zh-cn-to-tw-backend）加進去。
sys.path.insert(0, os.getcwd())

from db_utils.connection import get_ready_conn, sql

TIERS = ["11+", "10.15", "windows"]
MAJOR, MINOR = 2, 0

conn, cur = get_ready_conn()


def show(title):
    print(title)
    cur.execute("SELECT * FROM app_versions ORDER BY os, os_version")
    for row in cur.fetchall():
        print("  ", row)


show("目前：")
if "--apply" in sys.argv:
    for tier in TIERS:
        cur.execute(
            sql(
                "INSERT INTO app_versions (os, os_version, latest_major, latest_minor, min_major, min_minor) "
                "VALUES ('macos', ?, ?, ?, ?, ?) "
                "ON CONFLICT (os, os_version) DO UPDATE SET "
                "latest_major=EXCLUDED.latest_major, latest_minor=EXCLUDED.latest_minor, "
                "min_major=EXCLUDED.min_major, min_minor=EXCLUDED.min_minor"
            ),
            (tier, MAJOR, MINOR, MAJOR, MINOR),
        )
    conn.commit()
    show("更新後：")
conn.close()
