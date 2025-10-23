よくあるImport Schedule（インポートスケジュール）エラーの調査・対応方法 と 代表的なエラー一覧 を整理しました。

🧭 エラー発生時の基本確認手順
① Integration Dashboardの確認

メニュー: Service Graph Connectors → Integration Dashboard

該当のコネクタ（例：SG Tanium、SG SCCMなど）を選択

「Import with Errors」 が 0 でない場合、詳細を確認

👉 リンクをクリックすると sys_import_set_run レコード（実行履歴）画面に遷移します。

② Import Set Run の確認

sys_import_set_run テーブル（モジュール名：Import Set Runs）

状態が「Completed with Errors」または「Failed」のレコードを開く

「Related Links」内の Transform History または Import Log を確認

特に「Transform Map」や「Pre/Post Script」でのエラー内容を確認します。

③ Import Log でのエラー分類

ログの内容を見て、次のように分類します：
