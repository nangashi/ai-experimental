# [006/018] ArticleRepository + 統合テスト

**ブロック**: - Task 005（DB接続 + スキーマ）— DB接続設定、articlesテーブルスキーマ、Article型・AppError型定義

## 目的

全18タスク中の第6タスク。`IArticleRepository` インターフェース定義・`ArticleRepository` の全CRUDメソッド実装（create・findByUrl・findByStatus・countByStatus・updateStatus・deleteById・search）・PostgreSQLエラーコード23505のAppError変換・Vitestセットアップ・統合テスト（実DB使用）を実装することで、後続のService層タスクが利用するデータアクセス基盤を確立する。

## 受け入れ基準

- [ ] `IArticleRepository` インターフェースが `src/lib/interfaces/article-repository.interface.ts` に定義されていること
- [ ] `ArticleRepository` の全メソッド（create・findByUrl・findByStatus・countByStatus・updateStatus・deleteById・search）の統合テストが `pnpm vitest run` でパスすること
- [ ] UNIQUE制約違反（PostgreSQLエラーコード `23505`）発生時に `AppError({ kind: 'duplicate' })` が返却される統合テストがパスすること
- [ ] `vitest.config.ts` が配置され、テスト用DB接続設定が整備されていること
- [ ] `findByStatus('unread')` が `saved_at` 降順で結果を返すこと（インデックス活用）

## 入力

- `detailed-design.md` §2.3（IArticleRepositoryインターフェース定義・全メソッドシグネチャ）
- `detailed-design.md` §5.1（Article型定義）
- `detailed-design.md` §5.4（AppError型・kind: 'duplicate'変換仕様）
- `architecture.md` §5.3（テスト設計方針: 統合テストは実DB使用）
- `architecture.md` §9.1（重複チェックの二段構え設計: PostgreSQL23505変換）
- `standards.md` §5.4（トランザクション管理: UNIQUE制約最終保証）
- `development-process.md` §2.2（テストフレームワーク: Vitest）
- `development-process.md` §2.4（テストファイル配置: colocate方式）
- `development-process.md` §2.5（テストデータ管理: インラインファクトリー関数方式）
