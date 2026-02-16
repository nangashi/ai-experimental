# スキル構造分析: agent_audit_new

## A. ファイルインベントリ
| ファイル | 行数 | 役割 |
|---------|------|------|
| SKILL.md | 336 | メインワークフロー定義（Phase 0-3）、グループ分類ロジック、パス変数定義 |
| agents/evaluator/criteria-effectiveness.md | 134 | CE次元：評価基準の有効性分析（S/N比、実行可能性、費用対効果） |
| agents/evaluator/scope-alignment.md | 129 | SA次元（evaluator用）：スコープ定義品質、境界明確性、内部整合性 |
| agents/evaluator/detection-coverage.md | 139 | DC次元：検出戦略完全性、severity分類整合性、偽陽性リスク |
| agents/producer/workflow-completeness.md | 138 | WC次元：ワークフロー完全性、データフロー、エラーハンドリング |
| agents/producer/output-format.md | 136 | OF次元：出力形式実現可能性、下流互換性、情報完全性 |
| agents/shared/instruction-clarity.md | 126 | IC次元（全グループ共通）：ドキュメント構造、役割定義、コンテキスト充足 |
| group-classification.md | 24 | グループ分類基準（evaluator/producer特徴の判定ルール） |
| templates/apply-improvements.md | 38 | Phase 2 Step 4：承認済みfindings適用（削除→統合→修正→追加の順序ルール） |
| agents/unclassified/scope-alignment.md | 151 | SA次元（軽量版）：目的明確性、フォーカス適切性、境界暗黙性 |

## B. ワークフロー概要
- フェーズ構成: Phase 0 → Phase 1 → Phase 2 → Phase 3
- 各フェーズの目的:
  - **Phase 0**: エージェント定義読み込み、グループ分類（hybrid/evaluator/producer/unclassified）、出力ディレクトリ作成、分析次元セット決定
  - **Phase 1**: グループ別の次元セット（3-5次元）を並列サブエージェント起動で分析、findings保存
  - **Phase 2**: ユーザーへfindings提示→承認方針選択→per-item承認ループ→承認結果保存→改善適用（サブエージェント）→検証
  - **Phase 3**: 完了サマリ出力、次ステップ提示

- データフロー:
  - **Phase 0生成**: `{agent_path}`、`{agent_name}`、`{agent_group}`、次元リスト、`.agent_audit/{agent_name}/`ディレクトリ
  - **Phase 1生成**: `.agent_audit/{agent_name}/audit-{ID_PREFIX}.md`（各次元ごと）
  - **Phase 2生成**: `.agent_audit/{agent_name}/audit-approved.md`、`{agent_path}.backup-{timestamp}`、検証結果
  - **Phase 2参照**: Phase 1の全findings、`group-classification.md`（Phase 0で参照）、次元エージェント定義、`templates/apply-improvements.md`

## C. 外部参照の検出
| ファイル | 行番号 | 参照先パス | 用途 |
|---------|--------|-----------|------|
| なし | - | - | スキル内で完結（`.claude/skills/agent_audit_new/`配下のみ参照） |

**補足**: SKILL.md Phase 0 Step 6 で `.agent_audit/{agent_name}/` という出力ディレクトリを作成するが、これは分析結果の保存先であり外部参照ではない。

## D. コンテキスト予算分析
- SKILL.md 行数: 336行
- テンプレートファイル数: 1個（apply-improvements.md: 38行）、次元エージェント定義: 7個（平均約133行）
- サブエージェント委譲: あり
  - **Phase 1**: グループごとに3-5個の次元分析サブエージェント（model: sonnet, subagent_type: general-purpose）を並列起動
  - **Phase 2 Step 4**: 改善適用サブエージェント1個（model: sonnet, subagent_type: general-purpose）
