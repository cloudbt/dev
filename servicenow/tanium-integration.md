# ServiceNow - Tanium Integration

## 既存データの扱いに関する議論

### 削除案
コンピュータテーブルからTaniumデータを削除すると、過去のインシデントに紐づくCI情報が消える等の影響甚大であるため、推奨できない。

### 手動登録案
ログインIDを手動で流し込むことは可能だが、「全台数分の正しいログインIDリストを準備できるか」という運用・実現可能性に懸念がある。

## RTE (Runtime Transform Engine) カスタマイズリスク

先に挙げた「アップグレードへの影響」や「データの不整合」の他に、標準のRTEを独自にカスタマイズすることで、以下のようなリスクが考えられます。

理由は以下の通りです。

### アップグレードへの影響
アプリケーションのバージョンアップ時に、カスタマイズした設定が上書きされたり、競合が発生したりする可能性があります。

### 予期せぬ不整合
標準のRTEは、CIの識別・調整（IRE）ルールと密接に連携して設計されています。安易に変更すると、データの重複や不整合を引き起こすリスクがあります。

これらのリスクを避けるためにも、可能な限り標準のコネクタをそのまま利用し、カスタマイズが必要な場合でも、影響範囲を最小限に抑えるアプローチ（既存RTEのコピーや、独立した連携処理の作成など）を強くお勧めします。

## Tanium Hardware and Software データフロー

Taniumから連携されたハードウェアとソフトウェアのデータは、まず **x_taniu_tanium_s_sg_tanium_hardware_and_software** という単一のインポートセットテーブルに格納されます。

しかし、その後のインポートセットテーブルとRTEの関係は「1対多」と捉えるのがより正確です。

これは、1つのインポートセットテーブルに取り込まれたデータを、1つのRTE（実体はCMDB Integration Studio App Data Sourceレコード）が処理し、その内部で複数の変換マップ（ETL Entity Mapping）を通じて、CMDB上の様々なターゲットテーブル（CIクラス）にデータを振り分けるためです。

### データマッピング例

「SG-Tanium Hardware and Software」のデータは、以下のようにマッピングされます：

- コンピュータの基本情報 → `cmdb_ci_computer` (およびその子クラス)
- インストールされているソフトウェア情報 → `cmdb_sam_sw_install`
- ディスク情報 → `cmdb_ci_disk`
- ネットワークアダプタ情報 → `cmdb_ci_network_adapter`

このように、1つのインポート元（インポートセットテーブル）から、複数のCIクラスへデータが投入される構造になっています。

## Updates数が多い理由

updatesの数が多い理由を確認しました。

おそらく、updatesの単位は「フィールド」ではなく「レコード」だと思われます。

また、データインポート時にはターゲットテーブルだけでなく、ステージングテーブルにも更新が発生しているようです。
さらに、複数のテーブルや子テーブルが同時に更新されるケースが多いと考えられます。

たとえば、ステージングテーブルの1件のレコードが「CI（構成アイテム）情報」「ハードウェア一覧」「ソフトウェア一覧」の3つのテーブルにマッピングされている場合、1レコードにつき最低でも3件の更新が発生します。

実際には、ソフトウェアの数が多い場合など、1レコードに対して数十件から数百件の子レコードの更新が発生することもあります。

## 参考リンク

- [Service Graph Connector - SCCM Integration User Guide](https://www.servicenow.com/community/developer-forum/service-graph-connector-sccm-integration-user-guide/m-p/3103061)
- [CMDB Integration - Tanium](https://www.servicenow.com/docs/ja-JP/bundle/yokohama-servicenow-platform/page/product/configuration-management/concept/cmdb-integration-tanium.html#d320779e473)
- [Tanium Asset - Setting Up Asset](https://help.tanium.com/bundle/AssetGraphConxSetup/page/Integrations/SNOW/AssetGraphConxSetup/Tanium_Asset_Setting_Up_Asset.htm)
- [Import Transform Learning Path](https://www.servicenow.com/community/servicenow-ai-platform-articles/import-transform-learning-path/ta-p/2306952#ISST)
- [Developer Forum](https://www.servicenow.com/community/developer-forum/bd-p/developer-forum)

## 関連リソース

- Script Include → SGTaniumDataSourceUtil
- Application Navigator → Flow Designer → Actions
- [Map images custom-type-data-source](https://www.servicenow.com/docs/ja-JP/bundle/yokohama-integrate-applications/page/administer/import-sets/reference/custom-type-data-source.html)
- [Creating New Transform Maps](https://www.servicenow.com/docs/ja-JP/bundle/yokohama-integrate-applications/page/script/server-scripting/concept/c_CreatingNewTransformMaps.html)

## AWS Config Integration Note

```
ServiceNow user created in Designated Member Account, both managed and member accounts have different STS Role Names.
For the STS Role value in STS Assume Role Name (Include only name and not ARN), which account STS Role Name should be set?

指定メンバーアカウントで作成されたServiceNowユーザーは、管理アカウントとメンバーアカウントの両方で異なるSTS役割名を持っています。
STS Assume Role Name（ARNではなく名前のみを含む）のSTS Role値には、どのアカウントのSTS Role Nameを設定する必要がありますか？
```
