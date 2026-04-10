```
件名: SG-SCCM - 2系統のImportジョブ間でCIのName・Serialが繰り返し上書きされる

件名: SG-SCCM - 複数データソース間でCIレコードが交互に上書きされる問題（IRE/Reconciliation）
---
■ 環境構成
・製品: SG-SCCM
・影響テーブル: cmdb_ci_computer, cmdb_ci_hardware
・SCCM接続: it_prod / ot_prodE の2接続
・Scheduled Data Importジョブ:
  - sg_sccm_job_user_general（一般系）
  - sg_sccm_job_user_broadcast（放送系）
  - いずれも15分間隔で実行
・RTEのSG-SCCM Computer IdentityのAfter Scriptで、
  cmdb_ci_computer.u_system_category が空欄時に general=0 / broadcast=1 を設定
セgeneral側のデータソースにおけるジョブ実行間隔:
  - 15分間隔: it_prod_MCM-SG-SCCM Computer Identity / Network のみ
  - 1日1回（23時）: その他の it_prod_MCM-XXXX ジョブ
  ※ SG-SCCMは一般設備の構成情報を15分間隔で全件収集できないため、上記のように分けて運用

■ 問題内容
general側のScheduled Data Importが、broadcast側で作成されたCIレコードを誤って更新し、
Name・Serial number等の属性値が繰り返し上書きされる現象が発生しています。
特徴:
・broadcast側で作成されたレコードのみ影響を受ける（general側のレコードは変更されない）
・上書きの発生タイミングは不定期（毎回Import時に必ず発生するわけではない）
・Name・Serial共に異なるケース、Serialが同一でNameのみ異なるケースの両方で発生

発生例:
    レコードA (broadcast): Name=wmrns-f-at03 / Serial=1117XXXX / System category: Broadcast
  レコードB (general):   Name=01620-21-p07 / Serial=IPJ5XXXX / System category: General
  ① general側Import実行 → レコードAがBの値に上書きされる
　→    レコードA (broadcast):Name=01620-21-p07 / Serial=IPJ5XXXX / System category: Broadcast
　　★これが問題、同じNameとSerialのレコードが2個存在
  ② broadcast側Import実行 → レコードAが元の値に戻る
  ③ 以降 ①②の繰り返し

■ 影響
・ある時間帯で同一端末に対して複数（2個）CI（同じNameとSerial）が存在
・CI属性の履歴が汚染され、正確な構成管理が不可

■ 確認したいこと
上記現象の原因と対策をご確認いただけますと幸いです。

よろしくお願いいたします。
```

```

お疲れ様です。SG-SCCMの動作について問題を確認しましたのでご報告します。

■ 問題の概要
SG-SCCMの2インスタンス（general / broadcast）のScheduled Data Importが互いにCIレコードを上書きし合い、Name・Serial number等の属性値が繰り返し変化する現象が発生しています。

■ 発生パターン

【パターン①】NameもSerialも異なる2レコードが存在するケース

初期状態：
  レコードA（broadcast側で作成）
    Name: wmrns-f-at03 / Serial: 1117XXXX / System category: Broadcast
  レコードB（general側で作成）
    Name: 01620-21-p07 / Serial: IPJ5XXXX / System category: General

発生する動き：
  ① general側Import実行
    → レコードAが「Name: 01620-21-p07 / Serial: IPJ5XXXX」に上書きされる
  ② broadcast側Import実行
    → レコードAが「Name: wmrns-f-at03 / Serial: 1117XXXX」に戻る
  ③ 以降 ①②の繰り返し

【パターン②】Serialが同じ・Nameが異なる2レコードが存在するケース

初期状態：
  レコードA（broadcast側で作成）
    Name: wmrns-f-at03 / Serial: 11170319 / System category: Broadcast
  レコードB（general側で作成）
    Name: 01620-21-p07 / Serial: 11170319 / System category: General

発生する動き：
  ① general側Import実行
    → レコードAのNameが「01620-21-p07」に上書きされる
  ② broadcast側Import実行
    → レコードAのNameが「wmrns-f-at03」に戻る
  ③ 以降 ①②の繰り返し（Serialは11170319のまま変わらず）

■ 補足
・cmdb_ci_computer および親クラス cmdb_ci_hardware の両方でこの現象が発生
・broadcast側で作成されたレコードのみ影響を受けている
  （general側で作成されたレコードはgeneral側Importで変更されていない）
・general / broadcastのScheduled Data Importはいずれも15分間隔で実行
  ただし、上書きが発生するタイミングは不定期であり、
  毎回のImport実行時に必ず発生するわけではない

■ 想定される原因
① IREの誤マッチ
  IRE（Identification/Reconciliation）ルールにおいて、general側Importが
  broadcast側のレコードを誤って同一CIとしてマッチし、
  上書きしている可能性

② ジョブ実行間隔の差異によるデータ不整合
  general側のデータソースについて、SG-SCCMは一般設備の構成情報を
  15分間隔で全件収集できないため、以下のように分けて運用している。
    　15分間隔：it_prod_MCM-SG-SCCM Computer Identity / Network のみ
    　1日1回（23時）：その他の it_prod_MCM-XXXX ジョブ
  この収集タイミングの差異により、Computer Identity側が参照する
  関連データ（他ジョブで収集される属性）がまだ更新されておらず、
  不完全なデータ状態でIREが誤マッチを起こしている可能性がある

■ 次のアクション
ServiceNow Supportへ問い合わせを行い、この現象の原因と対策を確認する予定です。

以上、ご確認をお願いいたします。
```

