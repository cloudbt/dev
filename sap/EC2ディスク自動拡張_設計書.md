# EC2 ディスク自動拡張 設計書

| 項目 | 内容 |
|---|---|
| 対象システム | nonsap-prd-dataspider / nonsap-dev-dataspider |
| リージョン | ap-southeast-1（シンガポール） |
| 版数 | 0.1（ドラフト） |
| 作成日 | 2026/07/31 |
| 作成者 | （記入） |

---

## 1. 背景と目的

### 1.1 背景

過去にディスク空き容量が閾値を下回った際、以下の経緯でサーバ停止に至った。

1. GDS / CloudWatch は閾値超過を検知し、EYJP 宛にメール通知を実施
2. しかし通知が埋もれ、担当者が認識できなかった
3. CloudWatch アラームは状態遷移時のみ通知するため、**一度発報した後は再通知されなかった**
4. 結果、対処されないまま容量枯渇によりサーバ停止

顧客からは「週次定例で GDS のアラート一覧を確認する」運用案が提示されたが、
これは引き続き人手による確認に依存するため、見落としリスクが残る。

### 1.2 目的

**人手を介さずに容量枯渇を回避する仕組みを構築し、同種障害の再発を防止する。**

具体的には以下を実現する。

- 空き容量が一定値を下回った場合、EBS ボリュームを自動的に拡張する
- 無制限な拡張を防ぐため、複数の抑止機構（Stopper）を設ける
- 対処が必要な事象については、解決するまで繰り返し通知する

---

## 2. 対象範囲

### 2.1 対象サーバ・ボリューム

| 環境 | インスタンス名 | インスタンス ID | 対象ドライブ | 現容量 | 空き容量 |
|---|---|---|---|---|---|
| 本番 | nonsap-prd-dataspider | i-0f2330f055e8ed6fb | D: | 99.9 GB | 26.4 GB |
| 本番 | nonsap-prd-dataspider | i-0f2330f055e8ed6fb | E: | 199 GB | 105 GB |
| 開発 | nonsap-dev-dataspider | i-08bb5cd2c5db21dea | D: | 99.9 GB | 70.9 GB |
| 開発 | nonsap-dev-dataspider | i-08bb5cd2c5db21dea | E: | 99.9 GB | 86.2 GB |

**C: ドライブは対象外**（OS 領域のため、拡張は個別判断とする）。

### 2.2 対象外

- 上記以外の EC2 インスタンス（nonsap-prd-svf / nonsap-prd-jp1 等）
- GDS 側の設定変更・連携
- 既存の 20% メール通知（**現行のまま変更しない**）

---

## 3. 前提条件

| # | 前提 | 確認状況 |
|---|---|---|
| 1 | OS は Windows Server 2022 Datacenter | ✅ 確認済 |
| 2 | パーティション形式は GPT | ✅ 確認済 |
| 3 | ボリュームタイプは gp3 | ✅ 確認済 |
| 4 | SSM Run Command が実行可能（マネージドノード登録済・Online） | ✅ 確認済 |
| 5 | CloudWatch Agent が `LogicalDisk % Free Space` を収集済（60秒間隔） | ✅ 確認済 |
| 6 | メトリクスの dimension に `InstanceId` が含まれる | ✅ 確認済 |
| 7 | 対象パーティションがディスク末尾に存在する（拡張可能な配置） | ⬜ 実装時に確認 |
| 8 | Parameter Store が利用可能（既存で利用実績あり） | ✅ 確認済 |
| 9 | インフラは Console 手動構築（Terraform 未使用） | ✅ 確認済 |

---

## 4. 全体構成

### 4.1 使用する AWS サービス

| サービス | 役割 |
|---|---|
| CloudWatch Alarm | 空き容量 10% 未満を検知 |
| EventBridge | アラーム状態変化を検知し、後続処理を起動 |
| Step Functions | 一連の処理フローを制御（待機・リトライ・分岐） |
| Lambda | 各ステップの処理を実行 |
| SSM Run Command | Windows OS 側のパーティション拡張を実行 |
| Parameter Store | 設定値および状態の保持 |
| SNS | 通知の配信 |

### 4.2 構成イメージ

