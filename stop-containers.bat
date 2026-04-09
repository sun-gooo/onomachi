@echo off
setlocal

:: --- 設定項目 (起動バッチと合わせる) ---
set DISTRO=Ubuntu
set TARGET_DIR=/home/sango/docker-dev/onomachi
:: ----------------

echo WSL2内の開発環境 (onomachi) を停止中...

:: docker compose down を実行してコンテナを停止・削除します
wsl -d %DISTRO% --cd %TARGET_DIR% docker compose down

if %errorlevel% neq 0 (
    echo [ERROR] 停止処理中にエラーが発生しました。
    pause
    exit /b
)

echo.
echo すべてのサービスを正常に停止しました。
echo.

wsl --shutdown

pause