添付の最新版を確認しました。フロー図もStep 1/Step 2のテーブルも整っていますね。変更点として「クラウドサービスアカウント名」→「クラウドサービスアカウントID値」、Step 2(b)が「アカウントID属性の設定」になっている点も把握しました。

この最新版をベースに、未回復の指摘への回復案を作成します。

---

**#17（背景・目的）：**

> 修正しました。iNOC向けに以下の構成で書き直しました。
> - SG-AWSによる自動収集が標準運用であること
> - 自動収集が利用できない場合に限り手動登録が必要となること
> - 本セクションはAWS/Azure固有の注意事項・対処方法に限定して記載する旨
>
> プロジェクト課題管理からの転記ではなく、iNOC担当者が手動登録時に何を注意すべきか、という観点で再構成しています。

---

**#20（アプリケーションサービス紐づけ）：**

> 自動収集と同様に、アカウント単位でサービスインスタンスに紐づける方針としました。
> 利用者がポータル画面の新規登録申請時にサービスインスタンスフィールドで指定することで、CI関係性（Depends On: Used By）が自動作成されます。
> そのためiNOC側の後続作業は不要であり、利用者向け手順書にサービスインスタンスの指定手順を追記します。

---

**#21（クラウドサービスアカウント紐づけ）：**

> ポータル画面にはクラウドサービスアカウントとの紐づけフィールドが存在しないため、以下の運用フローで対処します。
>
> - 利用者：メモ欄に当該リソースが所属するクラウドサービスアカウントID値を記載
> - iNOC：申請承認後、メモ欄のアカウントID値をCIレコードのAccountIDに設定
>
> これにより、BRによる設備種別・管理グループの自動反映が機能し、VR/SIRでの正しい関連付けが担保されます。
> 具体的な手順はiNOC向け手順書に記載します。

---

**#24（混在管理→前提条件へ）：**

> 自動収集CIと手動登録CIの混在は前提条件に含めました。
> 識別方法として、手動登録CIにはDiscovery Source値を「Manual-AWS」または「Manual-Azure」に設定するルールとし、自動収集（SG-AWS / SG-Azure）と明確に区別できるようにしました。
> フィルタ条件（Discovery Source starts with "Manual" 等）を本手順書に記載しています。

---

**#25（まとめ）：**

> 書き直しました。以下の3層構成で整理しています。
>
> ①手動登録の制限事項（仕様制約として受容する2件）
> 　→ 既存の自動収集運用には影響しない旨も備考に明記
>
> ②ISM側で技術的にカバーする範囲
> 　→ サービスインスタンス紐づけ方針（アカウント単位）
> 　→ メモ欄を活用したアカウントID・Discovery Source値の受け渡し
> 　→ iNOCによるアカウントID設定・Discovery Source設定の手順
> 　→ フィルタ手順
>
> ③技術的にカバーできない範囲
> 　→ 案件固有の管理要件は汎用項目（メモ・備考等）で対応いただく
>
> 懸念点の投げっぱなしではなく、対処方法と手順書の紐づけを明記しています。


