```
(function () {

    // =====================================================================
    // 【設定】実行前に変更してください
    // =====================================================================
    var OT_IMPORT_SET_NUMBERS = [
        'ISET0000001'            // ← ot_prodE のISET番号
    ];
    var IT_IMPORT_SET_NUMBERS = [
        'ISET0000002',           // ← it_prod のISET番号（複数可）
        'ISET0000003'
    ];

    var OT_CATEGORY = '1'; // 放送系 u_system_category
    var IT_CATEGORY = '0'; // 一般系 u_system_category

    // =====================================================================
    // ログユーティリティ
    // =====================================================================
    function info(msg) { gs.print('[INFO]    ' + msg); }
    function warn(msg) { gs.print('[WARN]    ' + msg); }
    function div()     { gs.print('[INFO]    ----------------------------------------'); }

    function esc(v) {
        if (v === null || v === undefined) return '';
        return ('' + v).replace(/,/g, '／').replace(/\r?\n/g, ' ').trim();
    }

    function printCsv(fields) {
        gs.print('CSV|' + fields.map(function (f) {
            return esc(f === null || f === undefined ? '' : f);
        }).join(','));
    }

    // =====================================================================
    // フィールド名自動検出
    // =====================================================================
    function pickField(table, candidates) {
        var gr = new GlideRecord(table);
        for (var i = 0; i < candidates.length; i++) {
            if (gr.isValidField(candidates[i])) return candidates[i];
        }
        return '';
    }

    var IMPORT_TABLE = 'sn_sccm_integrate_sccm_2019_computer_id';
    var F_RES     = pickField(IMPORT_TABLE, ['u_resourceid',          'u_resource_id',           'resourceid',          'resource_id']);
    var F_NAME    = pickField(IMPORT_TABLE, ['u_name',                'name']);
    var F_BIOS    = pickField(IMPORT_TABLE, ['u_biosserialnumber',    'u_bios_serial_number',    'biosserialnumber']);
    var F_SYSSER  = pickField(IMPORT_TABLE, ['u_systemserialnumber',  'u_system_serial_number',  'systemserialnumber']);
    var F_CHASSIS = pickField(IMPORT_TABLE, ['u_chassisserialnumber', 'u_chassis_serial_number', 'chassisserialnumber']);

    div();
    info('フィールド検出結果');
    info('  resource      : ' + (F_RES     || '★未検出'));
    info('  name          : ' + (F_NAME    || '★未検出'));
    info('  bios_serial   : ' + (F_BIOS    || '未検出'));
    info('  system_serial : ' + (F_SYSSER  || '未検出'));
    info('  chassis_serial: ' + (F_CHASSIS || '未検出'));
    div();

    if (!F_RES || !F_NAME) {
        warn('必須フィールド(resource/name)が見つかりません。処理を中断します。');
        return;
    }

    // =====================================================================
    // ISET番号 → sys_id 変換
    // =====================================================================
    function getIsetSysIds(numbers, label) {
        var ids = [];
        for (var i = 0; i < numbers.length; i++) {
            var gr = new GlideRecord('sys_import_set');
            gr.addQuery('number', numbers[i]);
            gr.query();
            if (gr.next()) {
                ids.push(gr.getUniqueValue());
                info('  [' + label + '] ISET取得OK : ' + numbers[i] + ' → sys_id=' + gr.getUniqueValue());
            } else {
                warn('  [' + label + '] ISET未検出 : ' + numbers[i]);
            }
        }
        return ids;
    }

    // =====================================================================
    // Import Rows 読み込み → { ResourceID: row } Map
    // =====================================================================
    function loadImportRows(label, setNumbers) {
        info('[' + label + '] Import Rows 読み込み開始');
        var sysIds = getIsetSysIds(setNumbers, label);
        if (sysIds.length === 0) {
            warn('[' + label + '] 有効なISETが0件のため空Mapを返します。');
            return {};
        }

        var map       = {};
        var totalRows = 0;
        var dupCount  = 0;

        var gr = new GlideRecord(IMPORT_TABLE);
        gr.addQuery('sys_import_set', 'IN', sysIds.join(','));
        gr.orderByDesc('sys_created_on'); // 同一ResourceIDは最新行を採用
        gr.query();

        while (gr.next()) {
            var rid = (gr.getValue(F_RES) || '').trim();
            if (!rid) continue;
            totalRows++;

            if (map[rid]) { dupCount++; continue; }

            var bios    = F_BIOS    ? (gr.getValue(F_BIOS)    || '') : '';
            var sysser  = F_SYSSER  ? (gr.getValue(F_SYSSER)  || '') : '';
            var chassis = F_CHASSIS ? (gr.getValue(F_CHASSIS) || '') : '';

            map[rid] = {
                resource_id: rid,
                name:        (gr.getValue(F_NAME) || '').trim(),
                serial:      (bios || sysser || chassis).trim(),
                import_set:  gr.getDisplayValue('sys_import_set') || ''
            };
        }

        info('[' + label + '] 読込完了: 総行数=' + totalRows +
             ' / ユニークResourceID=' + Object.keys(map).length +
             ' / 重複スキップ=' + dupCount);
        return map;
    }

    // =====================================================================
    // cmdb_ci_computer 検索（name優先 → serial フォールバック）
    // =====================================================================
    var NO_CI = { found: false, sys_id: '', name: '', serial: '', category: '', found_by: 'NOT_FOUND' };

    function findCi(mcmName, mcmSerial) {

        // ① name で検索（完全一致）
        if (mcmName) {
            var gr = new GlideRecord('cmdb_ci_computer');
            gr.addQuery('name', mcmName);
            gr.query();
            if (gr.next()) {
                var r = {
                    found:    true,
                    sys_id:   gr.getUniqueValue(),
                    name:     gr.getValue('name')              || '',
                    serial:   gr.getValue('serial_number')     || '',
                    category: gr.getValue('u_system_category') || '',
                    found_by: 'name'
                };
                if (gr.next()) r.found_by = 'name_AMBIGUOUS';
                return r;
            }
        }

        // ② serial でフォールバック
        if (mcmSerial) {
            var gr2 = new GlideRecord('cmdb_ci_computer');
            gr2.addQuery('serial_number', mcmSerial);
            gr2.query();
            if (gr2.next()) {
                var r2 = {
                    found:    true,
                    sys_id:   gr2.getUniqueValue(),
                    name:     gr2.getValue('name')              || '',
                    serial:   gr2.getValue('serial_number')     || '',
                    category: gr2.getValue('u_system_category') || '',
                    found_by: 'serial'
                };
                if (gr2.next()) r2.found_by = 'serial_AMBIGUOUS';
                return r2;
            }
        }

        return NO_CI;
    }

    // =====================================================================
    // パターン判定
    // =====================================================================
    function determinePattern(otCi, itCi) {
        if (!otCi.found && !itCi.found)  return 'BOTH_NOT_FOUND';
        if (!otCi.found)                 return 'OT_CI_NOT_FOUND';
        if (!itCi.found)                 return 'IT_CI_NOT_FOUND';
        if (otCi.sys_id === itCi.sys_id) return 'COLLISION_SAME_CI';

        var otOk = (otCi.category === OT_CATEGORY);
        var itOk = (itCi.category === IT_CATEGORY);
        if ( otOk &&  itOk) return 'BOTH_CORRECT';
        if (!otOk &&  itOk) return 'BROADCAST_WRONG_CATEGORY';
        if ( otOk && !itOk) return 'GENERAL_WRONG_CATEGORY';
        return 'BOTH_WRONG_CATEGORY';
    }

    // =====================================================================
    // CSV DATA 行出力
    // =====================================================================
    function outputDataRow(rid, ot, it, otCi, itCi, pattern) {
        var sameCi = (otCi.found && itCi.found && otCi.sys_id === itCi.sys_id);
        printCsv([
            'DATA',         rid,
            ot.name,        ot.serial,
            it.name,        it.serial,
            otCi.found,  otCi.sys_id,  otCi.name,  otCi.serial,  otCi.category,  otCi.found_by,
            itCi.found,  itCi.sys_id,  itCi.name,  itCi.serial,  itCi.category,  itCi.found_by,
            sameCi,      pattern
        ]);
    }

    // =====================================================================
    // メイン処理開始
    // =====================================================================
    info('処理開始');
    div();

    var otRows = loadImportRows('broadcast(ot_prodE)', OT_IMPORT_SET_NUMBERS);
    var itRows = loadImportRows('general(it_prod)',    IT_IMPORT_SET_NUMBERS);
    div();
    info('放送系 ResourceID数 : ' + Object.keys(otRows).length);
    info('一般系 ResourceID数 : ' + Object.keys(itRows).length);
    div();

    // CSV ヘッダー行
    printCsv([
        'TYPE',         'resource_id',
        'ot_mcm_name',  'ot_mcm_serial',
        'it_mcm_name',  'it_mcm_serial',
        'ot_ci_exists', 'ot_ci_sys_id', 'ot_ci_name', 'ot_ci_serial', 'ot_ci_category', 'ot_ci_found_by',
        'it_ci_exists', 'it_ci_sys_id', 'it_ci_name', 'it_ci_serial', 'it_ci_category', 'it_ci_found_by',
        'same_ci',      'pattern'
    ]);

    // カウンター
    var c = {
        matched:        0,
        both_correct:   0, collision:     0,
        ot_wrong_cat:   0, it_wrong_cat:  0, both_wrong_cat: 0,
        ot_not_found:   0, it_not_found:  0, both_not_found: 0
    };

    function countPattern(pat) {
        switch (pat) {
            case 'BOTH_CORRECT':             c.both_correct++;   break;
            case 'COLLISION_SAME_CI':        c.collision++;      break;
            case 'BROADCAST_WRONG_CATEGORY': c.ot_wrong_cat++;   break;
            case 'GENERAL_WRONG_CATEGORY':   c.it_wrong_cat++;   break;
            case 'BOTH_WRONG_CATEGORY':      c.both_wrong_cat++; break;
            case 'OT_CI_NOT_FOUND':          c.ot_not_found++;   break;
            case 'IT_CI_NOT_FOUND':          c.it_not_found++;   break;
            case 'BOTH_NOT_FOUND':           c.both_not_found++; break;
        }
    }

    // =====================================================================
    // 処理: 両系共通 ResourceID（衝突確認）
    // =====================================================================
    info('--- 両系共通 ResourceID（衝突確認）---');

    for (var rid in otRows) {
        if (!itRows[rid]) continue;
        c.matched++;

        var ot    = otRows[rid];
        var it    = itRows[rid];
        var otCi  = findCi(ot.name, ot.serial);
        var itCi  = findCi(it.name, it.serial);
        var pat   = determinePattern(otCi, itCi);
        var same  = (otCi.found && itCi.found && otCi.sys_id === itCi.sys_id);

        countPattern(pat);

        info('  [MATCHED] ResourceID=' + rid + ' | pattern=' + pat +
             (same ? ' ★SAME_CI（衝突）★' : '') +
             '\n             ot_mcm : name=' + ot.name + ' / serial=' + ot.serial +
             '\n             it_mcm : name=' + it.name + ' / serial=' + it.serial +
             '\n             ot_ci  : ' + (otCi.found
                 ? 'sys_id=' + otCi.sys_id + ' / name=' + otCi.name + ' / category=' + otCi.category + ' / found_by=' + otCi.found_by
                 : 'NOT_FOUND') +
             '\n             it_ci  : ' + (itCi.found
                 ? 'sys_id=' + itCi.sys_id + ' / name=' + itCi.name + ' / category=' + itCi.category + ' / found_by=' + itCi.found_by
                 : 'NOT_FOUND'));

        outputDataRow(rid, ot, it, otCi, itCi, pat);
    }

    div();

    // =====================================================================
    // INFO サマリー
    // =====================================================================
    info('処理完了 - サマリー');
    div();
    info('放送系 ResourceID総数         : ' + Object.keys(otRows).length);
    info('一般系 ResourceID総数         : ' + Object.keys(itRows).length);
    info('両系共通 ResourceID 計        : ' + c.matched);
    info('  ├ BOTH_CORRECT              : ' + c.both_correct);
    info('  ├ COLLISION_SAME_CI         : ' + c.collision);
    info('  ├ BROADCAST_WRONG_CATEGORY  : ' + c.ot_wrong_cat);
    info('  ├ GENERAL_WRONG_CATEGORY    : ' + c.it_wrong_cat);
    info('  ├ BOTH_WRONG_CATEGORY       : ' + c.both_wrong_cat);
    info('  ├ OT_CI_NOT_FOUND           : ' + c.ot_not_found);
    info('  ├ IT_CI_NOT_FOUND           : ' + c.it_not_found);
    info('  └ BOTH_NOT_FOUND            : ' + c.both_not_found);
    div();

    // CSV サマリー行
    printCsv([
        'SUMMARY',
        'ot_total='   + Object.keys(otRows).length,
        'it_total='   + Object.keys(itRows).length,
        'matched='    + c.matched,
        'BOTH_CORRECT='             + c.both_correct,
        'COLLISION_SAME_CI='        + c.collision,
        'BROADCAST_WRONG_CATEGORY=' + c.ot_wrong_cat,
        'GENERAL_WRONG_CATEGORY='   + c.it_wrong_cat,
        'BOTH_WRONG_CATEGORY='      + c.both_wrong_cat,
        'OT_CI_NOT_FOUND='          + c.ot_not_found,
        'IT_CI_NOT_FOUND='          + c.it_not_found,
        'BOTH_NOT_FOUND='           + c.both_not_found
    ]);

})();
```


