### アーキテクチャレビュー結果

#### 重大な問題
- [外部スキル参照]: [SKILL.md, templates/phase1a-variant-generation.md, templates/phase1b-variant-generation.md] `.claude/skills/agent_bench/` への参照が19箇所。他スキル（agent_bench）のファイルを参照している。スキルが独立動作できず、agent_bench の変更に依存する。スキル間のカップリングが発生し、デプロイ時の動作保証がない。 [impact: high] [effort: medium]
- [Phase 3 インライン指示]: [SKILL.md:213-220] Phase 3 の評価実行サブエージェント指示（8行）がインライン化されている。7行超の指示はテンプレート外部化すべき。コンテキスト節約の原則に違反。 [impact: medium] [effort: low]
- [Phase 6 デプロイ指示]: [SKILL.md:308-313] Phase 6 のデプロイサブエージェント指示（6行）がインライン化されている。5行超の指示が非テンプレート化されているため、ワークフローの一貫性が欠如する。デプロイという重要操作の仕様が SKILL.md に埋め込まれており、変更管理が困難。 [impact: medium] [effort: low]

#### 改善提案
- [perspective 自動生成テンプレート参照]: [SKILL.md:81,92,124,146,166,184,249,272,324,336] サブエージェントへのテンプレート参照パスが `.claude/skills/agent_bench/templates/` を指している（10箇所）。agent_bench_new スキル内の `templates/` ディレクトリにファイルが存在するため、スキルディレクトリ内パスに修正すべき。現状では外部参照により独立性が損なわれている。 [impact: medium] [effort: low]
- [approach_catalog, proven_techniques 参照]: [SKILL.md:127,150-151,171-172,186,274,338, templates/phase1a-variant-generation.md:4-5, templates/phase1b-variant-generation.md:6,14] カタログファイルへの参照が `.claude/skills/agent_bench/` を指している（テンプレート内2箇所、SKILL.md内6箇所）。スキル内にファイルが存在するため、スキルディレクトリ内パスに修正すべき。 [impact: medium] [effort: low]
- [scoring_rubric, test_document_guide 参照]: [SKILL.md:186,251,274] 補助ファイルへの参照が `.claude/skills/agent_bench/` を指している。スキル内にファイルが存在するため、スキルディレクトリ内パスに修正すべき。 [impact: medium] [effort: low]
- [perspective フォールバック検索]: [SKILL.md:54] perspective 解決時のフォールバック検索が `.claude/skills/agent_bench/perspectives/{target}/{key}.md` を参照している。スキル内に perspectives ディレクトリが存在するため、スキル内パスに変更すべき。 [impact: low] [effort: low]
- [perspective 自動生成時の参照データ収集]: [SKILL.md:74] perspective 自動生成の Step 2 で `.claude/skills/agent_bench/perspectives/design/*.md` を Glob 検索している。スキル内に perspectives/design/ ディレクトリが存在するため、スキル内パスに変更すべき。 [impact: low] [effort: low]
- [エラー処理の非対称性]: [SKILL.md:261-264] Phase 4（採点）のエラー処理は全て明示されているが、Phase 1A/1B/2/5/6A/6B のサブエージェント失敗時の処理フローが SKILL.md に記載されていない。Phase 0 perspective 生成失敗時のみ「エラー出力して終了」と明記。統一的なエラーハンドリングポリシーを定義すべき。 [impact: medium] [effort: medium]

#### パターン準拠サマリ
| パターン | 状態 | 備考 |
|---------|------|------|
| テンプレート外部化 | 部分的 | Phase 3 (8行), Phase 6 デプロイ (6行) がインライン化。他の主要フェーズは全てテンプレート委譲 |
| サブエージェント委譲 | 準拠 | 全フェーズで「Read template + follow instructions + path variables」パターンを使用（Phase 3/6 デプロイは例外だが、指示は短い）。モデル選択は適切（haiku=デプロイ、sonnet=生成/判断） |
| ナレッジ蓄積 | 準拠 | 反復ループあり。knowledge.md で有界サイズ（20行制限）+ 保持+統合方式を採用。バリエーションステータステーブルで全履歴を追跡 |
| エラー耐性 | 部分的 | Phase 3/4 は詳細な分岐あり（部分失敗・プロンプト除外・リトライ）。Phase 0 は perspective 検証失敗→終了。他フェーズは処理フロー未定義 |
| 成果物の構造検証 | 部分的 | perspective 生成時のみ必須セクション検証あり（Step 6）。knowledge.md, prompts, reports 等の最終成果物に対する構造検証記述なし |
| ファイルスコープ | 非準拠 | `.claude/skills/agent_bench/` への外部参照が19箇所。スキルディレクトリ内に同一ファイルが存在するため、パス修正のみで解消可能 |

#### 良い点
- 3ホップパターン完全排除。全フェーズでサブエージェント間のデータ受け渡しがファイル経由。親は要約・メタデータ（7行サマリ、1行確認等）のみ保持し、コンテキスト節約の原則を徹底している
- knowledge.md の有界サイズ管理が詳細に設計されている（バリエーションステータステーブル、20行制限の一般化原則、保持+統合方式、サイズ超過時の統合/削除ルール）
- Phase 3/4 の並列実行時の部分失敗処理フローが詳細に定義され、ユーザー選択肢（リトライ/除外/中断）が明示されている
