# AWS Config PowerShell Scripts

## AWS Config リソース検索・取得スクリプト

### リソース検索（Select-CFGResourceConfig）

```powershell
# VPCリソースを検索
Select-CFGResourceConfig -Expression "SELECT resourceId, resourceType WHERE resourceType = 'AWS::EC2::VPC'"
```

### 複数リソースの設定を一括取得（Get-CFGGetResourceConfigBatch）

```powershell
# リソースキーの配列を定義
$resourceKeys = @(
    @{
        ResourceType = "AWS::EC2::VPC"
        ResourceId = "vpc-02f6419c0024583d8"
    },
    @{
        ResourceType = "AWS::EC2::NetworkAcl"
        ResourceId = "acl-035e429f9ad31f322"
    }
)

# バッチでリソース設定を取得
$result = Get-CFGGetResourceConfigBatch -ResourceKey $resourceKeys

# 結果を表示
Write-Output "取得したリソース設定："
$result.BaseConfigurationItems | ForEach-Object {
    Write-Output "リソースタイプ: $($_.ResourceType)"
    Write-Output "リソースID: $($_.ResourceId)"
    Write-Output "設定取得時刻: $($_.ConfigurationItemCaptureTime)"
    Write-Output "設定状態: $($_.ConfigurationItemStatus)"
    Write-Output "---"
}
```

## 使用例

### 特定のリソースタイプを検索

```powershell
# EC2インスタンスを検索
Select-CFGResourceConfig -Expression "SELECT resourceId, resourceName, resourceType WHERE resourceType = 'AWS::EC2::Instance'"

# S3バケットを検索
Select-CFGResourceConfig -Expression "SELECT resourceId, resourceName WHERE resourceType = 'AWS::S3::Bucket'"

# セキュリティグループを検索
Select-CFGResourceConfig -Expression "SELECT resourceId, resourceName WHERE resourceType = 'AWS::EC2::SecurityGroup'"
```

### タグでフィルタリング

```powershell
# 特定のタグを持つリソースを検索
Select-CFGResourceConfig -Expression "SELECT resourceId, resourceType, tags WHERE tags.tag = 'Environment=Production'"
```

### 複数条件での検索

```powershell
# 複数条件を組み合わせた検索
Select-CFGResourceConfig -Expression "SELECT resourceId, resourceType, availabilityZone WHERE resourceType = 'AWS::EC2::Instance' AND availabilityZone = 'ap-northeast-1a'"
```

## AWS Config Cmdlet リファレンス

### 主要なコマンドレット

| Cmdlet | 説明 |
|--------|------|
| `Select-CFGResourceConfig` | SQL風のクエリでリソースを検索 |
| `Get-CFGGetResourceConfigBatch` | 複数リソースの設定を一括取得 |
| `Get-CFGResourceConfigHistory` | リソースの設定履歴を取得 |
| `Get-CFGDiscoveredResource` | 検出されたリソースのリストを取得 |

### パラメータ

#### Select-CFGResourceConfig
- `-Expression`: 検索条件を指定するSQL風のクエリ文字列
- `-Limit`: 取得する結果の最大数
- `-NextToken`: ページネーション用のトークン

#### Get-CFGGetResourceConfigBatch
- `-ResourceKey`: リソースキーの配列（ResourceType と ResourceId のハッシュテーブル）

## 注意事項

### 前提条件
1. AWS Config が有効になっている必要があります
2. AWS PowerShell モジュール（AWSPowerShell または AWSPowerShell.NetCore）がインストールされている必要があります
3. 適切な IAM 権限が必要です：
   - `config:SelectResourceConfig`
   - `config:BatchGetResourceConfig`
   - `config:GetResourceConfigHistory`

### インストール

```powershell
# AWS PowerShell モジュールのインストール
Install-Module -Name AWSPowerShell.NetCore -Force -AllowClobber

# 認証情報の設定
Set-AWSCredential -AccessKey "YOUR_ACCESS_KEY" -SecretKey "YOUR_SECRET_KEY" -StoreAs "default"

# デフォルトリージョンの設定
Set-DefaultAWSRegion -Region ap-northeast-1
```

### パフォーマンスの考慮事項
- `Get-CFGGetResourceConfigBatch` は最大100リソースまで一度に取得可能
- 大量のリソースを取得する場合はページネーションを使用
- クエリの複雑さによって応答時間が変わる

## トラブルシューティング

### よくあるエラー

**エラー**: "ResourceNotDiscoveredException"
- **原因**: 指定したリソースがAWS Configで検出されていない
- **解決**: リソースIDが正しいか確認し、AWS Configの設定を確認

**エラー**: "AccessDeniedException"
- **原因**: IAM権限が不足している
- **解決**: 必要な権限をIAMロール/ユーザーに追加

**エラー**: "InvalidExpressionException"
- **原因**: クエリ構文が正しくない
- **解決**: クエリ構文を確認し、AWS Config クエリリファレンスを参照
