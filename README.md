

会議の内容を整理し、重要なポイントと今後のアクション（ToDo）をまとめました。
会議の要約
プラグインのアップデートとワークスペース移行に関する確認が行われました。主な議題は、既存設定の維持、バージョンアップの可否、およびインストール時の制約についてです。
 * セットアップ環境の変更: 今後は「ワークスペース」経由でのセットアップが推奨されるが、既存（旧方式）で設定済みのものもそのまま表示・利用可能であり問題ない。
 * バージョン3.8.1へのアップグレード: インスタンスの場所（横浜など）によって制限があるか懸念されたが、デモ環境ではアップグレードの表示が確認できた。
 * インストール時の制約: ストアで許可されていないパッケージ（SGC関連など）があるため、先に許可を得るプロセスが必要になる可能性がある。
ToDoリスト
【確認・調査】
 * [ ] インスタンスバージョンの確認: 現在のインスタンス（横浜等）で、本当にバージョン3.8.1まで上げられるのか詳細を確認する。
 * [ ] 依存パッケージの確認: SGC等の依存パッケージがストアで許可されているか確認し、未許可の場合は許可申請の手順を整理する。
 * [ ] 手順書の精査: アップグレードに関する注意事項2点について、既存の手順書に正しく記載されているか確認する。
【共有・連絡】
 * [ ] エビデンスの共有: アップグレード画面のキャプチャを撮影し、関係者に共有する。
 * [ ] ジョさんへの連携: 調査結果および確認事項について、ジョさんへ情報を共有する。
> [!NOTE]
> 発言者の方が本日16時に早退されるとのことですので、急ぎの確認事項がある場合は早めの連絡が良さそうです。
> 
こちらの内容で、議事録のドラフトとして修正や追加したい部分はありますか？




アップロードされた音声ファイル の内容に基づき、会議の文字起こしと要約を以下にまとめました。
会議の要約
本会議では、スマート配送のステータス通知におけるシステム構成の妥当性について議論が行われました。
 * 現状の課題: 既存の「ワークステータスラムダ（Lambda）」を介して新機能を実装する案が出ていますが、参加者からは「構成として美しくない」「既存への影響が懸念される」といった否定的な意見が相次ぎました。
 * 主な懸念点:
   * 特定の条件分岐のためにRDS（データベース）へ問い合わせる必要があり、現在のイベント駆動の仕組みと噛み合っていない可能性があること。
   * 処理が多段（ラムダの連鎖）になることで、エラー時の影響範囲の特定やデバッグが困難になるリスク。
 * 提案と今後の方針:
   * 既存のラムダに相乗りするのではなく、EventBridge側でロジックを分岐させ、新しいラムダを直接呼び出す構成が望ましいとの意見で一致しました。
   * この設計上の懸念について、依頼元のチームへヒアリングおよびアドバイスを行うこととし、本提案内容で投票・承認を進める運びとなりました。
文字起こし（要約版）
A: この依頼元のIssueにある図なんですが、正直ナンセンスだと思っています。既存の「ワークステータスラムダ」を呼び出す形になっていますが、これだとEventBridgeからのメッセージだけでは分岐条件が分からず、RDSに問い合わせる必要が出てきます。
B: なるほど。あまり良い構成とは思えませんね。
A: 例えばスマート配送の契約ステータスによって振り分けるようなロジックが必要になります。既存のラムダをいじりたくないという意図はあるかもしれませんが、処理が何段も重なると、どこでエラーが起きたか分かりづらくなります。
B: そうですね。EventBridge側でロジックを分けて、直接新しいラムダを呼び出した方がシンプルです。
A: 既存のワークステータスラムダに依存する形は避けるべきです。共通処理がそこにあるからという理由かもしれませんが、設計としてもう少しアドバイスが必要ですね。
C: （笑いながら）Issue番号が「401（Unauthorized）」なのも縁起が悪いですね。
A: 構成の検討も含めて、この方針で投票に進めたいと思います。他に質問はありますか？
一同: 大丈夫です。
こちらの要約に基づいた、依頼元へのフィードバック案の作成など、お手伝いできることはありますか？

会議で議論された懸念点について、音声内容に基づきさらに掘り下げて詳しく解説します。
主な問題は、**「現状の提案構成が、運用の複雑さを増大させ、システムの透明性を損なっている」**という点に集約されます。
1. データの不整合とDB依存の増加
 * イベント情報の不足: 本来、EventBridgeから送られてくるメッセージだけで後続の処理が完結するのが理想的ですが、今回のケースではそのデータだけでは「どの処理に分岐させるか」の判断ができません。
 * RDSへの追加クエリ: 分岐条件を判断するために、わざわざRDS（データベース）へユーザーの契約状況や設定を読みに行く必要が生じています。これはイベント駆動型設計としては非効率であり、DBへの負荷や処理遅延を招く懸念があります。
2. ラムダの多段構成（チェイン）によるリスク
 * エラー特定の困難さ: 既存の「ワークステータスラムダ」からさらに別のラムダを呼び出すような「多段処理」になると、処理の途中でエラーが起きた際の影響範囲が広がり、原因究明が非常に難しくなります。
 * 保守性の低下: 処理が重なることで、システム全体の流れが追いづらくなり、将来的な仕様変更やメンテナンスのコストが増大することが危惧されています。
3. 「既存コードへの接触回避」が招く不自然な設計
 * 消極的な理由による構成: 参加者は、この構成が選ばれた理由を「既存のラムダ（ワークステータスラムダ）のソースコードを極力いじりたくない、あるいは既存への影響を恐れているためではないか」と推測しています。
 * 設計の妥協: 既存ラムダ内にある「共通処理」を再利用したいという意図があるのかもしれませんが、そのためにアーキテクチャ全体が不自然（ナンセンス）な形になっていることが問題視されました。
4. 解決策としての提案
 * EventBridgeでの交通整理: 既存のラムダに相乗りするのではなく、EventBridge側のルールで「スマート配送」用と「既存」用を適切にフィルタリングし、それぞれ専用のラムダへ直接配送する構成が推奨されています。
この詳細な懸念点を踏まえて、**設計変更を依頼するための技術的な論理構成（ドキュメントの下書き）**を作成しましょうか？


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
