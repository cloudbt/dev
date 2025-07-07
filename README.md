
```
負荷分散の調整

ログオングループの設定見直し
ユーザーの接続先振り分けの最適化


RISE PCE サーバ: メモリ使用率が危険水準（ピンク色の高い使用率）
ST06: Free Memory使用率の問題
ABAPアドオンは確実にメモリを大量消費する可能性があります：
メモリリークの原因

不適切なInternal Tableの使用
大量データの一括処理
オブジェクトの適切な解放不備


特に問題となるパターン

無限ループやRecursive呼び出し
SELECT文での大量データ取得
不要なWORK AREAの保持


ABAPコードレビュー

カスタムプログラムのメモリ使用量チェック
Internal Tableのサイズ制限実装
適切なFREE文の追加


監視強化

メモリ使用量の定期監視
アドオンプログラムの実行ログ取得
```


```
先に挙げた「アップグレードへの影響」や「データの不整合」の他に、標準のRTEを独自にカスタマイズすることで、以下のようなリスクが考えられます。
理由は以下の通りです。

アップグレードへの影響: アプリケーションのバージョンアップ時に、カスタマイズした設定が上書きされたり、競合が発生したりする可能性があります。

予期せぬ不整合: 標準のRTEは、CIの識別・調整（IRE）ルールと密接に連携して設計されています。安易に変更すると、データの重複や不整合を引き起こすリスクがあります。
これらのリスクを避けるためにも、可能な限り標準のコネクタをそのまま利用し、カスタマイズが必要な場合でも、影響範囲を最小限に抑えるアプローチ（既存RTEのコピーや、独立した連携処理の作成など）を強くお勧めします。
Taniumから連携されたハードウェアとソフトウェアのデータは、まず**x_taniu_tanium_s_sg_tanium_hardware_and_software** という単一のインポートセットテーブルに格納されます。

しかし、その後のインポートセットテーブルとRTEの関係は「1対多」と捉えるのがより正確です。

これは、1つのインポートセットテーブルに取り込まれたデータを、1つのRTE（実体はCMDB Integration Studio App Data Sourceレコード）が処理し、その内部で複数の変換マップ（ETL Entity Mapping）を通じて、CMDB上の様々なターゲットテーブル（CIクラス）にデータを振り分けるためです。

例えば、「SG-Tanium Hardware and Software」のデータは、以下のようにマッピングされます。

コンピュータの基本情報 → cmdb_ci_computer (およびその子クラス)

インストールされているソフトウェア情報 → cmdb_sam_sw_install

ディスク情報 → cmdb_ci_disk

ネットワークアダプタ情報 → cmdb_ci_network_adapter

このように、1つのインポート元（インポートセットテーブル）から、複数のCIクラスへデータが投入される構造になっています。

```

```
//このスクリプトは SG-Tanium Hardware and Software の scheduled import 実行前に、特定の Entity Mapping を無視するように設定することで、不要なデータの取り込みを防ぐ目的で使用されていると思われます。
// 検索条件を設定
var entityMappingName = 'impTotemp.ci_installed_application[*]';
var definitionName = 'SG Tanium Hardware and Software';

var grEntityMapping = new GlideRecord('sys_rte_eb_entity_mapping');
grEntityMapping.addQuery('name', entityMappingName);
grEntityMapping.addQuery('sys_rte_eb_definition.name', definitionName);
grEntityMapping.query();

if (grEntityMapping.next()) {
    grEntityMapping.setValue('ignore', true);
    grEntityMapping.update();
    gs.info('Pre-import Script: Successfully set Ignore to true for Entity Mapping: ' + 
            entityMappingName + ' (sys_id: ' + grEntityMapping.getUniqueValue() + ')');
} else {
    gs.warn('Pre-import Script: Could not find Entity Mapping with name: ' + entityMappingName);
}
```

■Ｇｅｔ
```
// 検索条件を設定
var entityMappingName = 'impTotemp.ci_installed_application[*]';
var definitionName = 'SG Tanium Hardware and Software';

var grEntityMapping = new GlideRecord('sys_rte_eb_entity_mapping');
grEntityMapping.addQuery('name', entityMappingName);
grEntityMapping.addQuery('sys_rte_eb_definition.name', definitionName);
grEntityMapping.query();

if (grEntityMapping.next()) {
    // ignoreフィールドの値を取得
    var ignoreValue = grEntityMapping.getValue('ignore');
    // 結果をログに出力
    gs.info('Entity Mapping "' + entityMappingName + '" ignore value: ' + ignoreValue + 
            ' (sys_id: ' + grEntityMapping.getUniqueValue() + ')');
    // Boolean値として取得したい場合
    var ignoreBoolean = grEntityMapping.ignore == true;
    gs.info('Entity Mapping "' + entityMappingName + '" ignore boolean: ' + ignoreBoolean);
    
} else {
    gs.warn('Could not find Entity Mapping with specified criteria:');
    gs.warn('  Name: ' + entityMappingName);
    gs.warn('  Definition: ' + definitionName);
}
```

