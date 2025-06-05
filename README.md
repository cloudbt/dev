
```
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
