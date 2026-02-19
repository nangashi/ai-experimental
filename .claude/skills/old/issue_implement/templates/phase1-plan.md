以下の手順で実装ステップ計画を作成してください:

## 手順

### 1. 設計の把握

{design_path} を Read で読み込み、以下を把握する:
- 概要
- コンポーネント構成
- 処理フロー
- **実装ステップ**（このセクションが計画の主な入力）
- テスト戦略

### 2. プロジェクトツーリングの検出

以下のファイルを Glob/Read で探索し、プロジェクトのツーリングを特定する:

1. **テストコマンド**:
   - `package.json` の `scripts.test` → `npm test` / `yarn test`
   - `pyproject.toml` / `setup.cfg` → `pytest`
   - `Makefile` の `test` ターゲット → `make test`
   - `Cargo.toml` → `cargo test`
   - `go.mod` → `go test ./...`
   - 検出できない場合は「なし」

2. **lint コマンド**:
   - `package.json` の `scripts.lint` → `npm run lint`
   - `pyproject.toml` の `[tool.ruff]` → `ruff check --fix .`
   - `.eslintrc*` → `npx eslint --fix .`
   - 検出できない場合は「なし」

3. **format コマンド**:
   - `package.json` の `scripts.format` → `npm run format`
   - `pyproject.toml` の `[tool.ruff.format]` / `[tool.black]` → `ruff format .` / `black .`
   - `.prettierrc*` → `npx prettier --write .`
   - 検出できない場合は「なし」

### 3. 実装ステップの抽出

design.md の「実装ステップ」セクションからステップを抽出し、各ステップについて以下を整理する:

- **ステップ名**: 端的な名称
- **変更対象ファイル**: 新規作成 or 修正、ファイルパス
- **変更内容**: 具体的に何を実装するか
- **テスト方針**: 新規テスト追加 / 既存テスト修正 / テスト不要

ステップの順序は design.md の順序を尊重する。依存関係がある場合は、依存先を先に実装する。

### 4. 実装計画の保存

{plan_save_path} に Write で保存する:

```markdown
# 実装計画: #{issue_number} {issue_title}

## ツーリング

- test: {テストコマンド or なし}
- lint: {lintコマンド or なし}
- format: {formatコマンド or なし}

## ステップ

### Step 1: {ステップ名}

- ファイル: {変更対象ファイルリスト（新規/修正を明記）}
- 内容: {変更内容の詳細}
- テスト: {テスト方針}

### Step 2: {ステップ名}

- ファイル: {変更対象ファイルリスト}
- 内容: {変更内容の詳細}
- テスト: {テスト方針}

（以降、ステップ数分繰り返す）
```

### 5. 返答

以下のフォーマットで返答する:

```
result: success
total_steps: {ステップ数}
test_command: {テストコマンド or なし}
lint_command: {lintコマンド or なし}
format_command: {formatコマンド or なし}
summary: {計画の1行サマリ}
```
