
Azure環境にSG-Azure専用アプリを登録し、構成情報を収集するために必要な認証・権限・基盤を整備するため

SG-Azureにはジョブエラーの自動通知機能がないため、日次ジョブ実行後に手動でエラー有無を確認する必要がある。

1-7～1-9: ServiceNowにAzureとの接続設定を作成し、定期的な自動インポートを有効にするため
2-1～2-2: 追加サブスクリプションにSG-Azure用の閲覧権限とポリシーを適用するため
3-1～3-3: VMのソフトウェア・プロセス・TCP情報を収集するための監視エージェントと通信を整備するため
# SG-Azure 自動収集における前提条件と根拠

本資料の記載内容は **2026年3月1日時点** の情報に基づく。最新情報は各参照先ドキュメントを確認のこと。

---

## 前提条件一覧

| # | 分類 | 前提条件 | 根拠 | 備考 |
|:-:|:----:|---------|:----:|------|
| 1 | 共通 | Azure AD アプリ登録（App Registration）の作成 | ①②③ | |
| 2 | 共通 | Microsoft Graph API「User.Read」権限（委任）の付与 | ③ | |
| 3 | 共通 | 対象サブスクリプションの「閲覧者（Reader）」ロール付与 | ③ | |
| 4 | 共通 | ServiceNow側 ハードウェア接続の構成 | ①② | |
| 5 | SW収集 | Azure Log Analytics ワークスペースの作成 | ③⑤ | HW収集のみの場合は不要 |
| 6 | SW収集 | Log Analytics API「Data.Read」権限（委任）の付与 | ③ | |
| 7 | SW収集 | Azure Monitoring Agent (AMA) のインストール | ③⑦ | AMA未導入の場合、SW情報収集不可 |
| 8 | SW収集 | 変更履歴とインベントリ用DCRの構成 | ③ | |
| 9 | SW収集 | ServiceNow側 ソフトウェア接続の構成 | ①②③ | |
| 10 | プロセス/TCP | VM insights の有効化（Dependency Agent含む） | ④⑧ | 未導入の場合、プロセス・TCP情報収集不可 |
| 11 | プロセス/TCP | プロセスとTCP接続用DCRの構成 | ④ | SW用DCR（#8）とは別に必要 |
| 12 | Linux制約 | Linux Guest Agent 2.4.0.2未満ではDeep Discovery収集不可 | ③⑥ | RunCommand機能が非サポートのため |
| 13 | Linux制約 | 2.4.0.2未満のVMはLog Analytics＋DependencyAgentで代替 | ③④ | プロセス・TCP接続のみ代替可能 |

---

## 参照先ドキュメント一覧

| No. | ドキュメント名 | URL |
|:---:|--------------|-----|
| ① | ServiceNow Docs - SG-Azure 概要 (Yokohama) | https://www.servicenow.com/docs/bundle/yokohama-servicenow-platform/page/product/configuration-management/concept/cmdb-integration-azure.html |
| ② | ServiceNow Docs - SG-Azure 構成手順 (Yokohama) | https://www.servicenow.com/docs/bundle/yokohama-servicenow-platform/page/product/configuration-management/task/configure-azure-integration.html |
| ③ | ServiceNow Community - Azure SGC Version 1.12 | https://www.servicenow.com/community/cmdb-articles/azure-service-graph-connector-version-1-12/ta-p/3308034 |
| ④ | ServiceNow Community - Azure SGC Version 1.10 | https://www.servicenow.com/community/cmdb-articles/azure-service-graph-connector-version-1-10/ta-p/3079902 |
| ⑤ | ServiceNow Community - SG-Azure Overview | https://www.servicenow.com/community/cmdb-articles/service-graph-connector-for-azure-overview/ta-p/2301822 |
| ⑥ | Microsoft Learn - Managed Run Commands (Linux VM) | https://learn.microsoft.com/en-us/azure/virtual-machines/linux/run-command-managed |
| ⑦ | Microsoft Learn - Azure Monitoring Agent overview | https://learn.microsoft.com/en-us/azure/azure-monitor/agents/azure-monitor-agent-overview |
| ⑧ | Microsoft Learn - VM insights overview | https://learn.microsoft.com/en-us/azure/azure-monitor/vm/vminsights-overview |

















■SG-Azureによる自動収集の前提条件・制約事項
SG-Azureを使用してAzure環境から構成情報を自動収集するにあたり、以下の前提条件および制約事項がある。

【Azure側の前提条件】
1. Microsoft Entra ID（旧Azure AD）にSG-Azure専用のアプリ登録（サービスプリンシパル）が
   作成されていること。
   - Microsoft Graph API（User.Read, Delegated）およびLog Analytics API（Data.Read, Delegated）
     の権限が付与されていること。
   - 有効なクライアントシークレットが設定されていること（有効期限は最大24か月、
     本運用では180日ごとにローテーションを実施）。

