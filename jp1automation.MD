このエラーは **PowerShell Remoting の二重ホップ問題（Double-Hop Problem）** が原因です。リモートセッション内で `Start-Process -Credential` を使用すると、アクセス拒否されます。

## **解決方法1：CredSSP 認証を使用（推奨）**

### **設定手順**

#### **1. クライアント側（Windows 11）で設定：**

管理者権限で PowerShell を開く：

```powershell
# CredSSP を有効化
Enable-WSManCredSSP -Role Client -DelegateComputer "10.194.229.189" -Force

# または、すべてのコンピュータに対して
# Enable-WSManCredSSP -Role Client -DelegateComputer "*" -Force
```

#### **2. サーバー側（10.194.229.189）で設定：**

サーバーにログインして、管理者権限で実行：

```powershell
# CredSSP を有効化
Enable-WSManCredSSP -Role Server -Force
```

#### **3. スクリプトを修正：**

接続時に `-Authentication CredSSP` を追加：

```powershell
# 認証情報
$jp1User = "jp1_admin"
$jp1Password = "パスワード"
$serverIP = "10.194.229.189"
$serverAdminPassword = "サーバーのパスワード"

# 認証情報作成
$serverSecurePass = ConvertTo-SecureString $serverAdminPassword -AsPlainText -Force
$serverCredential = New-Object System.Management.Automation.PSCredential ("Administrator", $serverSecurePass)

# CredSSP 認証でリモート接続
Invoke-Command -ComputerName $serverIP -Credential $serverCredential -Authentication CredSSP -ScriptBlock {
    param($user, $pass)
    
    # 定義ファイル作成
    $defineFile = "D:\temp\IMP_group.txt"
    $defineContent = "unit=g,/IMP,,,,,,,,,,,,,,,,,,,,,,,;"
    
    $tempDir = "D:\temp"
    if (-not (Test-Path $tempDir)) {
        New-Item -ItemType Directory -Path $tempDir -Force
    }
    
    Set-Content -Path $defineFile -Value $defineContent -Encoding Default
    Write-Host "定義ファイル作成: $defineFile"
    
    # jp1_admin として ajsdefine 実行
    $secPass = ConvertTo-SecureString $pass -AsPlainText -Force
    $cred = New-Object System.Management.Automation.PSCredential ($user, $secPass)
    
    $scriptBlock = {
        param($file)
        Set-Location "D:\JP1\jp1ajs2\bin"
        & .\ajsdefine.exe $file
    }
    
    Start-Process powershell -Credential $cred -ArgumentList "-Command", "& {$scriptBlock} -file '$defineFile'" -Wait -NoNewWindow
    
    Write-Host "ジョブネットグループ 'IMP' 作成完了"
    
} -ArgumentList $jp1User, $jp1Password
```

---

## **解決方法2：PsExec を使用（CredSSP設定不要）**

PsExec は Sysinternals のツールですが、Windows に標準で入っていません。しかし、軽量で設定不要です。

```powershell
# サーバーで PsExec をダウンロード・実行
Invoke-Command -ComputerName $serverIP -Credential $serverCredential -ScriptBlock {
    param($user, $pass)
    
    # 定義ファイル作成
    $defineFile = "D:\temp\IMP_group.txt"
    $defineContent = "unit=g,/IMP,,,,,,,,,,,,,,,,,,,,,,,;"
    Set-Content -Path $defineFile -Value $defineContent -Encoding Default
    
    # PsExec で実行（存在する場合）
    $psexec = "C:\tools\PsExec.exe"
    if (Test-Path $psexec) {
        & $psexec -u $user -p $pass -accepteula cmd /c "cd /D D:\JP1\jp1ajs2\bin && ajsdefine.exe $defineFile"
    } else {
        Write-Host "PsExec が見つかりません"
    }
    
} -ArgumentList $jp1User, $jp1Password
```

---

## **解決方法3：スケジュールタスク経由（最も安全）**

