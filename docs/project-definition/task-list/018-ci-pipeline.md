# [018/018] GitHub Actions CIパイプライン

**ブロック**: - Task 009（コアUI + E2E）— Playwrightセットアップ（E2Eテスト基盤）、Vitest統合テスト（Task 006経由で間接的に前提）

## 目的

全18タスク中の第18タスク。`.github/workflows/ci.yml` を作成し、Stage 1（Fast: Biome lint/format check・TypeScript type check・Unit tests・gitleaks・pnpm audit）→ Stage 2（Heavy: Integration tests + 実DB・E2E tests・Build verification）の2ステージCI品質ゲートを構築することで、mainブランチへのpush時に全品質チェックが自動実行される状態を確立する。

## 受け入れ基準

- [ ] GitHubへのpush時にGitHub Actions CI（`.github/workflows/ci.yml`）が自動実行されること
- [ ] Stage 1（Fast）ジョブ（Biome lint/format check・TypeScript type check・Unit tests・gitleaks・pnpm audit）が全push時に実行され、いずれかの失敗でパイプラインが停止すること
- [ ] Stage 2（Heavy）ジョブ（Integration tests・E2E tests・Build verification）がStage 1成功後に実行されること
- [ ] Stage 2のIntegration tests・E2E testsでNeon接続に必要な環境変数（`DATABASE_URL`等）がGitHub Actions Secretsから注入されること
- [ ] CIの実行結果（パス・失敗・テストレポート）がGitHub ActionsのUI上で確認できること

## 入力

- `development-process.md` §2.8（CIでのテスト実行戦略: Stage 1・Stage 2の構成・実行コマンド）
- `development-process.md` §3.2（CIパイプライン構成: ジョブ一覧・トリガー・コマンド詳細）
- `development-process.md` §3.6（シークレット管理: GitHub Actions Secretsによる環境変数注入）
- `standards.md` §8（規約の自動強制サマリ: CIでの全チェック配置）