```
// Background Scriptで実行するためのコード

// 更新したいRTE Entity Mappingのsys_idを直接指定
var entityMappingSysId = '19278d7e53d030106747ddeeff7b128e';

// sys_rte_eb_entity_mappingテーブルをsys_idで直接検索
var grEntityMapping = new GlideRecord('sys_rte_eb_entity_mapping');

// .get()メソッドで指定したsys_idのレコードを取得
if (grEntityMapping.get(entityMappingSysId)) {
    // 対象のEntity Mappingの 'Ignore' を true に設定
    grEntityMapping.setValue('ignore', true);
    grEntityMapping.update();
    
    // 実行結果をシステムログに出力
    gs.info('Background Script: Successfully set Ignore to true for Entity Mapping: ' + grEntityMapping.getValue('name') + ' (sys_id: ' + entityMappingSysId + ')');

} else {
    // レコードが見つからない場合もログに出力
    gs.warn('Background Script: Could not find the Entity Mapping with sys_id: ' + entityMappingSysId);
}
```

```
Select-CFGResourceConfig -Expression "SELECT resourceId, resourceType WHERE resourceType = 'AWS::EC2::VPC'"

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

$result = Get-CFGGetResourceConfigBatch -ResourceKey $resourceKeys
Write-Output "取得したリソース設定："
$result.BaseConfigurationItems | ForEach-Object {
    Write-Output "リソースタイプ: $($_.ResourceType)"
    Write-Output "リソースID: $($_.ResourceId)"
    Write-Output "設定取得時刻: $($_.ConfigurationItemCaptureTime)"
    Write-Output "設定状態: $($_.ConfigurationItemStatus)"
    Write-Output "---"
}

   var recordIdToDelete = "1"; 

    // import_set_table から指定されたIDのレコードを検索
    var grDelete = new GlideRecord(import_set_table.getTableName());
    if (grDelete.get('id', recordIdToDelete)) { // 'id' フィールドで検索
        // レコードが見つかった場合、削除を実行
        gs.info("Deleting record with ID: " + recordIdToDelete + " from table: " + import_set_table.getTableName());
        grDelete.deleteRecord();
    } else {
        gs.info("Record with ID: " + recordIdToDelete + " not found in table: " + import_set_table.getTableName());
    }
```
■import-transform-learning-path
https://www.servicenow.com/community/servicenow-ai-platform-articles/import-transform-learning-path/ta-p/2306952#ISST

https://www.servicenow.com/community/developer-forum/bd-p/developer-forum

Script Include →SGTaniumDataSourceUtil
Application Navigator → Flow Designer → Actions

Tanium
https://help.tanium.com/bundle/AssetGraphConxSetup/page/Integrations/SNOW/AssetGraphConxSetup/Tanium_Asset_Setting_Up_Asset.htm

Map images custom-type-data-source
- https://www.servicenow.com/docs/ja-JP/bundle/yokohama-integrate-applications/page/script/server-scripting/concept/c_CreatingNewTransformMaps.html
- https://www.servicenow.com/docs/ja-JP/bundle/yokohama-integrate-applications/page/administer/import-sets/reference/custom-type-data-source.html


updates
 - https://www.servicenow.com/community/itsm-forum/i-want-to-get-the-row-count-on-inserted-created-updated-total/m-p/533191#M104970#:~:text=griii4.getValue%28,field%20names
 - https://www.servicenow.com/community/architect-forum/insertmultiple-import-set-api/m-p/2442022#:~:text=The%20import%20now%20completes%20,values%20appear%20in%20either%20staging


```
updatesの数が多い理由を確認しました。
おそらく、updatesの単位は「フィールド」ではなく「レコード」だと思われます。

また、データインポート時にはターゲットテーブルだけでなく、ステージングテーブルにも更新が発生しているようです。
さらに、複数のテーブルや子テーブルが同時に更新されるケースが多いと考えられます。

たとえば、ステージングテーブルの1件のレコードが「CI（構成アイテム）情報」「ハードウェア一覧」「ソフトウェア一覧」の3つのテーブルにマッピングされている場合、1レコードにつき最低でも3件の更新が発生します。

実際には、ソフトウェアの数が多い場合など、1レコードに対して数十件から数百件の子レコードの更新が発生することもあります。
```

このスクリプトは、インポートが実行される直前に評価され、trueを返した場合にのみインポートが実行されます。falseを返した場合は、その回のインポートはスキップされます。
https://www.servicenow.com/community/developer-forum/conditional-scheduled-imports/td-p/1527884?utm_source=chatgpt.com
```
//Return 'true' to run the job
var answer = false;

//Get the day of month. 
var now = new GlideDateTime();

//Run only on 2nd of month
if(now.getDayOfMonthLocalTime() == 2){
     answer = true;
}

answer;
```

```
var answer = true;
var now = new GlideDateTime();
var hour = now.getHourLocalTime();

// 例：全量ジョブが毎日 0:00〜4:00 の間に動くなら、その時間帯だけ絞り込みジョブをスキップ
if (hour >= 0 && hour < 4) {
  answer = false;
}

answer;

```

```
ServiceNow user created in Designated Member Account, both managed and member accounts have different STS Role Names.
For the STS Role value in STS Assume Role Name (Include only name and not ARN), which account STS Role Name should be set?

指定メンバーアカウントで作成されたServiceNowユーザーは、管理アカウントとメンバーアカウントの両方で異なるSTS役割名を持っています。
STS Assume Role Name（ARNではなく名前のみを含む）のSTS Role値には、どのアカウントのSTS Role Nameを設定する必要がありますか？
```