2. 対象サブスクリプションのIAMにおいて、SG-Azure専用アプリに
   「閲覧者（Reader）」ロールが割り当てられていること。

3. ソフトウェア情報の収集には、以下の構成が必要である。
   - Log Analyticsワークスペースが作成されていること。
   - Azure Monitoring Agent（AMA）が対象仮想マシンにインストールされていること。
   - Change Tracking and Inventory機能が有効化され、対応するData Collection Rule（DCR）が
     仮想マシンに関連付けられていること。
   ※AMAが導入されていない仮想マシンからは、ソフトウェア情報および
    TCPコネクション情報を収集することができない。

4. プロセス情報・TCPコネクション情報の収集には、VM insights（Dependency Agent）の
   有効化が必要である。

【Linux VMに関する制約事項】
- Linux VMのバージョンが2.4.0.2より古い場合、Azure RunCommand機能が
  サポートされないため、SG-AzureによるDeep Discoveryデータ
  （プロセス・TCPコネクション等）の収集ができない。
  ※当該バージョン未満のLinux VMについては、Log Analyticsワークスペースおよび
   Dependency Agentを使用した代替方式での収集が可能である。
- AMAがサポートするLinuxディストリビューションおよびカーネルバージョンに制限がある。
  詳細はMicrosoft公式ドキュメント「Azure Monitor Agent supported operating systems」
  を参照すること。
- Change Tracking拡張機能は、Linuxのハードニング標準をサポートしていない。

【ServiceNow側の前提条件】
- Service Graph Connector for Microsoft Azureプラグイン（ServiceNow Store）が
  インストールされていること。
  ※最新版: 1.15.0
  ※対応プラットフォームバージョン: Zurich, Yokohama, Xanadu, Washington DC,
   Vancouver, Utah
- システム管理者権限でログインし、システム言語を英語に設定して作業すること。

【その他の注意事項】
- SG-Azureにはキーローテーション機能および通知機能が組み込まれていないため、
  クライアントシークレットの有効期限管理は手動で行う必要がある。
- Change Tracking and Inventoryの有効化により、Azure Monitorおよび
  Azure Automationに追加料金が発生する場合がある。
  事前にAzure Monitorの料金体系を確認すること。
- 日本語・中国語環境のVMでは、Change Tracking拡張機能のSvcNameや
  SoftwareNameフィールドが文字化けする既知の問題がある
  （AMA for Windows 1.24.0以降で修正済み）。

※本手順書は2026年3月1日時点の情報に基づいて記載している。
 最新の前提条件・制約事項・サポート対象については、以下の公式ドキュメント
 （英語版）を参照すること。

- ServiceNow Docs - Service Graph Connector for Microsoft Azure (Yokohama):
  https://www.servicenow.com/docs/bundle/yokohama-servicenow-platform/page/product/configuration-management/concept/cmdb-integration-azure.html

- ServiceNow Docs - Configure Service Graph Connector for Microsoft Azure (Yokohama):
  https://www.servicenow.com/docs/bundle/yokohama-servicenow-platform/page/product/configuration-management/task/configure-azure-integration.html

- ServiceNow Docs - Service Graph Connector for Microsoft Azure Properties (Yokohama):
  https://www.servicenow.com/docs/bundle/yokohama-servicenow-platform/page/product/configuration-management/reference/cmdb-sgc-azure-props.html

- ServiceNow Docs - CMDB classes targeted in Service Graph Connector for Microsoft Azure (Yokohama):
  https://www.servicenow.com/docs/bundle/yokohama-servicenow-platform/page/product/configuration-management/reference/cmdb-azure-classes.html

- ServiceNow Store - Service Graph Connector for Microsoft Azure:
  https://store.servicenow.com/store/app/9fe86b2e1be06a50a85b16db234bcb0a

- Microsoft Learn - Azure Change Tracking and Inventory (AMA):
  https://learn.microsoft.com/en-us/azure/azure-change-tracking-inventory/overview-monitoring-agent

- Microsoft Learn - Azure Monitor Agent supported operating systems:
  https://learn.microsoft.com/en-us/azure/azure-monitor/agents/azure-monitor-agent-supported-operating-systems

- Microsoft Learn - Azure Change Tracking and Inventory Support matrix:
  https://learn.microsoft.com/en-us/azure/azure-change-tracking-inventory/change-tracking-inventory-support-matrix


