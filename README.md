

```
# 指定するグループ名またはID
$groupA = "GroupA"  # ここに実際のグループ名またはIDを指定してください

# 結果保存用のファイル
$outputFile = "group_a_direct_members.json"

# GroupAのIDを取得
$groupAInfo = az ad group show --group $groupA | ConvertFrom-Json

if (-not $groupAInfo) {
    Write-Host "エラー: グループ '$groupA' が見つかりません。" -ForegroundColor Red
    exit
}

# GroupAのメンバー一覧を取得
Write-Host "グループ '$groupA' の直接のメンバーを取得しています..." -ForegroundColor Cyan
$members = az ad group member list --group $groupAInfo.id | ConvertFrom-Json

# メンバーを分類（グループとユーザー）
$groupMembers = @()
$userMembers = @()

foreach ($member in $members) {
    if ($member.objectType -eq "Group") {
        # グループメンバーの場合、グループの詳細情報を取得
        $groupDetail = az ad group show --group $member.id | ConvertFrom-Json
        $groupMembers += [PSCustomObject]@{
            id = $groupDetail.id
            displayName = $groupDetail.displayName
            description = $groupDetail.description
            objectType = "Group"
            mail = $groupDetail.mail
        }
    } else {
        # ユーザーメンバーの場合
        $userDetail = az ad user show --id $member.id | ConvertFrom-Json 2>$null
        if ($userDetail) {
            $userMembers += [PSCustomObject]@{
                id = $userDetail.id
                displayName = $userDetail.displayName
                userPrincipalName = $userDetail.userPrincipalName
                objectType = "User"
                mail = $userDetail.mail
            }
        } else {
            # サービスプリンシパルなど、ユーザー以外のエンティティの場合
            $userMembers += $member
        }
    }
}

# 結果を作成
$result = [PSCustomObject]@{
    id = $groupAInfo.id
    displayName = $groupAInfo.displayName
    description = $groupAInfo.description
    directGroupMembers = $groupMembers
    directUserMembers = $userMembers
}

# 結果を保存
$result | ConvertTo-Json -Depth 5 > $outputFile
Write-Host "完了しました。結果は $outputFile に保存されました。" -ForegroundColor Green

# 概要を表示
Write-Host ""
Write-Host "概要:" -ForegroundColor Yellow
Write-Host "グループ数: $($groupMembers.Count)" -ForegroundColor Yellow
Write-Host "ユーザー数: $($userMembers.Count)" -ForegroundColor Yellow
```
