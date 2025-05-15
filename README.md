# 

```
# 環境変数設定
$Env:AWS_ACCESS_KEY_ID =　"xxx"
$Env:AWS_SECRET_ACCESS_KEY = "xxx"
# 既存の環境変数にPathを追加
$Env:PSModulePath += ";C:\Downloads\AWS.Tools.4.1.696"
```

```
function CallAwsCommand {
    <#
        .SYNOPSIS
        指定されたAWSモジュールと関数を動的に呼び出し、パラメータを適用してコマンドを実行する

        .PARAMETER ModuleName
        実行するAWSモジュール名（例: "S3"）

        .PARAMETER FunctionName
        実行するAWS関数名（例: "Write-S3Object"）

        .PARAMETER Parameters
        AWS関数に渡すパラメータのハッシュテーブル（オプション）

        .OUTPUTS
        実行結果に応じたオブジェクトまたはメッセージ
    #>
    param(
        [Parameter(Mandatory=$True)][String]$ModuleName,
        [Parameter(Mandatory=$True)][String]$FunctionName,
        [Parameter(Mandatory=$False)][Hashtable]$Parameters = @{ }
    )
    # モジュールのインポート
    Import-Module "AWS.Tools.$ModuleName"
    # パラメータの準備
    $Params = @{ }
    $Parameters.GetEnumerator() | ForEach-Object {
        $Params[$_.Key] = $_.Value
    }
    # AWSコマンドの実行
    & $FunctionName @Params
}


# 使用例:
<#
# S3バケットにオブジェクトを書き込む
$Params = @{
    BucketName = "your-bucket"
    Folder = "C:\LocalFolder"
    KeyPrefix = "remote/path/"
    Recurse = $true
}

CallAwsCommand -ModuleName "S3" -FunctionName "Write-S3Object" -Parameters $Params

また、
CallAwsCommand -ModuleName "S3" -FunctionName "Write-S3Object" -Parameters @{
    BucketName = "your-bucket"
    Folder = "C:\LocalFolder"
    KeyPrefix = "remote/path/"
    Recurse = $true
}
#>
```
