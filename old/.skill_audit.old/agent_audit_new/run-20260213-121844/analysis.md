# スキル構造分析: agent_audit_new

## A. ファイルインベントリ
| ファイル | 行数 | 役割 |
|---------|------|------|
| SKILL.md | 297 | スキルメインワークフロー定義（エージェント分類、Phase 0-3の実行フロー） |
| agents/evaluator/criteria-effectiveness.md | 184 | CE次元: 評価基準の有効性分析（曖昧さ、S/N比、実行可能性、費用対効果） |
| agents/evaluator/scope-alignment.md | 168 | SA次元: スコープ整合性分析（evaluator用、明示的スコープ定義を期待） |
| agents/evaluator/detection-coverage.md | 200 | DC次元: 検出カバレッジ分析（検出戦略完全性、severity分類、偽陽性リスク） |
| agents/producer/workflow-completeness.md | 190 | WC次元: ワークフロー完全性分析（ステップ依存、データフロー、エラーパス） |
| agents/producer/output-format.md | 195 | OF次元: 出力形式実現性分析（形式達成可能性、下流互換性、情報完全性） |
| agents/unclassified/scope-alignment.md | 150 | SA次元: スコープ整合性分析（軽量版、目的明確性とフォーカス適切性のみ） |
| agents/shared/instruction-clarity.md | 205 | IC次元: 指示明確性分析（役割定義、コンテキスト充足、情報構造、有効性） |
| group-classification.md | 21 | グループ分類基準定義（evaluator/producer/hybrid/unclassified） |
| templates/apply-improvements.md | 37 | Phase 2 Step 4: 承認済みfindings適用手順（変更順序、適用ルール、返答フォーマット） |

## B. ワークフロー概要
- フェーズ構成: Phase 0 → Phase 1 → Phase 2 → Phase 3
- 各フェーズの目的:
  - **Phase 0（初期化・グループ分類）**: エージェント定義読み込み → グループ判定（hybrid/evaluator/producer/unclassified） → 分析次元セット決定 → 出力ディレクトリ作成
  - **Phase 1（並列分析）**: グループ別の分析次元セット（3-5次元）を並列実行 → 各次元がfindings生成 → 件数集計
  - **Phase 2（ユーザー承認 + 改善適用）**: findings収集 → 一覧提示 → per-item承認（AskUserQuestion） → 承認結果保存 → バックアップ作成 → 改善適用（サブエージェント委譲） → 検証
  - **Phase 3（完了サマリ）**: 分析結果・承認状況・変更詳細をサマリ出力 → 次ステップ推奨（critical適用時は再audit、improvement適用時はagent_bench推奨）

- データフロー:
  - Phase 0: エージェント定義（agent_path）→ グループ分類 → 次元リスト → `.agent_audit/{agent_name}/` ディレクトリ作成
  - Phase 1: エージェント定義 + 次元定義ファイル → サブエージェント並列実行 → `.agent_audit/{agent_name}/audit-{ID_PREFIX}.md` （findings）
  - Phase 2: `.agent_audit/{agent_name}/audit-*.md` （findings） → ユーザー承認 → `.agent_audit/{agent_name}/audit-approved.md` → サブエージェント（apply-improvements.md） → エージェント定義変更
  - Phase 3: Phase 1-2の結果 → 完了サマリ出力

## C. 外部参照の検出
| ファイル | 行番号 | 参照先パス | 用途 |
|---------|--------|-----------|------|
| SKILL.md | 74 | `.claude/skills/agent_audit_new/group-classification.md` | グループ分類基準の参照 |
| SKILL.md | 127 | `.claude/skills/agent_audit_new/agents/{dim_path}.md` | 各次元のエージェント定義パス |
| SKILL.md | 233 | `.claude/skills/agent_audit_new/templates/apply-improvements.md` | 改善適用テンプレート |
| SKILL.md | 88, 25 | `.claude/` | agent_name導出の起点（`.claude/`配下判定） |
| SKILL.md | 27, 92, 93, 129, 133, 138, 160, 201, 236 | `.agent_audit/{agent_name}/` | 全出力ファイルの保存先ディレクトリ |

**外部参照分析**:
- `.claude/skills/agent_audit_new/` 内の相互参照: 3箇所（group-classification.md、agents/、templates/）
- `.agent_audit/` への出力参照: 9箇所（findings、approved、バックアップ）
- すべての外部参照は明示的パスまたはパターンで指定されている
- スキル外のプロジェクトファイルへの依存はない（完全静的分析）

