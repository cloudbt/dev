# Excel自動化コードスニペット

## Excel操作用PowerShellコード

### 日次データ格納用の配列定義

```powershell
# 各日のデータを格納する配列
$dailyData = @{}  # キー: 日(1-31), 値: @{Hours, Minutes}

# CSVデータを格納する配列（CSV出力用）
$workTimeData = @()

if ($workHours -gt 0) {
    # Excelデータ用に時間と分を分けて保存
    $dailyData[$day] = @{
        Hours = $hours
        Minutes = $minutes
    }
}
```

### Excelファイル作成

```powershell
# Excelファイルを作成
Write-Host "`nExcelファイルを作成中..."

$outputFileNameExcel = "WorkTime_${Year}_$(${Month}.ToString('00')).xlsx"
$outputPathExcel = Join-Path $outputFolder $outputFileNameExcel

try {
    # Excelアプリケーションを作成
    $excel = New-Object -ComObject Excel.Application
    $excel.Visible = $false
    $excel.DisplayAlerts = $false

    # 新しいワークブックを作成
    $workbook = $excel.Workbooks.Add()
    $worksheet = $workbook.Worksheets.Item(1)
    $worksheet.Name = "${Year}年${Month}月"

    # ヘッダー行を作成（1行目）
    $worksheet.Cells.Item(1, 1) = "年月"
    $worksheet.Cells.Item(1, 2) = "作業者氏名"

    # 日付の列ヘッダー（1～31）
    for ($day = 1; $day -le 31; $day++) {
        $worksheet.Cells.Item(1, $day + 2) = $day
    }

    # 2行目：作業者名と時間
    $worksheet.Cells.Item(2, 1) = $WorkerName
    $worksheet.Cells.Item(2, 2) = "時間"

    # 3行目：分
    $worksheet.Cells.Item(3, 2) = "分"

    # 各日のデータを入力
    for ($day = 1; $day -le $daysInMonth; $day++) {
        $col = $day + 2

        if ($dailyData[$day].Hours -ne "") {
            # 時間の行（2行目）
            $worksheet.Cells.Item(2, $col) = $dailyData[$day].Hours
            # 分の行（3行目）
            $worksheet.Cells.Item(3, $col) = $dailyData[$day].Minutes
        }
    }

    # 書式設定
    # ヘッダー行の書式
    $headerRange = $worksheet.Range($worksheet.Cells.Item(1, 1), $worksheet.Cells.Item(1, 33))
    $headerRange.Font.Bold = $true
    $headerRange.Interior.ColorIndex = 15  # 薄い灰色
    $headerRange.HorizontalAlignment = -4108  # xlCenter

    # 「作業者氏名」「時間」「分」列の書式
    $labelRange = $worksheet.Range($worksheet.Cells.Item(1, 2), $worksheet.Cells.Item(3, 2))
    $labelRange.Font.Bold = $true
    $labelRange.Interior.ColorIndex = 15
    $labelRange.HorizontalAlignment = -4108

    # 年月セルの書式
    $worksheet.Cells.Item(1, 1).Font.Bold = $true
    $worksheet.Cells.Item(1, 1).Interior.ColorIndex = 15
    $worksheet.Cells.Item(1, 1).HorizontalAlignment = -4108

    # 作業者名セルの書式
    $worksheet.Cells.Item(2, 1).Font.Bold = $true
    $worksheet.Cells.Item(2, 1).Interior.ColorIndex = 15
    $worksheet.Cells.Item(2, 1).HorizontalAlignment = -4108

    # 全体の罫線
    $dataRange = $worksheet.Range($worksheet.Cells.Item(1, 1), $worksheet.Cells.Item(3, 33))
    $dataRange.Borders.LineStyle = 1  # xlContinuous

    # 列幅の自動調整
    $worksheet.Columns.AutoFit() | Out-Null

    # ファイルを保存
    $workbook.SaveAs($outputPathExcel)
    $workbook.Close()
    $excel.Quit()

    # COMオブジェクトを解放
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($worksheet) | Out-Null
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($workbook) | Out-Null
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel) | Out-Null
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()

    Write-Host "✓ Excelファイルを作成しました" -ForegroundColor Green
    Write-Host "保存先: $outputPathExcel"
    Write-Log "Excelファイル作成成功: $outputPathExcel"

} catch {
    Write-Log "エラー: Excelファイルの作成に失敗しました - $($_.Exception.Message)"
    Write-Host "✗ Excelファイルの作成に失敗しました: $($_.Exception.Message)" -ForegroundColor Red
}

# Excelファイルを開く
Start-Process $outputPathExcel
Write-Host "✓ Excelファイルを開きました"
```

## 主要機能

### データ構造
- ハッシュテーブルを使用した日別データ管理
- 時間と分を分けて保存

### Excel操作
- COM オブジェクトによるExcel自動操作
- ワークシート作成とセル書き込み
- 書式設定（太字、背景色、罫線、配置）
- 列幅の自動調整

### リソース管理
- COMオブジェクトの適切な解放
- ガベージコレクションの実行
- メモリリークの防止
