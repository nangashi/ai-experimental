# [004/018] Netlifyデプロイ設定

**ブロック**: - Task 003（Auth.js認証設定）— Google OAuth設定、ALLOWED_EMAIL許可チェック、Auth.js Middleware

## 目的

全18タスク中の第4タスク。Netlify Starterプランへのデプロイ設定（netlify.toml等）・GitHub連携による自動デプロイ・Netlify環境変数の設定・HTTPS確認を行い、認証込みで本番動作可能な状態を確立する。

## 受け入れ基準

- [ ] `netlify.toml` またはNetlifyコンソール設定によりビルドコマンド・公開ディレクトリが正しく設定されており、`git push origin main` でNetlifyに自動デプロイが実行されること
- [ ] Netlifyコンソールの環境変数に `DATABASE_URL`・`ALLOWED_EMAIL`・`GOOGLE_CLIENT_ID`・`GOOGLE_CLIENT_SECRET`・`AUTH_SECRET`・`PING_SECRET` が設定されていること
- [ ] デプロイされたNetlifyのURLにHTTPS経由でアクセス可能であること
- [ ] 認証済みユーザー（ALLOWED_EMAIL一致アカウント）のみHTTPS経由でアプリにアクセスできること
- [ ] Netlifyのインスタントロールバック機能が利用可能な状態であること（デプロイ履歴が確認できること）

## 入力

- `architecture.md` §8.1（デプロイ構成・マイグレーション方針）
- `architecture.md` §8.2（環境設計: 本番環境・開発環境の構成）
- `architecture.md` §8.3（コスト設計: Netlify Starter $0）
- `standards.md` §3.5（確定済み環境変数一覧）
- `development-process.md` §1.4（リリースプロセス: `git push origin main` 自動デプロイ）
- `development-process.md` §3.3（CD戦略・ロールバック手順）
