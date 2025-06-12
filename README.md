通信フロー
EC2 → VPCエンドポイント → AWSサービス（内部）

EC2がリクエストを送信
VPCエンドポイントが受信して処理
AWS内部ネットワークで応答

正しいセキュリティグループ設定
VPCエンドポイント用セキュリティグループ
インバウンド:
- Protocol: TCP
- Port: 443
- Source: Private Subnet CIDR (10.0.1.0/24)

アウトバウンド:
- デフォルトルール（All Traffic → 0.0.0.0/0）を削除
- または何も設定しない
EC2用セキュリティグループ
アウトバウンド:
- Protocol: TCP
- Port: 443
- Destination: VPCエンドポイント用セキュリティグループID

最小権限の原則を適用する場合
より厳密にセキュリティを管理したい場合：
VPCエンドポイント用セキュリティグループ
インバウンド:
- Protocol: TCP, Port: 443, Source: EC2セキュリティグループID

アウトバウンド:
- Protocol: TCP, Port: 443, Destination: 0.0.0.0/0
- Protocol: TCP, Port: 80, Destination: 0.0.0.0/0
- Protocol: UDP, Port: 53, Destination: 0.0.0.0/0 (DNS)
EC2インスタンス用セキュリティグループ
アウトバウンド:
- Protocol: TCP, Port: 443, Destination: VPCエンドポイントセキュリティグループID
この設定により、EC2インスタンスとVPCエンドポイント間の通信が適切に制御され、セキュアな環境でSSMサービスを利用できます。再試行CグラフでEC2とSSMとそれぞれのSGの関係を説明して編集EC2とSSM VPCエンドポイント、そしてそれぞれのセキュリティグループの関係を視覚的に説明するグラフを作成します。EC2とSSM VPCエンドポイントのセキュリティグループ関係図インタラクティブアーティファクト このグラフは、EC2インスタンスとSSM VPCエンドポイントの関係、そしてそれぞれのセキュリティグループの設定を視覚的に表現しています。
主要ポイント
セキュリティグループの設定

EC2-SG（EC2用セキュリティグループ）

アウトバウンド: HTTPS(443) → Endpoint-SG
EC2からVPCエンドポイントへの通信を許可


Endpoint-SG（VPCエンドポイント用セキュリティグループ）

インバウンド: HTTPS(443) ← Private Subnet CIDR (10.0.1.0/24)
アウトバウンド: All Traffic → 0.0.0.0/0



通信の流れ

EC2インスタンスがSSMサービスを利用したい時
EC2-SGのアウトバウンドルールにより、HTTPS(443)でVPCエンドポイントに接続
Endpoint-SGのインバウンドルールにより、Private Subnetからの通信を受信
VPCエンドポイントがAWSのSSMサービスと内部通信（Endpoint-SGのアウトバウンドルールで許可）

3つの必須エンドポイント

SSM Endpoint: Systems Manager本体との通信
SSM Messages Endpoint: Session Manager機能用
EC2 Messages Endpoint: Systems Manager Agent用

この構成により、Private subnetのEC2インスタンスがインターネットゲートウェイやNATゲートウェイを経由せずに、安全にSSMサービスを利用できます。再試行Claudeは間違えることがあります。回答内容を必ずご確認ください。 Sonnet 4

![image](https://github.com/user-attachments/assets/31932cb8-40a7-4c50-86fd-e2a2ecc70512)


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
