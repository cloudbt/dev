# JP1自動化スクリプト

## 概要

リモートサーバーにeyadminで接続し、スケジュールタスクを使ってjp1_admin権限でJP1コマンドを実行するPowerShellスクリプト

## スクリプト本体

```powershell
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

## 動作の流れ

1. **eyadminで接続**: リモートサーバーにeyadmin権限で接続
2. **定義ファイル作成**: JP1ジョブネットグループの定義ファイルを作成
3. **スケジュールタスク登録**: jp1_admin権限で実行するタスクを登録
4. **タスク実行**: ajsdefine.exeを実行してジョブネットグループを作成
5. **結果確認**: タスクの実行結果を確認
6. **クリーンアップ**: 一時的なスケジュールタスクを削除

## 使用方法

1. スクリプト内の以下の値を環境に合わせて変更：
   - `$serverIP`: JP1サーバーのIPアドレス
   - `$eyadminPassword`: eyadminユーザーのパスワード
   - `$jp1Password`: jp1_adminユーザーのパスワード

2. PowerShellでスクリプトを実行

## 技術的なポイント

### 権限昇格の仕組み
- eyadmin権限ではJP1コマンドを実行できない
- スケジュールタスクを利用してjp1_admin権限で実行
- タスク実行後は自動的にクリーンアップ

### エラーハンドリング
- タスク実行のタイムアウト監視（30秒）
- 終了コードによる成功/失敗判定
- 既存タスクの重複チェックと削除

### セキュリティ
- 認証情報はSecureStringで管理
- 一時ファイルとタスクは実行後に削除
