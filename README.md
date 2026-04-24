Group by が直接できないのは ServiceNow の標準リスト画面の制約ですが、いくつか別の方法で同じ目的を達成できます。順番に提示します。

---

## ■ まず重要な発見：画像から判明した追加事実

画像をよく見ると、`Target table` 列に以下のバリエーションがあります：

| Target table | 役割 |
|-------------|------|
| `Software Installation [cmdb_sam_sw_install]` | ソフトウェアインストール |
| `Serial Number [cmdb_serial_number]` | シリアル番号エンティティ |
| `Key Value [cmdb_key_value]` | キーバリュー（属性） |
| `Computer [cmdb_ci_computer]` | **PC本体のCI** ← これが本命 |

11万件のうち、**真に問題なのは `Computer [cmdb_ci_computer]` ターゲットのレコード**です。残り（Serial Number, Software Installation, Key Value）は付随データであり、CI誤上書きの直接原因ではありません。

これは前回の回答からさらに絞り込みできることを意味します。

---

## ■ 重複target_sys_id 特定方法（複数案）

### 方法1: フィルタを Computer のみに絞る（最優先で実施）

まず、現在の検索条件を以下のように追加してください:

```
Filter: 
- Name = SG-SCCM
- ID contains 03066860c7122010b56243ac95c26027
- Target table = Computer [cmdb_ci_computer]    ← 追加
```

これにより 11万件 → おそらく **数千〜1万件程度** に絞れるはずです。残った件数が「Computer CI に対する Source Native Key の総数」です。

正常な状態であれば、PC1台につき1件のはずなので、この件数が **管理対象PC台数とほぼ一致** すれば汚染は限定的、**大幅に超過** していれば重複が広範に存在することを意味します。

### 方法2: List View での簡易確認

絞り込み後の Computer ターゲットレコードに対し:

1. `target_sys_id` 列でリストをソート
2. 同じ target_sys_id が連続して並ぶ箇所を目視確認（スクロール）
3. 重複が見つかれば、そのレコード ID 列の構造を比較
   - 例: `4201931||16778341||03066860...` と `62144729H||16778341||03066860...` が同じ target_sys_id を指していれば、それが汚染レコード

ただし数千件あると目視は厳しいです。

### 方法3: バックグラウンドスクリプトでの集計（推奨）

ServiceNow の **Scripts - Background**（`/sys.scripts.do`）で簡易な GlideAggregate スクリプトを実行する方法です。読み取り専用なので安全です。

```javascript
// 重複target_sys_idを集計するスクリプト（読み取り専用）
var ga = new GlideAggregate('sys_object_source');
ga.addQuery('name', 'SG-SCCM');
ga.addQuery('id', 'CONTAINS', '03066860c7122010b56243ac95c26027');
ga.addQuery('target_table', 'cmdb_ci_computer');
ga.addAggregate('COUNT', 'target_sys_id');
ga.groupBy('target_sys_id');
ga.addHaving('COUNT', 'target_sys_id', '>', 1);
ga.query();

var count = 0;
var output = [];
while (ga.next()) {
    count++;
    output.push(ga.getValue('target_sys_id') + ' : ' + ga.getAggregate('COUNT', 'target_sys_id') + '件');
}
gs.print('重複target_sys_idの件数: ' + count);
gs.print('---詳細---');
output.forEach(function(line) { gs.print(line); });
```

**実行手順:**
1. ナビゲーションから `Scripts - Background` を開く
2. 上記スクリプトを貼り付け
3. **Cancel execution** チェックボックスを確認（読み取りのみのため不要だが念のため確認）
4. **Run script** をクリック
5. 出力結果が画面下部に表示される

**注意:** 本番環境で実行する前に、必ず **読み取りのみ**であることを再確認してください。`gr.update()` や `gr.deleteRecord()` を含まなければ、データは一切変更されません。上記スクリプトはGlideAggregateで集計のみのため安全です。