```
[CloudWatch Alarm]  空き容量 10% 未満（10分継続）
        │
        ▼
[EventBridge Rule]  対象アラーム名を明示指定
        │
        ▼
[Step Functions]
   ①事前チェック   (SSM Run Command)  ← EBS には触れない
   ②Stopper 判定  (Parameter Store)
   ③EBS 拡張      (ModifyVolume +20GB)
   ④状態記録      (Parameter Store)
   ⑤拡張完了待機  (DescribeVolumesModifications をポーリング)
   ⑥OS 側拡張     (SSM Run Command / Resize-Partition)
   ⑦状態クリア・通知 (Parameter Store / SNS)
        │
        ▼
[SNS] → メール（および Teams：オプション）
```

### 4.3 既存構成との関係

**既存の 20% アラーム・メール通知は一切変更しない。**
本仕組みは 10% 用のアラームを新規に追加し、既存通知とは独立した経路で動作する。

```
空き容量 20% 未満 → 既存アラーム → 既存 SNS → メール（現行のまま）
空き容量 10% 未満 → 新規アラーム → EventBridge → 自動拡張（新規）
```

---

## 5. 処理フロー

### 5.1 正常系

| # | 処理 | 内容 |
|---|---|---|
| 1 | 検知 | 空き容量 10% 未満が 10 分継続 → アラーム発報 |
| 2 | 事前チェック | SSM Run Command でドライブ存在・GPT・拡張可否・Volume ID を取得。**NG の場合は EBS を拡張せず中断し通知** |
| 3 | Stopper 判定 | 容量上限・クールダウン・月次回数を Parameter Store で確認 |
| 4 | EBS 拡張 | `ModifyVolume` により +20GB |
| 5 | 状態記録 | `pending_resize = true`、拡張回数をインクリメント |
| 6 | 完了待機 | `ModificationState` が `optimizing` または `completed` になるまでポーリング |
| 7 | OS 側拡張 | `Resize-Partition` でパーティションを最大サイズまで拡張 |
| 8 | 完了処理 | `pending_resize = false`、INFO 通知を送信 |

### 5.2 ドライブレター → Volume ID の特定方式

Nitro 世代インスタンスのため、OS 側では NVMe デバイスとして認識される。
`Get-Disk` の `SerialNumber` から Volume ID を復元する。

```
SerialNumber : vol04376ab4a7dffa7eb_00000001
               ↓ "vol" の後にハイフンを挿入
Volume ID    : vol-04376ab4a7dffa7eb
```

※ ディスク番号は再起動により変動する可能性があるため、**キャッシュせず毎回ドライブレターから取得する**。

### 5.3 事前チェックスクリプト（SSM Document）

```powershell
param([string]$DriveLetter)
$ErrorActionPreference = 'Stop'
try {
    $part = Get-Partition -DriveLetter $DriveLetter
    $disk = Get-Disk -Number $part.DiskNumber
    $size = Get-PartitionSupportedSize -DiskNumber $part.DiskNumber `
                                       -PartitionNumber $part.PartitionNumber
    $isLast = ($part.PartitionNumber -eq (Get-Partition -DiskNumber $part.DiskNumber |
               Sort-Object Offset | Select-Object -Last 1).PartitionNumber)
    if ($disk.SerialNumber -notmatch '^vol([0-9a-f]{17})') {
        throw "SerialNumber format unexpected: $($disk.SerialNumber)"
    }
    @{
        Ok              = $true
        VolumeId        = "vol-$($matches[1])"
        DiskNumber      = $part.DiskNumber
        PartitionNumber = $part.PartitionNumber
        PartitionStyle  = $disk.PartitionStyle
        IsLastPartition = $isLast
        CurrentGB       = [math]::Round($part.Size / 1GB, 1)
        MaxGB           = [math]::Round($size.SizeMax / 1GB, 1)
    } | ConvertTo-Json -Compress
} catch {
    @{ Ok = $false; Error = $_.Exception.Message } | ConvertTo-Json -Compress
}
```

### 5.4 OS 側拡張スクリプト（SSM Document）

冪等性を確保するため、既に最大サイズの場合は何もしない。

```powershell
param([string]$DriveLetter)
$ErrorActionPreference = 'Stop'