```
(function () {

    // =====================================================================
    // 【設定】実行前に変更してください
    // =====================================================================
    var OT_IMPORT_SET_NUMBERS = [
        'ISET0000001'            // ← ot_prodE のISET番号
    ];
    var IT_IMPORT_SET_NUMBERS = [
        'ISET0000002',           // ← it_prod のISET番号（複数可）
        'ISET0000003'
    ];

    // false: 両系共通ResourceIDのみCI確認（推奨・高速）
    // true : OT_ONLY / IT_ONLY もCI確認（一般系が多い場合タイムアウト注意）
    var LOOKUP_CI_FOR_ONLY = false;

    var OT_CATEGORY = '1'; // 放送系 u_system_category
    var IT_CATEGORY = '0'; // 一般系 u_system_category

    // =====================================================================
    // ログユーティリティ
    // =====================================================================
    function info(msg) { gs.print('[INFO]    ' + msg); }
    function warn(msg) { gs.print('[WARN]    ' + msg); }
    function div()     { gs.print('[INFO]    ----------------------------------------'); }

    // CSV フィールドエスケープ（カンマ・改行を置換）
    function esc(v) {
        if (v === null || v === undefined) return '';
        return ('' + v).replace(/,/g, '／').replace(/\r?\n/g, ' ').trim();
    }

    // CSV行を出力（各行先頭に CSV| を付与）
    function printCsv(fields) {
        gs.print('CSV|' + fields.map(function (f) {
            return esc(f === null || f === undefined ? '' : f);
        }).join(','));
    }

    // =====================================================================
    // フィールド名自動検出
    // =====================================================================
    function pickField(table, candidates) {
        var gr = new GlideRecord(table);
        for (var i = 0; i < candidates.length; i++) {
            if (gr.isValidField(candidates[i])) return candidates[i];
        }
        return '';
    }

    var IMPORT_TABLE = 'sn_sccm_integrate_sccm_2019_computer_id';
    var F_RES     = pickField(IMPORT_TABLE, ['u_resourceid',          'u_resource_id',           'resourceid',          'resource_id']);
    var F_NAME    = pickField(IMPORT_TABLE, ['u_name',                'name']);
    var F_BIOS    = pickField(IMPORT_TABLE, ['u_biosserialnumber',    'u_bios_serial_number',    'biosserialnumber']);
    var F_SYSSER  = pickField(IMPORT_TABLE, ['u_systemserialnumber',  'u_system_serial_number',  'systemserialnumber']);
    var F_CHASSIS = pickField(IMPORT_TABLE, ['u_chassisserialnumber', 'u_chassis_serial_number', 'chassisserialnumber']);

    div();
    info('フィールド検出結果');
    info('  resource      : ' + (F_RES     || '★未検出'));
    info('  name          : ' + (F_NAME    || '★未検出'));
    info('  bios_serial   : ' + (F_BIOS    || '未検出'));
    info('  system_serial : ' + (F_SYSSER  || '未検出'));
    info('  chassis_serial: ' + (F_CHASSIS || '未検出'));
    div();

    if (!F_RES || !F_NAME) {
        warn('必須フィールド(resource/name)が見つかりません。処理を中断します。');
        return;
    }

    // =====================================================================
    // ISET番号 → sys_id 変換
    // =====================================================================
    function getIsetSysIds(numbers, label) {
        var ids = [];
        for (var i = 0; i < numbers.length; i++) {
            var gr = new GlideRecord('sys_import_set');
            gr.addQuery('number', numbers[i]);
            gr.query();
            if (gr.next()) {
                ids.push(gr.getUniqueValue());
                info('  [' + label + '] ISET取得OK : ' + numbers[i] + ' → sys_id=' + gr.getUniqueValue());
            } else {
                warn('  [' + label + '] ISET未検出 : ' + numbers[i]);
            }
        }
        return ids;
    }

    // =====================================================================
    // Import Rows 読み込み → { ResourceID: row } Map
    // =====================================================================
    function loadImportRows(label, setNumbers) {
        info('[' + label + '] Import Rows 読み込み開始');
        var sysIds = getIsetSysIds(setNumbers, label);
        if (sysIds.length === 0) {
            warn('[' + label + '] 有効なISETが0件のため空Mapを返します。');
            return {};
        }

        var map       = {};
        var totalRows = 0;
        var dupCount  = 0;

        var gr = new GlideRecord(IMPORT_TABLE);
        gr.addQuery('sys_import_set', 'IN', sysIds.join(','));
        gr.orderByDesc('sys_created_on'); // 同一ResourceIDは最新行を採用
        gr.query();

        while (gr.next()) {
            var rid = (gr.getValue(F_RES) || '').trim();
            if (!rid) continue;
            totalRows++;

            if (map[rid]) { dupCount++; continue; } // 最新のみ保持

            var bios    = F_BIOS    ? (gr.getValue(F_BIOS)    || '') : '';
            var sysser  = F_SYSSER  ? (gr.getValue(F_SYSSER)  || '') : '';
            var chassis = F_CHASSIS ? (gr.getValue(F_CHASSIS) || '') : '';

            map[rid] = {
                resource_id: rid,
                name:        (gr.getValue(F_NAME) || '').trim(),
                serial:      (bios || sysser || chassis).trim(),
                import_set:  gr.getDisplayValue('sys_import_set') || ''
            };
        }

        info('[' + label + '] 読込完了: 総行数=' + totalRows +
             ' / ユニークResourceID=' + Object.keys(map).length +
             ' / 重複スキップ=' + dupCount);
        return map;
    }

    // =====================================================================
    // cmdb_ci_computer 検索（name優先 → serial フォールバック）
    // =====================================================================
    var NO_CI = { found: false, sys_id: '', name: '', serial: '', category: '', found_by: 'NOT_FOUND' };

    function findCi(mcmName, mcmSerial) {

        // ① name で検索（完全一致）
        if (mcmName) {
            var gr = new GlideRecord('cmdb_ci_computer');
            gr.addQuery('name', mcmName);
            gr.query();
            if (gr.next()) {
                var r = {
                    found:    true,
                    sys_id:   gr.getUniqueValue(),
                    name:     gr.getValue('name')              || '',
                    serial:   gr.getValue('serial_number')     || '',
                    category: gr.getValue('u_system_category') || '',
                    found_by: 'name'
                };
                if (gr.next()) r.found_by = 'name_AMBIGUOUS'; // 同名CIが複数存在
                return r;
            }
        }

        // ② serial でフォールバック
        if (mcmSerial) {
            var gr2 = new GlideRecord('cmdb_ci_computer');
            gr2.addQuery('serial_number', mcmSerial);
            gr2.query();
            if (gr2.next()) {
                var r2 = {
                    found:    true,
                    sys_id:   gr2.getUniqueValue(),
                    name:     gr2.getValue('name')              || '',
                    serial:   gr2.getValue('serial_number')     || '',
                    category: gr2.getValue('u_system_category') || '',
                    found_by: 'serial'
                };
                if (gr2.next()) r2.found_by = 'serial_AMBIGUOUS';
                return r2;
            }
        }

        return NO_CI;
    }

    // =====================================================================
    // パターン判定
    // =====================================================================
    function determinePattern(otCi, itCi) {
        if (!otCi.found && !itCi.found)  return 'BOTH_NOT_FOUND';
        if (!otCi.found)                 return 'OT_CI_NOT_FOUND';
        if (!itCi.found)                 return 'IT_CI_NOT_FOUND';
        if (otCi.sys_id === itCi.sys_id) return 'COLLISION_SAME_CI';

        var otOk = (otCi.category === OT_CATEGORY);
        var itOk = (itCi.category === IT_CATEGORY);
        if ( otOk &&  itOk) return 'BOTH_CORRECT';
        if (!otOk &&  itOk) return 'BROADCAST_WRONG_CATEGORY';
        if ( otOk && !itOk) return 'GENERAL_WRONG_CATEGORY';
        return 'BOTH_WRONG_CATEGORY';
    }

    // =====================================================================
    // CSV DATA 行出力
    // =====================================================================
    function outputDataRow(rid, ot, it, otCi, itCi, pattern) {
        var sameCi = (otCi.found && itCi.found && otCi.sys_id === itCi.sys_id);
        printCsv([
            'DATA',         rid,
            ot ? ot.name   : '',  ot ? ot.serial   : '',
            it ? it.name   : '',  it ? it.serial   : '',
            otCi.found,  otCi.sys_id,  otCi.name,  otCi.serial,  otCi.category,  otCi.found_by,
            itCi.found,  itCi.sys_id,  itCi.name,  itCi.serial,  itCi.category,  itCi.found_by,
            sameCi,      pattern
        ]);
    }

    // =====================================================================
    // メイン処理開始
    // =====================================================================
    div();
    info('処理開始');
    info('  LOOKUP_CI_FOR_ONLY = ' + LOOKUP_CI_FOR_ONLY);
    div();

    var otRows = loadImportRows('broadcast(ot_prodE)', OT_IMPORT_SET_NUMBERS);
    var itRows = loadImportRows('general(it_prod)',    IT_IMPORT_SET_NUMBERS);
    div();
    info('放送系 ResourceID数 : ' + Object.keys(otRows).length);
    info('一般系 ResourceID数 : ' + Object.keys(itRows).length);
    div();

    // CSV ヘッダー行
    printCsv([
        'TYPE',         'resource_id',
        'ot_mcm_name',  'ot_mcm_serial',
        'it_mcm_name',  'it_mcm_serial',
        'ot_ci_exists', 'ot_ci_sys_id', 'ot_ci_name', 'ot_ci_serial', 'ot_ci_category', 'ot_ci_found_by',
        'it_ci_exists', 'it_ci_sys_id', 'it_ci_name', 'it_ci_serial', 'it_ci_category', 'it_ci_found_by',
        'same_ci',      'pattern'
    ]);

    // カウンター
    var c = {
        otOnly: 0, itOnly: 0, matched: 0,
        both_correct:   0, collision:     0,
        ot_wrong_cat:   0, it_wrong_cat:  0, both_wrong_cat: 0,
        ot_not_found:   0, it_not_found:  0, both_not_found: 0
    };

    function countPattern(pat) {
        switch (pat) {
            case 'BOTH_CORRECT':             c.both_correct++;   break;
            case 'COLLISION_SAME_CI':        c.collision++;      break;
            case 'BROADCAST_WRONG_CATEGORY': c.ot_wrong_cat++;   break;
            case 'GENERAL_WRONG_CATEGORY':   c.it_wrong_cat++;   break;
            case 'BOTH_WRONG_CATEGORY':      c.both_wrong_cat++; break;
            case 'OT_CI_NOT_FOUND':          c.ot_not_found++;   break;
            case 'IT_CI_NOT_FOUND':          c.it_not_found++;   break;
            case 'BOTH_NOT_FOUND':           c.both_not_found++; break;
        }
    }

    // =====================================================================
    // 処理1: 放送系のみ（一般系ISET に ResourceID なし）
    // =====================================================================
    info('--- [1/3] 放送系のみ（一般系ISET に ResourceID なし）---');

    for (var rid in otRows) {
        if (itRows[rid]) continue;
        c.otOnly++;
        var ot = otRows[rid];
        var otCiA = LOOKUP_CI_FOR_ONLY ? findCi(ot.name, ot.serial) : NO_CI;

        info('  [OT_ONLY] ResourceID=' + rid +
             ' | name=' + ot.name + ' | serial=' + ot.serial +
             (LOOKUP_CI_FOR_ONLY
                 ? (' | ci_found=' + otCiA.found +
                    (otCiA.found ? ' | sys_id=' + otCiA.sys_id + ' | category=' + otCiA.category + ' | found_by=' + otCiA.found_by : ''))
                 : ' | CI確認スキップ(LOOKUP_CI_FOR_ONLY=false)'));

        outputDataRow(rid, ot, null, otCiA, NO_CI, 'OT_ONLY');
    }
    info('  小計 OT_ONLY: ' + c.otOnly + ' 件');
    div();

    // =====================================================================
    // 処理2: 一般系のみ（放送系ISET に ResourceID なし）
    // =====================================================================
    info('--- [2/3] 一般系のみ（放送系ISET に ResourceID なし）---');

    for (var rid2 in itRows) {
        if (otRows[rid2]) continue;
        c.itOnly++;
        var it2   = itRows[rid2];
        var itCiB = LOOKUP_CI_FOR_ONLY ? findCi(it2.name, it2.serial) : NO_CI;

        info('  [IT_ONLY] ResourceID=' + rid2 +
             ' | name=' + it2.name + ' | serial=' + it2.serial +
             (LOOKUP_CI_FOR_ONLY
                 ? (' | ci_found=' + itCiB.found +
                    (itCiB.found ? ' | sys_id=' + itCiB.sys_id + ' | category=' + itCiB.category + ' | found_by=' + itCiB.found_by : ''))
                 : ' | CI確認スキップ(LOOKUP_CI_FOR_ONLY=false)'));

        outputDataRow(rid2, null, it2, NO_CI, itCiB, 'IT_ONLY');
    }
    info('  小計 IT_ONLY: ' + c.itOnly + ' 件');
    div();

    // =====================================================================
    // 処理3: 両系共通 ResourceID（衝突確認メイン）
    // =====================================================================
    info('--- [3/3] 両系共通 ResourceID（衝突確認メイン）---');

    for (var rid3 in otRows) {
        if (!itRows[rid3]) continue;
        c.matched++;

        var ot3   = otRows[rid3];
        var it3   = itRows[rid3];
        var otCi3 = findCi(ot3.name, ot3.serial);
        var itCi3 = findCi(it3.name, it3.serial);
        var pat3  = determinePattern(otCi3, itCi3);
        var same3 = (otCi3.found && itCi3.found && otCi3.sys_id === itCi3.sys_id);

        countPattern(pat3);

        info('  [MATCHED] ResourceID=' + rid3 + ' | pattern=' + pat3 +
             (same3 ? ' ★SAME_CI（衝突）★' : '') +
             '\n             ot_mcm : name=' + ot3.name  + ' / serial=' + ot3.serial  +
             '\n             it_mcm : name=' + it3.name  + ' / serial=' + it3.serial  +
             '\n             ot_ci  : ' + (otCi3.found
                 ? 'sys_id=' + otCi3.sys_id + ' / name=' + otCi3.name + ' / category=' + otCi3.category + ' / found_by=' + otCi3.found_by
                 : 'NOT_FOUND') +
             '\n             it_ci  : ' + (itCi3.found
                 ? 'sys_id=' + itCi3.sys_id + ' / name=' + itCi3.name + ' / category=' + itCi3.category + ' / found_by=' + itCi3.found_by
                 : 'NOT_FOUND'));

        outputDataRow(rid3, ot3, it3, otCi3, itCi3, pat3);
    }
    info('  小計 MATCHED: ' + c.matched + ' 件');
    div();

    // =====================================================================
    // INFO サマリー
    // =====================================================================
    info('処理完了 - サマリー');
    div();
    info('放送系 ResourceID総数         : ' + Object.keys(otRows).length);
    info('一般系 ResourceID総数         : ' + Object.keys(itRows).length);
    div();
    info('OT_ONLY  (放送系のみ)         : ' + c.otOnly);
    info('IT_ONLY  (一般系のみ)         : ' + c.itOnly);
    info('両系共通 ResourceID 計        : ' + c.matched);
    info('  ├ BOTH_CORRECT              : ' + c.both_correct);
    info('  ├ COLLISION_SAME_CI         : ' + c.collision);
    info('  ├ BROADCAST_WRONG_CATEGORY  : ' + c.ot_wrong_cat);
    info('  ├ GENERAL_WRONG_CATEGORY    : ' + c.it_wrong_cat);
    info('  ├ BOTH_WRONG_CATEGORY       : ' + c.both_wrong_cat);
    info('  ├ OT_CI_NOT_FOUND           : ' + c.ot_not_found);
    info('  ├ IT_CI_NOT_FOUND           : ' + c.it_not_found);
    info('  └ BOTH_NOT_FOUND            : ' + c.both_not_found);
    div();

    // CSV サマリー行
    printCsv([
        'SUMMARY',
        'ot_total='   + Object.keys(otRows).length,
        'it_total='   + Object.keys(itRows).length,
        'ot_only='    + c.otOnly,
        'it_only='    + c.itOnly,
        'matched='    + c.matched,
        'BOTH_CORRECT='             + c.both_correct,
        'COLLISION_SAME_CI='        + c.collision,
        'BROADCAST_WRONG_CATEGORY=' + c.ot_wrong_cat,
        'GENERAL_WRONG_CATEGORY='   + c.it_wrong_cat,
        'BOTH_WRONG_CATEGORY='      + c.both_wrong_cat,
        'OT_CI_NOT_FOUND='          + c.ot_not_found,
        'IT_CI_NOT_FOUND='          + c.it_not_found,
        'BOTH_NOT_FOUND='           + c.both_not_found
    ]);

})();
```
