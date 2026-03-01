# [008/018] 記事保存・一覧取得 Server Actions

**ブロック**: - Task 007（ArticleService + TitleFetcher + DI）— ArticleService実装、ITitleFetcher、createArticleServiceファクトリ関数

## 目的

全18タスク中の第8タスク。`saveArticle` Server Action（セッション検証・Zodバリデーション・ArticleService.save呼び出し・ActionResult返却・revalidatePath）および未読一覧取得ロジック・Zodスキーマ定義（articleUrlSchema・articleIdSchema・searchKeywordSchema）を実装することで、後続のコアUI（Task 9）が利用するデータ操作エンドポイントを確立する。

## 受け入れ基準

- [ ] `saveArticle` Server Actionが実装されており、セッション検証・Zodバリデーション・ArticleService.save呼び出し・ActionResult返却の処理フローが `detailed-design.md` §3.1 に準拠していること
- [ ] 無効なURL形式（URL形式不正・空文字）に対して `{ success: false, error: '...' }` を返却し、重複URLに対して `{ success: false, error: 'この URL は既に保存されています' }` を返却するエラーハンドリングが実装されていること
- [ ] タイトル取得失敗時に `{ success: true, data: { article, titleFetchFailed: true } }` を返却するフォールバック処理が実装されていること
- [ ] `articleUrlSchema`・`articleIdSchema`・`searchKeywordSchema` のZodスキーマ定義がエクスポートされていること
- [ ] `getUnreadArticles` および `getUnreadCount` のデータ取得ロジックが実装されていること
- [ ] `saveArticle` Server Action内で書き込み操作後に `revalidatePath('/')` と `revalidatePath('/search')` の両パスが実行されること

> **検証方針**: Server Actionsの動作確認はTask 009 E2Eテストで実施する（`development-process.md` §2.1 方針）。本タスクでは実装の完了とコードレビューで受け入れを判定する。

## 入力

- `detailed-design.md` §3.1（saveArticle Server Action仕様: 入力スキーマ・出力型・エラーレスポンス・関連SR）
- `detailed-design.md` §2.1（ArticleServiceメソッド一覧: getUnreadArticles・getUnreadCountの引数・戻り値・エラーケース）
- `detailed-design.md` §3.3（Server Componentデータ契約: ArticleListPageのデータ入力=articles・unreadCount、ソースServiceメソッド=getUnreadArticles・getUnreadCount）
- `detailed-design.md` §5.2（ActionResult型・SaveResult型・SaveArticleResult型）
- `architecture.md` §9.1（Server Actionsの標準返却型・エラーハンドリング方針）
- `architecture.md` §9.2（キャッシュ戦略: revalidatePath('/')・revalidatePath('/search')の両パス実行タイミング）
- `architecture.md` §9.3（バリデーション方針: Zodスキーマ例）
- `standards.md` §2.1（各層のエラー処理パターン・Server Actionsでのエラー返却例）
- `standards.md` §5.2（Zodスキーマ命名規則: camelCase + Schemaサフィックス）