```
Subject: SG-AWS - Serverクラスにおけるホスト名 / FQDNの取得について

Description:

Service Graph Connector for AWS（SG-AWS）を使用してAWS環境の構成情報をCMDBに取り込んでいます。
Serverクラス（cmdb_ci_server / cmdb_ci_linux_server / cmdb_ci_win_server）における
ホスト名またはFQDNの取得について、以下3点を確認させてください。

EC2インスタンスの実際のホスト名（OS上で設定されたホスト名）は、
SG-AWS経由でAWS側から取得できますか？
それとも、SG-AWSの仕様上取得対象外でしょうか？

Subject: SG-AWS - Serverクラスにおけるホスト名の格納フィールドについて

Description:

SG-AWS（v2.8.1）を使用してAWS環境の構成情報をCMDBに取り込んでいます。
Serverクラスのホスト名について確認させてください。

【背景】
現在の収集結果として、Serverクラス（cmdb_ci_server / linux_server / win_server）のフィールド状況は以下の通りです。
・Name：Private DNS Name（ip-x-x-x-x形式）が格納済み
・host_name：空白
・fqdn：空白

SSM Documentsを確認したところ、Linux・Windowsともにhostnameコマンドで取得していることを確認しました。
・Linux：hostname | sed 's/^/#HOST#/'
・Windows：hostname | foreach {"###HOST###"+ $_}

ただし、SSMが有効なEC2のレコードでもhost_name / fqdnは空白のままです。

【質問①】
SG-AWSによりServerクラスに取り込まれるホスト名情報は、
どのフィールドに格納される仕様でしょうか。
（Name / host_name / fqdn / その他）
また、現在空白となっている原因として考えられることはありますか。

【質問②】
ホスト名の取得にはSSM Deep Discoveryが有効であることが前提となりますか。
SSMが有効であってもhost_nameが空白になるケースはありますか。

【環境情報】
・SG-AWS：v2.8.1
・ServiceNow：○○
・SSM Deep Discovery：一部EC2で有効、大半は未構成
```


ご確認・FBありがとうございます。各点について回答します。

■Disk sizeの証跡追記
承知しました。cmdb_ci_storage_volumeテーブルにEBSレコードが存在すること、およびvm_instanceとのリレーションシップが張られていることを画面キャプチャで追記しました。

■host_name / FQDNフィールドについて
SG-AWSのFunctional Specを確認しました。
https://www.servicenow.com/community/cmdb-articles/service-graph-connector-for-aws-functional-spec-and-ci/ta-p/2301845

Serverクラス（cmdb_ci_server / linux_server / win_server）でSG-AWSが格納するフィールド一覧には、ホスト名関連として以下が含まれています。
・Name（= Private DNS Name、ip-x-x-x-x形式）
・DNS Domain
・

一方、host_nameやfqdnはこのフィールド一覧には明示されていません。

また、SSM Documentsの実行コマンドも確認しました。
https://www.servicenow.com/community/cmdb-articles/service-graph-connector-for-aws-ssm-documents/ta-p/2300486
・Linux：hostnameコマンドは含まれていません
・Windows：wmic computersystem get ... DNSHostName, domain が含まれているため、Windowsのみホスト名が取得される可能性があります

ただし、これはドキュメント上の確認ですので、実機でもcmdb_ci_server / linux_server / win_serverのhost_name・fqdnフィールドの値を確認し、実際の格納状況を証跡に追記します。

■45アカウントの件
承知しました。9アカウント以外の判断はNHK様側に委ねる方針で進めます。


■45アカウントの件
承知しました。9アカウント以外の判断はNHK様側に委ねる方針で進めます。

■NHK様への依頼予定
上記を踏まえ、以下2点についてNHK様に確認・依頼する予定です。

① SSM（AWS Systems Manager）の設定について
 → SSM未構成のEC2インスタンスに対して、設定実施のご予定をお伺いする
 ※手順は既にお渡し済みのセットアップ手順書（参考手順2-8～2-15）に記載済み

② 対象9アカウント以外のAWSアカウントの取扱いについて
 → 9アカウント以外のCIを管理対象とするか、参考情報扱いとするか等、NHK様側でのご判断をお伺いする

内容に問題なければ、NHK様へ連絡します。


```
いつもお世話になっております。○○です。

SG-AWSのCMDB収集データ確認に伴い、2点ご確認をお願いいたします。

【1】SSM設定の実施について
SG-AWSで収集されたサーバーの大半でOS情報が空白です。
これはSSM（Deep Discovery）が未構成のEC2ではOS情報が取得できない
SG-AWSの仕様によるものです。

OS情報を取得するには、対象EC2へのSSM Agent有効化設定が必要です。
手順は既にお渡し済みのセットアップ手順書（参考手順2-8～2-15）に
記載しておりますので、設定実施のご予定をお聞かせください。

【2】対象アカウント範囲のご判断
設定完了のご連絡をいただいている9アカウント以外にも、
一部アカウントで既に設定が完了しておりCI情報が収集されています。
9アカウント以外のCIの取扱い（管理対象とするか、参考情報扱いとするか等）
について、NHK様側でご判断いただけますでしょうか。

お手数ですが、ご確認のほどよろしくお願いいたします。
```

