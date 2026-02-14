# 改善計画: agent_audit_new

## 変更対象ファイル
| # | ファイル | 変更種別 | 変更概要 | 対応フィードバック |
|---|---------|---------|---------|------------------|
| 1 | templates/phase1-dimension-analysis.md | 修正 | パス変数セクションに `{dim_path}` を追加 | C-1, I-5 |
| 2 | SKILL.md | 修正 | Grep パターン、返答解析、検証項目、エラーハンドリングの修正 | C-2, I-1, I-2, I-3, I-6, I-7, I-8, I-9 |
| 3 | group-classification.md | 削除推奨 | SKILL.md に統合済みで冗長 | I-4 |

## 各ファイルの変更詳細

### 1. templates/phase1-dimension-analysis.md（修正）
**対応フィードバック**:
- C-1: 未定義変数参照 [stability]
- I-5: Phase 1 サブエージェントプロンプトの不完全な外部化 [architecture]

**変更内容**:
- パス変数セクション（5-9行目）: `{antipattern_catalog_path}` の次に `{dim_path}` を追加
  - 現在の記述:
    ```
    ## パス変数
    - `{agent_path}`: 分析対象のエージェント定義ファイルの絶対パス
    - `{agent_name}`: エージェント名（`.agent_audit/{agent_name}/` ディレクトリで使用）
    - `{findings_save_path}`: 分析結果を保存する findings ファイルの絶対パス
    - `{antipattern_catalog_path}`: この次元のアンチパターンカタログの絶対パス
    ```
  - 改善後の記述:
    ```
    ## パス変数
    - `{agent_path}`: 分析対象のエージェント定義ファイルの絶対パス
    - `{agent_name}`: エージェント名（`.agent_audit/{agent_name}/` ディレクトリで使用）
    - `{dim_path}`: 分析次元エージェント定義ファイルの絶対パス
    - `{findings_save_path}`: 分析結果を保存する findings ファイルの絶対パス
    - `{antipattern_catalog_path}`: この次元のアンチパターンカタログの絶対パス
    ```

### 2. SKILL.md（修正）
**対応フィードバック**:
- C-2: findings ファイル集計の Grep パターン誤り [stability]
- I-1: Phase 1 サブエージェント返答解析の冗長性 [efficiency]
- I-2: サマリヘッダ抽出の曖昧性 [stability]
- I-3: apply-improvements 返答の解析可能性 [stability]
- I-6: Phase 2 Step 2a: Per-item承認のテキスト出力量 [efficiency]
- I-7: Phase 2 Step 3 成果物構造検証の欠落 [architecture]
- I-8: Phase 1 サブエージェント返答フォーマット検証の欠落 [effectiveness]
- I-9: Phase 1 部分失敗時の続行判定の曖昧性 [stability]

**変更内容**:

- 203-205行目（Grep パターン修正）:
  - 現在: `grep -c "^\### .* \[severity: critical\]" {findings_path}`
  - 改善後: `grep -c "^### .* \[severity: critical\]" {findings_path}`
  - 理由: バックスラッシュが不要（`###` は正規表現メタ文字ではない）

- 202-206行目（findings 件数集計方法の全面改訂）:
  - 現在: Grep での個別抽出（27-45コール）による集計
  - 改善後: サマリヘッダ + 先頭10行Readによる集計
  - 追加記述:
    ```
    件数の集計方法: 各 findings ファイルの先頭10行を Read（`limit: 10`）でサマリヘッダを取得し、`Total: {N} (critical: {C}, improvement: {I}, info: {K})` パターンで解析する。サマリヘッダが存在しない場合は、findings ファイル全体を Read し、`grep -c "^### .* \[severity: {level}\]"` パターンで各 severity 件数を取得する。
    ```

- 221行目（サマリヘッダ抽出方法の明示）:
  - 現在: 「サマリヘッダ（`Total: {N} (critical: {C}, improvement: {I}, info: {K})`）を抽出する」
  - 改善後: 「サマリヘッダ（`Total: {N} (critical: {C}, improvement: {I}, info: {K})`）を正規表現 `Total: (\d+) \(critical: (\d+), improvement: (\d+), info: (\d+)\)` で抽出する」

