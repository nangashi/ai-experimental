# スキル構造分析: agent_audit_new

## A. ファイルインベントリ
| ファイル | 行数 | 役割 |
|---------|------|------|
| SKILL.md | 279 | スキルのメインドキュメント。ワークフロー全体（Phase 0-3）を定義し、グループ分類と次元マッピングを規定する |
| group-classification.md | 22 | エージェントのグループ判定基準（hybrid/evaluator/producer/unclassified）を定義 |
| agents/evaluator/criteria-effectiveness.md | 185 | CE次元（基準有効性）の分析エージェント定義。評価基準の明確性・S/N比・実行可能性・費用対効果を2段階（検出→報告）で分析 |
| agents/evaluator/scope-alignment.md | 169 | SA次元（スコープ整合性）の分析エージェント定義（evaluator用）。スコープ定義品質・境界明確性・内部整合性を評価 |
| agents/evaluator/detection-coverage.md | 201 | DC次元（検出カバレッジ）の分析エージェント定義。検出戦略の完全性・severity分類・出力形式・偽陽性リスクを評価 |
| agents/producer/workflow-completeness.md | 191 | WC次元（ワークフロー完全性）の分析エージェント定義。ステップ依存関係・データフロー・エラーハンドリング・条件分岐を評価 |
| agents/producer/output-format.md | 196 | OF次元（出力形式実現性）の分析エージェント定義。出力要素の実現可能性・下流互換性・情報完全性を評価 |
| agents/unclassified/scope-alignment.md | 151 | SA次元（スコープ整合性・軽量版）の分析エージェント定義（producer/unclassified用）。目的明確性・フォーカス適切性・境界暗黙性を評価 |
| agents/shared/instruction-clarity.md | 206 | IC次元（指示明確性）の分析エージェント定義（全グループ共通）。ドキュメント構造・役割定義・コンテキスト完全性・指示有効性を評価 |
| templates/apply-improvements.md | 38 | 承認済み findings に基づいてエージェント定義を改善する処理テンプレート。適用順序・変更ルール・返答フォーマットを規定 |

## B. ワークフロー概要
- フェーズ構成: Phase 0（初期化・グループ分類）→ Phase 1（並列分析）→ Phase 2（ユーザー承認 + 改善適用）→ Phase 3（完了サマリ）

### 各フェーズの目的
- **Phase 0**: 引数取得、エージェント定義読み込み、グループ分類（hybrid/evaluator/producer/unclassified）、出力ディレクトリ作成、分析次元セット決定
- **Phase 1**: グループに応じた複数次元（3-5個）を並列分析し、各次元のサブエージェントが findings ファイルを生成
- **Phase 2**:
  - Step 1: 全次元の findings ファイルを読み込み、critical/improvement を抽出
  - Step 2: ユーザーに一覧提示し、承認方針選択（全て承認/1件ずつ確認/キャンセル）
  - Step 2a: 1件ずつ確認の場合、各 finding について承認・スキップ・残りすべて承認・キャンセルを選択
  - Step 3: 承認結果を audit-approved.md に保存
  - Step 4: サブエージェント（templates/apply-improvements.md）に改善適用を委譲（バックアップ作成 → Edit による変更）
  - 検証: 改善適用後、エージェント定義の YAML frontmatter 存在確認
- **Phase 3**: 完了サマリ表示（グループ、次元数、検出件数、承認件数、変更詳細、バックアップパス、次のステップ推奨）

### データフロー
- **Phase 0 → Phase 1**: `{agent_path}`, `{agent_name}`, `{agent_group}`, dimensions テーブル
- **Phase 1 生成**: `.agent_audit/{agent_name}/audit-{ID_PREFIX}.md`（各次元の findings）
- **Phase 1 → Phase 2**: サブエージェント返答サマリ（`dim: {次元名}, critical: {N}, improvement: {M}, info: {K}`）
- **Phase 2 Step 1 読み込み**: 全次元の `.agent_audit/{agent_name}/audit-{ID_PREFIX}.md`
- **Phase 2 Step 3 生成**: `.agent_audit/{agent_name}/audit-approved.md`
- **Phase 2 Step 4 委譲**: `{approved_findings_path}` と `{agent_path}` をサブエージェントに引き渡し
- **Phase 2 Step 4 生成**: `{agent_path}.backup-{timestamp}`（バックアップ）+ `{agent_path}` の変更

## C. 外部参照の検出
| ファイル | 行番号 | 参照先パス | 用途 |
|---------|--------|-----------|------|
| SKILL.md | 64 | `.claude/skills/agent_audit/group-classification.md` | グループ分類基準の参照（実際は同スキル内の `group-classification.md` を使用すべきと思われるが、パスが `.claude/skills/agent_audit/` になっている） |
| SKILL.md | 221 | `.claude/skills/agent_audit/templates/apply-improvements.md` | 改善適用テンプレートの参照（実際は同スキル内の `templates/apply-improvements.md` を使用） |

**注**: SKILL.md 内の外部パス参照（`.claude/skills/agent_audit/`）は、同スキル内ファイル（`.claude/skills/agent_audit_new/`）を参照すべき箇所と思われる。現在の記述は旧スキルパスを参照しており、実行時にファイル不在エラーが発生する可能性がある。