Update-HostStorageCache   # EBS 側の容量変更を OS に認識させる

$part = Get-Partition -DriveLetter $DriveLetter
$size = Get-PartitionSupportedSize -DiskNumber $part.DiskNumber `
                                   -PartitionNumber $part.PartitionNumber

if ($part.Size -ge $size.SizeMax) {
    @{ Status = 'NoChange'; SizeGB = [math]::Round($part.Size / 1GB, 1) } |
        ConvertTo-Json -Compress
    exit 0
}

Resize-Partition -DiskNumber $part.DiskNumber `
                 -PartitionNumber $part.PartitionNumber -Size $size.SizeMax

$after = Get-Partition -DriveLetter $DriveLetter
@{ Status = 'Resized'; SizeGB = [math]::Round($after.Size / 1GB, 1) } |
    ConvertTo-Json -Compress
```

---

## 6. 監視設定

### 6.1 新規アラーム（4本：2台 × 2ドライブ）

| 項目 | 設定値 |
|---|---|
| 名前 | `{インスタンス名}-ec2-LogicalDisk {D or E}: Free Space-AutoExpand` |
| 名前空間 | `CWAgent` |
| メトリクス | `LogicalDisk % Free Space` |
| dimension | `instance` / `objectname` / `InstanceId` / `ImageId` / `InstanceType` の**5つすべてを完全一致で指定** |
| 統計 | 平均値 |
| 期間 | 5 分 |
| 条件 | `<= 10` |
| 評価期間 | 2 / 2（10 分継続で発報） |
| 欠落データの処理 | `notBreaching`（欠落を異常扱いしない） |
| アクション | なし（EventBridge 経由で処理） |

**評価期間を 2/2 とする理由**：本アラームは通知ではなく課金を伴う構成変更を起動するため、
瞬間的な変動では発動しない設計とする。

**欠落データを `notBreaching` とする理由**：`breaching` にすると、
メトリクス欠落時に自動拡張が起動してしまうため。

### 6.2 ウォッチドッグアラーム（監視の監視）

現行の dimension には `ImageId` / `InstanceType` が含まれるため、
**AMI 更新やインスタンスタイプ変更を行うとメトリクス系列が変化し、
既存アラームが無反応（かつ OK 状態のまま固定）になるリスク**がある。

これを検知するため、以下のアラームを別途設ける。

| 項目 | 設定値 |
|---|---|
| 対象 | 同一メトリクス |
| 欠落データの処理 | `breaching` |
| 評価期間 | 1 時間 |
| アクション | `dph-action` へ通知（**拡張は行わない**） |

### 6.3 EventBridge ルール

アカウント内に既存アラームが 119 本存在するため、
名前の前方一致ではなく**対象アラーム名を明示的に列挙する**。

```json
{
  "source": ["aws.cloudwatch"],
  "detail-type": ["CloudWatch Alarm State Change"],
  "detail": {
    "alarmName": [
      "nonsap-prd-dataspider-ec2-LogicalDisk D: Free Space-AutoExpand",
      "nonsap-prd-dataspider-ec2-LogicalDisk E: Free Space-AutoExpand",
      "nonsap-dev-dataspider-ec2-LogicalDisk D: Free Space-AutoExpand",
      "nonsap-dev-dataspider-ec2-LogicalDisk E: Free Space-AutoExpand"
    ],
    "state": { "value": ["ALARM"] }
  }
}
```

**多重起動の防止**：Step Functions の実行名を `{alarmName}-{state.timestamp}` とすることで、
同一イベントが重複配信されても 2 回目以降は `ExecutionAlreadyExists` で拒否される。

---

## 7. Stopper（拡張抑止）設計

奥平さんよりご指摘のあった「無制限に拡張されるのではないか」という懸念に対する対策。

### 7.1 Stopper 一覧

| # | 種別 | 設定値（案） | 発動時の動作 |
|---|---|---|---|
| 1 | 容量上限 | 500 GB / ボリューム | 拡張せず `dph-action` 通知 |
| 2 | クールダウン | 24 時間 | 拡張せず `dph-action` 通知 |
| 3 | 月次拡張回数上限 | 3 回 / 月（= 最大 +60GB） | 拡張せず `dph-action` 通知 |

**500GB は AWS の制限ではなく、本案件で定める運用上の上限値**である。
（参考：gp3 の最大容量は 16 TiB）

### 7.2 クールダウンに関する設計思想

24 時間以内に再度閾値を下回るということは、20GB を 1 日で消費するペースを意味する。
これは自動拡張で追随すべき事象ではなく、**アプリケーション側の異常
（ログの肥大化、一時ファイルの残存等）を疑うべき状態**である。

したがってこの場合は拡張を行わず、即座にエスカレーションする設計とする。

### 7.3 AWS 側の制限との関係

`ModifyVolume` は同一ボリュームに対し **6 時間の変更間隔制限**がある。
本設計の 24 時間クールダウンはこれより厳しいため、正常系では抵触しない。

ただしリトライ等の例外時に抵触する可能性があるため、
`ModifyVolume` 実行前に `DescribeVolumesModifications` で直近の変更時刻を確認し、
6 時間以内であれば API を呼び出さずスキップする。

### 7.4 拡張量の妥当性

拡張量は **+20GB 固定**とし、ドライブごとの差は設けない。
発報時の空き容量は「容量 × 10%」であるため、拡張後の空き率は以下の通り
**いかなる容量においても必ず 10% を上回る**。

| 現容量 | 発報時の空き | 拡張後容量 | 拡張後の空き率 |
|---|---|---|---|
| 100 GB | 10 GB | 120 GB | 25.0% |
| 200 GB | 20 GB | 220 GB | 18.2% |
| 500 GB | 50 GB | 520 GB | 13.5% |

容量が大きくなるほど余裕が縮小するため、容量上限（Stopper #1）を併用する。

### 7.5 費用への影響

gp3 のベースライン性能（3,000 IOPS / 125 MB/s）は容量に依存しないため、
**拡張しても性能は変化せず、ストレージ費用のみが増加する**。

```
1 回の拡張（+20GB）による月額増分 = 20 GB × gp3 単価
Stopper により想定される最大月額増分 = （記入）
```

※ 単価は AWS 公式料金ページ（ap-southeast-1）にて確認のうえ記入。

---

## 8. 状態管理（Parameter Store）

### 8.1 設定値

```
/dph/config/{instance-id}/{drive}/mode              = auto | notify_only
/dph/config/{instance-id}/{drive}/increment_gb      = 20
/dph/config/{instance-id}/{drive}/max_size_gb       = 500
/dph/config/{instance-id}/{drive}/cooldown_hours    = 24
/dph/config/{instance-id}/{drive}/monthly_max_count = 3
```

環境ごとの差異はすべて Parameter Store で吸収し、
**Lambda コード・SSM Document は dev / prd で共通**とする。

### 8.2 状態（JSON 形式で 1 パラメータにまとめる）

```
/dph/state/{instance-id}/{drive}
```

```json
{
  "last_expanded_at": "2026-07-31T14:00:00Z",
  "count_202607": 1,
  "pending_resize": false,
  "target_size_gb": null,
  "retry_count": 0,
  "last_error": null
}
```

1 パラメータに集約することで、読み書きを各 1 回に抑え、更新の原子性を確保する。

---

## 9. 通知設計

### 9.1 課題

前回の障害は「通知は送られていたが埋もれた」「一度発報後は再通知されなかった」ことに起因する。
したがって**重要度の分離**と**未解決事象の再通知**を設計の中心に据える。

### 9.2 SNS トピック構成

| トピック | 用途 | 宛先 | 想定頻度 |
|---|---|---|---|
| 既存トピック | 20% 到達通知（**現行のまま**） | 現行通り | 現行通り |
| `dph-info` | 拡張成功・正常終了 | 担当者 | 月 1〜2 件 |
| `dph-action` | **要対応**：Stopper 発動、拡張失敗、通知のみモード | 担当者 + リーダー | ほぼ 0 件 |

`dph-action` の件数をほぼゼロに保つことが重要である。
件数が少なければ埋もれない。前回の埋没は「すべてが同一の経路に流れていた」ことが原因である。

### 9.3 件名規約

```
[PRD][CRITICAL] nonsap-prd-dataspider D: OS拡張失敗 - 要手動対応
[PRD][WARN]     nonsap-prd-dataspider E: 上限500GB到達 - 拡張スキップ
[DEV][INFO]     nonsap-dev-dataspider D: 拡張完了 100GB → 120GB
```

固定フォーマットとすることで、メールクライアント側でのルール振り分けが可能となる。

### 9.4 未解決事象の再通知【重要】

CloudWatch アラームは状態遷移時のみ通知するため、これだけでは前回と同じ問題が残る。
**EventBridge Scheduler（1 日 1 回）から Lambda を起動し、
Parameter Store の未解決フラグを全件走査して、残っていれば再通知する。**

再通知の対象となる状態：

- OS 側拡張が失敗したまま（`pending_resize = true`）
- 容量上限に到達し、閾値を下回ったまま
- クールダウン中に閾値を下回ったまま
- 本番で「通知のみモード」となり、未対応のまま

**これにより、解決するまで毎日通知され続ける。**
本項目が前回障害との最大の差分である。

### 9.5 Teams 連携（オプション）

`dph-action` のみ AWS Chatbot 経由で Teams チャネルへ配信する。
設定作業のみで実現可能であり、見落としリスクをさらに低減できる。

---

## 10. 異常系設計

### 10.1 最も避けるべき状態

**「EBS は拡張されたが、OS 側の拡張に失敗した」中途半端な状態。**
費用は発生し、容量は使えず、アラームは鳴り続ける。

以下 4 段階で対処する。

### 10.2 ① 予防（最重要）

**EBS を拡張する前に、OS 側の操作が可能であることを確認する。**（5.3 の事前チェック）

- SSM の疎通
- 対象ドライブの存在
- パーティション形式が GPT であること
- 対象パーティションがディスク末尾にあること
- `Get-PartitionSupportedSize` が正常に取得できること

1 つでも NG の場合は **EBS を拡張せずに中断**する。
これにより中途半端な状態は原理的に発生しない。

### 10.3 ② 自動リトライ（Step Functions）

OS 側拡張ステップにリトライを設定する。

```
IntervalSeconds = 30 / BackoffRate = 2.0 / MaxAttempts = 3
（30秒 → 60秒 → 120秒）
```

`Resize-Partition` は冪等（既に最大なら何もしない）であるため、リトライは安全である。

### 10.4 ③ 自動復旧（リトライ枯渇後）

**EventBridge Scheduler（15 分間隔）から復旧用 Lambda を起動する。**

```
Parameter Store を走査し pending_resize = true を検出
  → OS 側拡張のみを再実行（EBS には触れない）
  → 成功：フラグをクリアし「自動復旧しました」を通知
  → 失敗：retry_count を加算、24 時間経過後は CRITICAL を日次で再通知
