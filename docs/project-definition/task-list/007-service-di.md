# [007/018] ArticleService + TitleFetcher + DI + Unitテスト

**ブロック**: - Task 006（ArticleRepository + 統合テスト）— IArticleRepositoryインターフェース、ArticleRepository実装、AppError('duplicate')変換

## 目的

全18タスク中の第7タスク。`ITitleFetcher` インターフェース定義・`TitleFetcher` 実装（SSRF対策・3秒タイムアウト）・`ArticleService` の全メソッド実装（コンストラクタ注入・重複チェック・タイトル取得失敗フォールバック）・ファクトリ関数・Unitテスト（DIモック注入）を実装することで、後続のServer Actions・Route Handlerタスクが利用するビジネスロジック層を確立する。

## 受け入れ基準

- [ ] `ArticleService` の全メソッド（save・getUnreadArticles・getReadArticles・getUnreadCount・markAsRead・markAsUnread・deleteArticle・search）のUnitテストが `pnpm vitest run` でパスすること
- [ ] 重複URLを保存しようとした場合に `AppError({ kind: 'duplicate' })` がthrowされるUnitテストがパスすること
- [ ] TitleFetcherがタイムアウト（3秒超過）またはHTTPエラーを発生させた場合、保存が続行され `SaveResult.titleFetchFailed = true` が返却されるUnitテストがパスすること
- [ ] SSRF対策（プライベートIPアドレス範囲・HTTPプロトコル拒否）のUnitテストがパスすること
- [ ] `createArticleService()` ファクトリ関数が `src/lib/services/article-service.ts` からエクスポートされていること
- [ ] `ITitleFetcher` インターフェースが `src/lib/interfaces/title-fetcher.interface.ts` に定義されていること

## 入力

- `detailed-design.md` §2.1（ArticleServiceメソッド一覧・ビジネスルール・saveメソッド処理フロー）
- `detailed-design.md` §2.2（TitleFetcherメソッド仕様・SSRF対策詳細・タイムアウト実装パターン）
- `detailed-design.md` §2.3（DIインターフェース定義: IArticleRepository・ITitleFetcher）
- `detailed-design.md` §2.4（ファクトリ関数: createArticleService）
- `detailed-design.md` §5.2（SaveResult型定義）
- `architecture.md` §5.1（TitleFetcherSSRF対策詳細・失敗時フォールバック動作）
- `architecture.md` §5.3（DI設計方針: コンストラクタ注入）
- `standards.md` §2.2（非同期処理: AbortController + setTimeout タイムアウト実装パターン）
- `development-process.md` §2.6（モック戦略: DIベースのモック注入）
