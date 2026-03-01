# [017/018] gitleaks + lefthook + Dependabot + pg_dumpバックアップ手順

**ブロック**: - Task 002（Next.jsプロジェクト基盤）— プロジェクト構造、README.md

## 目的

全18タスク中の第17タスク。gitleaks設定（.gitleaks.toml）・lefthook設定（pre-commit: Biome check + gitleaks実行）・.github/dependabot.yml設定（npm週次更新）・README.mdへのpg_dumpバックアップ手順追記を実装することで、開発・運用のセキュリティ基盤を確立する。

## 受け入れ基準

- [ ] `git commit` 時にlefthook pre-commit hookが実行され、Biome check（lint/formatチェック）がパスしない場合にcommitが中断されること
- [ ] `git commit` 時にlefthook pre-commit hookでgitleaksが実行され、シークレットが検出された場合にcommitが中断されること
- [ ] `.github/dependabot.yml` が配置されており、npmパッケージの週次更新PRが自動生成される設定になっていること
- [ ] `README.md` に `pg_dump $DATABASE_URL > backup-$(date +%Y%m%d).sql` 形式のバックアップ手順が記載されていること
- [ ] `lefthook.yml` がリポジトリルートに配置されていること

## 入力

- `standards.md` §1.1（Biome設定: lefthookでBiome checkを実行）
- `standards.md` §8（規約の自動強制サマリ: commit時のgitleaks+Biome check）
- `development-process.md` §4.3（データバックアップ: pg_dumpコマンド例・保存先）
- `development-process.md` §4.5（依存関係の脆弱性管理: lefthook pre-commit構成・dependabot.yml設定コード）
- `development-process.md` §6（品質チェック配置サマリ: commit時のBiome lint/format・gitleaks配置方針）
