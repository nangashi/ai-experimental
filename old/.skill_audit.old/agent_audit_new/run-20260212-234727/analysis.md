# スキル構造分析: agent_audit_new

## A. ファイルインベントリ
| ファイル | 行数 | 役割 |
|---------|------|------|
| SKILL.md | 279 | スキルのメインエントリポイント。ワークフロー全体とグループ分類ロジックを定義 |
| agents/evaluator/criteria-effectiveness.md | 185 | 評価基準の有効性を分析するレビューアーエージェント |
| agents/evaluator/detection-coverage.md | 201 | 検出カバレッジを分析するレビューアーエージェント |
| agents/evaluator/scope-alignment.md | 169 | スコープ整合性を分析するレビューアーエージェント（evaluator用） |
| agents/producer/workflow-completeness.md | 191 | ワークフロー完全性を分析するレビューアーエージェント |
| agents/producer/output-format.md | 196 | 出力形式実現性を分析するレビューアーエージェント |
| agents/shared/instruction-clarity.md | 172 | 指示明確性を分析するレビューアーエージェント（全グループ共通） |
| agents/unclassified/scope-alignment.md | 151 | スコープ整合性を分析するレビューアーエージェント（軽量版） |
| group-classification.md | 22 | グループ分類基準を定義した参照文書 |
| templates/apply-improvements.md | 38 | 承認済み findings をエージェント定義に適用するテンプレート |

## B. ワークフロー概要
- **フェーズ構成**: Phase 0 (初期化・グループ分類) → Phase 1 (並列分析) → Phase 2 (ユーザー承認 + 改善適用) → Phase 3 (完了サマリ)

### 各フェーズの目的
- **Phase 0**: エージェント定義を読み込み、グループ（hybrid/evaluator/producer/unclassified）に分類し、分析次元セットを決定する
- **Phase 1**: グループごとの次元セットに基づき、複数の分析エージェントを並列起動して findings を生成する
- **Phase 2**: ユーザーに findings を提示し、承認された項目のみを適用する（per-item 承認またはバッチ承認）
- **Phase 3**: 最終サマリを出力し、次のステップ（再監査または agent_bench）を提案する

### データフロー
- **Phase 0 → Phase 1**: グループ情報 + agent_path → 各分析エージェント
- **Phase 1 生成**: `.agent_audit/{agent_name}/audit-{ID_PREFIX}.md` （各次元の findings）
- **Phase 2 Step 1**: Phase 1 で生成された findings を収集
- **Phase 2 Step 3**: `.agent_audit/{agent_name}/audit-approved.md` 生成
- **Phase 2 Step 4**: audit-approved.md + agent_path → apply-improvements サブエージェント → agent_path を Edit
- **Phase 3**: Phase 1 と Phase 2 の結果を参照してサマリ出力

## C. 外部参照の検出
| ファイル | 行番号 | 参照先パス | 用途 |
|---------|--------|-----------|------|
| SKILL.md | 64 | `.claude/skills/agent_audit/group-classification.md` | グループ分類基準の詳細参照（現行実装では `agent_audit_new/group-classification.md` を参照すべきか？） |
| SKILL.md | 88-92 | `agents/{dim_path}.md` | 次元別分析エージェントへの相対パス（スキル内なので厳密には外部ではない） |
| SKILL.md | 221 | `.claude/skills/agent_audit/templates/apply-improvements.md` | 改善適用テンプレート（現行実装では `agent_audit_new/templates/apply-improvements.md` を参照すべきか？） |

**注**: SKILL.md の外部参照は、旧スキル名 `agent_audit` を使用している箇所がある。現在のスキル名 `agent_audit_new` への修正が必要。

