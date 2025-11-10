## **日本語翻訳版**

| パラメータ設定 | ユーザー権限 | 結果 |
|---------|---------|------|
| sapgui/user_scripting = FALSE | S_SCRの有無 | ❌ **使用不可** |
| sapgui/user_scripting = TRUE<br>sapgui/user_scripting_per_user = FALSE | S_SCRの有無 | ✅ **全ユーザーが使用可能** |
| sapgui/user_scripting = TRUE<br>sapgui/user_scripting_per_user = TRUE | **S_SCRあり** | ✅ **使用可能** |
| sapgui/user_scripting = TRUE<br>sapgui/user_scripting_per_user = TRUE | **S_SCRなし** | ❌ **使用不可** |

---

## **より詳細な日本語版**

| パラメータ設定 | ユーザー権限 | 結果 |
|---------------|------------|------|
| sapgui/user_scripting = FALSE | S_SCR権限の有無を問わず | ❌ **使用不可**<br>（サーバー側で無効） |
| sapgui/user_scripting = TRUE<br>sapgui/user_scripting_per_user = FALSE | S_SCR権限の有無を問わず | ✅ **全ユーザーが使用可能**<br>（権限チェックなし） |
| sapgui/user_scripting = TRUE<br>sapgui/user_scripting_per_user = TRUE | ✅ S_SCR権限**あり** | ✅ **使用可能** |
| sapgui/user_scripting = TRUE<br>sapgui/user_scripting_per_user = TRUE | ❌ S_SCR権限**なし** | ❌ **使用不可**<br>（権限エラー） |

---

## **列見出しの別訳オプション**

もし表の見出しを変更したい場合：

### **バージョン1（簡潔版）**
```
パラメータ設定 | 権限 | 結果
```

### **バージョン2（詳細版）**
```
サーバー側パラメータ | ユーザー認可オブジェクト | スクリプティング可否
```

### **バージョン3（ビジネス文書風）**
```
システムパラメータ | S_SCR認可 | 利用可否
```

---

どのバージョンがお好みですか？または他の表現が必要でしょうか？



了解しました！各サーバーで異なるユーザーとパスワードを使用するように修正します。

## **完全版スクリプト（各サーバー個別設定対応）**

`jp1-auto-deploy.ps1`：

