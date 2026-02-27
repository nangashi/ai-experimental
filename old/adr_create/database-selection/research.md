# リサーチ結果

## 調査日
2026-02-19

## 調査観点

決定ステートメント（Cloudflare Workers + Hono + TypeScript バックエンドのデータベース選定）から、時間経過で変化しうる事実として以下の観点を特定した。

1. Cloudflare D1 の GA ステータス・料金体系・制限値（進化が速い新サービスのため）
2. Turso (libSQL) の Cloudflare Workers 対応状況・料金体系
3. Cloudflare Workers 向け ORM/ドライバーのエコシステム（Drizzle ORM 等の対応状況）
4. Cloudflare D1 のフルテキスト検索（FTS）対応状況（スコープに「キーワード検索」が含まれるため）
5. Turso の無料枠・プランの最新状況

---

## 調査結果

### 観点1: Cloudflare D1 の GA ステータス・料金・制限値

- 検索クエリ: `Cloudflare D1 database pricing limits GA 2025 2026`
- 主要な知見:
  - D1 は一般提供（GA）済みで、プロダクション利用可能な状態にある
  - 課金はロウ読み取り数・ロウ書き込み数ベース。データ転送（egress）料金はなし
  - **Free プラン**: データベースサイズ上限 500 MB/DB、最大 10 DB/アカウント
  - **Paid プラン**: データベースサイズ上限 10 GB/DB（旧 2GB から拡大）、最大 50,000 DB/アカウント
  - 無料枠の上限超過時にエラーが返るようになったのは 2025-02-10 から（それ以前は超過しても無制限に動作していた）
- 出典: [Cloudflare D1 Pricing](https://developers.cloudflare.com/d1/platform/pricing/), [Cloudflare D1 Limits](https://developers.cloudflare.com/d1/platform/limits/)

### 観点2: Turso (libSQL) の Cloudflare Workers 対応状況

- 検索クエリ: `Turso libSQL Cloudflare Workers integration 2025`
- 主要な知見:
  - Turso は Cloudflare Integrations Marketplace の公式パートナーであり、Workers との統合が公式にサポートされている
  - `@libsql/client/web` を使うことで Workers（TCP 接続不可環境）でも動作する HTTP ベースのドライバーが提供されている
  - Turso はグローバルにレプリカを配置し、Workers が起動した場所に最も近いレプリカへ自動ルーティングされる
  - 接続には `LIBSQL_DB_URL`（接続文字列）と `LIBSQL_DB_AUTH_TOKEN`（認証トークン）の2つの環境変数が必要
  - Cloudflare Integrations Marketplace 経由で認証情報の自動設定が可能
- 出典: [Turso · Cloudflare Workers docs](https://developers.cloudflare.com/workers/databases/third-party-integrations/turso/), [Connect to Turso using Workers](https://developers.cloudflare.com/workers/tutorials/connect-to-turso-using-workers/)

### 観点3: Cloudflare Workers 向け ORM・クエリビルダーのエコシステム

- 検索クエリ: `Cloudflare Workers database options Drizzle ORM D1 2025`
- 主要な知見:
  - **Drizzle ORM**: Cloudflare D1 を公式サポート。TypeScript の型定義から D1 スキーマを自動生成できる。Cloudflare Workers 環境でのセットアップ事例が多数存在する
  - **Prisma ORM**: Cloudflare D1 および Workers への接続を公式サポート
  - **Kysely**: TypeScript セーフなクエリビルダーとして Workers 環境で利用可能
  - D1 は Cloudflare Workers エコシステムのステートフルバックエンドとして第一級サポートを受けており、ORM 周辺のエコシステムが整備されている
  - Drizzle + D1 + Hono + Workers の組み合わせは実際のプロジェクトで採用実績あり
- 出典: [Drizzle ORM - Cloudflare D1](https://orm.drizzle.team/docs/connect-cloudflare-d1), [Setting up D1 with Drizzle in Hono Cloudflare Worker](https://www.firdausng.com/posts/setup-d1-cloudflare-worker-with-drizzle)

### 観点4: Cloudflare D1 のフルテキスト検索（FTS）対応

- 検索クエリ: `Cloudflare D1 full-text search FTS SQLite 2025`
- 主要な知見:
  - D1 は SQLite の **FTS5 モジュール**（仮想テーブルを含む）をサポートしている
  - FTS5 によるキーワード検索は、Worker と D1 が同一リージョンにある場合に低レイテンシで動作することが確認されている
  - **制限事項**: 仮想テーブルを含むデータベースはエクスポート（`wrangler d1 export`）が非サポート。バックアップ・リストアの際に仮想テーブルのみ別途再作成が必要
  - ベクトル検索は D1 ではネイティブ非サポート（今回のスコープ外）
- 出典: [SQL statements · Cloudflare D1 docs](https://developers.cloudflare.com/d1/sql-api/sql-statements/), [D1 Support for Virtual Tables - Cloudflare Community](https://community.cloudflare.com/t/d1-support-for-virtual-tables/607277)

### 観点5: Turso の無料枠・プランの最新状況

- 検索クエリ: `Turso pricing free tier limits 2025 2026`
- 主要な知見:
  - **無料プラン（2025年3月時点）**: ロウ読み取り 5億回/月、ロウ書き込み 1,000万回/月、ストレージ 5 GB、最大 100 DB/アカウント。クレジットカード不要
  - **Developer プラン（有料、約$4.99/月）**: ロウ読み取り 25億回/月、ロウ書き込み 2,500万回/月、ストレージ 9 GB、月間アクティブ DB 上限 500（アカウント内DB数は無制限）
  - Turso は「Unlimited Databases」を段階的に解放しており、有料プランでは DB 数の上限撤廃が進んでいる
- 出典: [Turso Database Pricing](https://turso.tech/pricing), [Turso Cloud Debuts the New Developer Plan](https://turso.tech/blog/turso-cloud-debuts-the-new-developer-plan)

---

## サマリー

この決定に特に影響する主要な事実:

1. **D1 は GA 済みでプロダクション利用可能**。Free プランでは 500 MB/DB・10 DB 上限があるが、数千レコードのリーディングリスト管理には十分な容量。Paid プランへの移行で 10 GB まで拡張可能。

2. **D1 は FTS5 をサポートしているが、FTS5 仮想テーブルを含むデータベースのエクスポートは非サポート**。スコープに「バックアップ・リストア対応」が含まれるため、D1 を選択する場合にはこの制約への対応（仮想テーブル再作成手順の整備）が必要。

3. **Drizzle ORM + D1 + Hono + Cloudflare Workers の組み合わせは実績があり、エコシステムが成熟している**。TypeScript との親和性も高い。

4. **Turso は Cloudflare Workers との公式統合が整備されており、HTTP ドライバーで TCP 制限なく動作可能**。無料枠も十分広い（5 GB、5億ロウ読み取り/月）。ただし外部サービスへの依存が生じる。

5. **Cloudflare KV は今回の用途（SQL 的なクエリ、キーワード検索）には構造的に不向き**（KV はキーによる単一取得に特化した設計であり、SQLite 系の選択肢と比較して検索機能が著しく限定される）。