## D. コンテキスト予算分析
- **SKILL.md 行数**: 279行
- **テンプレートファイル数**: 1個（apply-improvements.md）、平均行数: 38行
- **サブエージェント委譲**: あり（Phase 1 で並列委譲、Phase 2 Step 4 で単一委譲）
  - Phase 1: グループごとの次元数（3-5個）の分析エージェントを並列起動（各エージェント 150-200行）
  - Phase 2 Step 4: apply-improvements サブエージェント（38行テンプレート）
- **親コンテキストに保持される情報**:
  - エージェント定義全文（`{agent_content}`）— Phase 0 で Read、Phase 2 検証で再 Read
  - グループ分類結果（`{agent_group}`, `{dim_count}`, dimensions リスト）
  - Phase 1 の各次元のサマリ（`critical: N, improvement: M, info: K` 形式）
  - Phase 2 での findings 一覧（critical/improvement のみ）および承認結果
- **3ホップパターンの有無**: なし
  - Phase 1 のサブエージェントは findings をファイルに保存し、サマリのみ返答
  - Phase 2 のサブエージェントは変更リストのみ返答
  - 親は findings 詳細をファイル経由で参照する

## E. ユーザーインタラクションポイント
| フェーズ | ツール | 目的 | Fast mode での扱い |
|---------|--------|------|-------------------|
| Phase 0 | AskUserQuestion | agent_path が未指定の場合にファイルパス確認 | 不明 |
| Phase 2 Step 2 | AskUserQuestion | 承認方針の選択（全承認/1件ずつ/キャンセル） | 不明 |
| Phase 2 Step 2a | AskUserQuestion | per-item 承認（承認/スキップ/残り全承認/キャンセル） | 不明 |

**Fast mode 対応**: SKILL.md にはファストモードに関する記述なし。全チェックポイントが毎回実行される。

## F. エラーハンドリングパターン
- **ファイル不在時**:
  - Phase 0: agent_path の Read 失敗時はエラー出力して終了
  - Phase 1: findings ファイルが生成されない場合は「分析失敗（{エラー概要}）」として記録し、該当次元をスキップして継続
- **サブエージェント失敗時**:
  - Phase 1: 各次元の findings ファイル存在確認で成否判定。全失敗の場合は終了、部分失敗の場合は成功した次元の結果のみで続行
  - Phase 2 Step 4: 失敗時の挙動は未定義（変更サマリが返らない場合の処理が記載されていない）
- **部分完了時**:
  - Phase 1: 一部の次元が失敗しても成功した次元の結果で Phase 2 に進む
  - Phase 2 Step 2a: ユーザーが「キャンセル」または「残りすべて承認」で途中終了可能
- **入力バリデーション**:
  - Phase 0: YAML frontmatter の存在確認（警告のみ、処理は継続）
  - Phase 2 検証ステップ: 改善適用後に agent_path の YAML frontmatter 再確認（失敗時はロールバック手順を提示）

## G. サブエージェント一覧
| フェーズ | モデル | テンプレート | 返答行数 | 並列数 |
|---------|--------|------------|---------|--------|
| Phase 1 | sonnet | agents/evaluator/criteria-effectiveness.md | 4行（`dim: CE\ncritical: N\nimprovement: M\ninfo: K`） | グループごとに 3-5個並列 |
| Phase 1 | sonnet | agents/evaluator/detection-coverage.md | 4行（同上） | 同上 |
| Phase 1 | sonnet | agents/evaluator/scope-alignment.md | 4行（同上） | 同上 |
| Phase 1 | sonnet | agents/producer/workflow-completeness.md | 4行（同上） | 同上 |
| Phase 1 | sonnet | agents/producer/output-format.md | 4行（同上） | 同上 |
| Phase 1 | sonnet | agents/shared/instruction-clarity.md | 4行（同上） | 全グループで実行 |
| Phase 1 | sonnet | agents/unclassified/scope-alignment.md | 4行（同上） | unclassified グループのみ |
| Phase 2 Step 4 | sonnet | templates/apply-improvements.md | 可変（`modified: N\n  - ...\nskipped: K\n  - ...`） | 1個 |
