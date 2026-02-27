# OBJ-4: 運用負荷の最小化 — 評価結果

## 提案した代替案

この目的（運用負荷の最小化）を最適化する観点から、以下の選択肢が適していると考えられる。

- **Cloudflare D1**（ALT-1に対応）: Cloudflare Workers と同一プラットフォームに存在するため、認証情報の管理・デプロイパイプラインの統合が不要。`wrangler` CLI 一本で DB 作成・マイグレーション・クエリ実行が完結し、別サービスのダッシュボードを行き来する手間がない。
- **PlanetScale（MySQL 互換 Serverless DB）**: ブランチングモデルによるスキーマ変更フローが整備されており、マイグレーション適用ミスのリスクが低い（今回ユーザー提供代替案には含まれていないが、この目的に特化した参考案として提示）。

> 注: ユーザー提供の代替案（ALT-1〜ALT-3）が既に存在するため、以下の評価は ALT-1〜ALT-3 を対象とする。

---

## 評価

### ALT-1: Cloudflare D1

- 評価: ◎
- 利点:
  - Cloudflare Workers と同一プラットフォーム（Cloudflare）に統合されており、追加サービスのアカウント管理・認証情報管理が不要。Workers の `wrangler.toml` に `[[d1_databases]]` を追記するだけで接続が完結する
  - `wrangler d1 create`・`wrangler d1 execute`・`wrangler d1 migrations apply` など、CLI 操作が一元化されており、管理ツールを切り替える必要がない
  - Drizzle ORM + D1 + Hono + Workers の組み合わせはエコシステムとして成熟しており（research.md 観点3）、公式ドキュメント・コミュニティの実例が豊富。詰まったときの情報が得やすい
  - Binding 方式のため、環境変数の設定・ローテーションが不要
  - Workers のデプロイ（`wrangler deploy`）と同一の CI/CD パイプラインに自然に組み込める
- 欠点:
  - FTS5 仮想テーブルを含む場合、`wrangler d1 export` でのバックアップが非対応（research.md 観点4、D1 に記載）。バックアップ手順を別途整備する必要があり、この点だけ運用負荷が増す
  - スキーマ確認や手動クエリ実行は `wrangler d1 execute` 経由か Cloudflare Dashboard の D1 ビューア経由になるため、GUI ツールの充実度は Supabase に比べて劣る
- 根拠: プラットフォーム統合による「管理対象サービスの一元化」がこの目的に直結する最大の優位点。外部サービス連携の設定・認証情報管理ゼロは個人開発の運用負荷を大幅に削減する
- CSD依存: S4（D1 の Free プランの継続提供）。プランが廃止・変更された場合、移行コストが運用負荷として顕在化する可能性がある

---

### ALT-2: Supabase

- 評価: ○
- 利点:
  - 充実した GUI ダッシュボード（Table Editor、SQL Editor、Auth ダッシュボード）を提供しており、スキーマ確認・データ操作・認証ユーザー管理を Web ブラウザから直感的に行える
  - 組み込み認証機能（Supabase Auth）により、認証機能の実装・管理が大幅に簡略化される（OBJ-2 と重複するが、運用負荷削減の観点でも有効）
  - PostgreSQL ベースのため、SQL の標準的な機能・ツールチェーン（pgAdmin、psql 等）が利用可能
  - Supabase CLI による local 開発環境の構築・マイグレーション管理が可能
- 欠点:
  - Cloudflare Workers からのアクセスは HTTP 経由（Supabase REST API または Supabase JS SDK）となるため、接続設定に `SUPABASE_URL` と `SUPABASE_ANON_KEY` の2つの環境変数を Workers に設定・管理する必要がある
  - 外部サービスのため、Supabase のアカウント管理・プロジェクト管理が追加で必要になる。障害時は Supabase のステータスページと Cloudflare のステータスページの両方を確認する必要がある
  - Free プランでは「非アクティブなプロジェクトは1週間でポーズされる」という仕様があり（2025年時点）、再開操作が運用負荷となりうる（S5 に相当する仮定。プライシング変更のリスクもあり）
- 根拠: GUI の充実度と認証機能の組み込みは運用しやすさに寄与するが、外部サービスとしての管理オーバーヘッド（環境変数・アカウント・ポーズ運用）が個人開発の文脈では摩擦になる
- CSD依存: Supabase Free プランの非アクティブポーズ仕様は変更されうる（Supposition）。改善された場合はこの欠点が消える可能性がある

---

### ALT-3: TiDB Serverless

- 評価: △
- 利点:
  - MySQL 互換のため、MySQL の既存ツール（DBeaver、TablePlus 等）やドライバーが利用可能であり、SQL に慣れた開発者には操作の学習コストが低い
  - Serverless 構成のため、インフラ管理（スケーリング・パッチ適用）は TiDB Cloud 側で自動化されている
  - TiDB Cloud の Web コンソールからスキーマ確認・データ操作が可能
