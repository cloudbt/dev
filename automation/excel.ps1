param(
    # 第一个工作簿名称（默认值：kong.xlsx）
    [string]$workbookIncidentName = "kong.xlsx",
    
    # 第一个工作表名称（默认值：Sheet1）
    [string]$sheetIncidentName = "Sheet1",
    
    # 第二个工作簿名称（默认值：PersonalTaskList_Wang.xlsx）
    [string]$workbookPersionalName = "PersonalTaskList_Wang.xlsx",
    
    # 第二个工作表名称（默认值：Task）
    [string]$sheetPersionalName = "Task"
)

# 显示配置信息
Write-Host "`n当前配置：" -ForegroundColor Cyan
Write-Host "第一个工作簿: $workbookIncidentName" -ForegroundColor Yellow
Write-Host "第一个工作表: $sheetIncidentName" -ForegroundColor Yellow
Write-Host "第二个工作簿: $workbookPersionalName" -ForegroundColor Yellow
Write-Host "第二个工作表: $sheetPersionalName" -ForegroundColor Yellow

# 询问用户是否使用默认配置
$useDefault = Read-Host "`n是否使用上述配置? (Y/N, 默认 Y)"
if ($useDefault -eq "N" -or $useDefault -eq "n") {
    # 允许用户重新输入配置
    $workbookIncidentName = Read-Host "请输入第一个工作簿名称 (默认: kong.xlsx)"
    if ([string]::IsNullOrWhiteSpace($workbookIncidentName)) {
        $workbookIncidentName = "kong.xlsx"
    }
    
    $sheetIncidentName = Read-Host "请输入第一个工作表名称 (默认: Sheet1)"
    if ([string]::IsNullOrWhiteSpace($sheetIncidentName)) {
        $sheetIncidentName = "Sheet1"
    }
    
    $workbookPersionalName = Read-Host "请输入第二个工作簿名称 (默认: PersonalTaskList_Wang.xlsx)"
    if ([string]::IsNullOrWhiteSpace($workbookPersionalName)) {
        $workbookPersionalName = "PersonalTaskList_Wang.xlsx"
    }
    
    $sheetPersionalName = Read-Host "请输入第二个工作表名称 (默认: Task)"
    if ([string]::IsNullOrWhiteSpace($sheetPersionalName)) {
        $sheetPersionalName = "Task"
    }
    
    # 显示更新后的配置
    Write-Host "`n更新后的配置：" -ForegroundColor Cyan
    Write-Host "第一个工作簿: $workbookIncidentName" -ForegroundColor Yellow
    Write-Host "第一个工作表: $sheetIncidentName" -ForegroundColor Yellow
    Write-Host "第二个工作簿: $workbookPersionalName" -ForegroundColor Yellow
    Write-Host "第二个工作表: $sheetPersionalName" -ForegroundColor Yellow
}

# 获取脚本所在目录
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# 在脚本所在目录查找所有TXT文件并存储文件名
$txtFiles = Get-ChildItem -Path $scriptDir -Filter *.txt | Where-Object { $_.Name -notlike "*.ps1" }

if ($txtFiles.Count -eq 0) {
    Write-Host "错误：在脚本所在目录未找到任何TXT文件。" -ForegroundColor Red
    Read-Host "按任意键退出..."
    exit
}

# 存储所有邮件TXT文件名的变量
$allEmailFilenames = $txtFiles | ForEach-Object { $_.Name }

# 显示找到的文件数量和文件名
Write-Host "`n在当前目录共找到 $($txtFiles.Count) 个邮件TXT文件：" -ForegroundColor Cyan
$allEmailFilenames | ForEach-Object { Write-Host "- $_" }

# 创建一个数组存储所有邮件的数据
$allEmailData = @()

