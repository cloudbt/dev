以下のように整理すると、**目的・前提・引継ぎ観点**が明確になり、iNOC担当者向けの引継ぎ内容としてわかりやすいです。

---

# 仮想マシン等のクラウドリソースを手動登録する場合の運用懸念点整理（引継ぎ用）

## 1. 目的

仮想マシン等のクラウドリソースについて、**自動収集ではなく手動登録が可能であることを前提**とし、
ポータル画面からCIの登録・更新申請を行う際に、**運用面で想定される懸念点を整理し、iNOC担当者へ引き継ぐこと**を目的とする。

## 2. 前提

* 対象は AWS / Azure 上の仮想マシン等のクラウドリソースとする
* Service Graph Connector for Azure/AWS による**自動収集は利用しない前提**
* CIの登録・更新は、**ポータル画面からの申請を起点に手動で実施する前提**
* 運用上、iNOC担当者によるメンテナンスや判断が必要となる場面がある
* 一部論点については、NHK様を含めた関係者確認が必要

## 3. 引継ぎしたい主旨

完全手動登録は実施自体は可能と考えられるが、
自動収集と比較すると、**CI間の関係性維持、登録粒度の統一、更新追随、セキュリティ運用との整合、運用負荷**などの面で懸念がある。
そのため、ポータル申請ベースで運用する場合に、事前に認識しておくべき懸念点を整理し、
今後の運用設計・ルール整備・関係者確認に活用できる状態で引き継ぐ。

---

# 4. 既に整理済みの懸念点

## 4-1. 誤ってクラウドリソースを登録した際は、iNOC担当者を通じたメンテナンスが必要

### 懸念

手動登録では、誤登録や誤更新が発生した場合に、利用部門だけでは修正が完結せず、
iNOC担当者を通じたメンテナンスが必要になる可能性がある。

### 想定影響

* 修正完了までに時間を要する
* 修正依頼の受付・確認・対応フローが必要になる
* 誤登録が残存すると、CMDBの信頼性が低下する

---

## 4-2. CI Relationships が収集されないため、各CIの関係性がわからない

### 懸念

手動登録では、自動収集時のようなCI Relationshipsが自動生成されないため、
各CIの依存関係や関連性が十分に表現できない。

### 想定影響

* 依存関係ビューが作成されない
* 障害時の影響範囲確認が難しくなる
* 構成把握や変更影響分析の精度が下がる

---

## 4-3. クラウドアカウント内のリソースについてリージョン関係を維持して登録できない

### 懸念

自動収集時はアカウント配下にリージョン単位でリソースが整理されるが、
手動登録では同様の階層・関係性を維持した登録が難しい。

### 想定影響

* リージョンをまたいだリソースが混在して見える
* 構成の見通しが悪くなる
* 自動収集時の管理方針と整合しにくくなる

---

## 4-4. 手動登録時の、アプリケーションサービスとクラウドリソースの紐づけ基準について整理が必要

### 懸念

手動登録時に、アプリケーションサービスとクラウドリソースをどの単位で紐づけるか、基準を事前に整理する必要がある。

### 想定される紐づけパターン

* AWS / Azure アカウント単位で紐づける
* EC2 / 仮想マシン単位で紐づける
* アプリケーションサービスに親子関係を作成し、子アプリケーションサービスにEC2 / 仮想マシン単位で紐づける

### 想定影響

* 紐づけ基準が曖昧だと案件ごとに登録方針がぶれる
* 構成の見え方が統一されない
* 自動収集時の管理方針との差異が発生する

### 補足

この点は特に、**NHK様の確認・合意が必要な論点**である。

---

## 4-5. クラウドサービスアカウントと紐づかない場合、VR / SIR に影響する可能性がある

### 懸念

AWS / Azure では、クラウドサービスアカウントに設定された設備種別や管理グループの情報を、
配下のクラウドリソースへ反映するようなBRが実装されている。
そのため、手動登録した仮想マシン等のクラウドリソースがクラウドサービスアカウントと適切に紐づかない場合、
VR（Vulnerability Response）やSIR（Security Incident Response）に影響する可能性がある。

### 想定影響

* 必要な属性がリソース側へ反映されない可能性がある
* セキュリティ運用上の分類や管理に支障が出る可能性がある
* 脆弱性管理・インシデント対応の精度に影響する可能性がある

---

# 5. 上記以外に考えられる追加の運用懸念点

## 5-1. リソース増減・変更への追随漏れ

クラウド環境では、仮想マシン、ディスク、NIC、SG、VPC/VNetなどの追加・削除・変更が日常的に発生する。
手動登録では、それらを都度CMDBへ反映する必要があり、更新漏れ・削除漏れが発生しやすい。

## 5-2. 登録タイミング遅延による情報鮮度の低下

申請から登録反映までに時間差が生じるため、CMDB上の情報が実環境に追いつかず、
最新状態を表せない可能性がある。

## 5-3. 命名ルール・属性入力ルールのばらつき

CI名、表示名、環境区分、用途、オーナー情報などの入力ルールが統一されていない場合、
担当者ごとに記載ゆれが発生し、検索性や一覧性が低下する。

## 5-4. 重複登録・誤紐づけの発生

既存CIの確認不足や識別ミスにより、同一リソースの重複登録や、別リソースへの誤紐づけが発生する可能性がある。

## 5-5. 登録対象範囲のばらつき

仮想マシンのみを登録対象とするのか、ネットワーク・ストレージ・セキュリティ関連CIまで含めるのかが明確でないと、
案件ごとに登録粒度が変わってしまう。