### 方法4: cmdb_ci_computer 側からの逆引き（補助）

別の角度から確認する方法です:

```javascript
// Computer CI ごとに、関連する SG-SCCM source エントリ数を確認
var ga = new GlideAggregate('sys_object_source');
ga.addQuery('name', 'SG-SCCM');
ga.addQuery('target_table', 'cmdb_ci_computer');
ga.addAggregate('COUNT', 'target_sys_id');
ga.groupBy('target_sys_id');
ga.addHaving('COUNT', 'target_sys_id', '>', 1);
ga.query();

gs.print('SG-SCCM全体で、複数source native keyを持つCI数: ' + ga.getRowCount());

// 上位件数のCIを確認
var details = [];
while (ga.next() && details.length < 20) {
    details.push(ga.getValue('target_sys_id') + ' : ' + ga.getAggregate('COUNT', 'target_sys_id') + '件');
}
gs.print('---上位20件---');
details.forEach(function(line) { gs.print(line); });
```

これは「03066860... に限らず、SG-SCCM 全体で重複しているCI」を見ます。汚染Connection IDだけでなく他にも重複問題がないかの広域確認になります。

---

## ■ 真の被害CIリストの作成方法

重複 target_sys_id が特定できたら、それらの target_sys_id を `cmdb_ci_computer` で検索することで被害CIリストになります。

### 手順1: 重複 target_sys_id のリスト出力

上記スクリプトを拡張して、target_sys_id をカンマ区切りで出力:

```javascript
var ga = new GlideAggregate('sys_object_source');
ga.addQuery('name', 'SG-SCCM');
ga.addQuery('id', 'CONTAINS', '03066860c7122010b56243ac95c26027');
ga.addQuery('target_table', 'cmdb_ci_computer');
ga.addAggregate('COUNT', 'target_sys_id');
ga.groupBy('target_sys_id');
ga.addHaving('COUNT', 'target_sys_id', '>', 1);
ga.query();

var sysIds = [];
while (ga.next()) {
    sysIds.push(ga.getValue('target_sys_id'));
}

gs.print('被害CI候補件数: ' + sysIds.length);
gs.print('---sys_id list (filter用)---');
gs.print(sysIds.join(','));
```

### 手順2: cmdb_ci_computer での確認

スクリプトの出力結果（カンマ区切りのsys_id文字列）を使って、`cmdb_ci_computer` のリストフィルタで:

```
Filter: sys_id IS ONE OF [上記スクリプトの出力をペースト]
```

これで **被害CIの全リスト** が画面表示されます。

### 手順3: Excelエクスポートして詳細分析

被害CIリストを右クリック → Export → Excel で出力。以下の列を含めると分析しやすい:

- Name
- Serial number
- Sys created on
- Sys created by
- Sys updated on
- Sys updated by
- Discovery source
- Login ID
- Manufacturer
- Model ID

特に **`sys_created_by` と `sys_updated_by` が異なるユーザ** （例: 作成は `sg_sccm_job_user_broadcast`、更新は `sg_sccm_job_user_general`）になっているCIが、典型的なクロス上書き被害CIです。

### 手順4: Activity履歴での詳細確認（個別CI単位）

被害CIの中から代表的な数件を選び、Activity / Field changes 履歴を開いて:
- いつ最初に作成されたか
- どのインスタンスのジョブが作ったか
- いつ別インスタンスのジョブによって上書きされたか
- 上書き前後の値の差分

を時系列で確認。これがサブプロ検証時のテストケースになります。

---

## ■ 別の重要な確認: cmdb_ci_hardware についても同様に

`cmdb_ci_computer` は `cmdb_ci_hardware` を継承しているため、`target_table = cmdb_ci_hardware` の sys_object_source エントリも別途存在します。同じスクリプトで `target_table = 'cmdb_ci_hardware'` に変更して実行し、重複を確認してください。

