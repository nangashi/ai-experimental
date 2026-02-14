### アーキテクチャレビュー結果

#### 重大な問題
- [外部参照 - 他スキルのフォールバックパス]: [SKILL.md:54] Phase 0 perspective フォールバック処理で `.claude/skills/agent_bench/perspectives/{target}/{key}.md` を参照する。これは agent_bench スキル（旧版）への依存を意味する。agent_bench_new 内に perspectives ディレクトリは既に存在するため、フォールバックパスを `.claude/skills/agent_bench_new/perspectives/{target}/{key}.md` に修正すべき [impact: medium] [effort: low]
- [外部参照 - 他スキルのデータファイル]: [SKILL.md:74] Phase 0 perspective 自動生成で `.claude/skills/agent_bench/perspectives/design/*.md` を参照する。これも旧版への依存。`.claude/skills/agent_bench_new/perspectives/design/*.md` に修正すべき [impact: medium] [effort: low]
- [外部参照 - クロススキル参照]: [SKILL.md:174, templates/phase1b-variant-generation.md:8] Phase 1B で `.agent_audit/{agent_name}/audit-*.md` を参照する。これは agent_audit スキルへの依存を意味する。agent_audit の分析結果は任意の補助情報であるべきだが、パス変数として渡される設計は強い依存を示唆する。agent_audit の結果を agent_bench_new のディレクトリ内にコピーするか、パラメータ化（明示的な有無フラグ）すべき [impact: medium] [effort: medium]

#### 改善提案
- [Phase 3 並列評価の直接指示]: [SKILL.md:213-220] Phase 3 で各サブエージェントへの指示が直接記述されている（8行）。テンプレートファイルへの外部化を提案する [impact: low] [effort: low]
- [Phase 6 Step 1 デプロイの直接指示]: [SKILL.md:307-313] プロンプトデプロイ処理が直接記述されている（7行）。頻繁に実行される処理であり、テンプレート化を検討すべき [impact: low] [effort: low]
- [perspective 批評テンプレートの不完全パターン]: [templates/perspective/critic-effectiveness.md:74] 批評テンプレートで TaskUpdate が指示されているが、Phase 0 の perspective 生成フローでは Task ツールによる並列実行ではなく親コンテキストでの実行を想定している。テンプレートの返答指示と実際の委譲パターンが不整合 [impact: low] [effort: medium]
- [knowledge.md の累計ラウンド数導出]: [SKILL.md:116-117, templates/phase6a-knowledge-update.md:8] knowledge.md の読み込み成否で Phase 1A/1B を分岐するが、累計ラウンド数の導出方法が SKILL.md に明示されていない。Phase 6A で累計ラウンド数を +1 するルールはあるが、Phase 0 で読み込み時にどのフィールドから取得するか不明確 [impact: medium] [effort: low]
- [テスト文書生成の過剰パス変数]: [SKILL.md:186-191] Phase 2 テスト文書生成で {perspective_path} と {perspective_source_path} の両方を渡しているが、テンプレート内で perspective_path は概要確認のみに使用される。perspective_source_path だけで十分であり、パス変数の削減を検討すべき [impact: low] [effort: low]
- [テンプレートの短い指示のインライン化]: [templates/phase4-scoring.md] Phase 4 採点テンプレートが13行と短い。サブエージェントへの指示として直接記述しても可読性を損なわない範囲であり、テンプレート外部化の利点が小さい [impact: low] [effort: low]

#### パターン準拠サマリ
| パターン | 状態 | 備考 |
|---------|------|------|
| テンプレート外部化 | 部分的 | Phase 3, 6 Step 1 で7-8行の直接指示あり。Phase 4 は13行で逆に過剰外部化の可能性 |
| サブエージェント委譲 | 準拠 | 「Read template + follow instructions + path variables」パターンが一貫して使用されている。モデル指定も適切（Phase 6 Step 1 デプロイのみ haiku、他は sonnet） |
| ナレッジ蓄積 | 準拠 | 反復的最適化ループに対する knowledge.md が有界サイズ（効果テーブル、バリエーションステータス、改善原則20行制限）・保持+統合方式で管理されている。proven-techniques.md も Section ごとの上限で管理 |
| エラー耐性 | 準拠 | Phase 3/4 で部分失敗時の AskUserQuestion 分岐あり。perspective 検証失敗時の中断あり。過剰なエラーハンドリングは検出されず |
| 成果物の構造検証 | 部分的 | perspective 生成時に必須セクション検証あり（Step 6）。他の最終成果物（knowledge.md, レポート等）には構造検証なし |
| ファイルスコープ | 非準拠 | `.claude/skills/agent_bench/perspectives/` および `.agent_audit/{agent_name}/` への外部参照が存在する |

#### 良い点
- コンテキスト節約原則が明確に定義され、サブエージェント間のデータ受け渡しがファイル経由で統一されている（3ホップパターンなし）
- サブエージェントの返答行数が明示され（1行, 7行, 構造化サマリ等）、親コンテキストに保持される情報が最小化されている
- 反復的最適化ループに対する知見蓄積の仕組み（knowledge.md, proven-techniques.md）が有界サイズ・保持+統合方式で適切に設計されている