```powershell
Invoke-Command -ComputerName $serverIP -Credential $serverCredential -ScriptBlock {
    param($user, $pass)
    
    # 定義ファイル作成
    $defineFile = "D:\temp\IMP_group.txt"
    $defineContent = "unit=g,/IMP,,,,,,,,,,,,,,,,,,,,,,,;"
    Set-Content -Path $defineFile -Value $defineContent -Encoding Default
    
    # 一時的なスケジュールタスクを作成
    $taskName = "JP1_IMP_Creation_" + (Get-Date -Format "yyyyMMddHHmmss")
    $action = New-ScheduledTaskAction -Execute "D:\JP1\jp1ajs2\bin\ajsdefine.exe" -Argument "$defineFile" -WorkingDirectory "D:\JP1\jp1ajs2\bin"
    
    $secPass = ConvertTo-SecureString $pass -AsPlainText -Force
    $cred = New-Object System.Management.Automation.PSCredential ($user, $secPass)
    
    Register-ScheduledTask -TaskName $taskName -Action $action -User $user -Password $pass -RunLevel Highest -Force
    
    # タスク実行
    Start-ScheduledTask -TaskName $taskName
    
    # 完了待機
    Start-Sleep -Seconds 5
    
    # タスク削除
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    
    Write-Host "ジョブネットグループ 'IMP' 作成完了"
    
} -ArgumentList $jp1User, $jp1Password
```

---

## **最も簡単な解決方法：CredSSP を使う**

**まず試してください：**

1. Windows 11 で実行：
```powershell
Enable-WSManCredSSP -Role Client -DelegateComputer "10.194.229.189" -Force
```

2. サーバー（10.194.229.189）で実行：
```powershell
Enable-WSManCredSSP -Role Server -Force
```

3. 修正したスクリプトを実行

これで解決するはずです。CredSSP 設定が難しい場合は、**解決方法3（スケジュールタスク）** が最も安定しています。

どの方法を試しますか?


はい、実現可能です！PowerShell Remoting を使って完全自動化できます。

## **完全自動化スクリプト**

`jp1-auto-export-import.ps1` を作成：

