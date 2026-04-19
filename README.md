```
Set-ExecutionPolicy -Scope Process Bypass
```

```
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class NativeDisplay {
    [DllImport("user32.dll")]
    public static extern bool SetProcessDPIAware();
}
"@

# =========================
# 設定
# =========================

# 保存先
$OutputDir = "C:\work\work-git\git\tools\work-assistant\servicenow\ServiceNowScreenshots"
$ExcelOutputDir = "C:\work\work-git\git\tools\work-assistant\servicenow\ServiceNowScreenshots"

# 1件ごとの待機秒数
$InitialDelaySeconds = 5      # 開始前の猶予。Citrix 画面を前面に出す時間
$PageLoadWaitSeconds = 8      # Enter後の読み込み待機
$BetweenItemsSeconds = 2      # 次の処理までの待機

# Citrix 側ブラウザのアドレスバーに飛ぶ操作
$UseCtrlL = $true

# 画面キャプチャ方法
# "FullScreen" = 画面全体
# "PrimaryScreen" = メインモニタだけ
$CaptureMode = "PrimaryScreen"

# Excel 出力
$ExportToExcel = $true
$OpenExcelAfterCreate = $true
$ExcelSheetName = "Screenshots"
$ExcelMaxImageWidth = 1000

# キャプチャ後の余白除去
$TrimCapturePadding = $true
$TrimColorTolerance = 10
$TrimSampleStep = 8
$TrimMinPaddingPixels = 12

# 実行モード
# "Tables" = Tables から URL を組み立てる
# "CustomUrls" = 完全な URL をそのまま使う
$TargetMode = "CustomUrls"

# ServiceNow の URL ベース
$InstanceBase = "https://dev317783.service-now.com/now/nav/ui/classic/params/target/"

# 固定のクエリ部分
$EncodedSuffix = "%3Fsysparm_query%3Ddiscovery_source%253DSG-AWS%26sysparm_first_row%3D1%26sysparm_view%3D"

# 対象テーブル
$Tables = @(
    "cmdb_ci_vm_instance.list",
    "cmdb_ci_linux_server.list",
    # "cmdb_ci_win_server.list",
    # "cmdb_ci_server.list",
    # "cmdb_ci_endpoint_vnic.list",
    # "cmdb_ci_endpoint_block.list",
    # "cmdb_ci_storage_mapping.list",
    # "cmdb_ci_ip_address.list",
    # "cmdb_ci_network_adapter.list",
    # "cmdb_ci_cloud_gateway.list",
    # "cmdb_ci_aws_datacenter.list",
    # "cmdb_ci_dynamodb_table.list",
    # "cmdb_ci_cloud_load_balancer.list",
    # "cmdb_ci_compute_template.list",
    # "cmdb_ci_os_template.list",
    # "cmdb_ci_cloud_function.list",
    # "cmdb_ci_nic.list",
    # "cmdb_ci_cloud_org.list",
    # "cmdb_ci_cloud_database.list",
    # "cmdb_ci_cloud_object_storage.list",
    # "cmdb_ci_compute_security_group.list",
    # "cmdb_ci_cloud_service_account.list",
    # "cmdb_ci_storage_volume.list",
    # "cmdb_ci_cloud_subnet.list",
    # "cmdb_ci_network.list",
    # "cmdb_ci_cmp_resource.list",
    # "cmdb_ci_availability_zone.list",
    # "cmdb_ci_storage_vol_snapshot.list",
    "cmdb_ci_aws_org_unit.list"
)

# 自宅PCなどでのテスト用
# Name は Excel / ファイル名に使用
# Url には完全な URL をそのまま入れる
$CustomTargets = @(
    @{
        Name = "test_page_01"
        Url  = "https://example.com/"
    },
    @{
        Name = "test_page_02"
        Url  = "https://www.bing.com/"
    },
    @{
        Name = "test_page_03"
        Url  = "https://www.microsoft.com/"
    }
)

# =========================
# 関数
# =========================

function New-OutputDirectory {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Convert-TableToUrl {
    param(
        [string]$TableName,
        [string]$BaseUrl,
        [string]$Suffix
    )

    # 例:
    # cmdb_ci_vm_instance.list
    # -> cmdb_ci_vm_instance_list.do
    $target = $TableName -replace '\.list$', '_list.do'
    return "$BaseUrl$target$Suffix"
}

function Get-CaptureTargets {
    param(
        [string]$Mode,
        [array]$Tables,
        [array]$CustomTargets,
        [string]$BaseUrl,
        [string]$Suffix
    )

    $targets = @()

    if ($Mode -eq "CustomUrls") {
        foreach ($target in $CustomTargets) {
            if (-not $target.Name -or -not $target.Url) {
                Write-Warning "Skipped invalid CustomTargets entry. Both Name and Url are required."
                continue
            }

            $targets += [PSCustomObject]@{
                Name = [string]$target.Name
                Url = [string]$target.Url
            }
        }

        return $targets
    }

    foreach ($table in $Tables) {
        $targets += [PSCustomObject]@{
            Name = [string]$table
            Url = Convert-TableToUrl -TableName $table -BaseUrl $BaseUrl -Suffix $Suffix
        }
    }

    return $targets
}

function Send-KeysSafe {
    param([string]$Keys)

    [System.Windows.Forms.SendKeys]::SendWait($Keys)
    Start-Sleep -Milliseconds 500
}

function Enable-DpiAwareness {
    try {
        [NativeDisplay]::SetProcessDPIAware() | Out-Null
    }
    catch {
        Write-Warning "Failed to enable DPI awareness: $($_.Exception.Message)"
    }
}

function Save-Screenshot {
    param(
        [string]$FilePath,
        [ValidateSet("FullScreen","PrimaryScreen")]
        [string]$Mode = "FullScreen"
    )

    if ($Mode -eq "FullScreen") {
        $virtual = [System.Windows.Forms.SystemInformation]::VirtualScreen
        $bmp = New-Object System.Drawing.Bitmap $virtual.Width, $virtual.Height
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.CopyFromScreen($virtual.Left, $virtual.Top, 0, 0, $bmp.Size)
    }
    else {
        $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
        $bmp = New-Object System.Drawing.Bitmap $bounds.Width, $bounds.Height
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.CopyFromScreen($bounds.Left, $bounds.Top, 0, 0, $bmp.Size)
    }

    $g.Dispose()

    if ($TrimCapturePadding) {
        $trimmed = Get-TrimmedScreenshotBitmap `
            -Bitmap $bmp `
            -Tolerance $TrimColorTolerance `
            -SampleStep $TrimSampleStep `
            -MinPaddingPixels $TrimMinPaddingPixels

        if ($trimmed -ne $bmp) {
            $bmp.Dispose()
            $bmp = $trimmed
        }
    }

    $bmp.Save($FilePath, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
}

function Test-UniformRow {
    param(
        [System.Drawing.Bitmap]$Bitmap,
        [int]$Y,
        [System.Drawing.Color]$BaseColor,
        [int]$Tolerance = 10,
        [int]$SampleStep = 8
    )

    for ($x = 0; $x -lt $Bitmap.Width; $x += [Math]::Max($SampleStep, 1)) {
        $color = $Bitmap.GetPixel($x, $Y)
        if (([Math]::Abs($color.R - $BaseColor.R) -gt $Tolerance) -or
            ([Math]::Abs($color.G - $BaseColor.G) -gt $Tolerance) -or
            ([Math]::Abs($color.B - $BaseColor.B) -gt $Tolerance)) {
            return $false
        }
    }

    return $true
}

function Test-UniformColumn {
    param(
        [System.Drawing.Bitmap]$Bitmap,
        [int]$X,
        [System.Drawing.Color]$BaseColor,
        [int]$Tolerance = 10,
        [int]$SampleStep = 8
    )

    for ($y = 0; $y -lt $Bitmap.Height; $y += [Math]::Max($SampleStep, 1)) {
        $color = $Bitmap.GetPixel($X, $y)
        if (([Math]::Abs($color.R - $BaseColor.R) -gt $Tolerance) -or
            ([Math]::Abs($color.G - $BaseColor.G) -gt $Tolerance) -or
            ([Math]::Abs($color.B - $BaseColor.B) -gt $Tolerance)) {
            return $false
        }
    }

    return $true
}

function Get-TrimmedScreenshotBitmap {
    param(
        [System.Drawing.Bitmap]$Bitmap,
        [int]$Tolerance = 10,
        [int]$SampleStep = 8,
        [int]$MinPaddingPixels = 12
    )

    $trimBottom = 0
    $trimRight = 0

    $bottomBaseColor = $Bitmap.GetPixel(0, $Bitmap.Height - 1)
    for ($y = $Bitmap.Height - 1; $y -ge 0; $y--) {
        if (Test-UniformRow -Bitmap $Bitmap -Y $y -BaseColor $bottomBaseColor -Tolerance $Tolerance -SampleStep $SampleStep) {
            $trimBottom++
        }
        else {
            break
        }
    }

    $rightBaseColor = $Bitmap.GetPixel($Bitmap.Width - 1, $Bitmap.Height - 1)
    for ($x = $Bitmap.Width - 1; $x -ge 0; $x--) {
        if (Test-UniformColumn -Bitmap $Bitmap -X $x -BaseColor $rightBaseColor -Tolerance $Tolerance -SampleStep $SampleStep) {
            $trimRight++
        }
        else {
            break
        }
    }

    if ($trimBottom -lt $MinPaddingPixels) {
        $trimBottom = 0
    }

    if ($trimRight -lt $MinPaddingPixels) {
        $trimRight = 0
    }

    $newWidth = $Bitmap.Width - $trimRight
    $newHeight = $Bitmap.Height - $trimBottom

    if (($newWidth -ge $Bitmap.Width) -and ($newHeight -ge $Bitmap.Height)) {
        return $Bitmap
    }

    if (($newWidth -le 0) -or ($newHeight -le 0)) {
        return $Bitmap
    }

    $rect = New-Object System.Drawing.Rectangle 0, 0, $newWidth, $newHeight
    return $Bitmap.Clone($rect, $Bitmap.PixelFormat)
}

function Optimize-ScreenshotFile {
    param(
        [string]$FilePath,
        [int]$Tolerance = 10,
        [int]$SampleStep = 8,
        [int]$MinPaddingPixels = 12
    )

    if (-not (Test-Path $FilePath)) {
        return
    }

    $bmp = $null
    $trimmed = $null

    try {
        $bmp = [System.Drawing.Bitmap]::FromFile($FilePath)
        $trimmed = Get-TrimmedScreenshotBitmap `
            -Bitmap $bmp `
            -Tolerance $Tolerance `
            -SampleStep $SampleStep `
            -MinPaddingPixels $MinPaddingPixels

        if ($trimmed -ne $bmp) {
            $bmp.Dispose()
            $bmp = $null
            $trimmed.Save($FilePath, [System.Drawing.Imaging.ImageFormat]::Png)
        }
    }
    finally {
        if ($trimmed) {
            $trimmed.Dispose()
        }

        if ($bmp) {
            $bmp.Dispose()
        }
    }
}

function Export-CapturesToExcel {
    param(
        [array]$Captures,
        [string]$ExcelOutputDir,
        [string]$WorksheetName,
        [int]$MaxImageWidth = 1000,
        [bool]$OpenAfterCreate = $true
    )

    if (-not $Captures -or $Captures.Count -eq 0) {
        Write-Warning "No captures to export to Excel."
        return
    }

    New-OutputDirectory -Path $ExcelOutputDir

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $excelPath = Join-Path $ExcelOutputDir "${timestamp}_ServiceNowScreenshots.xlsx"

    $excel = $null
    $workbook = $null
    $worksheet = $null

    try {
        $excel = New-Object -ComObject Excel.Application
        $excel.Visible = $false
        $excel.DisplayAlerts = $false

        $workbook = $excel.Workbooks.Add()
        $worksheet = $workbook.Worksheets.Item(1)
        $worksheet.Name = $WorksheetName

        $worksheet.Columns.Item("A").ColumnWidth = 20
        $worksheet.Columns.Item("B").ColumnWidth = 140

        $currentRow = 1

        foreach ($capture in $Captures) {
            if (-not (Test-Path $capture.FilePath)) {
                Write-Warning "Image not found: $($capture.FilePath)"
                continue
            }

            if ($TrimCapturePadding) {
                Optimize-ScreenshotFile `
                    -FilePath $capture.FilePath `
                    -Tolerance $TrimColorTolerance `
                    -SampleStep $TrimSampleStep `
                    -MinPaddingPixels $TrimMinPaddingPixels
            }

            $worksheet.Cells.Item($currentRow, 1).Value2 = $capture.TableName
            $worksheet.Cells.Item($currentRow, 1).Font.Bold = $true
            $worksheet.Cells.Item($currentRow, 1).Font.Size = 14
            $worksheet.Cells.Item($currentRow, 1).EntireRow.RowHeight = 24
            $currentRow++

            $img = [System.Drawing.Image]::FromFile($capture.FilePath)
            try {
                $targetWidth = [double][Math]::Min($MaxImageWidth, $img.Width)
                $targetHeight = [double]($img.Height * ($targetWidth / $img.Width))
            }
            finally {
                $img.Dispose()
            }

            $top = $worksheet.Cells.Item($currentRow, 2).Top
            $left = $worksheet.Cells.Item($currentRow, 2).Left

            $picture = $worksheet.Shapes.AddPicture(
                $capture.FilePath,
                $false,
                $true,
                $left,
                $top,
                $targetWidth,
                $targetHeight
            )

            $picture.LockAspectRatio = $true

            $rowsUsedByImage = [Math]::Ceiling(($picture.Height + 10) / 20)
            $currentRow += [Math]::Max($rowsUsedByImage, 1) + 2

            [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($picture)
        }

        $worksheet.Range("A:A").VerticalAlignment = -4160
        $worksheet.Range("A:B").EntireColumn.AutoFit() | Out-Null
        $worksheet.Activate() | Out-Null
        $worksheet.Range("A1").Select() | Out-Null
        $excel.ActiveWindow.FreezePanes = $false

        $workbook.SaveAs($excelPath)
        Write-Host "Excel saved: $excelPath" -ForegroundColor Green
    }
    finally {
        if ($workbook) {
            $workbook.Close($true)
            [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($workbook)
        }

        if ($worksheet) {
            [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($worksheet)
        }

        if ($excel) {
            $excel.Quit()
            [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($excel)
        }

        [GC]::Collect()
        [GC]::WaitForPendingFinalizers()
        [GC]::Collect()
        [GC]::WaitForPendingFinalizers()
    }

    if ($OpenAfterCreate -and (Test-Path $excelPath)) {
        Start-Process $excelPath | Out-Null
    }
}

function Invoke-OneCapture {
    param(
        [string]$TableName,
        [string]$Url,
        [string]$OutputDir,
        [int]$PageLoadWaitSeconds,
        [int]$BetweenItemsSeconds,
        [bool]$UseCtrlL,
        [string]$CaptureMode
    )

    Write-Host ""
    Write-Host "Processing: $TableName" -ForegroundColor Cyan
    Write-Host "URL: $Url"

    # クリップボードへ
    Set-Clipboard -Value $Url
    Start-Sleep -Milliseconds 500

    # アドレスバーへ
    if ($UseCtrlL) {
        Send-KeysSafe "^(l)"
    }

    # 貼り付け
    Send-KeysSafe "^(v)"

    # Enter
    Send-KeysSafe "{ENTER}"

    # 読み込み待機
    Write-Host "Waiting $PageLoadWaitSeconds sec for page load..."
    Start-Sleep -Seconds $PageLoadWaitSeconds

    # 保存ファイル名
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $safeTableName = $TableName -replace '[\\/:*?"<>|]', '_'
    $filePath = Join-Path $OutputDir "${timestamp}_${safeTableName}.png"

    # スクリーンショット
    Save-Screenshot -FilePath $filePath -Mode $CaptureMode
    Write-Host "Saved: $filePath" -ForegroundColor Green

    Start-Sleep -Seconds $BetweenItemsSeconds

    return [PSCustomObject]@{
        TableName = $TableName
        FilePath = $filePath
    }
}

# =========================
# 実行
# =========================

New-OutputDirectory -Path $OutputDir
Enable-DpiAwareness

Write-Host "----------------------------------------"
Write-Host "ServiceNow Citrix Capture Start"
Write-Host "OutputDir: $OutputDir"
Write-Host "CaptureMode: $CaptureMode"
Write-Host "TargetMode: $TargetMode"
Write-Host "Start after $InitialDelaySeconds seconds..."
Write-Host ""
Write-Host "Please do this now:"
Write-Host "1. Citrix / Remote PC window を前面に出す"
Write-Host "2. Remote PC のブラウザ画面をアクティブにする"
Write-Host "3. ローカル Windows のタスクバーが見える状態にしておく"
Write-Host "4. スクリプト実行中はキーボード・マウスに触らない"
Write-Host "----------------------------------------"

Start-Sleep -Seconds $InitialDelaySeconds

$captures = @()
$targets = Get-CaptureTargets `
    -Mode $TargetMode `
    -Tables $Tables `
    -CustomTargets $CustomTargets `
    -BaseUrl $InstanceBase `
    -Suffix $EncodedSuffix

foreach ($target in $targets) {
    try {
        $capture = Invoke-OneCapture `
            -TableName $target.Name `
            -Url $target.Url `
            -OutputDir $OutputDir `
            -PageLoadWaitSeconds $PageLoadWaitSeconds `
            -BetweenItemsSeconds $BetweenItemsSeconds `
            -UseCtrlL $UseCtrlL `
            -CaptureMode $CaptureMode

        if ($capture) {
            $captures += $capture
        }
    }
    catch {
        Write-Warning "Failed for $($target.Name) : $($_.Exception.Message)"
    }
}

if ($ExportToExcel) {
    Export-CapturesToExcel `
        -Captures $captures `
        -ExcelOutputDir $ExcelOutputDir `
        -WorksheetName $ExcelSheetName `
        -MaxImageWidth $ExcelMaxImageWidth `
        -OpenAfterCreate $OpenExcelAfterCreate
}

Write-Host ""
Write-Host "All done." -ForegroundColor Yellow

```
