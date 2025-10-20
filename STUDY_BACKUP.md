



SCCM 
assigned to
https://www.servicenow.com/docs/bundle/yokohama-platform-administration/page/integrate/cmdb/reference/how-sccm-integration-works.html#d263348e348

SGC-SCCM
https://www.servicenow.com/docs/bundle/yokohama-servicenow-platform/page/product/configuration-management/concept/cmdb-integration-sccm.html



```
(function(input, runId) {

    // 1. runIdからインポートセット実行(sys_import_set_run)レコードを取得
    var importSetRunGr = new GlideRecord('sys_import_set_run');
    if (!importSetRunGr.get(runId)) {
        return; // 実行レコードが見つからない場合は終了
    }

    // 2. インポートセット(sys_import_set)レコードを取得
    // (GlideRecordのgetRefRecord()はここでは使えない可能性があるため、import_setのsys_idを使います)
    var importSetSysId = importSetRunGr.getValue('import_set');
    var importSetGr = new GlideRecord('sys_import_set');
    if (!importSetGr.get(importSetSysId)) {
         return; // インポートセットが見つからない
    }

    // 3. データソース(sys_data_source)レコードを取得
    var dataSourceGr = importSetGr.data_source.getRefRecord();
    if (!dataSourceGr || !dataSourceGr.isValidRecord()) {
        return; // データソースが見つからない
    }

    // 4. データソース名で判定
    var dataSourceName = dataSourceGr.getValue('name');
    var systemCategory = ''; // デフォルト値

    if (dataSourceName.startsWith('ot_')) {
        systemCategory = 'ot';
    } else if (dataSourceName.startsWith('it_')) {
        systemCategory = 'it';
    }

    // 5. systemCategoryが設定された場合のみ、このバッチ内の全ペイロードに適用
    if (systemCategory) {
        
        // このバッチ内のすべてのペイロード(input[i])をループ
        for (var i = 0; i < input.length; i++) {
            
            // ペイロード内の 'items' 配列(input[i].payload.items)をループ
            for (var j = 0; j < input[i].payload.items.length; j++) {
                
                // 'cmdb_ci_computer' のペイロードにのみ値を追加
                if (input[i].payload.items[j].className == 'cmdb_ci_computer') {
                    
                    // 'values' オブジェクトに u_system_category を追加
                    // (コメントの指示通り、値は文字列として渡します)
                    input[i].payload.items[j].values.u_system_category = systemCategory;
                }
            }
        }
    }

})(input, runId);




(function(input, runId) {

    var systemCategory = ''; // 'ot' または 'it' を格納する変数

    // 1. runIdからインポートセット実行(sys_import_set_run)レコードを取得
    var importSetRunGr = new GlideRecord('sys_import_set_run');
    if (!importSetRunGr.get(runId)) {
        return; // 実行レコードが見つからない場合は終了
    }

    // 2. インポートセット(sys_import_set)レコードを取得
    var importSetSysId = importSetRunGr.getValue('import_set');
    var importSetGr = new GlideRecord('sys_import_set');
    if (!importSetGr.get(importSetSysId)) {
         return; // インポートセットが見つからない
    }

    // 3. インポートセットの作成者（＝実行ユーザ）のIDを取得
    var runAsUser = importSetGr.getValue('sys_created_by');

    // 4. 実行ユーザのIDで判定
    // ※ 'ot_user_id', 'it_user_id' の部分は、実際のユーザID(username)に置き換えてください
    if (runAsUser == 'ot_user_id') {
        systemCategory = 'ot';
    } else if (runAsUser == 'it_user_id') {
        systemCategory = 'it';
    }

    // 5. systemCategoryが設定された場合のみ、このバッチ内の全ペイロードに適用
    if (systemCategory) {
        
        // このバッチ内のすべてのペイロード(input[i])をループ
        for (var i = 0; i < input.length; i++) {
            
            // ペイロード内の 'items' 配列(input[i].payload.items)をループ
            for (var j = 0; j < input[i].payload.items.length; j++) {
                
                // 'cmdb_ci_computer' のペイロードにのみ値を追加
                if (input[i].payload.items[j].className == 'cmdb_ci_computer') {
                    
                    // 'values' オブジェクトに u_system_category を追加
                    // (値は文字列として渡します)
                    input[i].payload.items[j].values.u_system_category = systemCategory;
                }
            }
        }
    }

})(input, runId);
```

```
var is = new GlideRecord('sys_import_set');
      if (!is.get(String(runId))) return '';

  var dsId = is.getValue('data_source');
      var ds = new GlideRecord('sys_data_source');
      if (!ds.get(dsId)) return '';

      var name = (ds.getValue('name') || '').toLowerCase().trim(); // 例: 'ot_SG-SCCM Computer Identity'
      var pref = detectPrefix(name);


  function detectPrefix(name) {
    if (!name) return '';
    if (name.indexOf('it_') === 0) return 'it';
    if (name.indexOf('ot_') === 0) return 'ot';
    return '';
  }
```