```javascript
// cmdb_ci_hardware 版
var ga = new GlideAggregate('sys_object_source');
ga.addQuery('name', 'SG-SCCM');
ga.addQuery('id', 'CONTAINS', '03066860c7122010b56243ac95c26027');
ga.addQuery('target_table', 'cmdb_ci_hardware');     // ← ここを変更
ga.addAggregate('COUNT', 'target_sys_id');
ga.groupBy('target_sys_id');
ga.addHaving('COUNT', 'target_sys_id', '>', 1);
ga.query();

gs.print('cmdb_ci_hardware側 重複件数: ' + ga.getRowCount());
```

---

## ■ 重要な事前確認事項

スクリプト実行前に以下を確認してください:

1. **本番環境での Background Script 実行権限**
   - admin ロールが必要
   - 一部の組織ではセキュリティポリシー上、本番Background Script実行に承認が必要な場合あり

2. **実行時の負荷**
   - 11万件規模のGlideAggregateは数秒〜数十秒かかる可能性
   - 業務時間外や負荷の低い時間帯での実行が望ましい

3. **代替案: Reports機能**
   - Background Scriptが使えない環境であれば、Reports（`/sys_report.do`）で:
     - Source table: sys_object_source
     - Type: Bar / List
     - Group by: target_sys_id
     - Aggregation: COUNT
     - Filter: 上記と同じ
   - これでもGUIで集計可能

---

## ■ 期待される結果と次のアクション

実行結果の数字によって、次のステップが変わります:

| 重複target_sys_id件数 | 状況 | 次のアクション |
|---------------------|------|--------------|
| 0件 | 汚染なし。誤上書きの真因は別の可能性 | 再分析必要 |
| 1〜数十件 | 限定的な汚染 | 個別CI単位で対処、サブプロ検証は短期間で可能 |
| 数百件 | 中規模汚染 | 標準的な復旧フロー、サブプロ検証推奨 |
| 数千件以上 | 広範な汚染 | 復旧計画を厚めに、HI Support巻き込み検討 |

---

## ■ まとめ

1. まず **target_table = `cmdb_ci_computer` でフィルタを追加** して件数を確認（GUI操作のみ）
2. その上で **Background Script の方法3** で重複 target_sys_id を集計（最も確実）
3. 出力された sys_id リストで cmdb_ci_computer をフィルタ → 被害CIリスト確定
4. `cmdb_ci_hardware` についても同様に確認

スクリプト実行結果が分かりましたら、件数に応じて具体的な復旧計画に進みましょう。Background Script の実行が運用上難しい場合は、お知らせいただければ Reports 機能や別のGUIベースの方法もご案内します。
```
**■tanium**
cmdb_ci_computer.list
cmdb_ci_disk.list
cmdb_ci_file_system.list
cmdb_ci_ip_address.list
cmdb_ci_network_adapter.list

cmdb_serial_number.list
cmdb_sam_sw_install.list
cmdb_ci_appl.list
cmdb_running_process.list
cmdb_tcp.list

**■SCCM**
cmdb_ci_computer.list
cmdb_key_value.list
cmdb_ci_disk.list
cmdb_ci_ip_address.list
cmdb_ci_network_adapter.list
cmdb_serial_number.list
cmdb_sam_sw_install.list

sn_sccm_integrate_sccm_2019_computer_related.list
```


