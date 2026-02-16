# スキル構造分析: agent_bench_new

## A. ファイルインベントリ
| ファイル | 行数 | 役割 |
|---------|------|------|
| SKILL.md | 446 | メインワークフロー定義・Phase 0-6の詳細手順 |
| approach-catalog.md | 202 | 改善アプローチのカタログ（S/C/N/Mカテゴリ、バリエーション管理） |
| scoring-rubric.md | 70 | 採点基準（検出判定・スコア計算・推奨判定） |
| test-document-guide.md | 254 | テスト文書生成ガイド（入力型判定・問題埋め込み） |
| proven-techniques.md | 70 | エージェント横断の実証済みテクニック（自動更新） |
| perspectives/code/maintainability.md | 34 | 保守性観点定義（コードレビュー用） |
| perspectives/code/security.md | 37 | セキュリティ観点定義（コードレビュー用） |
| perspectives/code/performance.md | 37 | パフォーマンス観点定義（コードレビュー用） |
| perspectives/code/best-practices.md | 34 | ベストプラクティス観点定義（コードレビュー用） |
| perspectives/code/consistency.md | 33 | 一貫性観点定義（コードレビュー用） |
| perspectives/design/consistency.md | 51 | 一貫性観点定義（設計レビュー用） |
| perspectives/design/security.md | 43 | セキュリティ観点定義（設計レビュー用） |
| perspectives/design/structural-quality.md | 41 | 構造的品質観点定義（設計レビュー用） |
| perspectives/design/performance.md | 45 | パフォーマンス観点定義（設計レビュー用） |
| perspectives/design/reliability.md | 43 | 信頼性・運用性観点定義（設計レビュー用） |
| perspectives/design/old/maintainability.md | （未読） | （旧バージョン・非活性） |
| perspectives/design/old/best-practices.md | （未読） | （旧バージョン・非活性） |
| templates/knowledge-init-template.md | 53 | knowledge.md初期化テンプレート |
| templates/phase1a-variant-generation.md | 29 | Phase 1A（初回バリアント生成）サブエージェント定義 |
| templates/phase1b-variant-generation.md | 33 | Phase 1B（継続バリアント生成）サブエージェント定義 |
| templates/phase2-test-document.md | 17 | Phase 2（テスト文書生成）サブエージェント定義 |
| templates/phase4-scoring.md | 13 | Phase 4（採点）サブエージェント定義 |
| templates/phase5-analysis-report.md | 23 | Phase 5（分析・推奨判定）サブエージェント定義 |
| templates/phase6a-knowledge-update.md | 26 | Phase 6A（knowledge.md更新）サブエージェント定義 |
| templates/phase6b-proven-techniques-update.md | 53 | Phase 6B（proven-techniques.md更新）サブエージェント定義 |
| templates/perspective/generate-perspective.md | 68 | perspective自動生成サブエージェント定義 |
| templates/perspective/critic-effectiveness.md | 75 | perspective有効性批評サブエージェント定義 |
| templates/perspective/critic-clarity.md | 76 | perspective明確性批評サブエージェント定義 |
| templates/perspective/critic-completeness.md | 107 | perspective網羅性批評サブエージェント定義 |
| templates/perspective/critic-generality.md | 82 | perspective汎用性批評サブエージェント定義 |

## B. ワークフロー概要
- フェーズ構成: Phase 0 → 1A/1B → 2 → 3 → 4 → 5 → 6
- 各フェーズの目的:
  - **Phase 0**: 初期化・perspective解決/自動生成・knowledge.md初期化・初回/継続判定
  - **Phase 1A**: 初回時ベースライン+2バリアント生成（proven-techniques.md参照）
  - **Phase 1B**: 継続時ベースライン+2バリアント生成（knowledge.mdのステータステーブル参照、agent_audit結果を参考）
  - **Phase 2**: テスト入力文書+正解キー生成（perspective問題バンク参照、ドメイン多様性確保）
  - **Phase 3**: 3プロンプト×2回の並列評価実行（全て親で並列起動）
  - **Phase 4**: 各プロンプトの採点（並列サブエージェント起動）
  - **Phase 5**: 分析・推奨判定・レポート作成（サブエージェント起動）
  - **Phase 6**: プロンプト選択・デプロイ・knowledge.md更新・proven-techniques.md更新・次アクション選択

