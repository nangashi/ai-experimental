# [005/018] DB接続 + スキーマ + マイグレーション

**ブロック**: - Task 002（Next.jsプロジェクト基盤）— ディレクトリ構造、パスエイリアス設定

## 目的

全18タスク中の第5タスク。Neon PostgreSQLへの接続設定（Drizzle ORM + Neon Serverless Driver）・articlesテーブルスキーマ定義・インデックス定義・初回マイグレーション適用・共通型定義を実装することで、後続のRepository・Service・Handler各タスクのデータ層基盤を確立する。

## 受け入れ基準

- [ ] `src/lib/db/schema.ts` に `statusEnum`（`'unread'`, `'read'`）と `articles` テーブル（id・url・title・status・saved_at・read_at）が定義されていること
- [ ] `idx_articles_status_saved_at` 複合インデックス（status, saved_at）が定義されていること
- [ ] `pnpm drizzle-kit migrate` が成功し、Neon上に `articles` テーブルと `status` ENUM型が作成されていること
- [ ] DB接続タイムアウト（`connectionTimeoutMillis: 5000`）が設定されていること
- [ ] `src/lib/types.ts` に `Article` 型・`ActionResult` 型が、`src/lib/errors.ts` に `AppError` 型が定義されエクスポートされていること

## 入力

- `detailed-design.md` §1.2（articlesテーブル定義・Drizzle ORMスキーマ定義コード）
- `detailed-design.md` §1.3（Enum定義: status）
- `detailed-design.md` §1.4（インデックス定義）
- `detailed-design.md` §1.5（マイグレーション計画・実行順序）
- `detailed-design.md` §5.1（Article型定義）
- `detailed-design.md` §5.2（ActionResult型定義）
- `detailed-design.md` §5.4（AppError型定義）
- `architecture.md` §9.5（Neonコールドスタート対策: connectionTimeoutMillis設定）
- `standards.md` §5.1（スキーマ設計: pgEnum・UUID・UNIQUE制約・命名規約）
