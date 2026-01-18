# ServiceNow User and Role Management Scripts

## ユーザーのロール一覧を取得

指定したユーザー名のアクティブなロールをすべて表示するスクリプト

```javascript
var userName = 'testuser';
var userGr = new GlideRecord('sys_user');

if (userGr.get('user_name', userName)) {
    gs.print('========================================');
    gs.print('ユーザー名: ' + userGr.user_name);
    gs.print('表示名: ' + userGr.name);
    gs.print('アクティブ: ' + userGr.active);
    gs.print('========================================');

    var roleGr = new GlideRecord('sys_user_has_role');
    roleGr.addQuery('user', userGr.sys_id);
    roleGr.addQuery('state', 'active'); // アクティブなロールのみ
    roleGr.orderBy('role.name');
    roleGr.query();

    gs.print('ロール一覧:');
    var count = 0;
    while (roleGr.next()) {
        count++;
        var role = roleGr.role.getRefRecord();
        gs.print(count + '. ' + role.name + ' (' + role.sys_id + ')');
    }

    if (count == 0) {
        gs.print('このユーザーにはロールが割り当てられていません');
    }
    gs.print('========================================');
    gs.print('合計ロール数: ' + count);
}
```

## 使用方法

1. ServiceNow のナビゲーションメニューで **System Definition > Scripts - Background** に移動
2. 上記のスクリプトを貼り付け
3. `userName` 変数を確認したいユーザー名に変更
4. **Run script** をクリック

## 出力例

```
========================================
ユーザー名: testuser
表示名: Test User
アクティブ: true
========================================
ロール一覧:
1. admin (2831a114c611228501d4ea6c309d626d)
2. itil (e0926e44c611228401e9fa2388d9a2bd)
3. user_admin (4b7c8431c611228501d5e2e6630e7c14)
========================================
合計ロール数: 3
```
