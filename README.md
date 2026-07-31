## 映射规则确认了

Serial 格式：`vol02e3869be69455415_00000001.` —— `vol` + 17位hex + `_00000001`，中间的横杠被去掉了。转换只要在 `vol` 后面插回横杠：

| Drive | DiskNumber | Serial | → Volume ID |
|---|---|---|---|
| D: | 1 | vol04376ab4a7dffa7eb_00000001 | **vol-04376ab4a7dffa7eb** |
| E: | 2 | vol02e3869be69455415_00000001 | **vol-02e3869be69455415** |

去掉 `vol` 后正好 17 位，符合现行 volume ID 格式，规则成立。

最终版映射脚本（比上次的正则更稳，不依赖尾部格式）：

```powershell
Get-Partition | Where-Object DriveLetter -in 'D','E' | ForEach-Object {
    $serial = (Get-Disk -Number $_.DiskNumber).SerialNumber
    if ($serial -match '^vol([0-9a-f]{17})') {
        [PSCustomObject]@{
            DriveLetter = $_.DriveLetter
            DiskNumber  = $_.DiskNumber
            VolumeId    = "vol-$($matches[1])"
        }
    }
} | ConvertTo-Json -Compress
```

输出 JSON，Lambda 侧用 `GetCommandInvocation` 拿 `StandardOutputContent` 直接 `json.loads()` 就行，不用解析文本。

⚠️ **DiskNumber 不要缓存**，重启后可能变。每次都从 DriveLetter 现查。

---

## 顺便注意：这次跑的是 dev 机

命令 ID 的输出先是 `i-08bb5cd2c5db21dea`（nonsap-dev-da...），不是 prd 那台 `i-0f2330f055e8ed6fb`。dev 上验证是对的做法，但正式设计前建议在 prd 上也跑一次同样的确认 —— 两台的 AMI ID 不同（`ami-01e8630b...` vs `ami-0586763fe...`），虽然都是 Server 2022，但不能假定磁盘构成完全一致。

顺手也确认一下 dev 这台的 volume 数量和盘符构成跟 prd 是否一样（prd 是 350/100/200 三块）。如果 dev/prd 构成不同，测试环境的代表性就要在提案里说明。

---

## 下一步：OS 侧扩展脚本

ModifyVolume 之后要跑的部分，建议做成独立的 SSM Document（而不是每次传一大坨 commands）：

```powershell
param([string]$DriveLetter)

# 1. 让 OS 识别到 EBS 侧已扩大的容量
Update-HostStorageCache

# 2. 取得该分区可扩展的最大值
$part = Get-Partition -DriveLetter $DriveLetter
$size = Get-PartitionSupportedSize -DiskNumber $part.DiskNumber -PartitionNumber $part.PartitionNumber

# 3. 已经是最大就跳过（幂等）
if ($part.Size -ge $size.SizeMax) {
    Write-Output (@{Status='NoChange'; SizeGB=[math]::Round($part.Size/1GB,1)} | ConvertTo-Json -Compress)
    exit 0
}

Resize-Partition -DiskNumber $part.DiskNumber -PartitionNumber $part.PartitionNumber -Size $size.SizeMax

$after = Get-Partition -DriveLetter $DriveLetter
Write-Output (@{Status='Resized'; SizeGB=[math]::Round($after.Size/1GB,1)} | ConvertTo-Json -Compress)
```

**时序上必须注意的一点**：`ModifyVolume` 返回成功 ≠ 容量立刻可用。要先轮询 `DescribeVolumesModifications` 直到 `ModificationState` 变成 `optimizing` 或 `completed`，再发 Run Command。`optimizing` 阶段容量已经可用了，不用等到 `completed`（那可能要几小时）。

所以 Lambda 的流程实际是：

```
Alarm → Lambda
  ├ 1. Run Command: 取 DriveLetter→VolumeId 映射
  ├ 2. Parameter Store: 检查 stopper（上限/冷却/次数）
  ├ 3. ModifyVolume(+20GB)
  ├ 4. 轮询 DescribeVolumesModifications → optimizing
  ├ 5. Run Command: Resize-Partition
  ├ 6. Parameter Store: 更新扩容时刻/次数
  └ 7. SNS 通知结果
```

第 4 步的等待会让 Lambda 拖到几分钟。**建议把这套改成 Step Functions**，Lambda 只做单步，等待用 Wait state。这样超时、重试、失败通知都好控制，也避免 Lambda 15 分钟上限和空转计费。这一点值得写进提案的实装イメージ里。
