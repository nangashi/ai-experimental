# スキル構造分析: agent_bench_new

## A. ファイルインベントリ
| ファイル | 行数 | 役割 |
|---------|------|------|
| SKILL.md | 390 | スキルのメインワークフロー定義（Phase 0-6） |
| approach-catalog.md | 202 | 改善アプローチカタログ（S/C/N/M 4カテゴリ、バリエーション管理） |
| scoring-rubric.md | 70 | 採点基準・推奨判定・収束判定ルール |
| test-document-guide.md | 254 | テスト対象文書生成ガイド（入力型判定・問題埋め込み・正解キー） |
| proven-techniques.md | 70 | エージェント横断の実証済み知見（セクション1-4） |
| templates/knowledge-init-template.md | 53 | knowledge.md 初期化テンプレート |
| templates/phase1a-variant-generation.md | 41 | Phase 1A: 初回バリアント生成 |
| templates/phase1b-variant-generation.md | 33 | Phase 1B: 継続バリアント生成 |
| templates/phase2-test-document.md | 33 | Phase 2: テスト文書・正解キー生成 |
| templates/phase4-scoring.md | 13 | Phase 4: 採点実行 |
| templates/phase5-analysis-report.md | 22 | Phase 5: 分析・推奨判定・レポート作成 |
| templates/phase6a-knowledge-update.md | 26 | Phase 6A: knowledge.md 更新 |
| templates/phase6b-proven-techniques-update.md | 52 | Phase 6B: proven-techniques.md 更新 |
| templates/perspective/generate-perspective.md | 67 | perspective 初期生成 |
| templates/perspective/critic-effectiveness.md | 75 | 批判レビュー: 有効性 |
| templates/perspective/critic-completeness.md | 107 | 批判レビュー: 網羅性 |
| templates/perspective/critic-clarity.md | 未読 | 批判レビュー: 明確性 |
| templates/perspective/critic-generality.md | 未読 | 批判レビュー: 汎用性 |
| perspectives/design/security.md | 43 | 設計レビュー用 perspective（セキュリティ） |
| perspectives/design/performance.md | 未読 | 設計レビュー用 perspective（パフォーマンス） |
| perspectives/design/consistency.md | 未読 | 設計レビュー用 perspective（一貫性） |
| perspectives/design/structural-quality.md | 未読 | 設計レビュー用 perspective（構造品質） |
| perspectives/design/reliability.md | 未読 | 設計レビュー用 perspective（信頼性） |
| perspectives/code/security.md | 38 | 実装レビュー用 perspective（セキュリティ） |
| perspectives/code/performance.md | 未読 | 実装レビュー用 perspective（パフォーマンス） |
| perspectives/code/consistency.md | 未読 | 実装レビュー用 perspective（一貫性） |
| perspectives/code/best-practices.md | 未読 | 実装レビュー用 perspective（ベストプラクティス） |
| perspectives/code/maintainability.md | 未読 | 実装レビュー用 perspective（保守性） |
| perspectives/design/old/maintainability.md | 未読 | 旧バージョン perspective |
| perspectives/design/old/best-practices.md | 未読 | 旧バージョン perspective |

## B. ワークフロー概要
- **フェーズ構成**: Phase 0 → Phase 1A/1B → Phase 2 → Phase 3 → Phase 4 → Phase 5 → Phase 6 → (1Bにループまたは終了)
- **各フェーズの目的**:
  - **Phase 0**: 初期化・perspective解決（自動生成含む）・knowledge.md存在判定で1A/1B分岐
  - **Phase 1A**: 初回 — ベースライン作成＋バリアント生成（proven-techniques.md のガイドに従う）
  - **Phase 1B**: 継続 — knowledge.md の知見に基づくバリアント生成（Broad/Deep戦略）
  - **Phase 2**: テスト文書・正解キー生成（毎ラウンド）
  - **Phase 3**: 全プロンプト並列評価（各プロンプト×2回実行）
  - **Phase 4**: 並列採点（プロンプトごとに採点サブエージェント）
  - **Phase 5**: 分析・推奨判定・レポート作成（7行サマリ返答）
  - **Phase 6**: プロンプト選択・デプロイ（Step 1）→ ナレッジ更新・スキル知見フィードバック・次アクション（Step 2）
- **データフロー**:
  - Phase 0: perspective-source.md, perspective.md, knowledge.md 生成/検証
  - Phase 1A/1B: prompts/v{NNN}-*.md 生成
  - Phase 2: test-document-round-{NNN}.md, answer-key-round-{NNN}.md 生成
  - Phase 3: results/v{NNN}-{name}-run{R}.md 生成
  - Phase 4: results/v{NNN}-{name}-scoring.md 生成、Phase 5 が参照
  - Phase 5: reports/round-{NNN}-comparison.md 生成、7行サマリを Phase 6 に中継
  - Phase 6: エージェント定義ファイル更新（デプロイ）、knowledge.md 更新、proven-techniques.md 更新

## C. 外部参照の検出
| ファイル | 行番号 | 参照先パス | 用途 |
|---------|--------|-----------|------|
| SKILL.md | 179-180 | `.agent_audit/{agent_name}/audit-dim1.md`, `.agent_audit/{agent_name}/audit-dim2.md` | Phase 1B でバリアント生成時に agent_audit の分析結果を参考にする（ファイル不在時は空文字列） |