```powershell
# ===== 設定 =====
$devServer = "192.168.0.211"      # JP1開発機のIP
$prodServer = "192.168.0.212"     # JP1本番機のIP
$jp1User = "jp1_admin"
$jp1Password = "パスワード"       # jp1_admin のパスワード
$serverAdminPassword = "サーバーのAdministratorパスワード"

# 日付フォーマット (YYYYMMDD)
$dateStr = Get-Date -Format "yyyyMMdd"
$exportFileName = "${dateStr}_DAV.txt"

# 認証情報作成
$jp1SecurePass = ConvertTo-SecureString $jp1Password -AsPlainText -Force
$jp1Credential = New-Object System.Management.Automation.PSCredential ($jp1User, $jp1SecurePass)

$serverSecurePass = ConvertTo-SecureString $serverAdminPassword -AsPlainText -Force
$serverCredential = New-Object System.Management.Automation.PSCredential ("Administrator", $serverSecurePass)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "STEP 1: JP1開発機からエクスポート" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan

# 開発機でエクスポート実行
Invoke-Command -ComputerName $devServer -Credential $serverCredential -ScriptBlock {
    param($user, $pass, $fileName)
    
    $exportPath = "D:\ajsprint\$fileName"
    $exportDir = "D:\ajsprint"
    
    # ディレクトリ作成
    if (-not (Test-Path $exportDir)) {
        New-Item -ItemType Directory -Path $exportDir -Force
    }
    
    Write-Host "エクスポート開始: $exportPath"
    
    # PowerShell で jp1_admin として実行
    $secPass = ConvertTo-SecureString $pass -AsPlainText -Force
    $cred = New-Object System.Management.Automation.PSCredential ($user, $secPass)
    
    $scriptBlock = {
        param($outFile)
        Set-Location "D:\jp1\jp1ajs2\bin"
        & .\ajsprint.exe -a /DAV/Release > $outFile
    }
    
    Start-Process powershell -Credential $cred -ArgumentList "-Command", "& {$scriptBlock} -outFile '$exportPath'" -Wait -NoNewWindow
    
    Write-Host "エクスポート完了: $exportPath"
    return $exportPath
    
} -ArgumentList $jp1User, $jp1Password, $exportFileName

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "STEP 2: ファイルを本番機へ転送" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan

# セッション作成
$devSession = New-PSSession -ComputerName $devServer -Credential $serverCredential
$prodSession = New-PSSession -ComputerName $prodServer -Credential $serverCredential

# 開発機からファイル取得
$localTempFile = "$env:TEMP\$exportFileName"
Copy-Item -FromSession $devSession -Path "D:\ajsprint\$exportFileName" -Destination $localTempFile

Write-Host "ローカルへダウンロード完了: $localTempFile"

# 本番機へアップロード
$prodImportDir = "D:\JP1\JP1AMR3\import\DAV"
Invoke-Command -Session $prodSession -ScriptBlock {
    param($dir)
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force
    }
} -ArgumentList $prodImportDir

Copy-Item -ToSession $prodSession -Path $localTempFile -Destination "$prodImportDir\$exportFileName"

Write-Host "本番機へアップロード完了: $prodImportDir\$exportFileName"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "STEP 3: JP1本番機でインポート" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan

# 本番機でインポート実行
Invoke-Command -Session $prodSession -ScriptBlock {
    param($user, $pass, $fileName)
    
    Write-Host "インポート開始: $fileName"
    
    # PowerShell で jp1_admin として実行
    $secPass = ConvertTo-SecureString $pass -AsPlainText -Force
    $cred = New-Object System.Management.Automation.PSCredential ($user, $secPass)
    
    $scriptBlock = {
        param($file)
        Set-Location "D:\JP1\jp1AMR3\Import"
        & .\ajsdefine.exe -d /IMP $file
    }
    
    $importFile = "D:\JP1\JP1AMR3\import\DAV\$fileName"
    Start-Process powershell -Credential $cred -ArgumentList "-Command", "& {$scriptBlock} -file '$importFile'" -Wait -NoNewWindow
    
    Write-Host "インポート完了"
    
} -ArgumentList $jp1User, $jp1Password, $exportFileName

# セッションクリーンアップ
Remove-PSSession $devSession
Remove-PSSession $prodSession

# ローカル一時ファイル削除
Remove-Item $localTempFile -Force

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "すべての処理が完了しました！" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
```

## **使い方**

1. スクリプトを保存
2. 管理者権限で PowerShell を開く
3. 実行：
```powershell
powershell -ExecutionPolicy Bypass -File jp1-auto-export-import.ps1
```

---

## **さらに簡単に：バッチファイルでラッパー**

`jp1-auto.bat` を作成：

```batch
@echo off
powershell -ExecutionPolicy Bypass -File "%~dp0jp1-auto-export-import.ps1"
pause
```

これで `.bat` ファイルをダブルクリックするだけで自動実行できます。

---

## **注意点**

1. **パス確認**：スクリプト内のパスが実際のサーバー環境と一致するか確認してください
   - `D:\jp1\jp1ajs2\bin` (開発機)
   - `D:\JP1\JP1AMR3\import` (本番機)

2. **抛点名**：スクリプトでは `DAV` としていますが、必要に応じて変更してください

3. **エラーハンドリング**：必要に応じて追加可能です

実行してみて、エラーが出たら教えてください！



JP1でジョブネットグループ（Jobnet Group）を作成する方法は以下の通りです：

## **方法1：ajsdefine コマンドで直接作成**

### **定義ファイルを作成**

`IMP_group.txt` を作成：

```text
unit=g,IMP,,,,,,,,,,,,,,,,,,,,,,,;
```

### **インポート実行**

```batch
runas /user:jp1_admin cmd
cd /D D:\JP1\jp1ajs2\bin
ajsdefine IMP_group.txt
```

---

## **方法2：PowerShellで自動化**

