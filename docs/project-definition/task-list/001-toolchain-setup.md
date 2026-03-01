# [001/018] ツールチェーンセットアップ

**ブロック**: なし

## 目的

全18タスク中の第1タスク。Next.jsプロジェクトのスキャフォールドを生成し、Biome linter/formatter・TypeScript strict・VS Code設定ファイルを配置することで、後続全タスクの開発基盤を整備する。

## 受け入れ基準

- [ ] `create-next-app` によるNext.jsプロジェクトのスキャフォールドが生成されており、ESLint設定ファイルが削除されていること
- [ ] `biome.json` が配置され、`pnpm biome check` が正常実行可能であること
- [ ] `tsconfig.json` に `"strict": true` および `"noUncheckedIndexedAccess": true` が設定され、`tsc --noEmit` がエラーなく通ること
- [ ] `.vscode/settings.json`（Biome拡張有効化・保存時自動フォーマット設定）、`.vscode/extensions.json`（推奨拡張リスト）、`.vscode/launch.json`（Next.jsサーバーサイドデバッグ用設定）が配置されていること
- [ ] `pnpm vitest run` を実行可能な状態であること（テストファイルは空でも可）

## 入力

- `standards.md` §1.1（Biome設定方針: `recommended: true`、`noVar`/`useConst`/`noDangerouslySetInnerHtml`有効化）
- `standards.md` §1.2（TypeScript設定: `strict`・`noUncheckedIndexedAccess`）
- `standards.md` §1.5（インポート順序: Biome `organizeImports` 有効化）
- `development-process.md` §5.1（VS Code設定ファイル構成）