```powershell
# ===== 設定 =====
# JP1開発機設定
$devServer = "10.194.229.89"
$devLoginUser = "eyadmin"                    # 開発機リモートログイン用
$devLoginPassword = "eyadminのパスワード"
$devJp1User = "jp1_admin"                    # 開発機JP1実行用
$devJp1Password = "開発機jp1_adminのパスワード"

# JP1本番機設定
$prodServer = "10.194.229.84"
$prodLoginUser = "admin"                     # 本番機リモートログイン用
$prodLoginPassword = "adminのパスワード"
$prodJp1User = "jp1_admin"                   # 本番機JP1実行用
$prodJp1Password = "本番機jp1_adminのパスワード"

# 共通設定
$locationName = "DAV"                        # 拠点名

# ログファイル設定
$logDir = "D:\JP1_AutoDeploy_Logs"
$logFile = Join-Path $logDir "JP1_Deploy_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# ログディレクトリ作成
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

# ログ出力関数
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # コンソールとファイルに出力
    switch ($Level) {
        "ERROR"   { Write-Host $logMessage -ForegroundColor Red }
        "SUCCESS" { Write-Host $logMessage -ForegroundColor Green }
        "WARNING" { Write-Host $logMessage -ForegroundColor Yellow }
        default   { Write-Host $logMessage }
    }
    
    Add-Content -Path $logFile -Value $logMessage -Encoding UTF8
}

# 日付フォーマット
$dateStr = Get-Date -Format "yyyyMMdd"
$exportFileName = "ajsprint_${dateStr}_${locationName}.txt"

# 認証情報作成
$devLoginSecurePass = ConvertTo-SecureString $devLoginPassword -AsPlainText -Force
$devLoginCredential = New-Object System.Management.Automation.PSCredential ($devLoginUser, $devLoginSecurePass)

$prodLoginSecurePass = ConvertTo-SecureString $prodLoginPassword -AsPlainText -Force
$prodLoginCredential = New-Object System.Management.Automation.PSCredential ($prodLoginUser, $prodLoginSecurePass)

Write-Log "========================================" "INFO"
Write-Log "JP1 自動デプロイ開始" "INFO"
Write-Log "開発機: $devServer (ログイン: $devLoginUser / JP1実行: $devJp1User)" "INFO"
Write-Log "本番機: $prodServer (ログイン: $prodLoginUser / JP1実行: $prodJp1User)" "INFO"
Write-Log "拠点名: $locationName" "INFO"
Write-Log "ログファイル: $logFile" "INFO"
Write-Log "========================================" "INFO"

# ========================================
# STEP1: JP1開発機からジョブ定義Export
# ========================================
Write-Log "" "INFO"
Write-Log "========================================" "INFO"
Write-Log "STEP1: JP1開発機からジョブ定義Export" "INFO"
Write-Log "========================================" "INFO"

try {
    $step1Result = Invoke-Command -ComputerName $devServer -Credential $devLoginCredential -ScriptBlock {
        param($jp1User, $jp1Pass, $locationName, $exportFileName)
        
        $exportPath = "D:\ajsprint\$exportFileName"
        $exportDir = "D:\ajsprint"
        
        # ディレクトリ作成
        if (-not (Test-Path $exportDir)) {
            New-Item -ItemType Directory -Path $exportDir -Force | Out-Null
        }
        
        # スケジュールタスクでエクスポート実行
        $taskName = "JP1_Export_Temp_$(Get-Date -Format 'HHmmss')"
        
        # PowerShellスクリプトを作成
        $scriptContent = @"
Set-Location 'D:\jp1\jp1ajs2\bin'
`$output = & .\ajsprint.exe -a /${locationName}/Release 2>&1
`$output | Out-File -FilePath '$exportPath' -Encoding Default
exit `$LASTEXITCODE
"@
        $scriptFile = "D:\temp\export_script_$(Get-Date -Format 'HHmmss').ps1"
        $tempDir = "D:\temp"
        if (-not (Test-Path $tempDir)) {
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        }
        [System.IO.File]::WriteAllText($scriptFile, $scriptContent, [System.Text.Encoding]::UTF8)
        
        $action = New-ScheduledTaskAction -Execute "powershell.exe" `
                                           -Argument "-ExecutionPolicy Bypass -File `"$scriptFile`"" `
                                           -WorkingDirectory "D:\jp1\jp1ajs2\bin"
        
        # 既存タスク削除
        $existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        if ($existingTask) {
            Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
        }
        
        # タスク登録
        Register-ScheduledTask -TaskName $taskName `
                              -Action $action `
                              -User $jp1User `
                              -Password $jp1Pass `
                              -RunLevel Highest `
                              -Force | Out-Null
        
        # タスク実行
        Start-ScheduledTask -TaskName $taskName
        
        # 完了待機
        $timeout = 60
        $elapsed = 0
        while ((Get-ScheduledTask -TaskName $taskName).State -ne 'Ready' -and $elapsed -lt $timeout) {
            Start-Sleep -Seconds 1
            $elapsed++
        }
        
        # タスク結果取得
        $taskInfo = Get-ScheduledTaskInfo -TaskName $taskName
        $exitCode = $taskInfo.LastTaskResult
        
        # タスク削除
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
        
        # 一時スクリプト削除
        if (Test-Path $scriptFile) {
            Remove-Item $scriptFile -Force
        }
        
        # ファイル存在確認
        $fileExists = Test-Path $exportPath
        $fileSize = if ($fileExists) { (Get-Item $exportPath).Length } else { 0 }
        
        return @{
            Success = ($exitCode -eq 0 -and $fileExists -and $fileSize -gt 0)
            ExitCode = $exitCode
            FilePath = $exportPath
            FileSize = $fileSize
            FileExists = $fileExists
        }
        
    } -ArgumentList $devJp1User, $devJp1Password, $locationName, $exportFileName
    
    if ($step1Result.Success) {
        Write-Log "エクスポート成功" "SUCCESS"
        Write-Log "ファイル: $($step1Result.FilePath)" "INFO"
        Write-Log "サイズ: $($step1Result.FileSize) bytes" "INFO"
        Write-Log "終了コード: $($step1Result.ExitCode)" "INFO"
    } else {
        Write-Log "エクスポート失敗" "ERROR"
        Write-Log "終了コード: $($step1Result.ExitCode)" "ERROR"
        Write-Log "ファイル存在: $($step1Result.FileExists)" "ERROR"
        Write-Log "ファイルサイズ: $($step1Result.FileSize) bytes" "ERROR"
        throw "STEP1 エクスポート失敗"
    }
} catch {
    Write-Log "STEP1 でエラーが発生: $_" "ERROR"
    exit 1
}

# ========================================
# STEP2: ファイルを本番機へ転送
# ========================================
Write-Log "" "INFO"
Write-Log "========================================" "INFO"
Write-Log "STEP2: JP1開発機からJP1本番機へファイル移動" "INFO"
Write-Log "========================================" "INFO"

try {
    # セッション作成
    Write-Log "開発機へ接続中: $devServer ($devLoginUser)" "INFO"
    $devSession = New-PSSession -ComputerName $devServer -Credential $devLoginCredential
    
    Write-Log "本番機へ接続中: $prodServer ($prodLoginUser)" "INFO"
    $prodSession = New-PSSession -ComputerName $prodServer -Credential $prodLoginCredential
    
    Write-Log "リモートセッション作成完了" "SUCCESS"
    
    # 開発機からファイル取得
    $localTempFile = "$env:TEMP\$exportFileName"
    Write-Log "開発機からダウンロード中..." "INFO"
    Copy-Item -FromSession $devSession -Path "D:\ajsprint\$exportFileName" -Destination $localTempFile
    
    $localFileSize = (Get-Item $localTempFile).Length
    Write-Log "開発機からダウンロード完了: $localTempFile" "SUCCESS"
    Write-Log "ファイルサイズ: $localFileSize bytes" "INFO"
    
    # 本番機のインポートディレクトリ作成
    $prodImportDir = "D:\JP1\JP1AMR3\import\$locationName"
    Write-Log "本番機のインポートディレクトリ確認中: $prodImportDir" "INFO"
    
    $dirResult = Invoke-Command -Session $prodSession -ScriptBlock {
        param($dir)
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            return "ディレクトリ新規作成"
        } else {
            return "ディレクトリ既存"
        }
    } -ArgumentList $prodImportDir
    
    Write-Log "$dirResult : $prodImportDir" "INFO"
    
    # 本番機へアップロード
    Write-Log "本番機へアップロード中..." "INFO"
    Copy-Item -ToSession $prodSession -Path $localTempFile -Destination "$prodImportDir\$exportFileName"
    
    # アップロード確認
    $uploadVerify = Invoke-Command -Session $prodSession -ScriptBlock {
        param($file)
        if (Test-Path $file) {
            return @{
                Exists = $true
                Size = (Get-Item $file).Length
            }
        } else {
            return @{
                Exists = $false
                Size = 0
            }
        }
    } -ArgumentList "$prodImportDir\$exportFileName"
    
    if ($uploadVerify.Exists) {
        Write-Log "本番機へアップロード完了: $prodImportDir\$exportFileName" "SUCCESS"
        Write-Log "アップロード後サイズ: $($uploadVerify.Size) bytes" "INFO"
    } else {
        throw "本番機へのファイルアップロードが確認できません"
    }
    
    # ローカル一時ファイル削除
    Remove-Item $localTempFile -Force
    Write-Log "ローカル一時ファイル削除完了" "INFO"
    
} catch {
    Write-Log "STEP2 でエラーが発生: $_" "ERROR"
    if ($devSession) { Remove-PSSession $devSession }
    if ($prodSession) { Remove-PSSession $prodSession }
    exit 1
}

# ========================================
# STEP3: JP1本番機でIMPジョブGroupを作成
# ========================================
Write-Log "" "INFO"
Write-Log "========================================" "INFO"
Write-Log "STEP3: JP1本番機でIMPジョブGroupを作成" "INFO"
Write-Log "========================================" "INFO"

try {
    $step3Result = Invoke-Command -Session $prodSession -ScriptBlock {
        param($jp1User, $jp1Pass)
        
        # 定義ファイル作成
        $defineFile = "D:\temp\IMP_group.txt"
        $defineContent = "unit=g,/IMP;"
        
        $tempDir = "D:\temp"
        if (-not (Test-Path $tempDir)) {
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        }
        
        # Shift-JIS エンコーディングで保存
        $sjisEncoding = [System.Text.Encoding]::GetEncoding("Shift_JIS")
        [System.IO.File]::WriteAllText($defineFile, $defineContent, $sjisEncoding)
        
        # スケジュールタスクで実行
        $taskName = "JP1_IMP_Creation_Temp_$(Get-Date -Format 'HHmmss')"
        $action = New-ScheduledTaskAction -Execute "D:\JP1\JP1AJS2\bin\ajsdefine.exe" `
                                           -Argument "`"$defineFile`"" `
                                           -WorkingDirectory "D:\JP1\JP1AJS2\bin"
        
        # 既存タスク削除
        $existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        if ($existingTask) {
            Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
        }
        
        # タスク登録
        Register-ScheduledTask -TaskName $taskName `
                              -Action $action `
                              -User $jp1User `
                              -Password $jp1Pass `
                              -RunLevel Highest `
                              -Force | Out-Null
        
        # タスク実行
        Start-ScheduledTask -TaskName $taskName
        
        # 完了待機
        $timeout = 30
        $elapsed = 0
        while ((Get-ScheduledTask -TaskName $taskName).State -ne 'Ready' -and $elapsed -lt $timeout) {
            Start-Sleep -Seconds 1
            $elapsed++
        }
        
        # タスク結果取得
        $taskInfo = Get-ScheduledTaskInfo -TaskName $taskName
        $exitCode = $taskInfo.LastTaskResult
        
        # タスク削除
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
        
        return @{
            Success = ($exitCode -eq 0)
            ExitCode = $exitCode
        }
        
    } -ArgumentList $prodJp1User, $prodJp1Password
    
    if ($step3Result.Success) {
        Write-Log "IMPジョブグループ作成成功" "SUCCESS"
        Write-Log "終了コード: $($step3Result.ExitCode)" "INFO"
    } elseif ($step3Result.ExitCode -eq 267009) {
        # JP1のエラーコード: 既に存在する場合
        Write-Log "IMPジョブグループは既に存在します（スキップ）" "WARNING"
        Write-Log "終了コード: $($step3Result.ExitCode)" "WARNING"
    } else {
        Write-Log "IMPジョブグループ作成失敗" "WARNING"
        Write-Log "終了コード: $($step3Result.ExitCode)" "WARNING"
        Write-Log "既に存在する可能性があるため処理を継続します" "INFO"
    }
} catch {
    Write-Log "STEP3 でエラーが発生: $_" "ERROR"
    Write-Log "処理を継続します" "WARNING"
}

# ========================================
# STEP4: JP1本番機へインポート
# ========================================
Write-Log "" "INFO"
Write-Log "========================================" "INFO"
Write-Log "STEP4: JP1本番機へインポート" "INFO"
Write-Log "========================================" "INFO"

try {
    $step4Result = Invoke-Command -Session $prodSession -ScriptBlock {
        param($jp1User, $jp1Pass, $locationName, $exportFileName)
        
        $importFile = "D:\JP1\JP1AMR3\import\$locationName\$exportFileName"
        
        # ファイル存在確認
        if (-not (Test-Path $importFile)) {
            return @{
                Success = $false
                ExitCode = -1
                Error = "インポートファイルが見つかりません: $importFile"
            }
        }
        
        # 作業ディレクトリ作成
        $workDir = "D:\JP1\JP1AMR3\Import\$locationName"
        if (-not (Test-Path $workDir)) {
            New-Item -ItemType Directory -Path $workDir -Force | Out-Null
        }
        
        # PowerShellスクリプトを作成
        $scriptContent = @"
Set-Location 'D:\JP1\JP1AMR3\Import\${locationName}'
`$result = & D:\JP1\JP1AJS2\bin\ajsdefine.exe -d /IMP '$importFile' 2>&1
Write-Output `$result
exit `$LASTEXITCODE
"@
        $scriptFile = "D:\temp\import_script_$(Get-Date -Format 'HHmmss').ps1"
        [System.IO.File]::WriteAllText($scriptFile, $scriptContent, [System.Text.Encoding]::UTF8)
        
        # スケジュールタスクで実行
        $taskName = "JP1_Import_Temp_$(Get-Date -Format 'HHmmss')"
        $action = New-ScheduledTaskAction -Execute "powershell.exe" `
                                           -Argument "-ExecutionPolicy Bypass -File `"$scriptFile`"" `
                                           -WorkingDirectory $workDir
        
        # 既存タスク削除
        $existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        if ($existingTask) {
            Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
        }
        
        # タスク登録
        Register-ScheduledTask -TaskName $taskName `
                              -Action $action `
                              -User $jp1User `
                              -Password $jp1Pass `
                              -RunLevel Highest `
                              -Force | Out-Null
        
        # タスク実行
        Start-ScheduledTask -TaskName $taskName
        
        # 完了待機
        $timeout = 120
        $elapsed = 0
        while ((Get-ScheduledTask -TaskName $taskName).State -ne 'Ready' -and $elapsed -lt $timeout) {
            Start-Sleep -Seconds 1
            $elapsed++
        }
        
        # タスク結果取得
        $taskInfo = Get-ScheduledTaskInfo -TaskName $taskName
        $exitCode = $taskInfo.LastTaskResult
        
        # タスク削除
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
        
        # 一時スクリプト削除
        if (Test-Path $scriptFile) {
            Remove-Item $scriptFile -Force
        }
        
        return @{
            Success = ($exitCode -eq 0)
            ExitCode = $exitCode
            ImportFile = $importFile
        }
        
    } -ArgumentList $prodJp1User, $prodJp1Password, $locationName, $exportFileName
    
    if ($step4Result.Success) {
        Write-Log "インポート成功" "SUCCESS"
        Write-Log "ファイル: $($step4Result.ImportFile)" "INFO"
        Write-Log "終了コード: $($step4Result.ExitCode)" "INFO"
    } else {
        Write-Log "インポート失敗" "ERROR"
        Write-Log "終了コード: $($step4Result.ExitCode)" "ERROR"
        if ($step4Result.Error) {
            Write-Log "エラー詳細: $($step4Result.Error)" "ERROR"
        }
        throw "STEP4 インポート失敗"
    }
} catch {
    Write-Log "STEP4 でエラーが発生: $_" "ERROR"
    Remove-PSSession $devSession
    Remove-PSSession $prodSession
    exit 1
}

# セッションクリーンアップ
Remove-PSSession $devSession
Remove-PSSession $prodSession

Write-Log "" "INFO"
Write-Log "========================================" "INFO"
Write-Log "すべての処理が正常に完了しました！" "SUCCESS"
Write-Log "========================================" "INFO"
Write-Log "開発機: $devServer" "INFO"
Write-Log "本番機: $prodServer" "INFO"
Write-Log "拠点名: $locationName" "INFO"
Write-Log "エクスポートファイル: $exportFileName" "INFO"
Write-Log "ログファイル: $logFile" "INFO"
Write-Log "========================================" "INFO"

# ログファイルを開く
notepad $logFile
```