```powershell
# 認証情報
$jp1User = "jp1_admin"
$jp1Password = "パスワード"
$serverIP = "192.168.0.211"  # JP1サーバーのIP

# サーバー管理者パスワード
$serverAdminPassword = "サーバーのパスワード"

# 認証情報作成
$serverSecurePass = ConvertTo-SecureString $serverAdminPassword -AsPlainText -Force
$serverCredential = New-Object System.Management.Automation.PSCredential ("Administrator", $serverSecurePass)

# リモートで実行
Invoke-Command -ComputerName $serverIP -Credential $serverCredential -ScriptBlock {
    param($user, $pass)
    
    # 定義ファイル作成
    $defineFile = "D:\temp\IMP_group.txt"
    $defineContent = "unit=g,IMP,,,,,,,,,,,,,,,,,,,,,,,;"
    
    # ディレクトリ作成
    $tempDir = "D:\temp"
    if (-not (Test-Path $tempDir)) {
        New-Item -ItemType Directory -Path $tempDir -Force
    }
    
    # ファイル出力
    Set-Content -Path $defineFile -Value $defineContent -Encoding Default
    
    Write-Host "定義ファイル作成: $defineFile"
    
    # jp1_admin として ajsdefine 実行
    $secPass = ConvertTo-SecureString $pass -AsPlainText -Force
    $cred = New-Object System.Management.Automation.PSCredential ($user, $secPass)
    
    $scriptBlock = {
        param($file)
        Set-Location "D:\JP1\jp1ajs2\bin"
        & .\ajsdefine.exe $file
    }
    
    Start-Process powershell -Credential $cred -ArgumentList "-Command", "& {$scriptBlock} -file '$defineFile'" -Wait -NoNewWindow
    
    Write-Host "ジョブネットグループ 'IMP' 作成完了"
    
} -ArgumentList $jp1User, $jp1Password
```

---

## **方法3：より詳細な定義で作成**

親ユニット（例：`/DAV`）配下に作成する場合：

`IMP_group_detail.txt`：

```text
unit=g,/DAV/IMP,"IMPジョブネットグループ","","n","","","","","",\
"","","","","","","","","","","","","";
```

実行：
```batch
cd /D D:\JP1\jp1ajs2\bin
ajsdefine IMP_group_detail.txt
```

---

## **方法4：既存の自動化スクリプトに組み込む**

先ほどのスクリプトの **STEP 2と3の間** に追加：

```powershell
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "STEP 2.5: ジョブネットグループ 'IMP' 作成確認" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan

Invoke-Command -Session $prodSession -ScriptBlock {
    param($user, $pass)
    
    # 定義ファイル作成
    $defineFile = "D:\JP1\JP1AMR3\import\IMP_group.txt"
    $defineContent = "unit=g,/IMP,,,,,,,,,,,,,,,,,,,,,,,;"
    Set-Content -Path $defineFile -Value $defineContent -Encoding Default
    
    Write-Host "ジョブネットグループ定義ファイル作成"
    
    # jp1_admin として実行
    $secPass = ConvertTo-SecureString $pass -AsPlainText -Force
    $cred = New-Object System.Management.Automation.PSCredential ($user, $secPass)
    
    $scriptBlock = {
        param($file)
        Set-Location "D:\JP1\jp1ajs2\bin"
        
        # 既存確認（エラーが出ても続行）
        $null = & .\ajsprint.exe -a /IMP 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "ジョブネットグループ 'IMP' は存在しないため、新規作成します"
            & .\ajsdefine.exe $file
        } else {
            Write-Host "ジョブネットグループ 'IMP' は既に存在します"
        }
    }
    
    Start-Process powershell -Credential $cred -ArgumentList "-Command", "& {$scriptBlock} -file '$defineFile'" -Wait -NoNewWindow
    
} -ArgumentList $jp1User, $jp1Password
```

---

## **確認コマンド**

作成後、確認：
```batch
cd /D D:\JP1\jp1ajs2\bin
ajsprint -a /IMP
```

どの方法が一番使いやすいですか？スクリプトに組み込む場合はお知らせください！
