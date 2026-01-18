# Windows Remote Management Scripts

## WinRM設定スクリプト

管理者権限で実行する必要があります

```powershell
# WinRMサービスを起動
net start WinRM

# 直接创建並設置 TrustedHosts
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "192.168.0.211" -Force

# 験証是否設置成功
Get-Item WSMan:\localhost\Client\TrustedHosts

# ネットワーク接続テスト
Test-NetConnection -ComputerName 192.168.0.211 -Port 5985

# 重啓 WinRM 服務使配置生效
Restart-Service WinRM
```

## PowerShell Remoting接続スクリプト

```powershell
# 配置信息
$serverIP = "192.168.0.211"
$username = "Administrator"  # 如果是域用戶，格式為 "DOMAIN\Username"
$password = "你的密码"

# 創建憑據
$securePassword = ConvertTo-SecureString $password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential ($username, $securePassword)

# 連接
Enter-PSSession -ComputerName $serverIP -Credential $credential -Authentication Negotiate
```

## RDP自動登録スクリプト

### rdp-login.bat

```batch
@echo off
cmdkey /generic:TERMSRV/192.168.0.211 /user:Administrator /pass:你的密码
start mstsc /v:192.168.0.211
timeout /t 3 >nul
cmdkey /delete:TERMSRV/192.168.0.211
```

### rdp-login.ps1

```powershell
# rdp-login.ps1
$server = "192.168.1.100"
$username = "Administrator"
$password = "YourPassword"

# 臨時添加憑據
Start-Process cmdkey -ArgumentList "/generic:TERMSRV/$server /user:$username /pass:$password" -Wait -NoNewWindow

# 啓動 RDP
Start-Process mstsc -ArgumentList "/v:$server"

# 等待5秒後削除憑據（可選）
Start-Sleep -Seconds 5
Start-Process cmdkey -ArgumentList "/delete:TERMSRV/$server" -NoNewWindow
```

## 使用方法

### WinRM設定
1. 管理者権限でPowerShellを起動
2. WinRM設定スクリプトを実行
3. TrustedHostsに接続先IPアドレスを追加
4. WinRMサービスを再起動

### PowerShell Remoting
1. 接続情報（IP、ユーザー名、パスワード）を設定
2. スクリプトを実行してリモートセッションを開始
3. `Exit-PSSession` でセッションを終了

### RDP自動登録
1. バッチファイルまたはPowerShellスクリプトを選択
2. 接続先情報を編集
3. スクリプトを実行すると自動的にRDP接続が開始
4. セキュリティのため、接続後に認証情報は自動削除

## セキュリティに関する注意

- パスワードをスクリプト内に平文で保存するのは推奨されません
- 本番環境では以下の方法を検討してください：
  - 環境変数からの読み込み
  - 暗号化されたファイルの使用
  - Windows資格情報マネージャーの利用
  - Azure Key Vaultなどのシークレット管理サービス

## トラブルシューティング

### WinRM接続エラー
- ファイアウォールでポート5985（HTTP）または5986（HTTPS）が開いているか確認
- TrustedHostsに接続先が登録されているか確認
- WinRMサービスが起動しているか確認

### RDP接続エラー
- ネットワーク接続を確認
- リモートデスクトップがターゲットマシンで有効になっているか確認
- ファイアウォールでポート3389が開いているか確認