```
SG-AWSによるCMDBデータの収集結果を確認しておりますが、
以下2点について、NHK様側でのご確認・ご判断をお願いしたくご連絡いたします。

━━━━━━━━━━━━━━━━━━━━━━━━
■依頼①：SSM（AWS Systems Manager）の設定について
━━━━━━━━━━━━━━━━━━━━━━━━
SG-AWSで収集されたサーバー（cmdb_ci_server）のうち、
大半のレコードでOperating Systemが空白となっています。

これはSSM（Deep Discovery）が未構成のEC2インスタンスでは
OS情報を取得するAPIが存在しないためであり、SG-AWSの仕様上の制約です。

参考：ServiceNow公式コミュニティ記事
https://www.servicenow.com/community/cmdb-articles/service-graph-connector-for-aws-functional-spec-and-ci/ta-p/2301845

OS情報を取得するためには、対象のEC2インスタンスに対して
SSM Agentのインストールおよび有効化設定が必要となります。
※設定手順については、既にお渡ししているAWS環境セットアップ手順書
 （【NHK-ISM】AWS環境セットアップ手順書 ITb向け）の
 参考手順2-8～2-15に記載がございます。

つきましては、SSM設定が未実施のアカウント・EC2インスタンスについて、
設定実施のご予定をお聞かせいただけますでしょうか。

━━━━━━━━━━━━━━━━━━━━━━━━
■依頼②：対象9アカウント以外のAWSアカウントの取扱いについて
━━━━━━━━━━━━━━━━━━━━━━━━
現在、SG-AWSの対象として設定完了のご連絡をいただいているのは
全45アカウント中9アカウントです。

ただし、動作確認時点では9アカウント以外のいくつかのアカウントについても
既に設定が完了しており、それらに紐づくCI情報も併せて収集されている状況です。

今回の対象範囲として、以下のいずれの方針とするか
NHK様側でご判断いただけますでしょうか。

 A）対象9アカウントのCIのみを管理対象とする（それ以外は参考情報扱い）
 B）設定済みの全アカウントを管理対象に含める
 C）その他（対象アカウントを追加指定する等）

━━━━━━━━━━━━━━━━━━━━━━━━
```
お忙しいところ恐れ入りますが、ご確認のほどよろしくお願いいたします。
ご不明点がございましたらお気軽にお問い合わせください。

以上、よろしくお願いいたします。


```
NHK ○○様

いつもお世話になっております。○○です。

3月17日にServiceNow側からSG-AWSのジョブを手動実行し、構成情報の収集確認を実施しました。
今回は、OUに移行済みかつ設定完了しているAWSアカウント9件を対象に確認を行いました。
収集結果は以下のエクセルにまとめましたので、共有いたします。

＜収集結果ファイルリンク＞

確認の結果、2点気になることがありましたので、ご確認・ご判断をお願いいたします。

━━━━━━━━━━━━━━━━━━━━
１．OS情報・SW情報の欠損について
━━━━━━━━━━━━━━━━━━━━
SG-AWSで収集されたサーバー（cmdb_ci_server）のうち、大半のレコードでOS情報が空白となっており、また一部のEC2でSW情報（ソフトウェアインストール情報等）が収集されていない状況です。
原因として、対象EC2インスタンスでSSM（AWS Systems Manager）が有効になっていないことが考えられます。

AWS環境セットアップとしてCloudFormationを実施いただきましたが、SSMを有効化するためには別途SSM Agentのインストールおよび有効化設定が必要です。
※手順は既に共有済みのAWS環境セットアップ手順書
（【NHK-ISM】AWS環境セットアップ手順書 ITb向け）の参考手順2-8～2-15に記載がございます。

つきましては、SSM設定が未実施のアカウント・EC2インスタンスについて、設定実施いただけると幸いです。

━━━━━━━━━━━━━━━━━━━━
２．対象アカウント範囲のご確認
━━━━━━━━━━━━━━━━━━━━
現在、SG-AWSの対象として設定完了のご連絡をいただいているのは全45アカウント中9アカウントです。
ただし、動作確認時点（3/17）では9アカウント以外のアカウントについても既に設定が完了しており、CI情報が併せて収集されている状況です。

収集対象アカウントは全45アカウントとするか、当初予定の9アカウントのみとするか、ご判断いただけますでしょうか。



━━━━━━━━━━━━━━━━━━━━
２．対象アカウント範囲のご確認
━━━━━━━━━━━━━━━━━━━━
設定完了のご連絡をいただいている9アカウント以外にも、
一部アカウントのCI情報が収集されている状況です。
これらはOU移行対象の全45アカウントに含まれるアカウントです。

収集対象アカウントはOU移行対象の全45アカウントという認識であっていますでしょうか。
ご確認いただけますと幸いです。
━━━━━━━━━━━━━━━━━━━━

お忙しいところ恐れ入りますが、ご確認のほどよろしくお願いいたします。
```
