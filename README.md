```
/*****************************************************************
 * SG-SCCM ResourceID Collision Check
 *
 * 目的:
 *   ot_prodE(broadcast) 側 ResourceID を基準に、
 *   it_prod(general) 側に同一 ResourceID が存在するか確認
 *
 *   さらに cmdb_ci_computer 上で
 *   general / broadcast CI の存在確認を行う
 *
 * 条件:
 *   - sys_object_source 使用しない
 *   - connectionid 使用しない
 *   - ResourceID ベース
 *   - CI判定は u_system_category 使用
 *
 * u_system_category:
 *   0 = general
 *   1 = broadcast
 *
 * 出力:
 *   CSV形式
 *
 *****************************************************************/


/***************************************************************
 * 設定
 ***************************************************************/

// general 側 ISET
var GENERAL_ISETS = [
    'ISET0011111',
    'ISET0011112'
];

// broadcast 側 ISET
var BROADCAST_ISETS = [
    'ISET0022221'
];


/***************************************************************
 * Utility
 ***************************************************************/

function normalize(v) {
    if (!v) return '';
    return (v + '').trim().toLowerCase();
}

function esc(v) {
    if (v === null || v === undefined) return '';
    v = (v + '').replace(/"/g, '""');
    return '"' + v + '"';
}


/***************************************************************
 * ImportSet sys_id 取得
 ***************************************************************/

function getImportSetSysIds(numbers) {

    var result = [];

    var gr = new GlideRecord('sys_import_set');
    gr.addQuery('number', 'IN', numbers.join(','));
    gr.query();

    while (gr.next()) {
        result.push(gr.getUniqueValue());
    }

    return result;
}


/***************************************************************
 * Broadcast ResourceID MAP 作成
 ***************************************************************/

var broadcastMap = {};

var broadcastImportSetIds = getImportSetSysIds(BROADCAST_ISETS);

var br = new GlideRecord('sn_sccm_integrate_sccm_2019_computer_id');

br.addQuery('sys_import_set', 'IN', broadcastImportSetIds.join(','));
br.query();

while (br.next()) {

    var resourceId = normalize(br.getValue('resourceid'));

    if (!resourceId) {
        continue;
    }

    broadcastMap[resourceId] = {
        resource_id: resourceId,
        name: br.getValue('name') || '',
        serial: br.getValue('biosserialnumber') || '',
        row_sys_id: br.getUniqueValue()
    };
}

gs.print('Broadcast MAP count = ' + Object.keys(broadcastMap).length);


/***************************************************************
 * CSV HEADER
 ***************************************************************/

var header = [
    'resource_id',

    'general_name',
    'general_serial',

    'broadcast_name',
    'broadcast_serial',

    'general_ci_exists',
    'general_ci_sys_id',
    'general_ci_name',

    'broadcast_ci_exists',
    'broadcast_ci_sys_id',
    'broadcast_ci_name',

    'pattern'
];

gs.print(header.join(','));


/***************************************************************
 * general 側チェック
 ***************************************************************/

var generalImportSetIds = getImportSetSysIds(GENERAL_ISETS);

var checked = {};

var gen = new GlideRecord('sn_sccm_integrate_sccm_2019_computer_id');

gen.addQuery('sys_import_set', 'IN', generalImportSetIds.join(','));
gen.query();

while (gen.next()) {

    var resourceId = normalize(gen.getValue('resourceid'));

    if (!resourceId) {
        continue;
    }

    // broadcast側に存在しないなら skip
    if (!broadcastMap[resourceId]) {
        continue;
    }

    // 重複防止
    if (checked[resourceId]) {
        continue;
    }

    checked[resourceId] = true;

    var generalName = gen.getValue('name') || '';
    var generalSerial = gen.getValue('biosserialnumber') || '';

    var broadcastName = broadcastMap[resourceId].name || '';
    var broadcastSerial = broadcastMap[resourceId].serial || '';


    /***********************************************************
     * general CI 検索
     ***********************************************************/

    var generalCiExists = false;
    var generalCiSysId = '';
    var generalCiName = '';

    var ciGen = new GlideRecord('cmdb_ci_computer');

    ciGen.addQuery('u_system_category', '0');
    ciGen.addQuery('name', generalName);
    ciGen.addQuery('serial_number', generalSerial);

    ciGen.setLimit(1);
    ciGen.query();

    if (ciGen.next()) {
        generalCiExists = true;
        generalCiSysId = ciGen.getUniqueValue();
        generalCiName = ciGen.getValue('name');
    }


    /***********************************************************
     * broadcast CI 検索
     ***********************************************************/

    var broadcastCiExists = false;
    var broadcastCiSysId = '';
    var broadcastCiName = '';

    var ciBr = new GlideRecord('cmdb_ci_computer');

    ciBr.addQuery('u_system_category', '1');
    ciBr.addQuery('name', broadcastName);
    ciBr.addQuery('serial_number', broadcastSerial);

    ciBr.setLimit(1);
    ciBr.query();

    if (ciBr.next()) {
        broadcastCiExists = true;
        broadcastCiSysId = ciBr.getUniqueValue();
        broadcastCiName = ciBr.getValue('name');
    }


    /***********************************************************
     * Pattern 判定
     ***********************************************************/

    var pattern = '';

    if (!generalCiExists && broadcastCiExists) {
        pattern = 'PATTERN_1';
    }
    else if (generalCiExists && !broadcastCiExists) {
        pattern = 'PATTERN_2';
    }
    else if (generalCiExists && broadcastCiExists) {
        pattern = 'PATTERN_3_OR_4';
    }
    else {
        pattern = 'NO_CI_FOUND';
    }


    /***********************************************************
     * CSV 出力
     ***********************************************************/

    var row = [

        esc(resourceId),

        esc(generalName),
        esc(generalSerial),

        esc(broadcastName),
        esc(broadcastSerial),

        esc(generalCiExists),
        esc(generalCiSysId),
        esc(generalCiName),

        esc(broadcastCiExists),
        esc(broadcastCiSysId),
        esc(broadcastCiName),

        esc(pattern)
    ];

    gs.print(row.join(','));
}


/***************************************************************
 * END
 ***************************************************************/

gs.print('=== DONE ===');
```
