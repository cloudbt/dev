



SCCM 
assigned to
https://www.servicenow.com/docs/bundle/yokohama-platform-administration/page/integrate/cmdb/reference/how-sccm-integration-works.html#d263348e348

SGC-SCCM
https://www.servicenow.com/docs/bundle/yokohama-servicenow-platform/page/product/configuration-management/concept/cmdb-integration-sccm.html


```
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
