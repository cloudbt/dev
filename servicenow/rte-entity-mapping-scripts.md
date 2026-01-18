# ServiceNow RTE Entity Mapping Scripts

## Pre-Import Script: Entity Mapping を無視する

このスクリプトは SG-Tanium Hardware and Software の scheduled import 実行前に、特定の Entity Mapping を無視するように設定することで、不要なデータの取り込みを防ぐ目的で使用されます。

```javascript
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

## Entity Mapping の Ignore 値を取得

```javascript
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

## Background Script: sys_id で直接指定して更新

```javascript
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