```
■SG-Azureによる自動収集の前提条件
SG-Azureを使用してAzure環境の構成情報を自動収集する場合、以下の前提条件を満たす必要がある。

【共通の前提条件（ハードウェア情報収集）】
・Azure側にService Graph Connector専用のアプリ登録（App Registration）が作成されていること
・専用アプリに対して、対象サブスクリプションの「閲覧者（Reader）」ロールが付与されていること
・専用アプリに対して、Microsoft Graph API「User.Read」（委任）権限が付与されていること
・ServiceNow側にSG-Azureストアアプリがインストールされ、ハードウェア接続が構成されていること

【ソフトウェア情報収集の前提条件】
・Azure Log Analyticsワークスペースが作成されていること
・専用アプリに対して、Log Analytics API「Data.Read」（委任）権限が付与されていること
・対象VMにAzure Monitoring Agent (AMA) がインストールされていること
・「変更履歴とインベントリ（Change Tracking and Inventory）」用のデータ収集ルール（DCR）が構成されていること
・ServiceNow側にソフトウェア接続が構成されていること
※AMAが導入されていない場合、ソフトウェアインストール情報の収集は不可となる。

【プロセス・TCP接続情報収集の前提条件】
・VM insights が有効化されていること
・「プロセスとTCP接続（Processes and TCP Connections）」用のデータ収集ルール（DCR）が構成されていること
※AMAおよびVM insightsが導入されていない場合、実行プロセス情報およびTCP接続情報の収集は不可となる。

【Linux VMに関する制約事項】
・Azure Linux Guest Agentのバージョンが2.4.0.2未満のLinux VMでは、SG-AzureのDeep Discovery（ソフトウェア・プロセス・TCP接続等の詳細収集）データは収集されない。
　これは、バージョン2.4.0.2未満のLinux VMがAzure RunCommand機能をサポートしていないためである。
・バージョン2.4.0.2未満のLinux VMから実行プロセス・TCP接続データを収集する場合は、
　Log Analyticsワークスペースおよび関連するDependencyAgent Azure Monitoring Extensionを使用した代替手段で対応する必要がある。

【注意事項】
・本手順書の記載内容は、2026年3月1日時点の情報に基づいている。
・最新の前提条件、対応バージョン、および制約事項については、以下のServiceNow公式ドキュメント（現時点の最新リリースであるWashington DCバージョン）を参照すること。
　ServiceNow Docs - Service Graph Connector for Microsoft Azure：
　https://www.servicenow.com/docs/bundle/washingtondc-servicenow-platform/page/product/configuration-management/concept/cmdb-integration-azure.html
・Azure RunCommand機能のLinux VMサポート要件については、以下のMicrosoft公式ドキュメントを参照すること。
　Microsoft Learn - Run scripts in a Linux VM using managed Run Commands：
　https://learn.microsoft.com/en-us/azure/virtual-machines/linux/run-command-managed
```


```
項番  追記する備考内容
────────────────────────────────────────────────────
1-1   SG-AzureがAzure環境へAPIアクセスするために必要な認証用アプリケーションを作成するため
1-2   SG-Azureがユーザー情報およびLog Analyticsデータを取得するために必要なAPI権限を付与するため
1-3   SG-AzureがAzureへOAuth認証するために必要なクライアントシークレットを発行するため
1-4   各サブスクリプションに分散するソフトウェアデータをLog Analytics経由で一元的に収集するため
1-5   SG-Azure専用アプリが統合管理サブスクリプションのリソース情報を読み取れるようにするため
1-6   ソフトウェア情報・プロセス情報・TCPコネクション情報の収集先として必要なため
      ※AMAを使用しない場合、本設定は不要
1-7   SG-AzureがAzureからハードウェア構成情報（VM、ネットワーク等）を取得するための接続を作成するため
1-8   SG-AzureがAzureからソフトウェア情報を取得するための接続を作成するため
1-9   作成した接続に対して定期的な自動インポートを実行させるため
2-1   SG-Azure専用アプリが追加サブスクリプションのリソース情報を読み取れるようにするため
2-2   Change Tracking and Inventory等のAzure機能をサブスクリプション配下のVMに自動適用するため
3-1   VMにインストールされたソフトウェアおよび構成変更の情報をSG-Azureで収集可能にするため
3-2   VMのプロセス情報およびTCPコネクション情報をSG-Azureで収集可能にするため
      ※AMAを使用しない場合、本設定は不要。その場合ソフトウェア情報・TCP情報収集不可
3-3   SG-AzureがWindows VMに対してRunCommandを実行するために必要な通信経路を確保するため
4-1   不要なサブスクリプションの構成情報がServiceNow CMDBに取り込まれないようにするため
      ※Azure側で関連情報を解除すればよい。ServiceNow側での設定変更は特に不要
6-1   構成情報収集時にエラーが発生していないかを確認し、データ欠損を早期に検知するため
7-1   エラー発生時のリカバリ方針（差分収集で再実行するか、全量収集で再取得するか）を判断するため
```

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
