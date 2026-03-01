# [003/018] Auth.js認証設定

**ブロック**: - Task 002（Next.jsプロジェクト基盤）— ディレクトリ構造、Tailwind CSS + shadcn/ui、パスエイリアス設定

## 目的

全18タスク中の第3タスク。Auth.js + Google OAuthによるシングルユーザー認証、ALLOWED_EMAILによるアクセス制限、Auth.js Middlewareによる全ページ保護、認証関連ページ（ログイン画面）を実装することで、後続の全機能タスクの認証基盤を確立する。

## 受け入れ基準

- [ ] Google OAuthによるログインフローが動作し、認証成功後にアプリ画面（`/`）へリダイレクトされること
- [ ] 環境変数 `ALLOWED_EMAIL` と一致しないGoogleアカウントでのサインイン試行が拒否されること（`callbacks.signIn` での照合）
- [ ] 未認証状態で `/`・`/search` 等の保護されたページへアクセスした場合、ログインページへリダイレクトされること
- [ ] `src/middleware.ts` が配置され、Auth.js Middlewareによる認証ガードが機能していること
- [ ] `/api/ping` が `middleware.ts` の認証対象外（matcher設定または条件分岐）になっていること
- [ ] 認証失敗時に `events.signInFailure` コールバックで `console.error` ログが出力されること

## 入力

- `architecture.md` §7.1（認証フロー・シングルユーザー許可チェック設計）
- `architecture.md` §7.2（アクセス制御方針・middleware除外パス設計）
- `detailed-design.md` §3.1（Server Action共通処理フロー: セッション検証）
- `standards.md` §4.2（CSRF対策方針）
- `standards.md` §3.5（確定済み環境変数: `ALLOWED_EMAIL`・`GOOGLE_CLIENT_ID`・`GOOGLE_CLIENT_SECRET`・`AUTH_SECRET`）
- `development-process.md` §4.4（シークレット管理方針）