## D. コンテキスト予算分析
- SKILL.md 行数: 297行
- テンプレートファイル数: 1個（apply-improvements.md, 37行）
- エージェント定義ファイル数: 8個、平均行数: 177行（最小: 150行、最大: 205行）
- 補助定義ファイル数: 1個（group-classification.md, 21行）
- サブエージェント委譲: あり（Phase 1で3-5次元並列、Phase 2で1エージェント）
  - Phase 1: 次元ごとにエージェント定義（150-205行）+ 分析対象エージェント定義 → findings生成（返答は3行サマリ）
  - Phase 2 Step 4: apply-improvements.md（37行）+ 承認済みfindings + 分析対象エージェント定義 → 変更適用（返答は2行サマリ）
- 親コンテキストに保持される情報:
  - agent_path, agent_name, agent_group（Phase 0で決定）
  - 分析次元リスト（3-5項目）
  - Phase 1サブエージェント返答（各3行、計9-15行）
  - Phase 2 per-item承認状況（finding IDと判定のみ、詳細はファイル参照）
  - Phase 2サブエージェント返答（2行）
- 3ホップパターンの有無: **なし**
  - Phase 1の各次元サブエージェントは独立並列実行（相互参照なし）
  - Phase 2のapply-improvementsサブエージェントはfindings（ファイル）を直接読み込む

## E. ユーザーインタラクションポイント
| フェーズ | ツール | 目的 | Fast mode での扱い |
|---------|--------|------|-------------------|
| Phase 0 | AskUserQuestion | agent_path未指定時の確認 | 不明 |
| Phase 2 Step 2 | AskUserQuestion | 承認方針選択（1件ずつ / 全承認 / キャンセル） | 不明 |
| Phase 2 Step 2a | AskUserQuestion | per-item承認（承認 / スキップ / 残り全承認 / キャンセル） | 不明 |

**特記事項**:
- Phase 2 Step 2aのper-item承認は、finding件数に比例して呼び出し回数が増加する（N件のfindingsに対して最大N回）
- Fast mode対応の記載はSKILL.md内に存在しない
- agent_bench スキルと異なり、中間確認スキップの仕組みは未実装

## F. エラーハンドリングパターン
- ファイル不在時:
  - Phase 0: agent_path読み込み失敗 → エラー出力して終了（SKILL.md L68）
  - Phase 0: frontmatter検証失敗 → 警告出力、処理は継続（L69）
  - Phase 1: findings ファイル不在 → 該当次元を「分析失敗」として扱い、成否判定に反映（L137-139）
- サブエージェント失敗時:
  - Phase 1: findings生成失敗 → エラー概要を抽出し「分析失敗（{エラー概要}）」として記録、全次元失敗時は終了（L137-142）
  - Phase 2 Step 4: 改善適用失敗（modified: 0件）→ 警告出力、スキップ理由表示、バックアップパス表示（L240-242）
  - Phase 2 Step 4: 部分的失敗（modified > 0 かつ skipped > 0） → 警告出力（L245）
- 部分完了時:
  - Phase 1: 一部次元が失敗しても、成功次元の結果を使用してPhase 2へ進行（L141）
  - Phase 2 Step 4: 部分的成功（一部findingsがスキップ） → 警告表示、Phase 3で詳細サマリ（L245, L284）
- 入力バリデーション:
  - Phase 0: frontmatter簡易チェック（`---`と`description:`の存在確認、L69）
  - Phase 2 Step 4: 改善適用後の検証（frontmatter再確認、L250-254）
  - Phase 2: critical + improvement = 0 → Phase 2をスキップしてPhase 3へ直行（L150）

**特記事項**:
- バックアップは改善適用前に必ず作成される（Phase 2 Step 4, L229）
- 検証失敗時はロールバック手順を明示（L254）

## G. サブエージェント一覧
| フェーズ | モデル | テンプレート | 返答行数 | 並列数 |
|---------|--------|------------|---------|--------|
| Phase 1 | sonnet | `.claude/skills/agent_audit_new/agents/{dim_path}.md` | 3行（dim, critical, improvement, info） | 3-5次元（グループ依存） |
| Phase 2 Step 4 | sonnet | `.claude/skills/agent_audit_new/templates/apply-improvements.md` | 2行（modified, skipped） | 1 |

**各次元の詳細**:
- **hybrid グループ**: 5次元並列（IC, CE, SA[evaluator], WC, OF）
- **evaluator グループ**: 4次元並列（IC, CE, SA[evaluator], DC）
- **producer グループ**: 4次元並列（IC, WC, OF, SA[unclassified]）
- **unclassified グループ**: 3次元並列（IC, SA[unclassified], WC）

**返答形式**:
- Phase 1各次元: 3行固定（`dim: {ID}\ncritical: {N}\nimprovement: {N}\ninfo: {N}`）
- Phase 2 Step 4: 可変長（`modified: {N}件\n  - {詳細リスト}\nskipped: {K}件\n  - {詳細リスト}`）
