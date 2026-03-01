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
