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
