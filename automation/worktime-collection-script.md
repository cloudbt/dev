# 月度工作時間収集スクリプト
# Monthly Work Time Collection Script

## 概要

Outlookの送信済みメールから「業務終了報告」メールを検索し、月度の勤務時間を自動集計してCSVとExcelファイルを作成するPowerShellスクリプト

## スクリプト本体

### collect_monthly_worktime.ps1

```powershell
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

## 実行バッチファイル

### run_worktime_collection.bat

```batch
@echo off
powershell.exe -ExecutionPolicy Bypass -File "C:\Users\whz\Documents\collect_monthly_worktime.ps1" -Year 2025 -Month 11
pause
```

## 使用方法

1. `collect_monthly_worktime.ps1` をドキュメントフォルダに保存
2. バッチファイルのパスとパラメータ（Year, Month）を編集
3. バッチファイルを実行

## 機能

- Outlookの送信済みメールから「業務終了報告」を自動検索
- メール本文から勤務時間を正規表現で抽出
- 休憩時間（1時間）を自動控除
- CSV形式で月次レポート作成
- 詳細なログ記録
- 統計情報の表示
