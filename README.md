```
https://www.servicenow.com/docs/ja-JP/bundle/zurich-api-reference/page/integrate/inbound-rest/concept/c_IdentifyReconcileAPI.html
```

```
# 各日のデータを格納する配列
$dailyData = @{}  # キー: 日(1-31), 値: @{Hours, Minutes}

# CSVデータを格納する配列（CSV出力用）
$workTimeData = @()

                                if ($workHours -gt 0) {

                                    # Excelデータ用に時間と分を分けて保存
                                    $dailyData[$day] = @{
                                        Hours = $hours
                                        Minutes = $minutes
                                    }

# Excelファイルを作成
Write-Host "`nExcelファイルを作成中..."

$outputFileNameExcel = "WorkTime_${Year}_$(${Month}.ToString('00')).xlsx"
$outputPathExcel = Join-Path $outputFolder $outputFileNameExcel

try {
    # Excelアプリケーションを作成
    $excel = New-Object -ComObject Excel.Application
    $excel.Visible = $false
    $excel.DisplayAlerts = $false
    
    # 新しいワークブックを作成
    $workbook = $excel.Workbooks.Add()
    $worksheet = $workbook.Worksheets.Item(1)
    $worksheet.Name = "${Year}年${Month}月"
    
    # ヘッダー行を作成（1行目）
    $worksheet.Cells.Item(1, 1) = "年月"
    $worksheet.Cells.Item(1, 2) = "作業者氏名"
    
    # 日付の列ヘッダー（1～31）
    for ($day = 1; $day -le 31; $day++) {
        $worksheet.Cells.Item(1, $day + 2) = $day
    }
    
    # 2行目：作業者名と時間
    $worksheet.Cells.Item(2, 1) = $WorkerName
    $worksheet.Cells.Item(2, 2) = "時間"
    
    # 3行目：分
    $worksheet.Cells.Item(3, 2) = "分"
    
    # 各日のデータを入力
    for ($day = 1; $day -le $daysInMonth; $day++) {
        $col = $day + 2
        
        if ($dailyData[$day].Hours -ne "") {
            # 時間の行（2行目）
            $worksheet.Cells.Item(2, $col) = $dailyData[$day].Hours
            # 分の行（3行目）
            $worksheet.Cells.Item(3, $col) = $dailyData[$day].Minutes
        }
    }
    
    # 書式設定
    # ヘッダー行の書式
    $headerRange = $worksheet.Range($worksheet.Cells.Item(1, 1), $worksheet.Cells.Item(1, 33))
    $headerRange.Font.Bold = $true
    $headerRange.Interior.ColorIndex = 15  # 薄い灰色
    $headerRange.HorizontalAlignment = -4108  # xlCenter
    
    # 「作業者氏名」「時間」「分」列の書式
    $labelRange = $worksheet.Range($worksheet.Cells.Item(1, 2), $worksheet.Cells.Item(3, 2))
    $labelRange.Font.Bold = $true
    $labelRange.Interior.ColorIndex = 15
    $labelRange.HorizontalAlignment = -4108
    
    # 年月セルの書式
    $worksheet.Cells.Item(1, 1).Font.Bold = $true
    $worksheet.Cells.Item(1, 1).Interior.ColorIndex = 15
    $worksheet.Cells.Item(1, 1).HorizontalAlignment = -4108
    
    # 作業者名セルの書式
    $worksheet.Cells.Item(2, 1).Font.Bold = $true
    $worksheet.Cells.Item(2, 1).Interior.ColorIndex = 15
    $worksheet.Cells.Item(2, 1).HorizontalAlignment = -4108
    
    # 全体の罫線
    $dataRange = $worksheet.Range($worksheet.Cells.Item(1, 1), $worksheet.Cells.Item(3, 33))
    $dataRange.Borders.LineStyle = 1  # xlContinuous
    
    # 列幅の自動調整
    $worksheet.Columns.AutoFit() | Out-Null
    
    # ファイルを保存
    $workbook.SaveAs($outputPathExcel)
    $workbook.Close()
    $excel.Quit()
    
    # COMオブジェクトを解放
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($worksheet) | Out-Null
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($workbook) | Out-Null
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel) | Out-Null
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
    
    Write-Host "✓ Excelファイルを作成しました" -ForegroundColor Green
    Write-Host "保存先: $outputPathExcel"
    Write-Log "Excelファイル作成成功: $outputPathExcel"
    
} catch {
    Write-Log "エラー: Excelファイルの作成に失敗しました - $($_.Exception.Message)"
    Write-Host "✗ Excelファイルの作成に失敗しました: $($_.Exception.Message)" -ForegroundColor Red
}


    Start-Process $outputPathExcel
    Write-Host "✓ Excelファイルを開きました"