- 親コンテキストに保持される情報:
  - Phase 0: `{agent_path}`, `{agent_name}`, `{agent_group}`, 次元リスト、`{dim_count}`
  - Phase 1: 各次元の返答サマリ（`dim: {次元名}, critical: {N}, improvement: {M}, info: {K}`）、エラーテキスト先頭100文字（失敗時）
  - Phase 2: findings一覧（ID/severity/title/次元名のテーブル）、承認結果（承認/スキップ/修正）、改善適用サブエージェントの返答サマリ
  - **Phase 0でのagent_content破棄**: 分類後、`{agent_content}`を明示的に破棄（行85）。次元サブエージェントは`{agent_path}`を直接Readするため親での保持不要
- 3ホップパターンの有無: なし（Phase 1の全サブエージェント結果はファイル保存、Phase 2で直接Read。Phase 2サブエージェント結果も親が直接受信）

## E. ユーザーインタラクションポイント
| フェーズ | ツール | 目的 | Fast mode での扱い |
|---------|--------|------|-------------------|
| Phase 0 | AskUserQuestion | agent_path未指定時の確認 | 不明 |
| Phase 2 Step 2 | AskUserQuestion | 承認方針選択（全て承認/1件ずつ確認/キャンセル） | 不明 |
| Phase 2 Step 2a | AskUserQuestion | per-item承認（承認/修正して承認/スキップ/残りすべて承認/キャンセル） | 不明 |
| Phase 2 Step 4 | AskUserQuestion | 改善適用の最終確認（{承認数}件を適用/キャンセル） | 不明 |

**Fast mode の扱い**: SKILL.md に fast mode に関する記述なし。全確認が必須と思われる。

**タイムアウト処理**: Phase 2の全AskUserQuestion呼び出しで「タイムアウトまたは不正入力時は『キャンセル』として扱う」と明記（行191, 213, 251）

## F. エラーハンドリングパターン
- ファイル不在時:
  - **Phase 0 Step 2**: `{agent_path}`読み込み失敗時はエラー出力して終了（行68）
  - **Phase 0 Step 4**: `group-classification.md`不在時はエラー出力して終了（行75）
  - **Phase 1**: findings ファイル不在時は該当次元を失敗として扱い、エラーテキスト先頭100文字を表示（行143-144）
- サブエージェント失敗時:
  - **Phase 1 返答バリデーション**: 返答フォーマット不正時は件数を「?」表示、findings ファイル読み込み時に推定（行140-141）
  - **Phase 1 部分成功判定**: 全次元失敗 or IC失敗+固有次元全失敗 → 終了、それ以外 → 継続（行146-150）
  - **Phase 2 Step 4**: 改善適用サブエージェント返答に `modified:` または `skipped:` が含まれない場合は失敗扱い、ロールバック手順表示してPhase 3へ（行273）
- 部分完了時:
  - **Phase 1**: 成功次元が1つでもあればPhase 2へ継続（行151）
  - **Phase 2検証失敗時**: 検証失敗内容とロールバック手順を表示し、Phase 3でも警告表示（行287）
- 入力バリデーション:
  - **Phase 0 Step 3**: YAML frontmatter不在時は警告表示、処理は継続（行69）
  - **Phase 2 Step 1**: critical + improvement の合計が0の場合、Phase 2をスキップしてPhase 3へ直行（行160, 170）

## G. サブエージェント一覧
| フェーズ | モデル | テンプレート | 返答行数 | 並列数 |
|---------|--------|------------|---------|--------|
| Phase 1 | sonnet | agents/{dim_path}.md（次元別）| 1行（`dim: {次元名}, critical: {N}, improvement: {M}, info: {K}`） | 3-5個（グループ別：hybrid=5, evaluator=4, producer=4, unclassified=3） |
| Phase 2 Step 4 | sonnet | templates/apply-improvements.md | 複数行（`modified: {N}件` + `skipped: {K}件` + 各変更/スキップの詳細） | 1個 |

**Phase 1の次元マッピング**:
- hybrid: IC, CE, SA（evaluator版）, WC, OF
- evaluator: IC, CE, SA（evaluator版）, DC
- producer: IC, WC, OF, SA（軽量版）
- unclassified: IC, SA（軽量版）, WC