# 依次处理每个TXT文件
foreach ($file in $txtFiles) {
    Write-Host "`n=====================================" -ForegroundColor Green
    Write-Host "正在处理文件：$($file.Name)" -ForegroundColor Green
    Write-Host "=====================================" -ForegroundColor Green

    # 读取文件内容
    try {
        $content = Get-Content -Path $file.FullName -Raw -Encoding UTF8 -ErrorAction Stop
    } catch {
        Write-Host "无法读取文件 $($file.Name)：$_" -ForegroundColor Red
        continue
    }

    # 定义变量存储提取的信息
    $subject = $null
    $from = $null
    $sentDate = $null
    $body = $null
    $filename = $file.Name

    # 提取主题
    if ($content -match '(?im)^(?:Subject|件名)[\s:：]*\s*(.*?)$') {
        $subject = $matches[1].Trim()
    }

    if ($content -match '(?im)^(?:From|差出人)[\s:：]*\s*(.*?)$') {
        $from = $matches[1].Trim()
    }

    # 提取发送时间
    if ($content -match '(?im)^(?:Sent|送信日時)[\s:：]*\s*(.*?)$') {
        $sentDate = $matches[1].Trim()
    }

    $cultureCN = New-Object System.Globalization.CultureInfo("zh-CN")
    $cultureUS = New-Object System.Globalization.CultureInfo("en-US")

    # 处理每个日期
    foreach ($dateStr in $sentDate) {
        try {
            # 尝试解析中文日期格式（带星期）
            if ($dateStr -match '(\d{4})年(\d{1,2})月(\d{1,2})日') {
                $year = $matches[1]
                $month = $matches[2]
                $day = $matches[3]
                $formattedDate = "$year/$month/$day"
            }
            # 尝试解析英文日期格式
            elseif ($dateStr -match '([A-Za-z]+),([A-Za-z]+)(\d+)[，,](\d{4})') {
                $monthName = $matches[2]
                $day = $matches[3].Trim()
                $year = $matches[4]
                
                # 将月份名称转换为数字
                $month = [DateTime]::ParseExact($monthName, "MMMM", $cultureUS).Month
                $formattedDate = "$year/$month/$day"
            }
            # 尝试使用系统解析
            else {
                $dateObj = [DateTime]::Parse($dateStr, $cultureCN)
                $formattedDate = $dateObj.ToString("yyyy/M/d")
            }
        }
        catch {
            # 如果所有方法都失败，尝试基本格式提取
            if ($dateStr -match '\b(\d{4})[^\d]*?(\d{1,2})[^\d]*?(\d{1,2})\b') {
                $year = $matches[1]
                $month = $matches[2]
                $day = $matches[3]
                $formattedDate = "$year/$month/$day"
            }
            else {
                $formattedDate = "格式无法识别"
            }
        }
        
        Write-Host "原始日期: $dateStr -> 格式化后: $formattedDate"
    }

    # 提取正文内容
    # 匹配所有头部信息，直到遇到连续两个换行符，之后的内容视为正文
    if ($content -match '(?s)(\r?\n){2,}(.*)') {
        $body = $matches[2].Trim()
    } 

    # 提取 System ID
    if ($body -match '(?im)System ID\s*[：:]\s*(\S+)') {
        $systemID = $matches[1]
    }
    # 提取 Env
    if ($systemID -eq "F56") {
        $ENV = "PRD"
    } else {
        $ENV = "QAS-DEV"
    }

    # 提取 System #SAP
    $System = $null
    if ($subject -match '\[Asi-Oce\s+([^\]]+)\]') {
        $System = $matches[1].Trim()
    }

    # 将当前邮件数据添加到数组
    $emailData = [PSCustomObject]@{
        主题 = $subject
        发件人 = $from
        发送时间 = $formattedDate
        SystemID = $systemID
        System = $System
        ENV = $ENV
        正文 = $body
    }
    $allEmailData += $emailData
}