```



```
# 月度工作時間収集スクリプト
# Monthly Work Time Collection Script

param(
    [Parameter(Mandatory=$false)]
    [int]$Year = (Get-Date).Year,
    
    [Parameter(Mandatory=$false)]
    [int]$Month = (Get-Date).Month
)

# 設定
$logFile = "$env:USERPROFILE\monthly_worktime_log.txt"
$outputFolder = "$env:USERPROFILE\Documents\WorkTimeReports"

# ログ記録関数
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp - $Message"
    Add-Content -Path $logFile -Value $logMessage
    Write-Host $logMessage
}

# 出力フォルダーを作成
if (-not (Test-Path $outputFolder)) {
    New-Item -Path $outputFolder -ItemType Directory -Force | Out-Null
    Write-Log "出力フォルダーを作成しました: $outputFolder"
}

# 開始メッセージ
Write-Host "=========================================="
Write-Host "月度工作時間収集スクリプト"
Write-Host "対象月: $Year年$Month月"
Write-Host "=========================================="
Write-Log "スクリプト開始: $Year年$Month月"

# Outlookに接続
try {
    Write-Host "`nOutlookに接続中..."
    $outlook = New-Object -ComObject Outlook.Application
    $namespace = $outlook.GetNamespace("MAPI")
    $sentFolder = $namespace.GetDefaultFolder(5)  # 5 = olFolderSentMail
    Write-Log "Outlookに接続しました"
    Write-Host "✓ Outlook接続成功"
} catch {
    Write-Log "エラー: Outlookに接続できませんでした - $($_.Exception.Message)"
    Write-Host "✗ Outlookに接続できませんでした"
    exit
}

# 対象月の日数を取得
$firstDay = Get-Date -Year $Year -Month $Month -Day 1
$lastDay = $firstDay.AddMonths(1).AddDays(-1)
$daysInMonth = $lastDay.Day

Write-Host "`n対象期間: $($firstDay.ToString('yyyy/MM/dd')) ～ $($lastDay.ToString('yyyy/MM/dd'))"
Write-Host "日数: $daysInMonth 日"

# CSVデータを格納する配列
$workTimeData = @()

# ヘッダー行を追加
$workTimeData += "Date,StartTime,EndTime,DayTotalWorkTime"

# 各日付を処理
Write-Host "`n作業時間を収集中..."
Write-Host "----------------------------------------"