```
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
if (-not ([System.Management.Automation.PSTypeName]'NativeInput').Type) {
    Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class NativeDisplay {
    [DllImport("user32.dll")]
    public static extern bool SetProcessDPIAware();
}

[StructLayout(LayoutKind.Sequential)]
public struct INPUT {
    public UInt32 type;
    public InputUnion U;
}

[StructLayout(LayoutKind.Explicit)]
public struct InputUnion {
    [FieldOffset(0)]
    public KEYBDINPUT ki;
}

[StructLayout(LayoutKind.Sequential)]
public struct KEYBDINPUT {
    public UInt16 wVk;
    public UInt16 wScan;
    public UInt32 dwFlags;
    public UInt32 time;
    public IntPtr dwExtraInfo;
}

public static class NativeInput {
    public const UInt32 INPUT_KEYBOARD = 1;
    public const UInt32 KEYEVENTF_KEYUP = 0x0002;
    public const UInt32 KEYEVENTF_UNICODE = 0x0004;

    [DllImport("user32.dll", SetLastError = true)]
    public static extern UInt32 SendInput(UInt32 nInputs, INPUT[] pInputs, Int32 cbSize);
}
"@
}

# =========================
# 設定
# =========================

# 保存先
$OutputDir = "C:\work\work-git\git\tools\work-assistant\servicenow\ServiceNowScreenshots"
$ExcelOutputDir = "C:\work\work-git\git\tools\work-assistant\servicenow\ServiceNowScreenshots"

# 1件ごとの待機秒数
$InitialDelaySeconds = 5      # 開始前の猶予。Citrix 画面を前面に出す時間
$PageLoadWaitSecondsMin = 10 # Enter後の読み込み待機の最小秒数 (3分)
$PageLoadWaitSecondsMax = 60 # Enter後の読み込み待機の最大秒数 (5分)
$BetweenItemsSeconds = 2      # 次の処理までの待機

# Citrix 側ブラウザのアドレスバーに飛ぶ操作
$UseCtrlL = $true
$UseClipboardPaste = $false
$TextEntryMode = "SendKeysLiteral"
$KeyEntryDelayMilliseconds = 30

# 画面キャプチャ方法
# "FullScreen" = 画面全体
# "PrimaryScreen" = メインモニタだけ
$CaptureMode = "PrimaryScreen"

# Excel 出力
$ExportToExcel = $true
$OpenExcelAfterCreate = $true
$ExcelSheetName = "Screenshots"
$ExcelMaxImageWidth = 1000
$ExcelRowsBetweenCaptures = 3

# キャプチャ後の余白除去
$TrimCapturePadding = $true
$TrimColorTolerance = 10
$TrimSampleStep = 8
$TrimMinPaddingPixels = 12

# 実行モード
# "Tables" = Tables から URL を組み立てる
# "CustomUrls" = 完全な URL をそのまま使う
$TargetMode = "Tables"

# ServiceNow の URL ベース
$InstanceBase = "https://dev317783.service-now.com/now/nav/ui/classic/params/target/"

# 固定のクエリ部分
# $EncodedSuffix = "%3Fsysparm_query%3Ddiscovery_source%253DSG-AWS%26sysparm_first_row%3D1%26sysparm_view%3D"
$EncodedSuffix = "%3Fsysparm_query%3Ddiscovery_source%253DSG-AWS%255Esys_updated_onONToday%40javascript%3Ags.beginningOfToday()%40javascript%3Ags.endOfToday()%26sysparm_first_row%3D1%26sysparm_view%3D"

# 一部テーブルだけ URL のクエリ条件が異なる場合の上書き
$TableUrlOverrides = @{
    "cmdb_tcp.list" = "https://dev317783.service-now.com/now/nav/ui/classic/params/target/cmdb_tcp_list.do%3Fsysparm_query%3Dsys_updated_on%253Ejavascript%3Ags.dateGenerate(%25272026-04-20%2527%252C%252709%3A00%3A00%2527)%26sysparm_first_row%3D1%26sysparm_view%3D"
    "cmdb_running_process.list" = "https://dev317783.service-now.com/now/nav/ui/classic/params/target/cmdb_running_process_list.do%3Fsysparm_query%3Dsys_updated_on%253Ejavascript%3Ags.dateGenerate(%25272026-04-20%2527%252C%252709%3A00%3A00%2527)%26sysparm_first_row%3D1%26sysparm_view%3D"
}

# 対象テーブル
$Tables = @(
    "cmdb_ci_vm_instance.list",
    "cmdb_ci_linux_server.list",
    "cmdb_ci_win_server.list",
    "cmdb_ci_server.list",
    "cmdb_ci_endpoint_vnic.list",
    "cmdb_ci_endpoint_block.list",
    "cmdb_ci_storage_mapping.list",
    "cmdb_ci_ip_address.list",
    "cmdb_ci_network_adapter.list",
    "cmdb_ci_cloud_gateway.list",
    "cmdb_ci_aws_datacenter.list",
    "cmdb_ci_dynamodb_table.list",
    "cmdb_ci_cloud_load_balancer.list",
    "cmdb_ci_compute_template.list",
    "cmdb_ci_os_template.list",
    "cmdb_ci_cloud_function.list",
    "cmdb_ci_nic.list",
    "cmdb_ci_cloud_org.list",
    "cmdb_ci_cloud_database.list",
    "cmdb_ci_cloud_object_storage.list",
    "cmdb_ci_compute_security_group.list",
    "cmdb_ci_cloud_service_account.list",
    "cmdb_ci_storage_volume.list",
    "cmdb_ci_cloud_subnet.list",
    "cmdb_ci_network.list",
    "cmdb_ci_cmp_resource.list",
    "cmdb_ci_availability_zone.list",
    "cmdb_ci_storage_vol_snapshot.list",
    "cmdb_ci_aws_org_unit.list",
    "cmdb_sam_sw_install",
    "cmdb_tcp.list",
    "cmdb_running_process.list"
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
        [string]$Suffix,
        [hashtable]$Overrides = @{}
    )

    if ($Overrides.ContainsKey($TableName)) {
        return [string]$Overrides[$TableName]
    }

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
        [string]$Suffix,
        [hashtable]$Overrides = @{}
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
            Url = Convert-TableToUrl -TableName $table -BaseUrl $BaseUrl -Suffix $Suffix -Overrides $Overrides
        }
    }

    return $targets
}

function Send-KeysSafe {
    param([string]$Keys)

    [System.Windows.Forms.SendKeys]::SendWait($Keys)
    Start-Sleep -Milliseconds 500
}

function ConvertTo-SendKeysLiteral {
    param([string]$Text)

    $builder = New-Object System.Text.StringBuilder

    foreach ($ch in $Text.ToCharArray()) {
        switch ($ch) {
            '+' { [void]$builder.Append('{+}') }
            '^' { [void]$builder.Append('{^}') }
            '%' { [void]$builder.Append('{%}') }
            '~' { [void]$builder.Append('{~}') }
            '(' { [void]$builder.Append('{(}') }
            ')' { [void]$builder.Append('{)}') }
            '{' { [void]$builder.Append('{{}') }
            '}' { [void]$builder.Append('{}}') }
            '[' { [void]$builder.Append('{[}') }
            ']' { [void]$builder.Append('{]}') }
            default { [void]$builder.Append($ch) }
        }
    }

    return $builder.ToString()
}

function Send-TextSafe {
    param(
        [string]$Text,
        [ValidateSet("UnicodeInput","SendKeysLiteral")]
        [string]$Mode = "UnicodeInput",
        [int]$DelayMilliseconds = 30
    )

    if ($Mode -eq "SendKeysLiteral") {
        foreach ($ch in $Text.ToCharArray()) {
            [System.Windows.Forms.SendKeys]::SendWait((ConvertTo-SendKeysLiteral -Text ([string]$ch)))
            if ($DelayMilliseconds -gt 0) {
                Start-Sleep -Milliseconds $DelayMilliseconds
            }
        }

        Start-Sleep -Milliseconds 300
        return
    }

    foreach ($ch in $Text.ToCharArray()) {
        $keyDown = New-Object INPUT
        $keyDown.type = [NativeInput]::INPUT_KEYBOARD
        $keyDown.U.ki.wVk = 0
        $keyDown.U.ki.wScan = [uint16][char]$ch
        $keyDown.U.ki.dwFlags = [NativeInput]::KEYEVENTF_UNICODE
        $keyDown.U.ki.time = 0
        $keyDown.U.ki.dwExtraInfo = [IntPtr]::Zero

        $keyUp = New-Object INPUT
        $keyUp.type = [NativeInput]::INPUT_KEYBOARD
        $keyUp.U.ki.wVk = 0
        $keyUp.U.ki.wScan = [uint16][char]$ch
        $keyUp.U.ki.dwFlags = [NativeInput]::KEYEVENTF_UNICODE -bor [NativeInput]::KEYEVENTF_KEYUP
        $keyUp.U.ki.time = 0
        $keyUp.U.ki.dwExtraInfo = [IntPtr]::Zero

        [void][NativeInput]::SendInput(2, @($keyDown, $keyUp), [System.Runtime.InteropServices.Marshal]::SizeOf([INPUT]))
        if ($DelayMilliseconds -gt 0) {
            Start-Sleep -Milliseconds $DelayMilliseconds
        }
    }

    Start-Sleep -Milliseconds 300
}

function Get-RandomPageLoadWaitSeconds {
    param(
        [int]$MinSeconds,
        [int]$MaxSeconds
    )

    if ($MinSeconds -gt $MaxSeconds) {
        throw "Page load wait range is invalid. MinSeconds must be less than or equal to MaxSeconds."
    }

    if ($MinSeconds -eq $MaxSeconds) {
        return $MinSeconds
    }

    return Get-Random -Minimum $MinSeconds -Maximum ($MaxSeconds + 1)
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
        [int]$RowsBetweenCaptures = 3,
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
            $currentRow += [Math]::Max($rowsUsedByImage, 1) + $RowsBetweenCaptures

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
        [int]$PageLoadWaitSecondsMin,
        [int]$PageLoadWaitSecondsMax,
        [int]$BetweenItemsSeconds,
        [bool]$UseCtrlL,
        [string]$CaptureMode
    )

    Write-Host ""
    Write-Host "Processing: $TableName" -ForegroundColor Cyan
    Write-Host "URL: $Url"

    # アドレスバーへ
    if ($UseCtrlL) {
        Send-KeysSafe "^(l)"
    }

    # 既存入力を消して URL を入力
    if ($UseClipboardPaste) {
        Set-Clipboard -Value $Url
        Start-Sleep -Milliseconds 500
        Send-KeysSafe "^(v)"
    }
    else {
        Send-KeysSafe "^(a)"
        Send-KeysSafe "{BACKSPACE}"
        Send-TextSafe -Text $Url -Mode $TextEntryMode -DelayMilliseconds $KeyEntryDelayMilliseconds
    }

    # Enter
    Send-KeysSafe "{ENTER}"

    # 読み込み待機
    $pageLoadWaitSeconds = Get-RandomPageLoadWaitSeconds -MinSeconds $PageLoadWaitSecondsMin -MaxSeconds $PageLoadWaitSecondsMax
    Write-Host "Waiting $pageLoadWaitSeconds sec for page load..."
    Start-Sleep -Seconds $pageLoadWaitSeconds

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
    -Suffix $EncodedSuffix `
    -Overrides $TableUrlOverrides

foreach ($target in $targets) {
    try {
        $capture = Invoke-OneCapture `
            -TableName $target.Name `
            -Url $target.Url `
            -OutputDir $OutputDir `
            -PageLoadWaitSecondsMin $PageLoadWaitSecondsMin `
            -PageLoadWaitSecondsMax $PageLoadWaitSecondsMax `
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
        -RowsBetweenCaptures $ExcelRowsBetweenCaptures `
        -OpenAfterCreate $OpenExcelAfterCreate
}

Write-Host ""
Write-Host "All done." -ForegroundColor Yellow

```