- データフロー:
  - **Phase 0生成**: perspective-source.md, perspective.md, knowledge.md
  - **Phase 1生成**: prompts/v{NNN}-baseline.md, prompts/v{NNN}-variant-{name}.md（Phase 1Aは agent_path にも初期デプロイ）
  - **Phase 2生成**: test-document-round-{NNN}.md, answer-key-round-{NNN}.md
  - **Phase 3生成**: results/v{NNN}-{name}-run1.md, results/v{NNN}-{name}-run2.md
  - **Phase 4生成**: results/v{NNN}-{name}-scoring.md
  - **Phase 5生成**: reports/round-{NNN}-comparison.md
  - **Phase 6更新**: knowledge.md（Phase 6A）, proven-techniques.md（Phase 6B）, agent_path（デプロイ時）

## C. 外部参照の検出
| ファイル | 行番号 | 参照先パス | 用途 |
|---------|--------|-----------|------|
| SKILL.md | 30 | `.claude/skills/agent_bench_new/proven-techniques.md` | 実証済みテクニック自動更新（スキル内） |
| SKILL.md | 234-238 | `.agent_audit/{agent_name}/audit-ce-*.md`, `.agent_audit/{agent_name}/audit-sa-*.md` | agent_auditスキルの分析結果をPhase 1Bバリアント生成の参考にする（明示的外部依存） |
| templates/phase1b-variant-generation.md | 8-9 | `.agent_audit/{agent_name}/audit-*.md` | 同上 |

**外部依存の性質**:
- `.agent_audit/{agent_name}/` は agent_audit スキルの出力ディレクトリ
- 存在しない場合はスキップ可能（knowledge.mdのみでバリアント生成を行う）
- ドキュメント内で明示的に「agent_auditスキルが生成するディレクトリ」と記載されている

## D. コンテキスト予算分析
- SKILL.md 行数: 446行
- テンプレートファイル数: 12個、平均行数: 48行
- サブエージェント委譲: あり（Phase 0初期化, 1A, 1B, 2, 4×並列, 5, 6A, 6B, perspective自動生成×5）
- 親コンテキストに保持される情報:
  - Phase 0: agent_name, agent_path, agent_exists, perspective_source_path
  - Phase 1: 生成されたプロンプト名リスト
  - Phase 2: テスト文書の埋め込み問題数
  - Phase 3: 評価成功数・失敗プロンプト名
  - Phase 4: 採点完了数・失敗プロンプト名
  - Phase 5: 7行サマリ（recommended, reason, convergence, scores, variants, deploy_info, user_summary）
  - Phase 6: デプロイ確認・更新完了確認
- 3ホップパターンの有無: なし（Phase 5の7行サマリをPhase 6で参照するが、Phase 6は親で実行。サブエージェント間のデータ受け渡しは全てファイル経由）

## E. ユーザーインタラクションポイント
| フェーズ | ツール | 目的 | Fast mode での扱い |
|---------|--------|------|-------------------|
| Phase 0 | AskUserQuestion | agent_path未指定時の確認 | 不明 |
| Phase 0 | AskUserQuestion | perspective不完全時の再生成確認（削除して再生成/そのまま使用/中断） | 不明 |
| Phase 0 | AskUserQuestion | エージェント定義が実質空の場合の要件ヒアリング | 不明 |
| Phase 3 | AskUserQuestion | 評価失敗時の対応選択（再試行/除外して続行/中断） | 不明 |
| Phase 4 | AskUserQuestion | 採点失敗時の対応選択（再試行/除外して続行/中断） | 不明 |
| Phase 6 | AskUserQuestion | デプロイ対象プロンプトの選択（推奨を明示） | 不明 |
| Phase 6 | AskUserQuestion | デプロイ最終確認（不可逆操作） | 不明 |
| Phase 6 | AskUserQuestion | 次アクション選択（次ラウンド/終了） | 不明 |

