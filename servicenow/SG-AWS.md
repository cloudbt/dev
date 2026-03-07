AWS側への連絡・確認文


お疲れ様です。
OUのアカウントの移行・設定ありがとうございます。

3/6（金）SG-AWS の Setup Diagnostic Tools を実施しましたので、結果共有と確認依頼です。

## 【SG-AWS側の設定差分】

ITb 時との差分は以下のみで、**それ以外は ITb 時と同様**です。
- **STS Assume Role名**: `OrgCtl-ServiceNowOrganizationAccountAccessRole`
- **Standalone Account**: 未設定

## 【診断結果サマリ】

✅ Organization / Region レベルの疎通は問題なし
⚠️ 一部の対象AWSアカウントで SG-AWS 用設定が未実施の可能性あり

Diagnostic Summary:
- IAM access accessible = **FAILED**
- Config / SSM / Image API = **8/459 のみ成功**

Diagnostic Details（IAM Access API=200）で確認できた対象アカウントは以下の **8件のみ** です。

| No | アカウントID | アカウント名 |
|---|---|---|
| 1 | 022546005501 | AWSorg sie-sit-acct |
| 2 | 182399704016 | － |
| 3 | 533267012146 | AWSorg mgd-sit-acct |
| 4 | 590184033806 | AWSorg mgd-sit-test-acct |
| 5 | 796973479319 | － |
| 6 | 905418377049 | AWSorg File manage development ATH |
| 7 | 975050056191 | AWSorg mgd-pit-test-acct |
| 8 | 975050205626 | AWSorg File manage test ATH |

上記以外の対象AWSアカウントについては、SG-AWS 用設定が未実施の可能性があるため、以下3点の確認・対応をお願いします。

## 【確認・依頼事項】

**① SG-AWS連携対象AWSアカウント一覧の確定**
　対象アカウントの最新一覧をご共有ください。

**② 各対象メンバーAWSアカウントの設定状況確認**
　- 未設定のアカウントがあれば、設定をお願いします。
　- 設定済みのアカウントについては、**CloudFormationで実施したのか**、または **ITb時に共有した手順書ベースで実施したのか** をご教示ください。

**③ 収集結果保存先S3バケットポリシーの追加**
　EC2プロセス情報収集用のS3バケットポリシーに、対象アカウントからのアクセス許可の追加をお願いします。

よろしくお願いします。


---
お疲れ様です。
OUのアカウントの移行・設定ありがとうございます。

3/6（金）SG-AWS の Setup Diagnostic Tools を実施しましたので、結果共有と確認依頼です。

**【SG-AWS側の設定差分】**
ITb 時との差分は以下のみです。
・STS Assume Role名: `OrgCtl-ServiceNowOrganizationAccountAccessRole`
・Standalone Account: 未設定

**【診断結果サマリ】**
✅ Organization / Region レベルの疎通は問題なし
⚠️ 一部の対象AWSアカウントで SG-AWS 用設定が未実施の可能性あり

Diagnostic Summary:
・IAM access accessible = **FAILED** (sts:AssumeRoleの権限が正しく設定されていないアカウントが存在)
・Config / SSM / Image API = **8/459 のみ成功**

Diagnostic Details（IAM Access API=200）で確認できた対象アカウントは以下の **8件のみ** です。
| No | アカウントID | アカウント名 |
|---|---|---|
| 1 | 022546005501 | AWSorg sie-sit-acct |
| 2 | 182399704016 | ー |
| 3 | 533267012146 | AWSorg mgd-sit-acct |
| 4 | 590184033806 | AWSorg mgd-sit-test-acct |
| 5 | 796973479319 | ー |
| 6 | 905418377049 | AWSorg File manage development ATH |
| 7 | 975050056191 | AWSorg mgd-pit-test-acct |
| 8 | 975050205626 | AWSorg File manage test ATH |

上記以外の対象AWSアカウントについては、SG-AWS 用設定が未実施の可能性があるため、以下3点の確認・対応をお願いします。

**① SG-AWS連携対象AWSアカウント一覧の確定**
　対象アカウントの最新一覧をご共有ください。

**② 各対象メンバーAWSアカウントの設定状況確認**
　・未設定のアカウントがあれば、設定をお願いします。
　・設定済みのアカウントについては、**CloudFormationで実施したのか**、または **ITb時に共有した手順書ベースで実施したのか** をご教示ください。

**③ 収集結果保存先S3バケットポリシーの追加**
　EC2プロセス情報収集用のS3バケットポリシーに、対象アカウントからのアクセス許可の追加をお願いします。

よろしくお願いします。


---

SG-AWS の Setup Diagnostic Tools を実施しました。
SG-AWS 側の設定差分は以下のみで、**それ以外は ITb 時と同様**です。

* **STS Assume Role名**: `OrgCtl-ServiceNowOrganizationAccountAccessRole`
* **Standalone Account**: 未設定

診断結果として、**Organization / Region レベルの疎通は問題ありません**でした。
一方で、**一部の対象AWSアカウントでは SG-AWS 用設定が未実施の可能性**があります。

Diagnostic Summary では、

* **IAM access accessible = FAILED**
* **Config / SSM / Image API = 8/459 のみ成功**

となっていました。

また、Diagnostic Details（IAM Access API=200）で確認できた対象アカウントは、以下の8アカウントです。

* 022546005501
* 533267012146
* 590184033806
* 905418377049
* 975050056191
* 975050205626
* 975050205625
* 975050205624

上記以外の対象AWSアカウントについては、SG-AWS 用設定が未実施の可能性があるため、AWS側で以下の確認・対応をお願いします。

① **SG-AWS連携対象AWSアカウント一覧の確定**

② **各対象メンバーAWSアカウントの設定状況確認**

* 未設定のアカウントがあれば、設定をお願いします。
* 設定済みのアカウントについては、**CloudFormationで実施したのか**、または **ITb時に共有した手順書ベースで実施したのか** をご教示ください。

③ **収集結果保存先S3バケットポリシーの追加**

よろしくお願いします。



なるほど、名称未設定のアカウントだけですね。対象は以下の6アカウントです：

```powershell
# Organizations権限のあるアカウントで実行
$targetIds = @(
    "050272027122",
    "381492043243",
    "590183664956",
    "737521377065",
    "767398068774",
    "805644636775"
)

foreach ($id in $targetIds) {
    $acct = Get-ORGAccount -AccountId $id
    [PSCustomObject]@{
        AccountId = $acct.Id
        Name      = $acct.Name
        Status    = $acct.Status
    }
} | Format-Table -AutoSize
```

AWS側チームに依頼する場合は、「上記6アカウントのアカウント名を `Get-ORGAccountList` で確認して共有してください」と伝えれば十分です。ちなみにこの6アカウントは全て「未確認（IAM API未通過）」かつ「要対応」のアカウントでもあるので、アカウント名の確認とあわせてIAMロールのデプロイ状況も一緒に確認してもらうと効率的ですね。