- 欠点:
  - Cloudflare Workers からの接続は HTTP またはプロキシ経由が必要（TCP 直接接続は Workers の制約により不可）。TiDB Serverless の Workers 向け公式接続ドキュメント・ドライバーサポートが D1・Turso に比べて薄く、接続設定のトラブルシューティングが難しい可能性がある
  - Cloudflare Workers との公式統合（Integrations Marketplace）が D1 や Turso のような形では提供されていないため、セットアップ手順が手動で多くなる
  - TiDB は分散 SQL データベースとして本来大規模ワークロード向けに設計されており、数千レコードの個人開発用途に対して管理機能・設定項目が複雑すぎる可能性がある（オーバースペックによる複雑性）
  - エコシステム（ORM サポート・実例・コミュニティ）が Cloudflare Workers 周辺では D1 や Supabase より薄く、問題発生時の情報収集が困難
- 根拠: Cloudflare Workers との統合ドキュメントの薄さと、プラットフォーム公式サポートの不在が運用負荷の観点で最大のリスク。個人開発においてトラブルシューティングに費やす時間は直接的な運用負荷となる
- CSD依存: C1（Workers 互換の接続方式が必要）に関連。Workers からの HTTP 接続が TiDB Serverless で安定して動作するかの確認コストが初期セットアップで必要

---

### ALT-4: Turso (libSQL)

- 評価: ○
- 利点:
  - Cloudflare Integrations Marketplace の公式パートナーであり、Workers との統合が公式にサポートされている（research.md 観点2）。Integrations Marketplace 経由で `LIBSQL_DB_URL` と `LIBSQL_DB_AUTH_TOKEN` の環境変数を自動設定する導線が整備されており、初期セットアップの手順が明示化されている
  - 公式ドキュメント（Cloudflare Workers docs 内の Turso 統合ページ）とチュートリアル（Connect to Turso using Workers）が整備されており、トラブルシューティング時の情報源が確保されている
  - SQLite 互換のため、Drizzle ORM などの主要 ORM が Turso（libSQL）をサポートしており、スキーマ管理・マイグレーションツールが利用可能
  - Turso CLI（`turso db create`・`turso db shell`・`turso db list` 等）により、DB 操作を CLI から実行できる
  - `@libsql/client/web` HTTP ドライバーにより、Workers の TCP 制限を回避した安定した接続が可能（C1 への対応が公式に検証済み）
- 欠点:
  - 外部サービスのため、Cloudflare Workers の管理（wrangler）と Turso の管理（turso CLI・Turso Dashboard）の2つのツールを使い分ける必要がある。認証情報（`LIBSQL_DB_URL`・`LIBSQL_DB_AUTH_TOKEN`）の管理が追加で必要になる点は ALT-1 と比べて運用負荷が高い
  - Cloudflare Integrations Marketplace 経由の初期セットアップは便利だが、Workers の `wrangler.toml` に D1 Binding を追記するだけで完結する ALT-1 と比較すると、設定手順が多い（Turso アカウント作成・DB 作成・Integrations 連携の各ステップが必要）
  - 障害時は Cloudflare のステータスページと Turso のステータスページの両方を確認する必要がある（二重管理）
- 根拠: Cloudflare 公式パートナーとしての統合整備により、TiDB Serverless（ALT-3）と比較してドキュメント・サポートの充実度で明確に上回る。しかし、外部サービスとしての認証情報管理・マルチダッシュボード運用という摩擦は ALT-1（Cloudflare D1）の同一プラットフォーム統合には及ばず、Supabase（ALT-2）と同等の外部サービス管理オーバーヘッドがある
- CSD依存: S5（Turso の無料プランの継続提供）。無料プランが廃止・変更された場合、コスト増大または移行作業という運用負荷が発生する

---

## 比較サマリー（OBJ-4 の観点のみ）

| 代替案 | 評価 | 主な根拠 |
|--------|------|----------|
| ALT-1: Cloudflare D1 | ◎ | 同一プラットフォーム統合により管理対象ゼロ追加。wrangler CLI 一元管理 |
| ALT-2: Supabase | ○ | GUI・認証統合は有利だが、外部サービスとしての管理オーバーヘッドと Free プランのポーズ仕様が欠点 |
| ALT-3: TiDB Serverless | △ | Workers との公式統合が薄く、トラブルシューティングコストが運用負荷として顕在化するリスク |
| ALT-4: Turso (libSQL) | ○ | Cloudflare 公式パートナーとして統合整備済みで ALT-3 を上回るが、外部サービスとしての認証情報管理・マルチダッシュボード運用の摩擦が ALT-1 との差分 |