for ($day = 1; $day -le $daysInMonth; $day++) {
    $currentDate = Get-Date -Year $Year -Month $Month -Day $day
    $dateString = $currentDate.ToString("yyyy/MM/dd")
    $dateForSearch = $currentDate.ToString("MM/dd")  # 例: 11/06
    
    Write-Host "処理中: $dateString" -NoNewline
    
    # 初期値
    $startTime = ""
    $endTime = ""
    $totalWorkTime = ""
    $found = $false
    
    try {
        # 送信済みアイテムを検索
        $items = $sentFolder.Items
        $items.Sort("[SentOn]", $true)  # 送信日時でソート
        
        foreach ($item in $items) {
            if ($item.Class -eq 43) {  # 43 = olMail
                $subject = $item.Subject
                $sentDate = $item.SentOn
                
                # 件名に「業務終了報告」が含まれ、かつ日付が一致するかチェック
                if ($subject -match "業務終了報告" -and $subject -match [regex]::Escape($dateForSearch)) {
                    
                    # メール本文から実績時間を抽出
                    $body = $item.Body
                    
                    # 正規表現で「実績: HH:MM~HH:MM」のパターンを検索
                    if ($body -match "実績[：:\s]*(\d{1,2}):(\d{2})\s*[～~〜]\s*(\d{1,2}):(\d{2})") {
                        $startHour = $matches[1].PadLeft(2, '0')
                        $startMinute = $matches[2]
                        $endHour = $matches[3].PadLeft(2, '0')
                        $endMinute = $matches[4]
                        
                        $startTime = "${startHour}:${startMinute}"
                        $endTime = "${endHour}:${endMinute}"
                        
                        # 作業時間を計算（休憩1時間を引く）
                        $startDateTime = Get-Date -Hour ([int]$startHour) -Minute ([int]$startMinute) -Second 0
                        $endDateTime = Get-Date -Hour ([int]$endHour) -Minute ([int]$endMinute) -Second 0
                        
                        $workDuration = $endDateTime - $startDateTime
                        $workHours = $workDuration.TotalHours - 1.0  # 休憩1時間を引く
                        
                        if ($workHours -gt 0) {
                            $hours = [Math]::Floor($workHours)
                            $minutes = [Math]::Round(($workHours - $hours) * 60)
                            $totalWorkTime = "${hours}:$($minutes.ToString('00'))"
                        }
                        
                        $found = $true
                        Write-Host " ✓ 発見: $startTime - $endTime (計: $totalWorkTime)" -ForegroundColor Green
                        Write-Log "データ取得成功: $dateString - 件名[$subject] - 実績[$startTime~$endTime] - 合計[$totalWorkTime]"
                        break
                    }
                }
            }
            
            # COMオブジェクトを解放
            [System.Runtime.Interopservices.Marshal]::ReleaseComObject($item) | Out-Null
        }
        
        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($items) | Out-Null
        
    } catch {
        Write-Log "エラー: $dateString の処理中にエラーが発生しました - $($_.Exception.Message)"
    }
    
    if (-not $found) {
        Write-Host " - データなし" -ForegroundColor Yellow
        Write-Log "データなし: $dateString"
    }
    
    # CSVデータに追加
    $workTimeData += "$dateString,$startTime,$endTime,$totalWorkTime"
}

Write-Host "----------------------------------------"

# CSVファイルに出力
$outputFileName = "WorkTime_${Year}_$(${Month}.ToString('00')).csv"
$outputPath = Join-Path $outputFolder $outputFileName

try {
    # UTF-8 BOM付きで保存（Excelで正しく開けるように）
    $utf8BOM = New-Object System.Text.UTF8Encoding $true
    [System.IO.File]::WriteAllLines($outputPath, $workTimeData, $utf8BOM)
    
    Write-Host "`n✓ CSVファイルを作成しました" -ForegroundColor Green
    Write-Host "保存先: $outputPath"
    Write-Log "CSVファイル作成成功: $outputPath"
    
    # 統計情報を表示
    $dataLines = $workTimeData | Where-Object { $_ -notmatch "^Date," -and $_ -match ",\d+:\d+,\d+:\d+," }
    $workDays = $dataLines.Count
    
    Write-Host "`n=========================================="
    Write-Host "統計情報"
    Write-Host "=========================================="
    Write-Host "対象月: $Year年$Month月"
    Write-Host "総日数: $daysInMonth 日"
    Write-Host "勤務日数: $workDays 日"
    Write-Host "データなし: $($daysInMonth - $workDays) 日"
    Write-Host "=========================================="
    
    Write-Log "統計 - 総日数:$daysInMonth 勤務日数:$workDays データなし:$($daysInMonth - $workDays)"
    
} catch {
    Write-Log "エラー: CSVファイルの保存に失敗しました - $($_.Exception.Message)"
    Write-Host "✗ CSVファイルの保存に失敗しました" -ForegroundColor Red
}

# Outlookオブジェクトを解放
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($sentFolder) | Out-Null
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($namespace) | Out-Null
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($outlook) | Out-Null
[System.GC]::Collect()
[System.GC]::WaitForPendingFinalizers()

Write-Host "`n処理が完了しました！"
Write-Host "ログファイル: $logFile"
Write-Log "スクリプト終了"

