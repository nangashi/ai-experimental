# [010/018] 既読化・未読戻し・削除 Server Actions + 既読一覧取得

**ブロック**: - Task 007（ArticleService + TitleFetcher + DI）— ArticleService実装（markAsRead/markAsUnread/deleteArticle/getReadArticlesメソッド）

## 目的

全18タスク中の第10タスク。`markAsRead`・`markAsUnread`・`deleteArticle` Server Actions（セッション検証・Zodバリデーション・ArticleService呼び出し・revalidatePath）および `getReadArticles` 用のデータ取得ロジックを実装することで、後続の記事状態管理UI（Task 11）が利用する操作エンドポイントを確立する。

## 受け入れ基準

- [ ] `markAsRead`・`markAsUnread`・`deleteArticle` Server Actionが実装されており、セッション検証・Zodバリデーション（articleIdSchema）・ArticleService呼び出し・ActionResult返却の処理フローが `detailed-design.md` §3.1 に準拠していること
- [ ] 各Server Actionでシステムエラー時に `{ success: false, error: '操作に失敗しました' }` を返却するエラーハンドリングが実装されていること
- [ ] 書き込み操作後に `revalidatePath('/')` と `revalidatePath('/search')` の両パスが実行されること
- [ ] `getReadArticles` データ取得ロジックが実装されていること

> **検証方針**: Server Actionsの動作確認はTask 011 E2Eテストで実施する（`development-process.md` §2.1 方針）。本タスクでは実装の完了とコードレビューで受け入れを判定する。

## 入力

- `detailed-design.md` §3.1（markAsRead・markAsUnread・deleteArticle Server Action仕様: 入力スキーマ・出力型・エラーレスポンス）
- `detailed-design.md` §6.2（状態遷移マトリクス: unread→read・read→unread のガード条件・副作用）
- `architecture.md` §9.2（キャッシュ戦略: revalidatePath実施タイミング・対象パス）
- `standards.md` §2.1（各層のエラー処理パターン: Handler層はtry-catchでActionResultに変換しreturn）
- `development-process.md` §2.1（テスト投資配分: Server ActionsのテストはE2Eに委ねる）
