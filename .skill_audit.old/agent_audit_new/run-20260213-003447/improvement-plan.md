# 改善計画: agent_audit_new

## 変更対象ファイル
| # | ファイル | 変更種別 | 変更概要 | 対応フィードバック |
|---|---------|---------|---------|------------------|
| 1 | templates/collect-findings.md | 新規作成 | Phase 2 Step 1 の findings 収集処理を外部化 | C-6, I-1 |
| 2 | templates/validate-agent-structure.md | 新規作成 | Phase 2 検証ステップを外部化 | C-5, I-2 |
| 3 | templates/classify-agent-group.md | 新規作成 | Phase 0 グループ分類処理を外部化 | I-4 |
| 4 | SKILL.md | 修正 | Phase 2 Step 1 の inline prompt 除去、検証ステップ外部化、エラーハンドリング改善、Fast mode 明確化、進捗表示強化、バックアップ追加 | C-1, C-2, C-3, C-5, C-6, C-7, C-8, C-9, I-3, I-4, I-6, I-7, I-8, I-9 |

## 各ファイルの変更詳細

### 1. templates/collect-findings.md（新規作成）
**対応フィードバック**: C-6: 7行超の inline prompt, I-1: Phase 2 Step 1 サブエージェント prompt の外部化

**変更内容**:
- Phase 2 Step 1 の 31行の inline prompt（SKILL.md:224-256）を外部化
- パス変数: `{agent_name}`, `{findings_files}` (成功した次元のファイルパスリスト)
- 出力: findings-summary.md に total/critical/improvement を含むサマリテーブル
- 返答フォーマット: 3行（total, critical, improvement）

**ファイル構造**:
```markdown
## パス変数
- `{agent_name}`: エージェント名
- `{findings_files}`: 対象 findings ファイルのパスリスト（カンマ区切り）

## 手順
1. 各 findings ファイルを Read で読み込む
2. 境界検出、severity/title/次元名抽出
3. critical → improvement の順にソート
4. findings-summary.md に保存
5. 3行フォーマットで返答
```

### 2. templates/validate-agent-structure.md（新規作成）
**対応フィードバック**: C-5: SKILL.md 行数超過, I-2: テンプレートの細分化, I-6: 検証ステップの構造検証強化

**変更内容**:
- Phase 2 検証ステップの inline 記述（SKILL.md:309-323）を外部化
- パス変数: `{agent_path}`, `{backup_path}`, `{analysis_path}` (オプショナル)
- 検証強化: 必須セクション検証（## 使い方, ## ワークフロー等）、破損検出（markdown 構文エラー）を追加
- 検証失敗時の自動ロールバック（I-3）を実装
- 返答フォーマット: 4行（validation_status, structure_ok, references_ok, rollback_executed）

**ファイル構造**:
```markdown
## パス変数
- `{agent_path}`: エージェント定義ファイルのパス
- `{backup_path}`: バックアップファイルのパス
- `{analysis_path}`: analysis.md のパス（オプショナル）

## 手順
1. Read で agent_path を再読み込み
2. 構造検証:
   - YAML frontmatter 存在確認
   - 見出し行（## で始まる）の存在確認
   - **追加**: 必須セクション検証（使い方、ワークフロー、パス変数等の agent 種別に応じた必須セクション）
   - **追加**: markdown 構文エラー検出（対応していない見出し階層、不正な YAML 等）
3. 外部参照整合性検証（analysis_path が存在する場合のみ）
4. 検証失敗時: Bash で `cp {backup_path} {agent_path}` を実行（自動ロールバック）
5. 4行フォーマットで返答
```

### 3. templates/classify-agent-group.md（新規作成）
**対応フィードバック**: I-4: Phase 0 グループ分類のサブエージェント委譲

**変更内容**:
- Phase 0 グループ分類処理（SKILL.md:100-108）をサブエージェントに委譲
- パス変数: `{agent_content}`, `{classification_guide_path}` (= `.claude/skills/agent_audit_new/group-classification.md`)
- 返答フォーマット: 2行（agent_group, reasoning）

**ファイル構造**:
```markdown
## パス変数
- `{agent_content}`: エージェント定義の内容（Read 済み）
- `{classification_guide_path}`: グループ分類基準のパス

## 手順
1. Read で classification_guide_path を読み込み
2. agent_content を分析し、evaluator 特徴 / producer 特徴をカウント
3. 判定ルール（hybrid → evaluator → producer → unclassified）に従って分類
4. 2行フォーマットで返答
```

### 4. SKILL.md（修正）
**対応フィードバック**: C-1, C-2, C-3, C-5, C-6, C-7, C-8, C-9, I-3, I-4, I-6, I-7, I-8, I-9

**変更内容**:

#### a. Phase 0 グループ分類のサブエージェント委譲（I-4, C-5の一部）
- **現在の記述**（100-108行目）: メインコンテキストで直接 group-classification.md を Read して判定
- **改善後の記述**: Task ツールでサブエージェントに委譲し、templates/classify-agent-group.md を使用。返答は2行（agent_group, reasoning）のみ受け取る

#### b. Phase 0 グループ分類結果の確認追加（I-8）
- **現在の記述**: グループ分類結果をテキスト出力のみ（ユーザー確認なし）
- **改善後の記述**: AskUserQuestion で「グループ: {agent_group} で分析を開始しますか？（理由: {reasoning}）」を追加（選択肢: 「開始する」「手動で変更」「キャンセル」）

#### c. Phase 0 必須次元の定義明確化（C-8）
- **現在の記述**（194行目）: IC が必須である理由が未説明
- **改善後の記述**: テキスト出力に「IC（指示明確性）は全グループ共通の必須次元です」を追加