## 5-6. 監査証跡・変更履歴の管理負荷増大

誰が、いつ、何を根拠に登録・更新・削除したかを明確に残さないと、
後から変更理由を追跡できず、監査対応や障害調査で負荷が高まる。

## 5-7. 属人化の発生

登録判断や紐づけ方針が担当者依存になると、異動・引継ぎ時に運用品質が下がりやすい。
特に判断基準が文書化されていない場合、引継ぎ後にルールが崩れやすい。

## 5-8. 大規模環境での運用負荷増大

アカウント数、Subscription数、リージョン数、リソース数が多い環境では、
手動登録・更新・棚卸に必要な工数が大きくなり、継続運用が重くなる。

## 5-9. 例外運用の増加

案件都合で簡易登録や一部省略が発生すると、標準ルールが徐々に崩れ、
CMDB全体の一貫性が損なわれる可能性がある。

## 5-10. 障害時・変更時の影響調査精度の低下

CI間の関係や属性が十分でない場合、障害時や変更時に影響範囲を迅速かつ正確に把握しにくくなる。

---

# 6. iNOC担当者へ引き継ぐ際に特に押さえたい観点

## 6-1. 登録・更新・削除の責任分界

* どこまでを申請者が担うか
* どこからをiNOC担当者が担うか
* 誤登録時の修正責任をどう整理するか

## 6-2. 登録基準の標準化

* 登録対象CIの範囲
* 命名ルール
* 必須属性
* 紐づけルール
* 更新・削除の判断基準

## 6-3. 紐づけ方針の明確化

* クラウドサービスアカウントとの紐づけ要否
* アプリケーションサービスとの紐づけ単位
* リージョンの扱い

## 6-4. セキュリティ運用との整合

* VR / SIR に必要な属性や関係性が満たせるか
* BRによる属性反映の前提条件を満たせるか
* 手動登録時の代替運用が必要か

## 6-5. 継続運用の現実性

* 初期登録だけでなく、更新・棚卸まで含めて運用可能か
* 大規模環境でも回るルール設計になっているか
* 属人化しない運用にできるか

---

# 7. 引継ぎメッセージとしてのまとめ案

仮想マシン等のクラウドリソースについて、手動登録そのものは可能と考えられるが、
自動収集を利用する場合と比べると、**CI関係性の不足、リージョンや階層構造の維持困難、紐づけ基準の整理不足、属性反映やVR/SIRへの影響、更新追随漏れ、運用負荷増大**といった懸念がある。

そのため、ポータル画面からCI登録・更新申請を前提に運用する場合は、
単に登録できるかどうかだけではなく、**どの粒度で、どの基準で、誰が、どのタイミングで維持管理するか**を明確にした上で運用設計する必要がある。
本整理は、その前提認識をiNOC担当者へ引き継ぐためのものである。

---

必要であれば次に、これをベースに**「引継ぎ資料向けの、もっと業務文書らしい文体」**へ整えます。


# Dev Repository

This repository contains scripts, documentation, and resources organized by purpose.

## Directory Structure

```
.
├── sap/              # SAP related scripts and documentation
├── automation/       # Automation scripts and tools
├── aws/              # AWS related scripts and configurations
├── servicenow/       # ServiceNow scripts and integration documentation
└── docs/             # General documentation and learning materials
```

## Contents by Category

### SAP
- **sap-login-scripts.md** - SAP GUI automatic login batch scripts with CSV password management
- **sap-performance-notes.md** - Performance issues analysis and solutions

### Automation
- **worktime-collection-script.md** - Monthly work time collection script from Outlook emails
- **excel-automation-snippets.md** - Excel automation PowerShell code snippets
- **jp1-automation-script.md** - JP1 automation script with remote execution
- **windows-remote-management.md** - WinRM and RDP automation scripts

### AWS
- **aws-config-scripts.md** - AWS Config PowerShell scripts for resource management

### ServiceNow
- **tanium-integration.md** - Tanium integration documentation and data flow
- **rte-entity-mapping-scripts.md** - Runtime Transform Engine (RTE) entity mapping scripts
- **import-set-scripts.md** - Import Set scripts and conditional scheduling
- **user-role-scripts.md** - User and role management scripts

### Docs
- **STUDY_BACKUP.md** - Study notes and backup documentation
- **tools.md** - Tools and utilities reference
- **MailToTask.txt** - Mail to task conversion notes

## Quick Links

### SAP
- [SAP Login Scripts](sap/sap-login-scripts.md)
- [SAP Performance Notes](sap/sap-performance-notes.md)

### Automation
- [Work Time Collection](automation/worktime-collection-script.md)
- [Excel Automation](automation/excel-automation-snippets.md)
- [JP1 Automation](automation/jp1-automation-script.md)
- [Windows Remote Management](automation/windows-remote-management.md)

### AWS
- [AWS Config Scripts](aws/aws-config-scripts.md)

### ServiceNow
- [Tanium Integration](servicenow/tanium-integration.md)
- [RTE Entity Mapping](servicenow/rte-entity-mapping-scripts.md)
- [Import Set Scripts](servicenow/import-set-scripts.md)
- [User Role Scripts](servicenow/user-role-scripts.md)

## Usage

Each folder contains detailed documentation in markdown format. Refer to individual files for specific instructions and usage examples.

## Contributing

When adding new content:
1. Place files in the appropriate category folder
2. Use descriptive file names in lowercase with hyphens
3. Update this README with links to new content
4. Include clear documentation and usage examples
