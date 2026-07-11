

```batch
# 按Win + ↑（上方向键）：将当前窗口最大化。
Start-Sleep -Seconds 1
$wshell.SendKeys("^{UP}")
# Login to the website
Start-Sleep -Seconds 1
$wshell.SendKeys("{ENTER}")

# # Windows11 Ctrl + Vでクリップボードの内容を貼り付ける
# $wshell.SendKeys("^(v)")

# # Windows11 Ctrl + Sで保存する
# $wshell.SendKeys("^(s)")
# # Windows11 Ctrl + Aで選択する
# $wshell.SendKeys("^(a)")

# 打开主主页面。
Invoke-MouseClick -X $ClickX -Y $ClickY

# 读取这个 file 的值，是一个，只有一行。
$ITPMValue = Get-Content "C:\\Users\\whz\\Desktop\\ITPM.txt"

# 输出到屏幕里头
Write-Host "ITPM Value: $ITPMValue"

Start-Sleep -Seconds 2

# 打开简易检索。
Invoke-MouseClick -X 302 -Y 262
Start-Sleep -Seconds 2
Invoke-MouseClick -X 611 -Y 529
Start-Sleep -Seconds 2
$wshell.SendKeys($ITPMValue)
Start-Sleep -Seconds 2

$wshell.SendKeys("{ENTER}")
```



