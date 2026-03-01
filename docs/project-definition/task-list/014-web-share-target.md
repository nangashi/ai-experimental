# [014/018] Web Share Target Route Handler + テスト

**ブロック**: - Task 007（ArticleService + TitleFetcher + DI）— ArticleService（saveメソッド）
- Task 013（PWA manifest + Service Worker）— PWA manifest（share_target設定）

## 目的

全18タスク中の第14タスク。POST /api/share Route Handler（Originヘッダー検証=CSRF対策・セッション検証・Zodバリデーション・ArticleService.save呼び出し・302リダイレクト）・テスト（Originヘッダー不一致で403・正常フローで302リダイレクト）を実装することで、Androidの共有メニューからURLを保存するエンドツーエンドのフローを完成させる。

## 受け入れ基準

- [ ] Originヘッダーが `process.env.URL`（Netlifyデプロイドメイン）と一致しないリクエストに対して `403 Forbidden` が返却されること
- [ ] 正常な共有リクエスト（Originヘッダー一致・認証済み・有効なURL）に対して記事が保存され、`302 Redirect → /` が返却されること
- [ ] バリデーションエラー（無効なURL形式）の場合に `302 Redirect → /?error=invalid_url` が返却されること
- [ ] 重複URLの場合に `302 Redirect → /?error=duplicate` が返却されること
- [ ] `src/app/api/share/route.ts` が配置されており、POSTメソッドのRoute Handlerが実装されていること

## 入力

- `detailed-design.md` §3.2（POST /api/share Route Handler仕様: リクエスト・レスポンス・認証・CSRF・処理フロー）
- `architecture.md` §7.2（CSRF保護: Route HandlerのOriginヘッダー検証方式）
- `standards.md` §4.2（CSRF対策: WebShareTargetHandlerのCSRF実装パターンコード）
- `standards.md` §3.5（確定済み環境変数一覧: `URL` 環境変数=Netlifyデプロイドメイン）
- `development-process.md` §2.1（テスト投資配分: Route HandlerはE2Eまたは統合テスト）