# 出力ファイルを開くか確認
$response = Read-Host "`nCSVファイルを開きますか？ (Y/N)"
if ($response -eq "Y" -or $response -eq "y") {
    Start-Process $outputPath
}

```

```
@echo off
powershell.exe -ExecutionPolicy Bypass -File "C:\Users\whz\Documents\collect_monthly_worktime.ps1"  -Year 2025 -Month 11
pause
```

F36_SAP_Login.bat
```
@echo off
setlocal EnableDelayedExpansion

REM SAP Login Script for F36 System

set "SYSTEM=F36"

call :log "Script started for %SYSTEM%"

REM --- Locate sapshcut.exe ---
set "SAPSHCUT=%ProgramFiles(x86)%\SAP\FrontEnd\SAPgui\sapshcut.exe"
if not exist "%SAPSHCUT%" set "SAPSHCUT=%ProgramFiles%\SAP\FrontEnd\SAPgui\sapshcut.exe"

if not exist "%SAPSHCUT%" (
  call :log "ERROR: sapshcut.exe not found"
  pause
  exit /b 1
)

REM --- Get user input ---
set /p client=Enter client number (e.g. 100): 
if "%client%"=="" (
  call :log "ERROR: Client number required"
  pause
  exit /b 1
)

set /p user=Enter username (default: 2EY165): 
if "%user%"=="" set "user=2EY165"

set /p lang=Enter language (default EN): 
if "%lang%"=="" set "lang=EN"

REM --- Check user's password file ---
set "CSV=%~dp0%user%.csv"
call :log "User: %user%, Client: %client%"
call :log "Password file: %CSV%"

if not exist "%CSV%" (
  call :log "ERROR: Password file %user%.csv not found"
  pause
  exit /b 1
)

set "pwd="
set "commonPwd="

REM --- Search for specific client password and common password ---
for /f "usebackq tokens=1-3 delims=, skip=1" %%A in ("%CSV%") do (
  set "csvSys=%%A"
  set "csvClient=%%B"
  set "csvPwd=%%C"
  
  REM Remove spaces
  set "csvSys=!csvSys: =!"
  set "csvClient=!csvClient: =!"
  
  if /I "!csvSys!"=="%SYSTEM%" (
    if /I "!csvClient!"=="%client%" (
      set "pwd=!csvPwd!"
      call :log "Found password for client %client%"
    )
    if /I "!csvClient!"=="common" (
      set "commonPwd=!csvPwd!"
      call :log "Found common password"
    )
  )
)

REM --- Use common password if specific client password not found ---
if not defined pwd (
  if defined commonPwd (
    set "pwd=!commonPwd!"
    call :log "Using common password for client %client%"
  ) else (
    call :log "ERROR: No password found for system=%SYSTEM%, client=%client%"
    pause
    exit /b 1
  )
)

REM --- Launch SAP GUI ---
call :log "Launching SAP GUI with system=%SYSTEM%, client=%client%, language=%lang%, password=%pwd%"
START "" "%SAPSHCUT%" -system=%SYSTEM% -sysname=%SYSTEM% -client=%client% -user=%user% -pw=%pwd% -language=%lang%

call :log "Script finished"
timeout /t 30 /nobreak >nul
exit /b 0

REM --- Log function ---
:log
echo [%date% %time%] %~1
goto :eof
```

2EY165.csv
```
system,client,password
F36,100,AAA
F36,200,BBB
F36,common,CCC
F46,100,CCC
F46,common,CCC
F56,500,DDD
F56,common,CCC
```


```
# ===== 設定 =====
$serverIP = "10.194.229.189"
$eyadminUser = "eyadmin"
$eyadminPassword = "eyadminのパスワード"
$jp1User = "jp1_admin"
$jp1Password = "jp1_adminのパスワード"

# 認証情報作成
$eyadminSecurePass = ConvertTo-SecureString $eyadminPassword -AsPlainText -Force
$eyadminCredential = New-Object System.Management.Automation.PSCredential ($eyadminUser, $eyadminSecurePass)

Write-Host "eyadmin でリモート接続中..." -ForegroundColor Green

