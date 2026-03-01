# [016/018] warm-up pingエンドポイント + テスト

**ブロック**: - Task 005（DB接続 + スキーマ）— DB接続設定（SELECT 1クエリ実行前提）

## 目的

全18タスク中の第16タスク。GET /api/ping Route Handler（PING_SECRETトークン検証・SELECT 1軽量クエリ・200 OK / 401 Unauthorized）・Netlify Scheduled Functions設定（5〜10分間隔、利用不可時はGitHub Actions scheduled workflow代替）・テスト（トークン一致で200・不一致で401）を実装することで、Neonコールドスタート対策の定期実行基盤を確立する。

## 受け入れ基準

- [ ] `Authorization: Bearer <PING_SECRET>` ヘッダー付きのGETリクエストに対して `200 OK { "status": "ok" }` が返却されること
- [ ] `Authorization` ヘッダーが不正またはなしのGETリクエストに対して `401 Unauthorized` が返却されること
- [ ] `src/app/api/ping/route.ts` が `/api/ping` に配置されており、Auth.js Middlewareの認証対象外になっていること
- [ ] 定期実行（5〜10分間隔で `/api/ping` を呼び出し）が設定されていること。Netlify StarterプランでScheduled Functionsが利用可能な場合はnetlify.toml設定を使用し、利用不可の場合はGitHub Actions scheduled workflowで代替する（判断基準: `development-process.md` §4.7 参照）
- [ ] テスト（Vitest統合テストまたはRoute Handler単体テスト）でトークン一致/不一致の両ケースがパスすること

## 入力

- `detailed-design.md` §3.2（GET /api/ping Route Handler仕様: リクエスト・レスポンス・認証設計）
- `detailed-design.md` §4.1（ジョブ定義: warm-up ping・頻度・タイムアウト・べき等性）
- `detailed-design.md` §4.2（データフロー: Scheduler→/api/ping→PING_SECRET検証→SELECT 1）
- `architecture.md` §9.5（Neonコールドスタート対策: warm-up ping設計・セキュリティ・middleware除外設計）
- `development-process.md` §4.7（ヘルスチェック・稼働監視: Netlify Scheduled Functions利用不可時の代替手段）
