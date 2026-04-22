@echo off
chcp 65001 >nul 2>&1

REM --- タイムスタンプ取得 ---
for /f "usebackq" %%I in (`powershell -NoProfile -Command "Get-Date -Format 'yyyyMMdd'"`) do set DATESTAMP=%%I

REM --- バックアップ先 ---
set BACKUP_ROOT=C:\backup
set BACKUP_DIR=%BACKUP_ROOT%\backup_%DATESTAMP%
set LOG_FILE=%BACKUP_DIR%\backup.log

if "%~1"=="--log" goto :main
mkdir "%BACKUP_DIR%" 2>nul
call "%~f0" --log 2>&1 | powershell -NoProfile -Command "$enc=[System.Text.UTF8Encoding]::new($false); $input | ForEach-Object { Write-Host $_; [System.IO.File]::AppendAllText('%LOG_FILE%', $_ + [Environment]::NewLine, $enc) }"
exit /b

:main
powershell -NoProfile -Command "$enc=[System.Text.UTF8Encoding]::new($false); [System.IO.File]::AppendAllText('%LOG_FILE%', '=== 実行開始: ' + (Get-Date -Format 'yyyy/MM/dd HH:mm:ss') + ' ===' + [Environment]::NewLine, $enc)"
for /f "usebackq delims=" %%S in (`powershell -NoProfile -Command "(Get-Date).Ticks"`) do set START_TICKS=%%S
echo ============================================
echo   onomachi バックアップスクリプト
echo   出力先: %BACKUP_DIR%
echo ============================================
echo.

REM --- フォルダ作成 ---
mkdir "%BACKUP_DIR%\db"       2>nul
mkdir "%BACKUP_DIR%\wordpress" 2>nul
mkdir "%BACKUP_DIR%\redmine"   2>nul

if not exist "%BACKUP_DIR%\db\" (
    echo [エラー] バックアップ先フォルダを作成できませんでした。
    echo         C:\backup フォルダが存在するか確認するか、先に手動で作成してください。
    echo         例: mkdir C:\backup
    echo.
    pause
    exit /b 1
)

REM --- 7日より古いバックアップフォルダを削除 (フォルダ名の日付で判断) ---
echo 古いバックアップを削除しています (7日以上前)...
powershell -NoProfile -Command "$today = (Get-Date).Date; Get-ChildItem -Path '%BACKUP_ROOT%' -Directory | Where-Object { $_.Name -match '^backup_(\d{8})$' -and ($today - [datetime]::ParseExact($matches[1], 'yyyyMMdd', $null)).Days -ge 7 } | ForEach-Object { Remove-Item $_.FullName -Recurse -Force; Write-Host ('  削除: ' + $_.Name) }"
echo   完了
echo.

REM --- DB コンテナが起動しているか確認 ---
wsl -d Ubuntu -- bash -c "docker ps --filter name=onomachi-it-media-db --filter status=running --format '{{.Names}}' 2>/dev/null" | findstr /C:"onomachi-it-media-db" >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [エラー] DB コンテナ ^(onomachi-it-media-db^) が起動していません。
    echo         先に start-containers.bat を実行してください。
    echo.
    pause
    exit /b 1
)
echo DB コンテナ: 起動確認OK
echo.

REM --- [1/4] WordPress DB ダンプ ---
echo [1/4] WordPress DB をダンプ中...
wsl -d Ubuntu -- bash -c "PASS=\$(grep '^MYSQL_ROOT_PASSWORD=' ~/docker-dev/onomachi/.env | tr -d '\r' | cut -d= -f2-); WPDB=\$(grep '^DB_NAME_WP=' ~/docker-dev/onomachi/.env | tr -d '\r' | cut -d= -f2-); docker exec onomachi-it-media-db mysqldump -uroot -p\"\$PASS\" \"\$WPDB\"" > "%BACKUP_DIR%\db\wordpress.sql"
if %ERRORLEVEL% neq 0 (
    echo [エラー] WordPress DB のダンプに失敗しました。
    pause
    exit /b 1
)
echo   完了 -^> %BACKUP_DIR%\db\wordpress.sql
echo.

REM --- [2/4] Redmine DB ダンプ ---
echo [2/4] Redmine DB をダンプ中...
wsl -d Ubuntu -- bash -c "PASS=\$(grep '^MYSQL_ROOT_PASSWORD=' ~/docker-dev/onomachi/.env | tr -d '\r' | cut -d= -f2-); docker exec onomachi-it-media-db mysqldump -uroot -p\"\$PASS\" redmine" > "%BACKUP_DIR%\db\redmine.sql"
if %ERRORLEVEL% neq 0 (
    echo [エラー] Redmine DB のダンプに失敗しました。
    pause
    exit /b 1
)
echo   完了 -^> %BACKUP_DIR%\db\redmine.sql
echo.

REM --- [3/4] WordPress ファイルバックアップ ---
echo [3/4] WordPress ファイルをコピー中...
robocopy "\\wsl.localhost\Ubuntu\home\sango\docker-dev\onomachi\wordpress\onomachi-it-media\html" "%BACKUP_DIR%\wordpress\html" /E /NFL /NDL /NJH /NJS /NC /NS /NP
if %ERRORLEVEL% geq 8 (
    echo [エラー] WordPress ファイルのコピーに失敗しました。
    pause
    exit /b 1
)
echo   完了 -^> %BACKUP_DIR%\wordpress\html
echo.

REM --- [4/4] Redmine ファイルバックアップ ---
echo [4/4] Redmine ファイルをコピー中...
robocopy "\\wsl.localhost\Ubuntu\home\sango\docker-dev\onomachi\redmine\data" "%BACKUP_DIR%\redmine\data" /E /NFL /NDL /NJH /NJS /NC /NS /NP
if %ERRORLEVEL% geq 8 (
    echo [エラー] Redmine data のコピーに失敗しました。
    pause
    exit /b 1
)
robocopy "\\wsl.localhost\Ubuntu\home\sango\docker-dev\onomachi\redmine\plugins" "%BACKUP_DIR%\redmine\plugins" /E /NFL /NDL /NJH /NJS /NC /NS /NP
if %ERRORLEVEL% geq 8 (
    echo [エラー] Redmine plugins のコピーに失敗しました。
    pause
    exit /b 1
)
echo   完了 -^> %BACKUP_DIR%\redmine
echo.

echo ============================================
echo   バックアップ完了！
echo --------------------------------------------
echo   保存先: %BACKUP_DIR%
echo   ログ:   %LOG_FILE%
echo.
echo   db\wordpress.sql  ... WordPress DB
echo   db\redmine.sql    ... Redmine DB
echo   wordpress\html\   ... WordPress ファイル
echo   redmine\data\     ... Redmine 添付ファイル
echo   redmine\plugins\  ... Redmine プラグイン
echo ============================================
echo.
for /f "usebackq delims=" %%T in (`powershell -NoProfile -Command "Get-Date -Format 'yyyy/MM/dd HH:mm:ss'"`) do echo === 実行終了: %%T [正常終了] ===
for /f "usebackq delims=" %%E in (`powershell -NoProfile -Command "[math]::Round(((Get-Date).Ticks - %START_TICKS%) / 10000000)"`) do echo     所要時間: %%E 秒
echo.
rem pause