#### d. Phase 1 findings ファイル上書き時のバックアップ追加（C-9）
- **現在の記述**（156-158行目）: 既存ファイルを上書き警告のみ
- **改善後の記述**: 上書き対象ファイルを `.prev` 拡張子でバックアップ（例: `audit-CE.md` → `audit-CE.md.prev`）

#### e. Phase 1 並列処理の進捗表示強化（I-7）
- **現在の記述**（160行目）: 「並列分析中...」のみ
- **改善後の記述**: 各次元の開始メッセージ（「- {次元名} 分析開始」）と完了メッセージ（「- {次元名} 完了: critical {N}, improvement {M}」）を追加

#### f. Phase 1 部分失敗時の Fast mode 扱い明確化（C-2）
- **現在の記述**（195-199行目）: Fast mode 時の部分失敗処理が未定義
- **改善後の記述**: 継続条件のブロックに「Fast mode の場合: AskUserQuestion をスキップし、自動継続する」を追加

#### g. Phase 2 Step 1 の inline prompt 除去（C-6, I-1, C-5の一部）
- **現在の記述**（224-256行目）: 31行の inline prompt
- **改善後の記述**: Task prompt を以下に置換:
  ```
  `.claude/skills/agent_audit_new/templates/collect-findings.md` を Read で読み込み、その内容に従って処理を実行してください。
  パス変数:
  - `{agent_name}`: {実際の agent_name}
  - `{findings_files}`: {成功した次元のファイルパスリスト（カンマ区切り）}
  ```

#### h. Phase 2 Step 1 失敗時の処理追加（C-1, C-4）
- **現在の記述**: サブエージェント完了後の処理が記述されているが、失敗時の処理が未定義
- **改善後の記述**: サブエージェント完了後、以下を追加:
  1. findings-summary.md の存在確認: Bash で `test -f {findings_summary_path}` を実行
  2. Read 成否判定: Read 失敗時または findings-summary.md が空の場合
  3. 失敗時の処理: 「✗ エラー: findings の収集に失敗しました。{エラー詳細}」とエラー出力し、Phase 3 へ直行

#### i. Phase 2 Step 1 の進捗表示（I-9）
- **現在の記述**（222行目）: テキスト出力なし
- **改善後の記述**: サブエージェント起動前に「findings を収集中...」、完了後に「✓ findings 収集完了: total {N}件」を追加

#### j. Phase 2 Step 4 の進捗表示強化（C-3）
- **現在の記述**（289行目）: 「改善を適用しています...」のみ
- **改善後の記述**:
  - 開始前: 「改善を適用中（対象: {N}件）...」
  - 完了時: 「✓ 改善適用完了: {modified}件の変更を適用、{skipped}件をスキップ」

#### k. 検証ステップの外部化と強化（C-5, I-2, I-6, I-3, C-7）
- **現在の記述**（309-323行目）: 15行の inline 検証ステップ、検証失敗時は警告のみ、analysis.md Read 失敗時の処理なし
- **改善後の記述**:
  1. Task ツールでサブエージェント起動（templates/validate-agent-structure.md 使用）
  2. パス変数: `{agent_path}`, `{backup_path}`, `{analysis_path}` (オプショナル)
  3. サブエージェント失敗時: 「✗ エラー: 検証処理に失敗しました」とエラー出力、Phase 3 へ進む
  4. 返答から validation_status を取得
  5. validation_status が "failed" の場合: `{validation_failed} = true` を記録、rollback_executed が true の場合は「✓ 自動ロールバック完了」を出力

## 新規作成ファイル
| ファイル | 目的 | 対応フィードバック |
|---------|------|------------------|
| templates/collect-findings.md | Phase 2 Step 1 の findings 収集処理を外部化 | C-6, I-1 |
| templates/validate-agent-structure.md | Phase 2 検証ステップを外部化、検証強化、自動ロールバック実装 | C-5, I-2, I-3, I-6, C-7 |
| templates/classify-agent-group.md | Phase 0 グループ分類処理をサブエージェントに委譲 | I-4 |

## 削除推奨ファイル
（該当なし）

## 実装順序
1. **templates/classify-agent-group.md の新規作成**
   - 理由: SKILL.md の Phase 0 変更（グループ分類のサブエージェント委譲）で参照される
2. **templates/collect-findings.md の新規作成**
   - 理由: SKILL.md の Phase 2 Step 1 変更で参照される
3. **templates/validate-agent-structure.md の新規作成**
   - 理由: SKILL.md の Phase 2 検証ステップ変更で参照される
4. **SKILL.md の変更**
   - 理由: 新規テンプレートファイルへの参照を追加し、inline 記述を除去する（依存: 1, 2, 3）

依存関係の検出方法:
- テンプレート新規作成（1, 2, 3）→ SKILL.md でのテンプレート参照追加（4）→ 1, 2, 3 が先

## 注意事項
- 変更によって既存のワークフローが壊れないこと
  - 各 Phase の入出力インターフェースは変更しない
  - サブエージェントの返答フォーマット（行数、key: value 形式）を維持
  - findings ファイル、findings-summary.md、audit-approved.md のフォーマットを維持
- テンプレート外部化の場合、SKILL.md の参照箇所も同時に更新すること
  - Phase 0: templates/classify-agent-group.md への参照追加
  - Phase 2 Step 1: templates/collect-findings.md への参照追加
  - Phase 2 検証ステップ: templates/validate-agent-structure.md への参照追加
- 新規テンプレートのパス変数が SKILL.md で定義されていること
  - classify-agent-group.md: `{agent_content}`, `{classification_guide_path}`
  - collect-findings.md: `{agent_name}`, `{findings_files}`
  - validate-agent-structure.md: `{agent_path}`, `{backup_path}`, `{analysis_path}`
