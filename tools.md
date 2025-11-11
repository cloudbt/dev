Screen Never Lockout

```
# 環境変数の確認
$strikkeyflag = 'off'
if ($strikkeyflag -eq 'on') {
    Write-Host "Screen Never Lockout"
    # 環境変数をoffに変更
    [Environment]::SetEnvironmentVariable("strikkeyflag", "off", "User")
    # PowerShell自己プロセスを終了
    Get-Process -Name "powershell" -ErrorAction SilentlyContinue | Where-Object { $_.Id -ne $PID } | Stop-Process -Force
} else {
    Write-Host "Screen Never Lockout"
    # 環境変数をonに設定
    [Environment]::SetEnvironmentVariable("strikkeyflag", "on", "User")
    # Sendkeysを使うためのアセンブリをロード
    Add-Type -AssemblyName System.Windows.Forms

    # ScrollLockキーを送信
    [System.Windows.Forms.SendKeys]::SendWait("{SCROLLLOCK}")

    # 2分間待機（120000ミリ秒 = 120秒）
    Start-Sleep -Seconds 120
}
while ($true)

```
