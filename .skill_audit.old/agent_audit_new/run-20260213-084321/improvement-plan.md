# 改善計画: agent_audit_new

## 変更対象ファイル
| # | ファイル | 変更種別 | 変更概要 | 対応フィードバック |
|---|---------|---------|---------|------------------|
| 1 | templates/apply-improvements.md | 修正 | パス変数セクションの追加 | C-1 |
| 2 | SKILL.md | 修正 | Phase 0-2の複数箇所の改善（既存ディレクトリ処理、バックアップ失敗処理、検証詳細化、エラーメッセージ改善等） | C-2, C-3, C-4, C-5, I-1, I-2, I-3, I-4, I-5, I-6, I-7, I-8, I-9 |

## 各ファイルの変更詳細

### 1. templates/apply-improvements.md（修正）
**対応フィードバック**: C-1: 参照整合性: テンプレート内のパス変数が未定義

**変更内容**:
- ファイル先頭: パス変数セクションが存在しない → パス変数セクションを追加
  ```markdown
  ## パス変数
  - `{agent_path}`: エージェント定義ファイルの絶対パス（変更対象）
  - `{approved_findings_path}`: 承認済みfindings（`.agent_audit/{agent_name}/audit-approved.md`）の絶対パス
  ```

### 2. SKILL.md（修正）
**対応フィードバック**: C-2, C-3, C-4, C-5, I-1, I-2, I-3, I-4, I-5, I-6, I-7, I-8, I-9

**変更内容**:

#### 変更箇所1: Phase 0 Step 6（行94）- 既存ディレクトリ処理の明確化 [C-2]
- 現在の記述: 「既存ディレクトリが存在する場合はそのまま使用する。既存ファイルは上書きせず、各Phaseで必要に応じて新規作成または更新する」
- 改善後の記述: 以下の詳細説明を追加
  ```markdown
  既存ディレクトリが存在する場合はそのまま使用する。既存ファイルの扱い:
  - Phase 1生成ファイル（`audit-{ID_PREFIX}.md`）: Write で上書きする
  - Phase 2生成ファイル（`audit-approved.md`, `verification.md`）: Write で上書きする
  - バックアップファイル（`{agent_path}.backup-*`）: 既存ファイルがあれば再利用、なければ新規作成
  ```

#### 変更箇所2: Phase 0 Step 4（行75）- group-classification.md 不在時エラーメッセージの改善 [I-2]
- 現在の記述: 「`group-classification.md` が存在しない場合はエラー出力して終了する」
- 改善後の記述:
  ```markdown
  `group-classification.md` が存在しない場合は以下のエラーを出力して終了する:
  「✗ グループ分類基準ファイルが見つかりません: .claude/skills/agent_audit_new/group-classification.md
  このファイルはスキルの必須コンポーネントです。スキルディレクトリの整合性を確認してください。」
  ```

#### 変更箇所3: Phase 0 Step 2（行68）- agent_path 読み込み失敗時エラーメッセージの改善 [I-3]
- 現在の記述: 「読み込み失敗時はエラー出力して終了」
- 改善後の記述:
  ```markdown
  読み込み失敗時は Read ツールのエラーメッセージを含めて出力し、終了する:
  「✗ エージェント定義ファイルの読み込みに失敗しました: {agent_path}
  エラー詳細: {Read ツールのエラーメッセージ}」
  ```

#### 変更箇所4: Phase 0 Step 4（行73-85）- グループ分類のサブエージェント委譲 [I-1]
- 現在の記述: 「この判定はメインコンテキストで直接行う（サブエージェント不要）」
- 改善後の記述:
  ```markdown
  この判定はサブエージェントに委譲する（`subagent_type: "general-purpose"`, `model: "haiku"`）。

  Task prompt:
  > `.claude/skills/agent_audit_new/group-classification.md` を Read し、その分類基準に従って以下のエージェント定義を分類してください。
  > エージェント定義: `{agent_path}`
  > 以下のフォーマットで返答してください: `group: {グループ名}`
  > グループ名は hybrid / evaluator / producer / unclassified のいずれか

  サブエージェント返答から `group: {グループ名}` を抽出し、`{agent_group}` として保持する。
  返答フォーマット不正時はエラー出力して終了する。
  ```

