# [012/018] searchArticles Server Action + SearchPage + E2Eテスト

**ブロック**: - Task 009（コアUI + E2E）— ArticleCard共通コンポーネント、Playwrightセットアップ

## 目的

全18タスク中の第12タスク。`searchArticles` Server Action（セッション検証・Zodバリデーション・ArticleService.search呼び出し）・`SearchPage`（検索フォーム+結果一覧表示）・E2Eテスト（キーワード検索→該当記事表示）を実装することで、検索機能のエンドツーエンドフローを完成させる。

## 受け入れ基準

- [ ] キーワード入力→タイトルまたはURLに部分一致する記事が未読・既読問わず表示されるE2Eフロー（`pnpm playwright test`）がパスすること
- [ ] `searchArticles` Server Actionが実装されており、キーワードを渡した場合に `ActionResult<Article[]>` が返却されること
- [ ] 空文字のキーワードを渡した場合にバリデーションエラーが返却されること
- [ ] `SearchPage` が `src/app/(app)/search/page.tsx` に配置され、検索フォームと結果一覧が表示されること
- [ ] 検索結果として `ArticleCard` コンポーネントが再利用されていること

## 入力

- `detailed-design.md` §3.1（searchArticles Server Action仕様: 入力スキーマ・出力型・エラーレスポンス）
- `detailed-design.md` §3.3（SearchPageデータ契約: Article[]をAction経由で取得）
- `architecture.md` §5.1（SearchPageの責務: 検索キーワード入力・検索結果一覧表示）
- `architecture.md` §6.2（検索方式: LIKE部分一致・シーケンシャルスキャン）
- `architecture.md` §9.3（バリデーション方針: Zodスキーマ例・空文字チェック等のバリデーションルール）
- `development-process.md` §2.4（E2Eテストファイル配置: `e2e/search.spec.ts`）
