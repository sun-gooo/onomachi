@echo off
chcp 65001 >nul 2>&1

REM --- 管理者権限チェック ---
net session >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo 管理者権限で再起動しています...
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs -Wait"
    exit /b
)

call :main
echo.
pause
exit /b

:main
echo ============================================
echo   onomachi コンテナ起動スクリプト
echo ============================================
echo.

REM --- WSL ディストリビューションが利用可能になるまで待機 ---
echo WSL の起動を待機しています...
:wait_wsl
wsl -d Ubuntu -- echo ready >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo   WSL がまだ利用できません。10秒後にリトライします...
    timeout /t 10 /nobreak >nul
    goto wait_wsl
)
echo WSL: 準備完了
echo.

REM --- WSL 上の Docker Engine が応答するまで待機 ---
echo Docker Engine の起動を待機しています...
:wait_docker
wsl -d Ubuntu -- bash -c "docker info > /dev/null 2>&1"
if %ERRORLEVEL% neq 0 (
    echo   まだ起動していません。10秒後にリトライします...
    timeout /t 10 /nobreak >nul
    goto wait_docker
)
echo Docker Engine: 準備完了
echo.

REM --- Windows ファイアウォール: ポート 80 を許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
可 ---
REM --- (nat モード: portproxy 経由でポート 80 をフォワード) ---
netsh advfirewall firewall delete rule name="WSL2 Gateway Port 80" >nul 2>&1
netsh advfirewall firewall add rule name="WSL2 Gateway Port 80" dir=in action=allow protocol=TCP localport=80 >nul 2>&1
REM --- 古い portproxy 設定が残っていれば削除 (docker compose up の前に実行する必要がある) ---
netsh interface portproxy delete v4tov4 listenport=80 listenaddress=0.0.0.0 >nul 2>&1
echo.

REM --- コンテナ起動 ---
echo コンテナを起動しています...
wsl -d Ubuntu -- bash -c "cd ~/docker-dev/onomachi && docker compose down && docker compose up -d --build"
if %ERRORLEVEL% neq 0 (
    echo.
    echo [エラー] docker compose up に失敗しました。
    exit /b 1
)
echo.

REM --- portproxy 設定: Windows localhost:80 → WSL:80 (nat モード用) ---
wsl -d Ubuntu -- ip -4 addr show eth0 > "%TEMP%\wsl_ip.txt"
for /f "tokens=2 delims=/ " %%i in ('findstr "inet" "%TEMP%\wsl_ip.txt"') do set WSL_IP=%%i
del "%TEMP%\wsl_ip.txt" >nul 2>&1
if "%WSL_IP%"=="" (
    echo [エラー] WSL の IP アドレスを取得できませんでした。
    exit /b 1
)
echo WSL IP: %WSL_IP%
netsh interface portproxy add v4tov4 listenaddress=0.0.0.0 listenport=80 connectaddress=%WSL_IP% connectport=80 >nul 2>&1
echo portproxy: 設定完了 ^(Windows:80 ^-^> %WSL_IP%:80^)
echo.

REM --- Windows hosts ファイルに PC_NAME のエントリを追加 ---
for /f "usebackq tokens=1* delims==" %%a in (`findstr /B "PC_NAME=" "%~dp0.env"`) do set _PC_VAL=%%b
for /f "tokens=1" %%a in ("%_PC_VAL%") do set PC_NAME_HOSTS=%%a
if not "%PC_NAME_HOSTS%"=="" (
    findstr /C:"127.0.0.1 %PC_NAME_HOSTS%" "C:\Windows\System32\drivers\etc\hosts" >nul 2>&1
    if %ERRORLEVEL% neq 0 (
        echo 127.0.0.1 %PC_NAME_HOSTS% >> "C:\Windows\System32\drivers\etc\hosts"
        echo hosts: 127.0.0.1 %PC_NAME_HOSTS% を追加しました
    ) else (
        echo hosts: %PC_NAME_HOSTS% は既に登録済みです
    )
)
echo.

REM --- 各サービスが実際に応答するまで待機 ---
echo.
echo 各サービスの起動完了を待機しています...
echo   (Redmine は初回起動に 1〜2 分かかる場合があります)
echo.