#### 変更箇所5: Phase 1（行128-135）- findings ファイル保存の明確化 [C-3]
- Task prompt の「findings の保存先」行の後に追加:
  ```markdown
  > findings の保存は Write ツールを使用し、既存ファイルは上書きしてください。
  ```

#### 変更箇所6: Phase 2 Step 1（行168-170）- 前提条件の明示 [C-4]
- 「Phase 2: ユーザー承認」セクションの直後（Step 1 の前）に追加:
  ```markdown
  **前提条件**: Phase 1 で成功次元が1件以上存在する（Phase 1 の部分成功判定を通過している）
  ```

#### 変更箇所7: Phase 2 Step 1（行170）- findings 抽出の詳細化とエラーハンドリング [I-4]
- 現在の記述: 「各ファイルから severity が critical または improvement の finding（`###` ブロック単位）を抽出し」
- 改善後の記述:
  ```markdown
  各ファイルから severity が critical または improvement の finding を抽出する:
  - 抽出方法: `### {ID_PREFIX}-` で始まるブロックを finding として認識し、各ブロック内の `- severity:` 行から severity を判定
  - severity が critical または improvement のブロックのみを抽出対象とする
  - 抽出失敗時（フォーマット不正等）: 該当ファイルの findings を全てスキップし、警告表示（「⚠ {次元名}のfindings抽出に失敗しました。該当次元の指摘はスキップされます」）して継続
  ```

#### 変更箇所8: Phase 2 Step 4 バックアップ作成（行253-258）- バックアップ失敗処理の追加 [C-5]
- バックアップ作成手順の3番の後に追加:
  ```markdown
  4. バックアップ作成失敗時（cp コマンドの終了コード非ゼロ）: 「✗ バックアップ作成に失敗しました。改善適用を中止します。」とテキスト出力し、Phase 3 へ直行する
  ```

#### 変更箇所9: Phase 2 Step 4 バックアップ作成（行254）- ls コマンドのソート指定 [I-8]
- 現在の記述: `ls {agent_path}.backup-* 2>/dev/null | tail -1`
- 改善後の記述: `ls -t {agent_path}.backup-* 2>/dev/null | head -1`
  （`-t` オプションで最新のファイルが先頭に来るため、`head -1` で最新を取得）

#### 変更箇所10: Phase 2 検証ステップ（行277-287）- 検証の詳細化 [I-5]
- 現在の記述: 承認済み findings の適用確認の箇条書き
- 改善後の記述:
  ```markdown
  3. 承認済み findings の適用確認（各承認済み finding について以下を検証）:
     a. finding の recommendation からキーワードを抽出する（セクション名、追加推奨文字列、削除対象フレーズ等）
     b. 削除推奨の場合: Grep でキーワードを検索し、マッチしない（削除されている）ことを確認
     c. 追加推奨の場合: Grep でキーワードを検索し、マッチする（追加されている）ことを確認
     d. 修正推奨の場合: 修正後キーワードが存在し、修正前キーワードが存在しないことを確認
     e. 検証失敗（期待と異なる）の finding は `{failed_findings}` リストに追加
  ```

#### 変更箇所11: Phase 2 検証ステップ（行280, 287）- frontmatter 検証失敗時の処理 [I-9]
- 行280の記述を以下に変更:
  ```markdown
  2. YAML frontmatter の存在確認:
     - ファイル先頭が `---` で始まり、`description:` を含むことを確認
     - frontmatter 不在時: 「⚠ YAML frontmatter が見つかりません（削除された可能性があります）」と警告表示し、`{validation_warnings}` に記録
  ```
- 行287の記述に以下を追加:
  ```markdown
  5. 検証失敗時の分類:
     - **重大な失敗**（frontmatter 削除、承認済み finding の適用失敗）: 「✗ 検証失敗: {失敗内容}。ロールバックを強く推奨します: `cp {backup_path} {agent_path}`」
     - **警告**（frontmatter 不在だが元々存在しなかった場合等）: 「⚠ 検証警告: {警告内容}」
     - Phase 3 でも検証失敗/警告を再表示
  ```

#### 変更箇所12: Phase 1 返答バリデーション（行140）- フォーマット検証ルールの明示 [I-6]
- 現在の記述: 「フォーマット不正時は件数を「?」として表示し」
- 改善後の記述:
  ```markdown
  フォーマット検証: 返答が正規表現 `^dim: .+, critical: \d+, improvement: \d+, info: \d+$` にマッチするか確認する。マッチしない場合はフォーマット不正として件数を「?」表示し
  ```

#### 変更箇所13: Phase 1（行130-135）- サブエージェント返答の拡張 [I-7]
- 現在の返答フォーマット（行131）を以下に変更:
  ```markdown
  > 分析完了後、以下のフォーマットで返答してください:
  > ```
  > dim: {次元名}, critical: {N}, improvement: {M}, info: {K}
  > critical findings:
  > - {ID}: {title}
  > （critical が0の場合は省略）
  > improvement findings:
  > - {ID}: {title}
  > （improvement が0の場合は省略）
  > ```
  ```
- Phase 2 Step 1（行170）の findings ファイル読み込みを以下に変更:
  ```markdown
  Phase 1 で成功した全次元の返答から critical/improvement の finding リスト（ID + title）を抽出する。
  詳細が必要な finding のみ、対応する findings ファイル（`.agent_audit/{agent_name}/audit-{ID_PREFIX}.md`）を Read で取得する。
  ```

## 新規作成ファイル
該当なし

## 削除推奨ファイル
該当なし

## 実装順序
1. **templates/apply-improvements.md（パス変数セクション追加）**: 他の変更に依存しない独立した修正
2. **SKILL.md（全変更の一括適用）**: テンプレートファイルの修正完了後に実施。以下の順序で各変更箇所を適用:
   - Phase 0 関連の修正（変更箇所2, 3, 4）→ データフロー上流から
   - Phase 1 関連の修正（変更箇所5, 12, 13）→ Phase 0 の後続
   - Phase 2 関連の修正（変更箇所6, 7, 8, 9, 10, 11）→ Phase 1 の後続
   - Phase 0 Step 6（変更箇所1）→ 全フェーズの生成ファイル仕様が確定後

依存関係の検出方法:
- templates/apply-improvements.md は SKILL.md Phase 2 Step 4 で参照されるが、参照箇所自体の変更はないため、テンプレート修正を先行できる
- SKILL.md 内の各変更箇所はフェーズ順（Phase 0 → 1 → 2）に依存関係があるため、データフロー順に適用

## 注意事項
- 変更によって既存のワークフローが壊れないこと
  - Phase 0 グループ分類のサブエージェント委譲（変更箇所4）は返答フォーマット検証を含めており、失敗時は明示的にエラー終了するため安全性を確保
  - Phase 1 返答拡張（変更箇所13）はフォーマット拡張だが、既存の1行目フォーマットを維持し後方互換性を確保
- テンプレート外部化の場合、SKILL.md の参照箇所も同時に更新すること
  - 該当なし（新規テンプレート作成なし）
- 新規テンプレートのパス変数が SKILL.md で定義されていること
  - 該当なし（新規テンプレート作成なし）
- Phase 0 グループ分類のサブエージェント委譲により、初回実行時のコンテキスト消費が削減される（agent_content の親保持が不要）
- Phase 1 返答拡張により、Phase 2 での findings ファイル再読み込みが部分的に削減される（critical/improvement の ID + title は返答から取得可能）
