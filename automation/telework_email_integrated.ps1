# テレワークメール自動作成統合スクリプト
# Telework Email Auto-Creation Integrated Script
# 機能：1. 業務開始報告  2. 日報コピー  3. 業務終了報告

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("start", "dailyreport", "end", "all")]
    [string]$Mode = "all"
)

# 共通設定
$senderName = "王洪志"  # あなたの名前
$recipientEmail = "3bs-snow_poc@example.com"  # 収件人邮箱地址（请修改）
$currentDate = Get-Date -Format "MM/dd"
$logFile = "$env:USERPROFILE\telework_email_log.txt"

# ログ記録関数
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $logFile -Value "$timestamp - $Message"
}

# Outlookオブジェクト作成
try {
    $outlook = New-Object -ComObject Outlook.Application
    $namespace = $outlook.GetNamespace("MAPI")
    Write-Log "Outlookに接続しました"
} catch {
    Write-Log "エラー: Outlookに接続できませんでした - $($_.Exception.Message)"
    exit
}

# 機能1: 業務開始報告メール作成
function Create-StartReport {
    try {
        $mail = $outlook.CreateItem(0)
        $mail.Subject = "【テレワーク】業務開始報告（$currentDate）$senderName"
        
        $mail.Body = @"
お疲れ様です。
王です。

業務を開始します。

【業務開始・終了予定】
予定: 09:30~18:30
実績: 09:30~

【作業場所】
自宅

【その他連絡事項】
なし

以上、よろしくお願いいたします。
"@
        
        $mail.Recipients.Add($recipientEmail) | Out-Null
        $mail.Save()
        
        Write-Log "業務開始報告メール作成成功: $($mail.Subject)"
        Write-Host "✓ 業務開始報告メールを作成しました"
        
        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($mail) | Out-Null
    } catch {
        Write-Log "エラー: 業務開始報告メール作成失敗 - $($_.Exception.Message)"
        Write-Host "✗ 業務開始報告メールの作成に失敗しました: $($_.Exception.Message)"
    }
}

# 機能2: 日報メールをコピー
function Copy-DailyReport {
    try {
        # 送信済みアイテムフォルダーを取得
        $sentFolder = $namespace.GetDefaultFolder(5)  # 5 = olFolderSentMail
        $items = $sentFolder.Items
        $items.Sort("[ReceivedTime]", $true)  # 最新順にソート
        
        $found = $false
        $count = 0
        $maxCheck = 5  # 最新5件をチェック
        
        Write-Host "送信済みアイテムから日報を検索中..."
        
        foreach ($item in $items) {
            if ($count -ge $maxCheck) { break }
            $count++
            
            # メールアイテムのみ処理
            if ($item.Class -eq 43) {  # 43 = olMail
                $subject = $item.Subject
                
                # 件名の先頭が「日報」で始まるかチェック
                if ($subject -match "^日報") {
                    Write-Host "日報メールを発見: $subject"
                    
                    # 新しい下書きメールを作成
                    $newMail = $outlook.CreateItem(0)
                    
                    # 新しい件名を設定
                    $newMail.Subject = "日報($currentDate $senderName)"
                    
                    # 本文をコピー
                    $newMail.Body = $item.Body
                    
                    # 受信者をコピー
                    foreach ($recipient in $item.Recipients) {
                        $newMail.Recipients.Add($recipient.Address) | Out-Null
                    }
                    
                    # 添付ファイルをコピー（もしあれば）
                    foreach ($attachment in $item.Attachments) {
                        $tempPath = "$env:TEMP\$($attachment.FileName)"
                        $attachment.SaveAsFile($tempPath)
                        $newMail.Attachments.Add($tempPath) | Out-Null
                        Remove-Item $tempPath -ErrorAction SilentlyContinue
                    }
                    
                    # 下書きとして保存
                    $newMail.Save()
                    
                    Write-Log "日報メールコピー成功: 元の件名[$subject] → 新しい件名[$($newMail.Subject)]"
                    Write-Host "✓ 日報メールをコピーしました: $($newMail.Subject)"
                    
                    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($newMail) | Out-Null
                    $found = $true
                    break
                }
            }
            
            # COMオブジェクトを解放
            [System.Runtime.Interopservices.Marshal]::ReleaseComObject($item) | Out-Null
        }
        
        if (-not $found) {
            Write-Log "日報メールが見つかりませんでした（最新5件を確認）"
            Write-Host "✗ 送信済みアイテムに日報メールが見つかりませんでした"
        }
        
        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($items) | Out-Null
        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($sentFolder) | Out-Null
        
    } catch {
        Write-Log "エラー: 日報メールコピー失敗 - $($_.Exception.Message)"
        Write-Host "✗ 日報メールのコピーに失敗しました: $($_.Exception.Message)"
    }
}

# 機能3: 業務終了報告メール作成
function Create-EndReport {
    try {
        $mail = $outlook.CreateItem(0)
        $mail.Subject = "【テレワーク】業務終了報告（$currentDate）$senderName"
        
        # 現在の時刻を取得
        $currentTime = Get-Date -Format "HH:mm"
        
        $mail.Body = @"
お疲れ様です。
王です。

業務を終了します。

【業務開始・終了予定】
予定: 09:30~18:30
実績: 09:30~19:00

【作業場所】
自宅

【その他連絡事項】
なし

以上、よろしくお願いいたします。
"@
        
        $mail.Recipients.Add($recipientEmail) | Out-Null
        $mail.Save()
        
        Write-Log "業務終了報告メール作成成功: $($mail.Subject)"
        Write-Host "✓ 業務終了報告メールを作成しました"
        
        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($mail) | Out-Null
    } catch {
        Write-Log "エラー: 業務終了報告メール作成失敗 - $($_.Exception.Message)"
        Write-Host "✗ 業務終了報告メールの作成に失敗しました: $($_.Exception.Message)"
    }
}

# メイン処理
Write-Host "=========================================="
Write-Host "テレワークメール自動作成スクリプト"
Write-Host "実行モード: $Mode"
Write-Host "日付: $currentDate"
Write-Host "=========================================="

switch ($Mode) {
    "start" {
        Write-Host "`n[1/1] 業務開始報告メールを作成中..."
        Create-StartReport
    }
    "dailyreport" {
        Write-Host "`n[1/1] 日報メールをコピー中..."
        Copy-DailyReport
    }
    "end" {
        Write-Host "`n[1/1] 業務終了報告メールを作成中..."
        Create-EndReport
    }
    "all" {
        Write-Host "`n[1/3] 業務開始報告メールを作成中..."
        Create-StartReport
        Start-Sleep -Seconds 1
        
        Write-Host "`n[2/3] 日報メールをコピー中..."
        Copy-DailyReport
        Start-Sleep -Seconds 1
        
        Write-Host "`n[3/3] 業務終了報告メールを作成中..."
        Create-EndReport
    }
}

# Outlookオブジェクトを解放
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($namespace) | Out-Null
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($outlook) | Out-Null
[System.GC]::Collect()
[System.GC]::WaitForPendingFinalizers()

Write-Host "`n=========================================="
Write-Host "処理が完了しました"
Write-Host "Outlookの下書きフォルダーを確認してください"
Write-Host "ログファイル: $logFile"
Write-Host "=========================================="
