```

お疲れ様です。王です。
SG-SCCM Softwareの件、確認しましたので回答いたします。

結論として、レジストリパスによる絞り込みは対応できません。

現在ServiceNow側のSQL文が参照しているMECM側のビュー（v_GS_ADD_REMOVE_PROGRAMS / v_GS_ADD_REMOVE_PROGRAMS_64）には、レジストリパスに関する項目が存在しないためです。

なお、上記ビューの取得元は既にHKLMの2箇所（Uninstall / WOW6432Node配下）のみであり、ご質問にあったHKCU配下の情報はMECMの標準インベントリでは収集されないため、もともと含まれておりません。
根拠：
・https://learn.microsoft.com/en-us/intune/configmgr/develop/core/understand/sqlviews/hardware-inventory-views-configuration-manager
・https://learn.microsoft.com/en-us/answers/questions/1003529/installed-software-missing-from-installed-software

また、現在のServiceNow側ソフトウェア情報は全体で約187万件ありますが、対象PCが約23,923台（一般：22,448台、放送：1,475台）あるため、1PCあたりの平均は約78件です。PC単位で見ると特別多い状況ではありません。

よろしくお願いいたします。
```

```
有田さん

お疲れ様です。王です。
SG-SCCM Softwareのソフトウェア情報量の件について確認しましたので、回答いたします。

【結論】
レジストリパスによる絞り込みはできません。

【理由】
現在SG-SCCM SoftwareのData SourceのSQL文では、MECM側の以下2つのビューからソフトウェア情報を取得しています。

・v_GS_ADD_REMOVE_PROGRAMS（32bitアプリ情報）
・v_GS_ADD_REMOVE_PROGRAMS_64（64bitアプリ情報）

これらのビューには、DisplayName、Version、Publisher、InstallDate等の項目はありますが、レジストリパスに関する項目は含まれておりません。
そのため、SQLのWHERE句でレジストリパスを条件にした絞り込みは対応できない状況です。
※SQL文のWHERE句でPublisherやDisplayNameの条件を追加し、不要なソフトウェアを除外することができます。

また、上記2つのビューの取得元は以下の通りです。

・v_GS_ADD_REMOVE_PROGRAMS → HKLM\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall
・v_GS_ADD_REMOVE_PROGRAMS_64 → HKLM\Software\Microsoft\Windows\CurrentVersion\Uninstall

つまり、現状のSQLは既にHKLMの上記2箇所のみから取得しており、HKCU（ユーザー単位のインストール情報）はMECMの標準ハードウェアインベントリでは収集対象外のため、もともと含まれておりません。

【参考：データ量について】
現在ServiceNow側収集したソフトウェア情報の全体数は約187万件ですが、これは対象PCが約23,923台（一般：22,448台、放送：1,475台）あるためです。
1PCあたりの平均ソフトウェア数は約78件であり、PC単位で見ると特別多い状況ではありません。

【根拠】
・Microsoft Learn - Hardware inventory views（v_GS_ADD_REMOVE_PROGRAMSビューの公式定義）
https://learn.microsoft.com/en-us/intune/configmgr/develop/core/understand/sqlviews/hardware-inventory-views-configuration-manager
Microsoft Learn - Q&A（MECMがHKLMのみ収集しHKCUは対象外であることの公式回答）
https://learn.microsoft.com/en-us/answers/questions/1003529/installed-software-missing-from-installed-software

よろしくお願いいたします。
```

