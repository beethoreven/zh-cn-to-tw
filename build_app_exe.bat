@echo off
rem Entry point at the meta-repo root: cleans zh-cn-to-tw-windows's bin/obj,
rem then calls zh-cn-to-tw-windows\packaging\build_installer.bat, which does
rem the real work (dotnet publish -> copy web/ocr-service -> Inno Setup).
rem
rem Why always clean first: same reasoning as zh-cn-to-tw-mac's
rem build_mac_dmg.sh (see known-issue-check item 21) -- this entry point is
rem for "package it up to test/ship," not day-to-day iteration (for that,
rem just run "dotnet run" directly inside src\ZhCnToTw). For this use case,
rem paying the cost of a genuinely clean rebuild is worth the guarantee that
rem the result actually matches the current source.
rem
rem Note: this file is intentionally plain ASCII (no Chinese comments) --
rem Windows batch files handle non-ASCII source encoding unreliably (BOM
rem handling in cmd.exe's parser is inconsistent across locales/codepages,
rem confirmed by hitting it directly while writing this script), unlike the
rem rest of this project's source files.

setlocal
set "REPO_ROOT=%~dp0"

echo ==^> Cleaning old bin/obj (forcing a clean build)
if exist "%REPO_ROOT%zh-cn-to-tw-windows\src\ZhCnToTw\bin" rmdir /s /q "%REPO_ROOT%zh-cn-to-tw-windows\src\ZhCnToTw\bin"
if exist "%REPO_ROOT%zh-cn-to-tw-windows\src\ZhCnToTw\obj" rmdir /s /q "%REPO_ROOT%zh-cn-to-tw-windows\src\ZhCnToTw\obj"

echo.
call "%REPO_ROOT%zh-cn-to-tw-windows\packaging\build_installer.bat"
