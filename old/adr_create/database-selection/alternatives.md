# 代替案一覧

## 採用候補

### ALT-1: Cloudflare D1
- 概要: Cloudflare のエッジ SQLite データベース。Workers との同一プラットフォーム統合。SQL クエリ・LIKE 検索・FTS 対応。無料枠: 5GB、読み取り500万回/日、書き込み10万回/日
- 提案元: ユーザー提供

### ALT-2: Supabase
- 概要: PostgreSQL ベースの BaaS。RESTful API・リアルタイム機能・認証機能を統合提供。無料枠: 500MB、5万MAU。外部サービスとして Workers から HTTP 接続
- 提案元: ユーザー提供

### ALT-3: TiDB Serverless
- 概要: MySQL 互換の分散 NewSQL データベース。サーバーレス構成で自動スケーリング。無料枠: 5GiB ストレージ、5,000万 Request Units/月。外部サービスとして Workers から HTTP/TCP 接続
- 提案元: ユーザー提供

### ALT-4: Turso (libSQL)
- 概要: SQLite 互換の分散エッジデータベース。Cloudflare 公式パートナー。`@libsql/client/web` HTTP ドライバーで Workers から接続可能。エッジレプリカによる低レイテンシ。無料枠: 5GB、5億ロウ読み取り/月
- 提案元: 評価エージェント提案（OBJ-1, OBJ-5）+ ユーザー承認

## 除外した代替案
なし