- 193行目（部分失敗時の続行判定明示化）:
  - 現在: 「部分失敗（一部成功）の場合: 「⚠ 一部の次元が失敗しました: {失敗次元リスト}。成功した次元で続行します。」と警告出力し、Phase 2 へ進む。」
  - 改善後: 「部分失敗（成功数 > 0 かつ 失敗数 > 0）の場合: 「⚠ 一部の次元が失敗しました: {失敗次元リスト}。成功した次元で続行します。」と警告出力し、Phase 2 へ進む。」

- 188-193行目（Phase 1 エラーハンドリング改訂）:
  - 追加: サブエージェント返答が `error: {概要}` の場合、エラー概要を抽出して失敗次元リストに含める記述
  - 現在記述の後に追加:
    ```
    各サブエージェント返答を解析し、`saved: {path}` パターンならば成功、`error: {概要}` パターンならば失敗とする。失敗時はエラー概要を抽出し、失敗次元リスト表示時に「{次元名} (理由: {エラー概要})」と出力する。
    ```

- 242-252行目（Per-item 承認のテキスト出力削減）:
  - 現在: findings 全文（description, evidence, recommendation）を表示
  - 改善後: ID/severity/title のみ表示し、詳細は Read 参照に変更
  - 改訂記述:
    ```
    各 finding に対して以下をテキスト出力する:
    ```
    ### [{N}/{total}] {ID}: {title} ({severity})
    次元: {次元名}

    詳細は {findings_path} の該当セクションを参照してください。
    ---
    ```

    続けて `AskUserQuestion` で方針確認（選択肢は以下の4つ）:
    ```

- 300行目（apply-improvements 返答の解析方法明示）:
  - 現在: 「サブエージェント完了後、返答内容（変更サマリ）をテキスト出力する。」
  - 改善後: 「サブエージェント完了後、返答内容（`modified: N件`, `skipped: K件`, 詳細リスト）を変数 `improvement_summary` に記録し、そのままテキスト出力する。この内容は Phase 3 でも再利用する。」

- 308-313行目（構造検証の拡充）:
  - 現在: frontmatter と description フィールドのみ検証
  - 改善後: エージェント定義の必須セクション全体を検証
  - 追加検証項目:
    ```
    1. **構造検証**: Grep で `{agent_path}` の構造を検証する:
       - YAML frontmatter の存在: `grep -q "^---" {agent_path}` でファイル先頭の `---` を確認
       - description フィールドの存在: `grep -q "description:" {agent_path}` を確認
       - 主要セクションの存在（エージェントグループ依存）:
         - evaluator系: `grep -q "^## 検出戦略" {agent_path}`, `grep -q "^## 評価基準" {agent_path}` を確認
         - producer系: `grep -q "^## 手順" {agent_path}` または `grep -q "^## ワークフロー" {agent_path}` を確認
    ```

### 3. group-classification.md（削除推奨）
**対応フィードバック**: I-4: group-classification.md の統合不完全 [architecture]

**変更内容**:
- ファイル全体を削除
- 理由: SKILL.md の 30-60行目に全内容が統合済みで、独立ファイルとして保持する必要がない

## 新規作成ファイル
なし

## 削除推奨ファイル
| ファイル | 理由 | 対応フィードバック |
|---------|------|------------------|
| group-classification.md | SKILL.md に統合済みで冗長 | I-4 |

## 実装順序
1. **templates/phase1-dimension-analysis.md** を修正（パス変数追加）
   - 理由: SKILL.md の Phase 1 サブエージェント呼び出しで参照されるため、先に修正して整合性を確保する
2. **SKILL.md** を修正（Grep パターン、返答解析、検証項目、エラーハンドリングの修正）
   - 理由: テンプレート修正後にワークフロー本体を修正することで、依存関係が明確になる
3. **group-classification.md** を削除
   - 理由: SKILL.md の修正後に不要ファイルを削除することで、変更が完全に適用されたことを確認できる

## 注意事項
- C-3（agent_bench サブディレクトリの分離）は別スキルの構造変更が必要であり、本改善計画のスコープ外とする
- SKILL.md の Phase 1 サブエージェント呼び出し時に `{dim_path}` パス変数を渡している箇所（162行目付近）が、templates/phase1-dimension-analysis.md のパス変数リストと整合していることを確認する
- Per-item 承認のテキスト出力削減により、ユーザーは findings ファイルを直接参照する必要があるため、findings ファイルパスを明示的に表示する
- 構造検証の拡充により、エージェントグループ判定結果（Phase 0 で取得）を Phase 2 Step 3 で参照する必要がある
