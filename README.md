(function () {
  var SOURCE_NAME = 'SG-SCCM';
  var OLD_CONN = '03066860c7122010b56243ac95c26027';

  // it_prod 側の Load All Records ISET を複数指定
  var IT_IMPORT_SET_NUMBERS = [
    'ISET_IT_000001',
    'ISET_IT_000002'
  ];

  // ot_prodE 側の Load All Records ISET を複数指定
  var OT_IMPORT_SET_NUMBERS = [
    'ISET_OT_000001'
  ];

  // true = 問題候補だけ出力
  var ONLY_MISMATCH = true;

  var IT_CREATED_BY = 'sg_sccm_job_user_general';
  var OT_CREATED_BY = 'sg_sccm_job_user_broadcast';

  function log(msg) {
    gs.print(msg);
  }

  function normName(v) {
    return (v || '').toString().trim().toLowerCase();
  }

  function normSerial(v) {
    return (v || '')
      .toString()
      .trim()
      .toLowerCase()
      .replace(/\s+/g, '')
      .replace(/-/g, '');
  }

  function safe(v) {
    return (v || '').toString().replace(/\|/g, '/');
  }

  function pickField(tableName, fields) {
    var gr = new GlideRecord(tableName);
    for (var i = 0; i < fields.length; i++) {
      if (gr.isValidField(fields[i])) {
        return fields[i];
      }
    }
    return '';
  }

  function getValue(gr, field) {
    if (!field || !gr.isValidField(field)) return '';
    return gr.getValue(field) || '';
  }

  function getImportSetSysIds(numbers) {
    var sysIds = [];
    for (var i = 0; i < numbers.length; i++) {
      var set = new GlideRecord('sys_import_set');
      set.addQuery('number', numbers[i]);
      set.query();
      if (set.next()) {
        sysIds.push(set.getUniqueValue());
        log('INFO|IMPORT_SET_FOUND|number=' + numbers[i] + '|sys_id=' + set.getUniqueValue());
      } else {
        log('WARN|IMPORT_SET_NOT_FOUND|number=' + numbers[i]);
      }
    }
    return sysIds;
  }

  function loadLatestImportRows(side, importSetNumbers, createdBy) {
    var out = {};
    var importSetSysIds = getImportSetSysIds(importSetNumbers);

    if (importSetSysIds.length === 0) {
      log('ERROR|NO_IMPORT_SET_SYS_IDS|side=' + side);
      return out;
    }

    var RESOURCE_FIELD = pickField('sn_sccm_integrate_sccm_2019_computer_id', [
      'u_resourceid',
      'u_resource_id',
      'resourceid',
      'resource_id'
    ]);

    var NAME_FIELD = pickField('sn_sccm_integrate_sccm_2019_computer_id', [
      'u_name',
      'name'
    ]);

    var BIOS_FIELD = pickField('sn_sccm_integrate_sccm_2019_computer_id', [
      'u_biosserialnumber',
      'u_bios_serial_number',
      'biosserialnumber'
    ]);

    var SYS_SERIAL_FIELD = pickField('sn_sccm_integrate_sccm_2019_computer_id', [
      'u_systemserialnumber',
      'u_system_serial_number',
      'systemserialnumber'
    ]);

    var CHASSIS_FIELD = pickField('sn_sccm_integrate_sccm_2019_computer_id', [
      'u_chassisserialnumber',
      'u_chassis_serial_number',
      'chassisserialnumber'
    ]);

    var CONN_FIELD = pickField('sn_sccm_integrate_sccm_2019_computer_id', [
      'u_connectionid',
      'u_connection_id',
      'connectionid',
      'connection_id'
    ]);

    if (!RESOURCE_FIELD || !NAME_FIELD || !CONN_FIELD) {
      log('ERROR|IMPORT_FIELD_NOT_FOUND|side=' + side +
        '|resource=' + RESOURCE_FIELD +
        '|name=' + NAME_FIELD +
        '|connection=' + CONN_FIELD);
      return out;
    }

    var gr = new GlideRecord('sn_sccm_integrate_sccm_2019_computer_id');
    gr.addQuery('sys_import_set', 'IN', importSetSysIds.join(','));
    gr.addQuery('sys_created_by', createdBy);
    gr.orderByDesc('sys_created_on');
    gr.query();

    while (gr.next()) {
      var rid = getValue(gr, RESOURCE_FIELD);
      if (!rid) continue;

      // 同一ResourceIDが複数あっても最新を採用
      if (!out[rid]) {
        out[rid] = {
          resource_id: rid,
          side: side,
          created_by: createdBy,
          import_row_sys_id: gr.getUniqueValue(),
          import_set: gr.getDisplayValue('sys_import_set'),
          created_on: gr.getValue('sys_created_on'),
          connectionid: getValue(gr, CONN_FIELD),
          name: getValue(gr, NAME_FIELD),
          bios: getValue(gr, BIOS_FIELD),
          system_serial: getValue(gr, SYS_SERIAL_FIELD),
          chassis_serial: getValue(gr, CHASSIS_FIELD)
        };
        out[rid].serial = out[rid].bios || out[rid].system_serial || out[rid].chassis_serial || '';
      }
    }

    log('INFO|IMPORT_ROWS_LOADED|side=' + side + '|count=' + Object.keys(out).length);
    return out;
  }

  function parseSourceId(sourceId) {
    // 対象: ResourceID|ConnectionID
    // 除外: ResourceID|ConnectionID|ComputerRelatedOU / 他形式
    var parts = (sourceId || '').split('|');
    if (parts.length !== 2) return null;
    if (parts[1] !== OLD_CONN) return null;
    if (!/^\d+$/.test(parts[0])) return null;
    return {
      resource_id: parts[0],
      connectionid: parts[1]
    };
  }

  function getCiFromTable(targetSysId) {
    var ci = new GlideRecord('cmdb_ci_computer');
    if (!ci.get(targetSysId)) return null;
    return ci;
  }

  function matchScore(ci, row) {
    if (!ci || !row) return 0;

    var score = 0;
    var ciName = normName(ci.getValue('name'));
    var ciSerial = normSerial(ci.getValue('serial_number'));

    if (row.name && ciName === normName(row.name)) score += 1;
    if (row.serial && ciSerial === normSerial(row.serial)) score += 1;

    return score;
  }

  function ciInfo(ci) {
    if (!ci) return {
      exists: false,
      sys_id: '',
      name: '',
      serial: '',
      host_name: '',
      updated_by: '',
      created_by: ''
    };

    return {
      exists: true,
      sys_id: ci.getUniqueValue(),
      name: ci.getValue('name'),
      serial: ci.getValue('serial_number'),
      host_name: ci.isValidField('host_name') ? ci.getValue('host_name') : '',
      updated_by: ci.getValue('sys_updated_by'),
      created_by: ci.getValue('sys_created_by')
    };
  }

  function patternBy(targetCount, currentSide) {
    if (targetCount === 1 && currentSide === 'broadcast') return 'PATTERN_1';
    if (targetCount === 1 && currentSide === 'general') return 'PATTERN_2';
    if (targetCount >= 2 && currentSide === 'general') return 'PATTERN_3';
    if (targetCount >= 2 && currentSide === 'broadcast') return 'PATTERN_4';
    return 'PATTERN_UNKNOWN';
  }

  // 1) Import Rows をロード
  var itRows = loadLatestImportRows('general', IT_IMPORT_SET_NUMBERS, IT_CREATED_BY);
  var otRows = loadLatestImportRows('broadcast', OT_IMPORT_SET_NUMBERS, OT_CREATED_BY);

  // 2) sys_object_source をロード
  var sourceByRid = {};
  var sourceCount = 0;
  var skippedNonIdentity = 0;
  var skippedNonComputer = 0;
  var resourceSet = {};

  var sos = new GlideRecord('sys_object_source');
  sos.addQuery('name', SOURCE_NAME);
  sos.addQuery('id', 'CONTAINS', OLD_CONN);
  sos.query();

  while (sos.next()) {
    var sourceId = sos.getValue('id');
    var parsed = parseSourceId(sourceId);
    if (!parsed) {
      skippedNonIdentity++;
      continue;
    }

    var targetTableDisplay = '';
    if (sos.isValidField('target_table')) {
      targetTableDisplay = sos.getDisplayValue('target_table') || sos.getValue('target_table') || '';
      if (targetTableDisplay.indexOf('cmdb_ci_computer') < 0) {
        skippedNonComputer++;
        continue;
      }
    }

    var createdBy = sos.getValue('sys_created_by');
    var side = (createdBy === IT_CREATED_BY) ? 'general' :
               (createdBy === OT_CREATED_BY) ? 'broadcast' : 'unknown';

    if (!sourceByRid[parsed.resource_id]) {
      sourceByRid[parsed.resource_id] = [];
    }

    sourceByRid[parsed.resource_id].push({
      source_sys_id: sos.getUniqueValue(),
      source_id: sourceId,
      resource_id: parsed.resource_id,
      connectionid: parsed.connectionid,
      created_by: createdBy,
      updated_by: sos.getValue('sys_updated_by'),
      created_on: sos.getValue('sys_created_on'),
      updated_on: sos.getValue('sys_updated_on'),
      target_sys_id: sos.getValue('target_sys_id'),
      target_table: targetTableDisplay,
      side: side
    });

    resourceSet[parsed.resource_id] = true;
    sourceCount++;
  }

  log('INFO|SOURCE_ROWS_LOADED|count=' + sourceCount +
    '|resources=' + Object.keys(resourceSet).length +
    '|skipped_non_identity=' + skippedNonIdentity +
    '|skipped_non_computer=' + skippedNonComputer);

  // 3) ResourceIDごとに判定
  var resultCount = 0;
  var mismatchCount = 0;
  var ambiguousCount = 0;
  var patternCounts = {
    PATTERN_1: 0,
    PATTERN_2: 0,
    PATTERN_3: 0,
    PATTERN_4: 0,
    PATTERN_UNKNOWN: 0
  };

  for (var rid in sourceByRid) {
    var sources = sourceByRid[rid];

    // 最新の source_object_source を current とする
    sources.sort(function (a, b) {
      return (a.updated_on || a.created_on || '') < (b.updated_on || b.created_on || '') ? 1 : -1;
    });

    var current = sources[0];

    var it = itRows[rid] || null;
    var ot = otRows[rid] || null;

    // general / broadcast が両方ないと比較しにくい
    if (!it || !ot) {
      continue;
    }

    // MCM同士の差分が無いものは除外（必要なら false に変更）
    var sideNameDiff = normName(it.name) !== normName(ot.name);
    var sideSerialDiff = normSerial(it.serial) !== normSerial(ot.serial);
    if (ONLY_MISMATCH && !sideNameDiff && !sideSerialDiff) {
      continue;
    }

    var targetCi = getCiFromTable(current.target_sys_id);
    if (!targetCi) {
      ambiguousCount++;
      log('RESULT|TARGET_NOT_FOUND' +
        '|resource_id=' + rid +
        '|source_sys_id=' + current.source_sys_id +
        '|source_id=' + current.source_id +
        '|current_target_sys_id=' + current.target_sys_id +
        '|target_table=' + current.target_table +
        '|it_name=' + safe(it.name) +
        '|it_serial=' + safe(it.serial) +
        '|ot_name=' + safe(ot.name) +
        '|ot_serial=' + safe(ot.serial));
      continue;
    }

    var targetInfo = ciInfo(targetCi);

    // current target がどちら側の値に近いか判定
    var scoreGeneral = matchScore(targetCi, it);
    var scoreBroadcast = matchScore(targetCi, ot);

    var currentSide = 'unknown';
    if (scoreGeneral > scoreBroadcast) {
      currentSide = 'general';
    } else if (scoreBroadcast > scoreGeneral) {
      currentSide = 'broadcast';
    } else if (scoreGeneral === 2 && scoreBroadcast === 2) {
      currentSide = 'both';
    }

    var distinctTargetCount = 0;
    var targetSet = {};
    for (var i = 0; i < sources.length; i++) {
      targetSet[sources[i].target_sys_id] = true;
    }
    for (var k in targetSet) {
      distinctTargetCount++;
    }

    var pattern = patternBy(distinctTargetCount, currentSide);
    patternCounts[pattern] = (patternCounts[pattern] || 0) + 1;

    var mismatchType = [];
    if (normName(targetInfo.name) !== normName(it.name)) mismatchType.push('IT_NAME_DIFF');
    if (normSerial(targetInfo.serial) !== normSerial(it.serial)) mismatchType.push('IT_SERIAL_DIFF');
    if (normName(targetInfo.name) !== normName(ot.name)) mismatchType.push('OT_NAME_DIFF');
    if (normSerial(targetInfo.serial) !== normSerial(ot.serial)) mismatchType.push('OT_SERIAL_DIFF');

    // 問題候補だけ出す
    var isProblem = (mismatchType.length > 0);

    if (ONLY_MISMATCH && !isProblem) {
      continue;
    }

    resultCount++;

    log([
      'RESULT|' + (isProblem ? 'MISMATCH' : 'MATCH'),
      'pattern=' + pattern,
      'resource_id=' + rid,
      'current_side=' + currentSide,
      'distinct_target_count=' + distinctTargetCount,
      'it_name=' + safe(it.name),
      'it_serial=' + safe(it.serial),
      'ot_name=' + safe(ot.name),
      'ot_serial=' + safe(ot.serial),
      'target_name=' + safe(targetInfo.name),
      'target_serial=' + safe(targetInfo.serial),
      'target_sys_id=' + current.target_sys_id,
      'target_table=' + current.target_table,
      'source_sys_id=' + current.source_sys_id,
      'source_created_by=' + current.created_by,
      'source_updated_by=' + current.updated_by,
      'source_id=' + safe(current.source_id),
      'mismatch_type=' + (mismatchType.length ? mismatchType.join(',') : 'NONE'),
      'source_row_count=' + sources.length,
      'it_source_row_sys_id=' + (it ? it.import_row_sys_id : ''),
      'ot_source_row_sys_id=' + (ot ? ot.import_row_sys_id : '')
    ].join('|'));
  }

  log('SUMMARY' +
    '|result_count=' + resultCount +
    '|mismatch_count=' + mismatchCount +
    '|ambiguous_count=' + ambiguousCount +
    '|pattern1=' + patternCounts.PATTERN_1 +
    '|pattern2=' + patternCounts.PATTERN_2 +
    '|pattern3=' + patternCounts.PATTERN_3 +
    '|pattern4=' + patternCounts.PATTERN_4 +
    '|pattern_unknown=' + patternCounts.PATTERN_UNKNOWN +
    '|it_resource_count=' + Object.keys(itRows).length +
    '|ot_resource_count=' + Object.keys(otRows).length +
    '|source_resource_count=' + Object.keys(sourceByRid).length);
})();
