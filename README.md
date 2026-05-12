承知しました。データ方向と追加費用列を削除した版です。

---

# ServiceNow-Tanium 15分連携 3案比較(改訂版)

**目的:** Tanium Asset 1時間更新制約を回避し、Tanium 1,000台のCMDB 15分間隔同期を実現
**前提:** ServiceNow = SaaS(Now Platform)、MID Server = 既存配置済

| No | 案 | 概要 | 追加必要なもの<br>(Tanium導入形態別) | 変更規模 | リアルタイム性 | **懸念点** |
|:-:|---|---|---|:-:|:-:|---|
| **①** | **Tanium<br>Connect Push** | Tanium側で定期/イベントトリガにより、ServiceNow **Import Set API** へPush配信 | **Tanium側:** Connectモジュール **(別売)**<br>**Snow側:** **Import Set API利用(標準API、自作不要)**<br><br>**Cloud:** Snowへ直接配信(egress allow list設定要)<br>**オンプレ:** ファイアウォール経由でSnowへ送信 | **中**<br>(5~8人日) | **即時Push可** | • **Connectモジュールが別売ライセンス**、契約状況の確認が前提<br>• Push失敗時の **再送/補填設計** が必要(Connect側のリトライ機能は限定的)<br>• Snow側で「**データが来ない**」状況の死活監視が必要<br>• Tanium Cloud時は egress allow list 運用が発生<br>• Saved Question取得結果がスナップショット型、変更検知の細かさに限界 |
| **②** | **Tanium SDK 経由** | ServiceNow側から Tanium API Gateway (GraphQL) へ定期Pull取得。Tanium公式無料SDKが認証・リトライ・ページング等を抽象化 | **Tanium側:** API Gatewayモジュール(無料で導入可)<br>**Snow側:** Tanium SDK(無料Store App)<br><br>**Cloud:** API Gateway標準搭載、MID Server不要<br>**オンプレ:** API Gatewayを無料インポート、MID Server経由 | **中**<br>(7~10人日) | 15分Pull | • API Gatewayモジュールの **Tanium側導入作業** が必要(無料だが調整要)<br>• Snow Store からの **公式アプリ導入** に社内承認プロセスが必要な場合あり<br>• SDKの **バージョンアップ追従** が継続的に必要<br>• SDK抽象化に乗るため、細かい挙動カスタマイズに制約<br>• Pull型のため **15分間隔が上限** |
| **③** | **REST API<br>直接コール** | MID Server経由でTanium Platform REST APIを直接コール、認証・リトライ等全て自作 | なし(既存機能で完結)<br><br>**Cloud:** Token認証のみ、MID Server不要<br>**オンプレ:** Basic/Token両対応、MID Server経由 | **大**<br>(17~25人日) | 15分Pull | • Token Rotation・エラーハンドリング・ページネーション等 **全て自作・自前品質保証**<br>• Tanium公式は **Platform REST APIの統合用途を段階的廃止**、中長期で API Gateway 移行が必要な可能性<br>• 開発者依存で **属人化リスク** が高い<br>• Tanium公式サポート範囲外、トラブル時はコミュニティ頼み<br>• Pull型のため **15分間隔が上限** |

---

## 採用判断

- **API Gateway 利用可** → **案①(Connect Push)** を採用(リアルタイム性最優先)
- **API Gateway 利用不可** → **案③(REST API直接)** を採用(Platform REST APIで確実に実現可能)
- **案②(SDK)** は、API Gateway利用可だが Connect ライセンス未保有の場合の代替案

---

これでよろしいでしょうか?問題なければPPT化に進みます。
