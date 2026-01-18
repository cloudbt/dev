# ServiceNow Import Set Scripts

## Import Set レコード削除スクリプト

```javascript
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

## Conditional Scheduled Imports

このスクリプトは、インポートが実行される直前に評価され、trueを返した場合にのみインポートが実行されます。falseを返した場合は、その回のインポートはスキップされます。

[参考リンク](https://www.servicenow.com/community/developer-forum/conditional-scheduled-imports/td-p/1527884?utm_source=chatgpt.com)

### 例1: 月の特定日にのみ実行

```javascript
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

### 例2: 時間帯によってスキップ

全量ジョブが毎日 0:00〜4:00 の間に動くなら、その時間帯だけ絞り込みジョブをスキップ

```javascript
var answer = true;
var now = new GlideDateTime();
var hour = now.getHourLocalTime();

// 例：全量ジョブが毎日 0:00〜4:00 の間に動くなら、その時間帯だけ絞り込みジョブをスキップ
if (hour >= 0 && hour < 4) {
  answer = false;
}

answer;
```

## Import Statistics References

- [Row count on inserted/created/updated/total](https://www.servicenow.com/community/itsm-forum/i-want-to-get-the-row-count-on-inserted-created-updated-total/m-p/533191#M104970)
- [insertMultiple Import Set API](https://www.servicenow.com/community/architect-forum/insertmultiple-import-set-api/m-p/2442022)