try {
    # 获取当前活动的Excel应用程序实例
    $excel = [Runtime.InteropServices.Marshal]::GetActiveObject("Excel.Application")
    
    # 获取所有打开的工作簿
    $workbooks = $excel.Workbooks
    
    # 查找工作簿
    $workbookIncident = $null
    $workbookPersional = $null
    
    # 使用用户输入的工作簿名称查找
    foreach ($wb in $workbooks) {
        if ($wb.Name -eq $workbookIncidentName) {
            $workbookIncident = $wb
        }
        elseif ($wb.Name -eq $workbookPersionalName) {
            $workbookPersional = $wb
        }
    }
    
    # 检查工作簿是否找到
    if (-not $workbookIncident) {
        throw "未找到已打开的 $workbookIncidentName 工作簿"
    }
    if (-not $workbookPersional) {
        throw "未找到已打开的 $workbookPersionalName 工作簿"
    }
    
    # 获取工作表（使用用户输入的工作表名称）
    $sheetIncident = $workbookIncident.Sheets.Item($sheetIncidentName)
    $sheetPersional = $workbookPersional.Sheets.Item($sheetPersionalName)
    
    Write-Host "`n成功连接到工作簿 [$workbookIncidentName] 的工作表 [$sheetIncidentName]" -ForegroundColor Green
    Write-Host "成功连接到工作簿 [$workbookPersionalName] 的工作表 [$sheetPersionalName]" -ForegroundColor Green

    # 获取第一个工作表的最新行
    $startRowIncident = 4
    while ($sheetIncident.Cells.Item($startRowIncident, 2).Value2 -ne $null -and 
           $sheetIncident.Cells.Item($startRowIncident, 2).Value2 -ne "") {
        $startRowIncident++
    }
    Write-Host "工作表 [$sheetIncidentName] 的最新行: $startRowIncident" -ForegroundColor Yellow

    # 获取第二个工作表的最新行
    $startRowPersional = 2
    while ($sheetPersional.Cells.Item($startRowPersional, 2).Value2 -ne $null -and 
           $sheetPersional.Cells.Item($startRowPersional, 2).Value2 -ne "") {
        $startRowPersional++
    }
    Write-Host "工作表 [$sheetPersionalName] 的最新行: $startRowPersional" -ForegroundColor Yellow

    # 写入数据
    $rowINC = $startRowIncident
    $rowPER = $startRowPersional
    foreach ($data in $allEmailData) {
        $INCnumber = $sheetIncident.Cells.Item($rowINC, 1).Value2 #获取编号
        $sheetIncident.Cells.Item($rowINC, 2).Value2 = $data.System #写入SYSTEM
        $sheetIncident.Cells.Item($rowINC, 3).Value2 = $data.ENV #写入ENV
        $sheetIncident.Cells.Item($rowINC, 6).Value2 = $data.正文 #Request Detail
        $sheetIncident.Cells.Item($rowINC, 8).Value2 = "Raised" #Status
        $sheetIncident.Cells.Item($rowINC, 9).Value2 = $data.发件人 #Requester
        $sheetIncident.Cells.Item($rowINC, 10).Value2 = $data.发送时间
        $rowINC++
        
        $sheetPersional.Cells.Item($rowPER, 1).Value2 = $INCnumber
        $sheetPersional.Cells.Item($rowPER, 2).Value2 = $data.发送时间
        $sheetPersional.Cells.Item($rowPER, 4).Value2 = "Wang"
        $sheetPersional.Cells.Item($rowPER, 5).Value2 = $data.发送时间
        $rowPER++
    }
    
    # 保存工作簿
    $workbookIncident.Save()
    $workbookPersional.Save()
    Write-Host "`n工作簿 [$workbookIncidentName] 和 [$workbookPersionalName] 已保存" -ForegroundColor Green
}
catch {
    Write-Host "`n操作过程中出错: $($_.Exception.Message)" -ForegroundColor Red
    Read-Host "按任意键退出..."
    exit
}
finally {
    # 释放 COM 对象（但不关闭工作簿）
    if ($sheetIncident) { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($sheetIncident) | Out-Null }
    if ($sheetPersional) { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($sheetPersional) | Out-Null }
    if ($workbookIncident) { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($workbookIncident) | Out-Null }
    if ($workbookPersional) { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($workbookPersional) | Out-Null }
    if ($workbooks) { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($workbooks) | Out-Null }
    if ($excel) { [System.Runtime.InteropServices.Marshal]::ReleaseComObject($excel) | Out-Null }
    
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
    
    Write-Host "`n操作完成" -ForegroundColor Green
}

Read-Host "按任意键退出..."
