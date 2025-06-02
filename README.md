https://www.servicenow.com/community/developer-forum/bd-p/developer-forum

Script Include →SGTaniumDataSourceUtil
Application Navigator → Flow Designer → Actions

Tanium
https://help.tanium.com/bundle/AssetGraphConxSetup/page/Integrations/SNOW/AssetGraphConxSetup/Tanium_Asset_Setting_Up_Asset.htm

Map images custom-type-data-source
- https://www.servicenow.com/docs/ja-JP/bundle/yokohama-integrate-applications/page/script/server-scripting/concept/c_CreatingNewTransformMaps.html
- https://www.servicenow.com/docs/ja-JP/bundle/yokohama-integrate-applications/page/administer/import-sets/reference/custom-type-data-source.html


```

var scriptName = "SG Tanium - Before Script"; // ログ用のスクリプト名


var filterPeriodSeconds = 3600; // 例: 3600秒 (1時間)。この値を変更することで期間を調整できます。

var currentGDT = new GlideDateTime(); // 現在のUTC日時を取得
var currentMillis = currentGDT.getNumericValue(); // 現在時刻のミリ秒値 (UTC)
var thresholdMillis2 = currentMillis - (filterPeriodSeconds * 1000); // 指定秒数前の時刻のミリ秒値
currentGDT.addSeconds(-filterPeriodSeconds);
var thresholdMillis = currentGDT.getNumericValue();

var lastSeenAtStr = "2025-06-02 05:00:15";
gs.info(scriptName + ": last_seen_at_string '" + lastSeenAtStr);

var lastSeenAtGDT = new GlideDateTime();
// === 修正箇所: setValueUTC を使用して日時とフォーマットを明示的に指定 ===
// last_seen_at のフォーマット 'YYYY-MM-DD HH:mm:ss' がUTCであると仮定
var format = "yyyy-MM-dd HH:mm:ss"; // GlideDateTimeで使用するフォーマット文字列
lastSeenAtGDT.setValueUTC(lastSeenAtStr, format);

var lastSeenAtMillis = lastSeenAtGDT.getNumericValue(); // last_seen_at のミリ秒値 (UTC)
gs.info(scriptName + ": lastSeenAtMillis '" + lastSeenAtMillis+ ": thresholdMillis '" + thresholdMillis+ ": thresholdMillis2 '" + thresholdMillis2 );
gs.info(scriptName + ": lastSeenAt '" + lastSeenAtGDT.getValue()+ ": current-days '" + currentGDT.getValue() );


if (lastSeenAtMillis < thresholdMillis) {
	gs.info(scriptName + ": lastSeenAtMillis< '" + lastSeenAtMillis+ ": thresholdMillis '" + thresholdMillis );
}

```