REM --- Redmine ---
echo [1/3] Redmine の起動を待機中...
set RETRY=0
:wait_redmine
set /a RETRY+=1
if %RETRY% gtr 40 (
    echo   [警告] Redmine の起動がタイムアウトしました。手動で確認してください。
    goto check_wp
)
wsl -d Ubuntu -- bash -c "curl -s --connect-timeout 5 --max-time 10 -o /dev/null -w '%%{http_code}' http://localhost/redmine 2>/dev/null | grep -q '200\|301\|302'"
if %ERRORLEVEL% neq 0 (
    echo   待機中... [%RETRY%/40] 5秒後にリトライ
    timeout /t 5 /nobreak >nul
    goto wait_redmine
)
echo   Redmine: 準備完了
echo.

REM --- WordPress ---
:check_wp
echo [2/3] WordPress の起動を待機中...
set RETRY=0
:wait_wp
set /a RETRY+=1
if %RETRY% gtr 20 (
    echo   [警告] WordPress の起動がタイムアウトしました。手動で確認してください。
    goto check_pma
)
wsl -d Ubuntu -- bash -c "curl -s --connect-timeout 5 --max-time 10 -o /dev/null -w '%%{http_code}' http://localhost/onomachi-it-media/ 2>/dev/null | grep -q '200\|301\|302'"
if %ERRORLEVEL% neq 0 (
    echo   待機中... [%RETRY%/20] 5秒後にリトライ
    timeout /t 5 /nobreak >nul
    goto wait_wp
)
echo   WordPress: 準備完了
echo.

REM --- phpMyAdmin ---
:check_pma
echo [3/3] phpMyAdmin の起動を待機中...
set RETRY=0
:wait_pma
set /a RETRY+=1
if %RETRY% gtr 20 (
    echo   [警告] phpMyAdmin の起動がタイムアウトしました。手動で確認してください。
    goto done
)
wsl -d Ubuntu -- bash -c "curl -s --connect-timeout 5 --max-time 10 -o /dev/null -w '%%{http_code}' http://localhost/phpmyadmin/ 2>/dev/null | grep -q '200\|301\|302'"
if %ERRORLEVEL% neq 0 (
    echo   待機中... [%RETRY%/20] 5秒後にリトライ
    timeout /t 5 /nobreak >nul
    goto wait_pma
)
echo   phpMyAdmin: 準備完了
echo.

REM --- Windows 側から実際にアクセスできるか確認 ---
echo [4/4] Windows 側からの接続を確認中...
echo   (WSL2 の localhost フォワーディングが有効になるまで待機)
set RETRY=0
:wait_windows
set /a RETRY+=1
if %RETRY% gtr 30 (
    echo   [警告] Windows 側からの接続がタイムアウトしました。
    echo   タスクスケジューラの設定を確認してください:
    echo     - トリガー: 「ログオン時」に設定
    echo     - 「ユーザーがログオンしているときのみ実行する」を選択
    goto done
)
powershell -Command "try { $req = [System.Net.WebRequest]::Create('http://127.0.0.1/redmine'); $req.Proxy = [System.Net.GlobalProxySelection]::GetEmptyWebProxy(); $req.Timeout = 5000; $resp = $req.GetResponse(); $ok = [int]$resp.StatusCode -ge 200 -and [int]$resp.StatusCode -lt 400; $resp.Close(); if ($ok) { exit 0 } else { exit 1 } } catch [System.Net.WebException] { if ($_.Exception.Response -ne $null -and [int]$_.Exception.Response.StatusCode -ge 200 -and [int]$_.Exception.Response.StatusCode -lt 400) { exit 0 } else { exit 1 } } catch { exit 1 }" >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo   待機中... [%RETRY%/30] 5秒後にリトライ
    timeout /t 5 /nobreak >nul
    goto wait_windows
)
echo   Windows -^> localhost: 接続確認OK
echo.

:done
echo ============================================
echo   起動完了！
echo --------------------------------------------
if not "%PC_NAME_HOSTS%"=="" (
    echo   WordPress : http://%PC_NAME_HOSTS%/onomachi-it-media/
    echo   Redmine   : http://%PC_NAME_HOSTS%/redmine
    echo   phpMyAdmin: http://%PC_NAME_HOSTS%/phpmyadmin/
) else (
    echo   WordPress : http://localhost/onomachi-it-media/
    echo   Redmine   : http://localhost/redmine
    echo   phpMyAdmin: http://localhost/phpmyadmin/
)
echo ============================================

:: --- 追加: WSLのセッションを維持するための処理 ---
echo WSLの常駐を維持しています...
wsl -d Ubuntu -- bash -c "while true; do sleep 60; done"

goto :eof