```

SSM Agent の一時的な不調、Windows Update による再起動中などは、これで自動的に解消される。

### 10.5 ④ 二重拡張の防止【重要】

中途半端な状態では OS から見た空き容量が変化しないため、アラームは鳴り続ける。
次回のアラーム受信時、以下の分岐を必ず設ける。

```
pending_resize == true の場合
  → EBS 拡張はスキップ
  → OS 側拡張のみ実行
```

**この分岐がない場合、アラームのたびに +20GB され、
費用のみ増加して容量は使えないという最悪の事態を招く。**

### 10.6 ⑤ 手動復旧手順（運用手順書に記載）

Session Manager または RDP で接続し、以下を実行する。

```powershell
$p = Get-Partition -DriveLetter D
$s = Get-PartitionSupportedSize -DiskNumber $p.DiskNumber -PartitionNumber $p.PartitionNumber
Resize-Partition -DiskNumber $p.DiskNumber -PartitionNumber $p.PartitionNumber -Size $s.SizeMax
```

実行後、Parameter Store の `pending_resize` を `false` に手動更新する。

---

## 11. 本番環境の適用方針（A 案 / B 案）

本番環境に対する無人での自動拡張の可否について、2 案を提示する。

### A 案：段階導入型（開発は全自動 / 本番は通知のみ）

```
開発環境：閾値割れ → 自動拡張 → 結果通知
本番環境：閾値割れ → 【要対応】通知のみ
          → 運用者が判断
          → SSM Automation を手動実行
          → 以降は開発環境と同一の処理が動作