## D. コンテキスト予算分析
- **SKILL.md 行数**: 390行
- **テンプレートファイル数**: 13個、平均行数: 48行
- **サブエージェント委譲**: あり
  - Phase 0: knowledge-init-template（初回のみ）、perspective 自動生成（1サブエージェント+4批判レビュー並列）
  - Phase 1A/1B: variant-generation（1サブエージェント）
  - Phase 2: test-document（1サブエージェント）
  - Phase 3: 評価実行（N×2並列サブエージェント、N=プロンプト数）
  - Phase 4: 採点（N並列サブエージェント）
  - Phase 5: analysis-report（1サブエージェント）
  - Phase 6: デプロイ（haiku、1サブエージェント）、knowledge-update（1サブエージェント）、proven-techniques-update（1サブエージェント）
- **親コンテキストに保持される情報**:
  - agent_name, agent_path, perspective_source_path の導出結果
  - 累計ラウンド数（knowledge.md から抽出）
  - Phase 5 の7行サマリ（recommended, reason, convergence, scores, variants, deploy_info, user_summary）
  - Phase 3/4 の成功数カウント（部分失敗判定に使用）
- **3ホップパターンの有無**: なし。サブエージェント間のデータ受け渡しはファイル経由で統一されている（Phase 4 → Phase 5 は scoring ファイル経由、Phase 5 → Phase 6A は report ファイル経由）

## E. ユーザーインタラクションポイント
| フェーズ | ツール | 目的 | Fast mode での扱い |
|---------|--------|------|-------------------|
| Phase 0 | AskUserQuestion | agent_path 未指定時の確認 | 不明 |
| Phase 0 | AskUserQuestion | perspective 自動生成時のヒアリング（エージェント定義が不完全な場合） | 不明 |
| Phase 3 | AskUserQuestion | 部分失敗時の対応選択（再試行/除外して続行/中断） | 不明 |
| Phase 4 | AskUserQuestion | 採点失敗時の対応選択（再試行/除外して続行/中断） | 不明 |
| Phase 6 Step 1 | AskUserQuestion | プロンプト選択（ベースライン含む全プロンプト） | 不明 |
| Phase 6 Step 2 | AskUserQuestion | 次アクション選択（次ラウンド/終了） | 不明 |

## F. エラーハンドリングパターン
- **ファイル不在時**:
  - エージェントファイル (Phase 0): エラー出力して終了
  - knowledge.md (Phase 0): 初期化して Phase 1A へ
  - perspective-source.md (Phase 0): パターン検索→自動生成→検証失敗時はエラー出力して終了
  - audit-dim1.md/audit-dim2.md (Phase 1B): 空文字列を渡して続行
- **サブエージェント失敗時**:
  - Phase 3（評価実行）: 成功数に応じて分岐（全成功→続行、部分成功で最低1回成功あり→警告して続行、0回成功のプロンプトあり→AskUserQuestion で選択）
  - Phase 4（採点）: AskUserQuestion で選択（再試行/除外して続行/中断）、ベースライン失敗時は中断
  - その他のフェーズ: 明示的な定義なし（暗黙的に中断と推定）
- **部分完了時**:
  - Phase 3: 各プロンプトに最低1回の成功結果があれば続行可能（SD=N/Aで採点）
  - Phase 4: 成功したプロンプトのみで続行可能（ベースライン失敗時は中断）
- **入力バリデーション**: agent_path の不在時の確認のみ（Phase 0）。その他のバリデーション（ファイル形式、perspective 必須セクション）は perspective 自動生成の Step 7 で実施

## G. サブエージェント一覧
| フェーズ | モデル | テンプレート | 返答行数 | 並列数 |
|---------|--------|------------|---------|--------|
| Phase 0 (knowledge初期化) | sonnet | knowledge-init-template | 1行（確認） | 1 |
| Phase 0 (perspective生成) | sonnet | perspective/generate-perspective | 4行（サマリ） | 1 |
| Phase 0 (perspective批判) | sonnet | perspective/critic-* (4種) | 可変（批評結果セクション） | 4（並列） |
| Phase 1A | sonnet | phase1a-variant-generation | 可変（構造分析+バリアント情報） | 1 |
| Phase 1B | sonnet | phase1b-variant-generation | 可変（選定プロセス+バリアント情報） | 1 |
| Phase 2 | sonnet | phase2-test-document | 可変（問題サマリテーブル） | 1 |
| Phase 3 | sonnet | （テンプレートなし、直接指示） | 1行（保存完了確認） | N×2（N=プロンプト数） |
| Phase 4 | sonnet | phase4-scoring | 2行（スコアサマリ） | N（プロンプト数） |
| Phase 5 | sonnet | phase5-analysis-report | 7行（固定フォーマット） | 1 |
| Phase 6 (デプロイ) | haiku | （テンプレートなし、直接指示） | 1行（デプロイ完了確認） | 1 |
| Phase 6A | sonnet | phase6a-knowledge-update | 1行（確認） | 1 |
| Phase 6B | sonnet | phase6b-proven-techniques-update | 1行（確認） | 1 |