---

## **設定箇所（スクリプト冒頭を編集）**

```powershell
# JP1開発機設定
$devServer = "10.194.229.89"
$devLoginUser = "eyadmin"
$devLoginPassword = "eyadminのパスワード"
$devJp1User = "jp1_admin"
$devJp1Password = "開発機jp1_adminのパスワード"

# JP1本番機設定
$prodServer = "10.194.229.84"
$prodLoginUser = "admin"
$prodLoginPassword = "adminのパスワード"
$prodJp1User = "jp1_admin"
$prodJp1Password = "本番機jp1_adminのパスワード"

# 共通設定
$locationName = "DAV"
```

---

## **実行方法**

### **方法1：直接実行**
```powershell
powershell -ExecutionPolicy Bypass -File jp1-auto-deploy.ps1
```

### **方法2：バッチファイル作成**

`jp1-deploy.bat`：
```batch
@echo off
echo ========================================
echo JP1 自動デプロイツール
echo ========================================
echo.
echo 開発機: 10.194.229.89 (eyadmin)
echo 本番機: 10.194.229.84 (admin)
echo 拠点名: DAV
echo.
pause
powershell -ExecutionPolicy Bypass -File "%~dp0jp1-auto-deploy.ps1"
pause
```

このスクリプトで各サーバーの異なるユーザー・パスワードに対応できます。実行してみてください！