# eyadmin でリモート接続（通常の認証）
Invoke-Command -ComputerName $serverIP -Credential $eyadminCredential -ScriptBlock {
    param($jp1User, $jp1Pass)
    
    Write-Host "接続成功: $env:USERNAME でログイン済み"
    
    # 定義ファイル作成
    $defineFile = "D:\temp\IMP_group.txt"
    $defineContent = "unit=g,/IMP,,,,,,,,,,,,,,,,,,,,,,,;"
    
    $tempDir = "D:\temp"
    if (-not (Test-Path $tempDir)) {
        New-Item -ItemType Directory -Path $tempDir -Force
    }
    
    Set-Content -Path $defineFile -Value $defineContent -Encoding Default
    Write-Host "定義ファイル作成: $defineFile"
    
    # スケジュールタスクで jp1_admin として実行
    $taskName = "JP1_IMP_Creation_Temp"
    $action = New-ScheduledTaskAction -Execute "D:\JP1\jp1ajs2\bin\ajsdefine.exe" `
                                       -Argument "`"$defineFile`"" `
                                       -WorkingDirectory "D:\JP1\jp1ajs2\bin"
    
    # 既存タスクがあれば削除
    $existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($existingTask) {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    }
    
    Write-Host "スケジュールタスク作成: $taskName"
    
    # タスク登録（jp1_admin で実行）
    Register-ScheduledTask -TaskName $taskName `
                          -Action $action `
                          -User $jp1User `
                          -Password $jp1Pass `
                          -RunLevel Highest `
                          -Force | Out-Null
    
    Write-Host "jp1_admin でタスク実行中..."
    
    # タスク実行
    Start-ScheduledTask -TaskName $taskName
    
    # 完了待機
    $timeout = 30
    $elapsed = 0
    while ((Get-ScheduledTask -TaskName $taskName).State -ne 'Ready' -and $elapsed -lt $timeout) {
        Start-Sleep -Seconds 1
        $elapsed++
    }
    
    # タスク情報取得
    $taskInfo = Get-ScheduledTaskInfo -TaskName $taskName
    Write-Host "タスク実行結果: $($taskInfo.LastTaskResult)"
    
    # タスク削除
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    
    if ($taskInfo.LastTaskResult -eq 0) {
        Write-Host "ジョブネットグループ 'IMP' 作成完了" -ForegroundColor Green
    } else {
        Write-Host "エラーが発生しました。終了コード: $($taskInfo.LastTaskResult)" -ForegroundColor Red
    }
    
} -ArgumentList $jp1User, $jp1Password

Write-Host ""
Write-Host "すべての処理が完了しました！" -ForegroundColor Green
```

https://www.servicenow.com/community/developer-forum/service-graph-connector-sccm-integration-user-guide/m-p/3103061

```
var userName = 'testuser';
var userGr = new GlideRecord('sys_user');

if (userGr.get('user_name', userName)) {
    gs.print('========================================');
    gs.print('ユーザー名: ' + userGr.user_name);
    gs.print('表示名: ' + userGr.name);
    gs.print('アクティブ: ' + userGr.active);
    gs.print('========================================');
    
    var roleGr = new GlideRecord('sys_user_has_role');
    roleGr.addQuery('user', userGr.sys_id);
    roleGr.addQuery('state', 'active'); // アクティブなロールのみ
    roleGr.orderBy('role.name');
    roleGr.query();
    
    gs.print('ロール一覧:');
    var count = 0;
    while (roleGr.next()) {
        count++;
        var role = roleGr.role.getRefRecord();
        gs.print(count + '. ' + role.name + ' (' + role.sys_id + ')');
    }
    
    if (count == 0) {
        gs.print('このユーザーにはロールが割り当てられていません');
    }
    gs.print('========================================');
    gs.print('合計ロール数: ' + count);
}
```



管理者で実行
```
net start WinRM
# 直接创建并设置 TrustedHosts
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "192.168.0.211" -Force

# 验证是否设置成功
Get-Item WSMan:\localhost\Client\TrustedHosts
Test-NetConnection -ComputerName 192.168.0.211 -Port 5985
# 重启 WinRM 服务使配置生效
Restart-Service WinRM
```

```
# 配置信息
$serverIP = "192.168.0.211"
$username = "Administrator"  # 如果是域用户，格式为 "DOMAIN\Username"
$password = "你的密码"

# 创建凭据
$securePassword = ConvertTo-SecureString $password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential ($username, $securePassword)

# 连接
Enter-PSSession -ComputerName $serverIP -Credential $credential -Authentication Negotiate
```

rdp-login.bat
```
@echo off
cmdkey /generic:TERMSRV/192.168.0.211 /user:Administrator /pass:你的密码
start mstsc /v:192.168.0.211
timeout /t 3 >nul
cmdkey /delete:TERMSRV/192.168.0.211
```

```
# rdp-login.ps1
$server = "192.168.1.100"
$username = "Administrator"
$password = "YourPassword"

# 临时添加凭据
Start-Process cmdkey -ArgumentList "/generic:TERMSRV/$server /user:$username /pass:$password" -Wait -NoNewWindow

# 启动 RDP
Start-Process mstsc -ArgumentList "/v:$server"

# 等待5秒后删除凭据（可选）
Start-Sleep -Seconds 5
Start-Process cmdkey -ArgumentList "/delete:TERMSRV/$server" -NoNewWindow
```

https://www.servicenow.com/docs/ja-JP/bundle/yokohama-servicenow-platform/page/product/configuration-management/concept/cmdb-integration-tanium.html#d320779e473

```
負荷分散の調整

ログオングループの設定見直し
ユーザーの接続先振り分けの最適化


RISE PCE サーバ: メモリ使用率が危険水準（ピンク色の高い使用率）
ST06: Free Memory使用率の問題
ABAPアドオンは確実にメモリを大量消費する可能性があります：
メモリリークの原因

不適切なInternal Tableの使用
大量データの一括処理
オブジェクトの適切な解放不備


特に問題となるパターン

無限ループやRecursive呼び出し
SELECT文での大量データ取得
不要なWORK AREAの保持


ABAPコードレビュー

カスタムプログラムのメモリ使用量チェック
Internal Tableのサイズ制限実装
適切なFREE文の追加


監視強化

メモリ使用量の定期監視
アドオンプログラムの実行ログ取得
```


```
先に挙げた「アップグレードへの影響」や「データの不整合」の他に、標準のRTEを独自にカスタマイズすることで、以下のようなリスクが考えられます。
理由は以下の通りです。

アップグレードへの影響: アプリケーションのバージョンアップ時に、カスタマイズした設定が上書きされたり、競合が発生したりする可能性があります。

予期せぬ不整合: 標準のRTEは、CIの識別・調整（IRE）ルールと密接に連携して設計されています。安易に変更すると、データの重複や不整合を引き起こすリスクがあります。
これらのリスクを避けるためにも、可能な限り標準のコネクタをそのまま利用し、カスタマイズが必要な場合でも、影響範囲を最小限に抑えるアプローチ（既存RTEのコピーや、独立した連携処理の作成など）を強くお勧めします。
Taniumから連携されたハードウェアとソフトウェアのデータは、まず**x_taniu_tanium_s_sg_tanium_hardware_and_software** という単一のインポートセットテーブルに格納されます。

しかし、その後のインポートセットテーブルとRTEの関係は「1対多」と捉えるのがより正確です。

これは、1つのインポートセットテーブルに取り込まれたデータを、1つのRTE（実体はCMDB Integration Studio App Data Sourceレコード）が処理し、その内部で複数の変換マップ（ETL Entity Mapping）を通じて、CMDB上の様々なターゲットテーブル（CIクラス）にデータを振り分けるためです。

例えば、「SG-Tanium Hardware and Software」のデータは、以下のようにマッピングされます。

コンピュータの基本情報 → cmdb_ci_computer (およびその子クラス)

インストールされているソフトウェア情報 → cmdb_sam_sw_install

ディスク情報 → cmdb_ci_disk

ネットワークアダプタ情報 → cmdb_ci_network_adapter

このように、1つのインポート元（インポートセットテーブル）から、複数のCIクラスへデータが投入される構造になっています。

```

```
//このスクリプトは SG-Tanium Hardware and Software の scheduled import 実行前に、特定の Entity Mapping を無視するように設定することで、不要なデータの取り込みを防ぐ目的で使用されていると思われます。
// 検索条件を設定
var entityMappingName = 'impTotemp.ci_installed_application[*]';
var definitionName = 'SG Tanium Hardware and Software';

var grEntityMapping = new GlideRecord('sys_rte_eb_entity_mapping');
grEntityMapping.addQuery('name', entityMappingName);
grEntityMapping.addQuery('sys_rte_eb_definition.name', definitionName);
grEntityMapping.query();

if (grEntityMapping.next()) {
    grEntityMapping.setValue('ignore', true);
    grEntityMapping.update();
    gs.info('Pre-import Script: Successfully set Ignore to true for Entity Mapping: ' + 
            entityMappingName + ' (sys_id: ' + grEntityMapping.getUniqueValue() + ')');
} else {
    gs.warn('Pre-import Script: Could not find Entity Mapping with name: ' + entityMappingName);
}
```

■Ｇｅｔ
```
// 検索条件を設定
var entityMappingName = 'impTotemp.ci_installed_application[*]';
var definitionName = 'SG Tanium Hardware and Software';

var grEntityMapping = new GlideRecord('sys_rte_eb_entity_mapping');
grEntityMapping.addQuery('name', entityMappingName);
grEntityMapping.addQuery('sys_rte_eb_definition.name', definitionName);
grEntityMapping.query();

if (grEntityMapping.next()) {
    // ignoreフィールドの値を取得
    var ignoreValue = grEntityMapping.getValue('ignore');
    // 結果をログに出力
    gs.info('Entity Mapping "' + entityMappingName + '" ignore value: ' + ignoreValue + 
            ' (sys_id: ' + grEntityMapping.getUniqueValue() + ')');
    // Boolean値として取得したい場合
    var ignoreBoolean = grEntityMapping.ignore == true;
    gs.info('Entity Mapping "' + entityMappingName + '" ignore boolean: ' + ignoreBoolean);
    
} else {
    gs.warn('Could not find Entity Mapping with specified criteria:');
    gs.warn('  Name: ' + entityMappingName);
    gs.warn('  Definition: ' + definitionName);
}
```

```
// Background Scriptで実行するためのコード

// 更新したいRTE Entity Mappingのsys_idを直接指定
var entityMappingSysId = '19278d7e53d030106747ddeeff7b128e';

// sys_rte_eb_entity_mappingテーブルをsys_idで直接検索
var grEntityMapping = new GlideRecord('sys_rte_eb_entity_mapping');

// .get()メソッドで指定したsys_idのレコードを取得
if (grEntityMapping.get(entityMappingSysId)) {
    // 対象のEntity Mappingの 'Ignore' を true に設定
    grEntityMapping.setValue('ignore', true);
    grEntityMapping.update();
    
    // 実行結果をシステムログに出力
    gs.info('Background Script: Successfully set Ignore to true for Entity Mapping: ' + grEntityMapping.getValue('name') + ' (sys_id: ' + entityMappingSysId + ')');

} else {
    // レコードが見つからない場合もログに出力
    gs.warn('Background Script: Could not find the Entity Mapping with sys_id: ' + entityMappingSysId);
}
```

```
Select-CFGResourceConfig -Expression "SELECT resourceId, resourceType WHERE resourceType = 'AWS::EC2::VPC'"

$resourceKeys = @(
    @{
        ResourceType = "AWS::EC2::VPC"
        ResourceId = "vpc-02f6419c0024583d8"
    },
    @{
        ResourceType = "AWS::EC2::NetworkAcl"
        ResourceId = "acl-035e429f9ad31f322"
    }
)

$result = Get-CFGGetResourceConfigBatch -ResourceKey $resourceKeys
Write-Output "取得したリソース設定："
$result.BaseConfigurationItems | ForEach-Object {
    Write-Output "リソースタイプ: $($_.ResourceType)"
    Write-Output "リソースID: $($_.ResourceId)"
    Write-Output "設定取得時刻: $($_.ConfigurationItemCaptureTime)"
    Write-Output "設定状態: $($_.ConfigurationItemStatus)"
    Write-Output "---"
}

   var recordIdToDelete = "1"; 

    // import_set_table から指定されたIDのレコードを検索
    var grDelete = new GlideRecord(import_set_table.getTableName());
    if (grDelete.get('id', recordIdToDelete)) { // 'id' フィールドで検索
        // レコードが見つかった場合、削除を実行
        gs.info("Deleting record with ID: " + recordIdToDelete + " from table: " + import_set_table.getTableName());
        grDelete.deleteRecord();
    } else {
        gs.info("Record with ID: " + recordIdToDelete + " not found in table: " + import_set_table.getTableName());
    }
```
■import-transform-learning-path
https://www.servicenow.com/community/servicenow-ai-platform-articles/import-transform-learning-path/ta-p/2306952#ISST

https://www.servicenow.com/community/developer-forum/bd-p/developer-forum

Script Include →SGTaniumDataSourceUtil
Application Navigator → Flow Designer → Actions

Tanium
https://help.tanium.com/bundle/AssetGraphConxSetup/page/Integrations/SNOW/AssetGraphConxSetup/Tanium_Asset_Setting_Up_Asset.htm

Map images custom-type-data-source
- https://www.servicenow.com/docs/ja-JP/bundle/yokohama-integrate-applications/page/script/server-scripting/concept/c_CreatingNewTransformMaps.html
- https://www.servicenow.com/docs/ja-JP/bundle/yokohama-integrate-applications/page/administer/import-sets/reference/custom-type-data-source.html


updates
 - https://www.servicenow.com/community/itsm-forum/i-want-to-get-the-row-count-on-inserted-created-updated-total/m-p/533191#M104970#:~:text=griii4.getValue%28,field%20names
 - https://www.servicenow.com/community/architect-forum/insertmultiple-import-set-api/m-p/2442022#:~:text=The%20import%20now%20completes%20,values%20appear%20in%20either%20staging


```
updatesの数が多い理由を確認しました。
おそらく、updatesの単位は「フィールド」ではなく「レコード」だと思われます。

また、データインポート時にはターゲットテーブルだけでなく、ステージングテーブルにも更新が発生しているようです。
さらに、複数のテーブルや子テーブルが同時に更新されるケースが多いと考えられます。

たとえば、ステージングテーブルの1件のレコードが「CI（構成アイテム）情報」「ハードウェア一覧」「ソフトウェア一覧」の3つのテーブルにマッピングされている場合、1レコードにつき最低でも3件の更新が発生します。

実際には、ソフトウェアの数が多い場合など、1レコードに対して数十件から数百件の子レコードの更新が発生することもあります。
```

このスクリプトは、インポートが実行される直前に評価され、trueを返した場合にのみインポートが実行されます。falseを返した場合は、その回のインポートはスキップされます。
https://www.servicenow.com/community/developer-forum/conditional-scheduled-imports/td-p/1527884?utm_source=chatgpt.com
```
//Return 'true' to run the job
var answer = false;

//Get the day of month. 
var now = new GlideDateTime();

//Run only on 2nd of month
if(now.getDayOfMonthLocalTime() == 2){
     answer = true;
}

answer;
```

```
var answer = true;
var now = new GlideDateTime();
var hour = now.getHourLocalTime();

// 例：全量ジョブが毎日 0:00〜4:00 の間に動くなら、その時間帯だけ絞り込みジョブをスキップ
if (hour >= 0 && hour < 4) {
  answer = false;
}

answer;

```

```
ServiceNow user created in Designated Member Account, both managed and member accounts have different STS Role Names.
For the STS Role value in STS Assume Role Name (Include only name and not ARN), which account STS Role Name should be set?

指定メンバーアカウントで作成されたServiceNowユーザーは、管理アカウントとメンバーアカウントの両方で異なるSTS役割名を持っています。
STS Assume Role Name（ARNではなく名前のみを含む）のSTS Role値には、どのアカウントのSTS Role Nameを設定する必要がありますか？
```