```

実装は同一の Step Functions を使用し、Parameter Store の `mode` により分岐する。
手動実行の入口も同一の Automation ドキュメントであるため、二重実装は発生しない。

| 評価 | 内容 |
|---|---|
| ○ | 本番への自動書き込みが無いため、承認を得やすい |
| ○ | 実装・テスト工数が最小 |
| ○ | 開発環境で実績を蓄積した後、本番自動化へ移行できる |
| × | 深夜・休日は人が対応するまで拡張されない（障害防止効果は限定的） |
| × | 「人が見なければ対処されない」という根本課題が一部残る（再通知設計により緩和） |

### B 案：全自動 + Change Calendar による時間帯制御

```
本番も自動化。ただし SSM Change Calendar で実行可能時間帯を制御
  営業時間内（平日 9-18 時）→ CLOSED：拡張せず通知のみ
  営業時間外・休日          → OPEN  ：自動拡張を実行

＜緊急オーバーライド＞
  空き 10% 未満 かつ CLOSED → 通知のみ
  空き  5% 未満             → カレンダーを無視して即時拡張
```

緊急オーバーライドが無い場合、営業時間内に急速な容量増加が発生すると
夜間を待たずに停止する可能性があり、本来の目的を達成できない。
そのため 2 段階の閾値（アラーム 8 本）が必要となる。

| 評価 | 内容 |
|---|---|
| ○ | 24/365 で障害を防止でき、目的を完全に達成できる |
| ○ | 変更が業務時間外に限定され、影響発生時の対応がしやすい |
| × | 本番への無人書き込みに対する心理的ハードル（承認取得に時間を要する可能性） |
| × | アラーム数が倍増し、実装・テスト工数が増加 |
| × | カレンダーの保守（祝日・特別稼働日）が運用タスクとして残る |

### 推奨：A 案 → B 案の段階導入

| # | 理由 |
|---|---|
| 1 | 「暴走が怖い」という懸念に対し、A 案は本番で物理的に暴走し得ない構成であり、最も直接的な回答となる |
| 2 | 開発環境で 1〜2 ヶ月の運用実績（拡張回数・誤検知件数・所要時間）を蓄積し、**数値を根拠として**本番自動化の承認を取得できる |
| 3 | Phase 1 で早期に価値を提供しつつ、Phase 2 を別見積として切り出せる |

**提案上の位置づけ**

- Phase 1（今回スコープ）：A 案
- Phase 2（次期提案）：B 案

---

## 12. テスト計画

### 12.1 テスト方式

対象ドライブを直接使用する場合、閾値到達までに以下の書き込みが必要となる。

| 対象 | 必要書き込み量 |
|---|---|
| dev D: | 約 61 GB |
| dev E: | 約 76 GB |

加えて **EBS ボリュームは縮小できない**ため、テストで拡張した容量は元に戻せず、
費用が恒久的に増加する。

したがって、**テスト専用ボリュームを一時的に作成する方式を推奨する。**

```
1. dev インスタンスに gp3 10GB を追加アタッチ → F: としてフォーマット（GPT）
2. F: を対象とするアラーム / Parameter Store 設定を作成
3. 約 9GB の書き込みで閾値割れを再現（fsutil により数秒）
4. 全シナリオを F: で消化
5. 最終確認として 1 回のみ dev D: で実施
6. F: をデタッチ・削除
```

ダミーファイル作成コマンド：

```powershell
fsutil file createnew F:\_dph_test_dummy.bin 9663676416   # 9GB
Remove-Item F:\_dph_test_dummy.bin                        # 後片付け
```

### 12.2 テストシナリオ

| # | シナリオ | 確認内容 |
|---|---|---|
| 1 | 正常系（auto） | 閾値割れ → EBS +20GB → OS 拡張 → INFO 通知 |
| 2 | 通知のみモード | 拡張されず `dph-action` 通知のみ |
| 3 | 手動 Automation 実行 | 通知後の手動実行で正常に拡張されること |
| 4 | 容量上限到達 | 上限を一時的に低く設定 → スキップ + 通知 |
| 5 | クールダウン中 | 連続実行 → スキップ + 通知 |
| 6 | 月次回数上限 | カウンタを上限値に設定 → スキップ + 通知 |
| 7 | **事前チェック NG** | SSM Agent 停止状態 → **EBS が拡張されないこと** |
| 8 | **中途半端状態からの復旧** | `pending_resize` を手動設定 → **EBS 拡張されず OS 拡張のみ**動作 |
| 9 | 自動復旧 Lambda | 15 分後に自動リトライされること |
| 10 | 未解決の再通知 | 翌日に再通知されること（Scheduler を短周期化して確認） |
| 11 | 冪等性 | 同一アラームの重複配信で二重拡張しないこと |
| 12 | 通知の振り分け | 3 トピックへ正しく配信されること |
| 13 | ウォッチドッグ | メトリクス停止時に通知されること |

**#7・#8 が本設計の中核**であるため、証跡を重点的に取得する。

---

## 13. 構成管理方針

Terraform 等の IaC は未使用であり、Console での手動構築を前提とする。

| 対象 | 方針 |
|---|---|
| CloudWatch Alarm / EventBridge / SNS / IAM | Console で手動構築し、**構築手順書を成果物に含める** |
| Lambda コード | Console 直接編集は行わず、Git または S3（バージョニング有効）で管理し zip でアップロード |
| SSM Document | JSON / YAML を Git 管理 |
| 環境差分 | コードに埋め込まず Parameter Store で外出し（dev / prd で同一コード） |
| 将来の IaC 化 | 今回スコープ外。実施する場合は別途見積とする |

---

## 14. 制約事項・留意点

| # | 内容 |
|---|---|
| 1 | **EBS ボリュームは縮小できない。** 一度拡張した容量は元に戻せず、費用は恒久的に増加する |
| 2 | `ModifyVolume` は同一ボリュームに対し 6 時間の変更間隔制限がある |
| 3 | 拡張直後は `optimizing` 状態となる。容量自体は使用可能だが、`completed` までは数時間を要する |
| 4 | gp3 のベースライン性能は容量に依存しないため、拡張による性能向上は無い |
| 5 | `ImageId` / `InstanceType` が dimension に含まれるため、AMI 更新・インスタンスタイプ変更時はアラームの再作成が必要（6.2 のウォッチドッグで検知） |
| 6 | dev の E: は 100GB、prd の E: は 200GB と構成に差異がある |
| 7 | dev と prd で AMI が異なる（dev: ami-01e8630b… / prd: ami-0adcf082d…） |
| 8 | ディスク番号は再起動により変動する可能性があるため、キャッシュしない |

---

## 15. 残課題

| # | 項目 | 確認先 |
|---|---|---|
| 1 | A 案 / B 案の選択 | リーダー / 顧客 |
| 2 | 本番環境でのドライブ構成の確認（事前チェックスクリプトの実行） | リーダー（本番作業承認） |
| 3 | `dph-action` の通知先（担当者・リーダー） | リーダー |
| 4 | Teams 連携の要否 | 顧客 |
| 5 | Stopper 各値（500GB / 24時間 / 3回）の妥当性 | 顧客 |
| 6 | テストにより dev の EBS が拡張されたまま戻せないことの事前合意 | リーダー |
| 7 | gp3 単価（ap-southeast-1）の確認と最大月額増分の算出 | 自チーム |

---

## 16. 参考：現状と実装後の動作比較

| 空き容量 | 現状 | 実装後（A 案） |
|---|---|---|
| 20% 未満 | メール通知（1 回のみ） | メール通知（**現行のまま変更なし**） |
| 10% 未満（dev） | 通知なし | **自動で +20GB 拡張**、結果を通知 |
| 10% 未満（prd） | 通知なし | 【要対応】通知（**解決するまで日次で再通知**） |
| Stopper 発動時 | — | 拡張せず `dph-action` へ通知 |
| 拡張失敗時 | — | 自動リトライ → 自動復旧 → 日次再通知 |

以上