**Fast mode の記載**: SKILL.md内にFast modeに関する明示的な記載なし

## F. エラーハンドリングパターン
- **perspective不在時**: Phase 0で自動生成（`*-design-reviewer`/`*-code-reviewer`パターンのフォールバック検索 → 自動生成）。検証失敗時はAskUserQuestionで確認
- **perspective不完全時**: Phase 0で検証し、不足セクションを提示してAskUserQuestionで再生成確認
- **エージェント定義不在時**: Phase 0で agent_exists=false として処理継続。Phase 1Aでベースライン新規生成+初期デプロイ
- **knowledge.md不在時**: Phase 0で初期化テンプレートを使って生成（サブエージェント委譲）
- **proven-techniques.md不在時**: Phase 0で初期内容を生成（親で実行）
- **サブエージェント失敗時**:
  - Phase 0 perspective自動生成: 1回再試行。2回失敗でエラー終了（欠落セクション一覧を含む）
  - Phase 3評価失敗: 成功数集計し、各プロンプトに最低1回成功があればPhase 4へ。いずれかで0回成功ならAskUserQuestionで確認（再試行/除外/中断）
  - Phase 4採点失敗: AskUserQuestionで確認（再試行/除外/中断）。ベースライン失敗の場合は中断
- **部分完了時**: Phase 3で一部失敗した場合、SD=N/Aとして処理継続（Phase 4/5テンプレートに対応ルール記載）
- **入力バリデーション**: agent_path未指定時はAskUserQuestionで確認。perspective自動生成後の必須セクション検証あり

## G. サブエージェント一覧
| フェーズ | モデル | テンプレート | 返答行数 | 並列数 |
|---------|--------|------------|---------|--------|
| Phase 0 perspective生成 | sonnet | templates/perspective/generate-perspective.md | 4行（観点/入力型/評価スコープ/問題バンク） | 1 |
| Phase 0 perspective批評 | sonnet | templates/perspective/critic-effectiveness.md, critic-clarity.md, critic-completeness.md, critic-generality.md | SendMessage（セクション形式、行数可変） | 4並列 |
| Phase 0 perspective再生成 | sonnet | templates/perspective/generate-perspective.md | 4行 | 1（フィードバック統合後） |
| Phase 0 knowledge初期化 | sonnet | templates/knowledge-init-template.md | 1行（バリエーション数） | 1 |
| Phase 1A | sonnet | templates/phase1a-variant-generation.md | 1行（生成完了） | 1 |
| Phase 1B | sonnet | templates/phase1b-variant-generation.md | 1行（生成完了） | 1 |
| Phase 2 | sonnet | templates/phase2-test-document.md | 1行（埋め込み問題数） | 1 |
| Phase 3 | sonnet | （各プロンプトファイル自体が指示） | 1行（保存完了） | (プロンプト数)×2回 |
| Phase 4 | sonnet | templates/phase4-scoring.md | 2行（スコアサマリ） | プロンプト数 |
| Phase 5 | sonnet | templates/phase5-analysis-report.md | 7行（recommended/reason/convergence/scores/variants/deploy_info/user_summary） | 1 |
| Phase 6A | sonnet | templates/phase6a-knowledge-update.md | 1行（更新完了） | 1 |
| Phase 6B | sonnet | templates/phase6b-proven-techniques-update.md | 1行（更新完了/更新なし） | 1 |
| Phase 6 Step 1 デプロイ | haiku | （インライン指示） | 1行（デプロイ完了） | 1 |

**注記**:
- Phase 6A と 6B は並列起動可能（独立した更新タスク）
- Phase 3 の並列数は典型的には6（3プロンプト×2回）
- Phase 4 の並列数は典型的には3（プロンプト数）
