# [002/018] Next.jsプロジェクト基盤 + ドキュメント

**ブロック**: - Task 001（ツールチェーンセットアップ）— biome.json、tsconfig.json strict設定、.vscode/* 設定ファイル

## 目的

全18タスク中の第2タスク。architecture.md §5.4に従いディレクトリ構造を整備し、Tailwind CSS + shadcn/ui初期化・パスエイリアス設定・プロジェクトドキュメント（README.md・CLAUDE.md・.env.example）を配置することで、後続全機能タスクのコード配置基盤を確立する。

## 受け入れ基準

- [ ] `src/app/`・`src/lib/`・`src/components/` のディレクトリ構造が `architecture.md` §5.4 の定義に準拠して整備されていること
- [ ] `tsconfig.json` に `"@/*": ["./src/*"]` パスエイリアスが設定されており、`@/` インポートが機能すること
- [ ] Tailwind CSS + shadcn/ui が初期化されており、shadcn/uiのコンポーネントを追加インストール可能な状態であること
- [ ] `pnpm dev` でNext.jsが正常起動し、ブラウザからアクセス可能であること
- [ ] `README.md`・`CLAUDE.md`・`.env.example` がリポジトリルートに配置されていること
- [ ] `.gitignore` に `.env.local` が含まれていること

## 入力

- `architecture.md` §5.4（ディレクトリ構造・ファイル配置ポリシー・命名規則）
- `standards.md` §3.2（ディレクトリ構成詳細・役割テーブル）
- `standards.md` §3.5（環境変数一覧: `.env.example` の記載内容）
- `standards.md` §3.6（`@/` エイリアスパス設定）
- `development-process.md` §5.4（ドキュメント戦略: README.md・CLAUDE.md・.env.example の記載内容）