## D. コンテキスト予算分析
- **SKILL.md 行数**: 279行
- **テンプレートファイル数**: 1個（apply-improvements.md）、行数: 38行
- **サブエージェント委譲**: あり
  - **Phase 1**: グループに応じて3-5個の次元分析エージェントを並列起動（model: sonnet, subagent_type: general-purpose）。各エージェントは `.claude/skills/agent_audit_new/agents/{dim_path}.md` を Read して指示に従う
  - **Phase 2 Step 4**: 改善適用エージェントを1個起動（model: sonnet, subagent_type: general-purpose）。`templates/apply-improvements.md` を Read して指示に従う
- **親コンテキストに保持される情報**:
  - 引数から取得した `{agent_path}`
  - Read で取得した `{agent_content}`（エージェント定義の全文）
  - グループ分類結果 `{agent_group}`
  - 導出した `{agent_name}`
  - 分析次元数 `{dim_count}` と dimensions リスト
  - Phase 1 の各サブエージェント返答サマリ（`dim: {次元名}, critical: {N}, improvement: {M}, info: {K}`）
  - Phase 2 での承認方針選択結果と各 finding の承認・スキップ判定
  - Phase 2 Step 4 サブエージェントの返答（変更サマリ）
  - バックアップパス `{backup_path}`
- **3ホップパターンの有無**: なし
  - Phase 1 の各サブエージェントは findings を `.agent_audit/{agent_name}/audit-{ID_PREFIX}.md` に保存し、親は返答サマリのみ受け取る
  - Phase 2 Step 4 のサブエージェントは `audit-approved.md` を読み込み、親に返答サマリのみ返す
  - 全てのデータ受け渡しはファイル経由で行われ、親が中継する構造は存在しない

## E. ユーザーインタラクションポイント
| フェーズ | ツール | 目的 | Fast mode での扱い |
|---------|--------|------|-------------------|
| Phase 0 | AskUserQuestion | 引数未指定時に agent_path を確認 | 不明 |
| Phase 2 Step 2 | AskUserQuestion | 承認方針選択（全て承認/1件ずつ確認/キャンセル） | 不明 |
| Phase 2 Step 2a | AskUserQuestion | 各 finding の per-item 承認（承認/スキップ/残りすべて承認/キャンセル + ユーザー修正内容入力） | 不明 |

**注**: SKILL.md には Fast mode に関する記述がなく、ユーザー確認のスキップ条件は定義されていない。

## F. エラーハンドリングパターン
- **ファイル不在時**:
  - Phase 0: `agent_path` が読み込み失敗した場合、エラー出力して終了
  - Phase 1: 各サブエージェントが findings ファイルを生成しなかった場合、「分析失敗（{エラー概要}）」として扱う。全次元失敗時は「Phase 1: 全次元の分析に失敗しました。」とエラー出力して終了
- **サブエージェント失敗時**:
  - Phase 1: 対応する findings ファイルが存在しない、または空の場合、Task ツール返答からエラーメッセージを抽出し「分析失敗（{エラー概要}）」として扱う。部分失敗は許容し、成功した次元のみで処理を継続
  - Phase 2 Step 4: エラーハンドリング記載なし（サブエージェント失敗時の挙動は未定義）
- **部分完了時**:
  - Phase 1: 成功した次元が1つ以上あれば Phase 2 へ進む。全次元失敗時のみ終了
  - Phase 2: critical + improvement が 0 件の場合、Phase 2 をスキップして Phase 3 へ直行
  - Phase 2 Step 2a: ユーザーが「キャンセル」を選択した場合、Phase 3 へ直行
  - Phase 2 Step 3: 承認数が 0 件の場合、改善適用なしで Phase 3 へ直行
- **入力バリデーション**:
  - Phase 0 Step 3: ファイル先頭に YAML frontmatter（`---` で囲まれ `description:` を含む）が存在しない場合、警告テキスト出力するが処理は継続
  - Phase 2 検証ステップ: 改善適用後、YAML frontmatter 存在確認。失敗時は警告出力し、Phase 3 でも警告表示

## G. サブエージェント一覧
| フェーズ | モデル | テンプレート | 返答行数 | 並列数 |
|---------|--------|------------|---------|--------|
| Phase 1 (hybrid) | sonnet | agents/shared/instruction-clarity.md, agents/evaluator/criteria-effectiveness.md, agents/evaluator/scope-alignment.md, agents/producer/workflow-completeness.md, agents/producer/output-format.md | 4（dim, critical, improvement, info） | 5 |
| Phase 1 (evaluator) | sonnet | agents/shared/instruction-clarity.md, agents/evaluator/criteria-effectiveness.md, agents/evaluator/scope-alignment.md, agents/evaluator/detection-coverage.md | 4 | 4 |
| Phase 1 (producer) | sonnet | agents/shared/instruction-clarity.md, agents/producer/workflow-completeness.md, agents/producer/output-format.md, agents/unclassified/scope-alignment.md | 4 | 4 |
| Phase 1 (unclassified) | sonnet | agents/shared/instruction-clarity.md, agents/unclassified/scope-alignment.md, agents/producer/workflow-completeness.md | 4 | 3 |
| Phase 2 Step 4 | sonnet | templates/apply-improvements.md | 2+（modified: N件 + リスト、skipped: K件 + リスト） | 1 |
