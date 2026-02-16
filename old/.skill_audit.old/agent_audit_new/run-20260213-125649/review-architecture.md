### アーキテクチャレビュー結果

#### 重大な問題
- [Phase 3 削除処理の競合リスク]: [SKILL.md:222] Phase 3 開始前の `rm -f .agent_bench/{agent_name}/results/v{NNN}-*.md` が並列実行・再試行時に既存結果ファイルを削除する可能性がある。再試行分岐が複数ありうる処理で冪等性を担保できない [impact: medium] [effort: low]
- [Phase 3/4 エラーハンドリングの未定義分岐]: [SKILL.md:259-262, 287-290] 再試行失敗時の処理が「再度確認を求める」と曖昧。無限ループまたは中断判定基準が不明確 [impact: medium] [effort: low]
- [Phase 0 perspective 検証失敗時のデータ損失]: [SKILL.md:127] 必須セクション検証失敗時に「エラー出力してスキル終了」としているが、Step 5 で再生成した perspective が検証失敗した場合、Step 3 の初期生成版も失われる（上書き済み）。リカバリ不能 [impact: medium] [effort: medium]
- [Phase 1B の audit 結果検索ロジックの曖昧性]: [SKILL.md:193-197] 「最新ラウンドのファイルのみ抽出」の判定基準が未定義。run-YYYYMMDD-HHMMSS パターンのソート方法（辞書順/時刻順）、複数ディレクトリ存在時の処理が不明。実行時エラーまたは誤ファイル参照のリスク [impact: medium] [effort: low]
- [Phase 6B と Phase 6C の並列実行の記述誤り]: [SKILL.md:371-381] 「B) とC) の完了を待ってから」としているが、C) が AskUserQuestion であり並列実行不可。C) の結果が確定しないと次アクション分岐できない。記述が実装フローと矛盾 [impact: low] [effort: low]

#### 改善提案
- [Phase 0 の agent_path 読み込み失敗時の処理不足]: [SKILL.md:42] エージェントファイル読み込み失敗時に「エラー出力して終了」としているが、ファイルパスの typo や権限エラーの可能性がある。パス再確認または新規作成モードへのフォールバック提案を検討すべき [impact: low] [effort: low]
- [Phase 3/4 の部分失敗時の判定基準の可視性]: [SKILL.md:258, 289] 「各プロンプトに最低1回の成功結果」「ベースライン失敗時は中断」の基準は妥当だが、SKILL.md 内に明示的なルールセクションとして抽出すべき（フローから基準を推測する必要がある） [impact: low] [effort: low]
- [Phase 6A デプロイ時の差分プレビュー処理の重複]: [SKILL.md:336, phase6a-deploy.md:4] 親で diff 実行後、サブエージェントで再度差分比較している。サブエージェントの差分比較ステップは冗長 [impact: low] [effort: low]
- [knowledge.md 構造検証の再初期化ロジックの冗長性]: [SKILL.md:134] 検証失敗時に「エラー出力し、knowledge.md を再初期化して Phase 1A へ」としているが、エラー出力は不要（再初期化で自動復旧する）。ユーザーへの通知は警告レベルで十分 [impact: low] [effort: low]
- [perspective-source.md と perspective.md の分離目的の不透明性]: [SKILL.md:70] 「Phase 4 採点バイアス防止のため問題バンクは含めない」としているが、Phase 4 は answer-key.md を参照するため perspective.md に問題バンクがあってもバイアスは発生しない。2ファイル分離の根拠が不明確 [impact: low] [effort: medium]
- [Phase 0 の knowledge.md 検証失敗時の処理順序]: [SKILL.md:133-135] 検証失敗時に「エラー出力 → 再初期化 → Phase 1A」としているが、再初期化（knowledge-init-template サブエージェント）の失敗時処理が未定義。再初期化失敗時はスキル終了すべき [impact: low] [effort: low]
- [Phase 1A/1B の返答フォーマットの一貫性欠如]: [phase1a-variant-generation.md:22-40, phase1b-variant-generation.md:20-33] Phase 1A は構造分析テーブルを含むが Phase 1B は含まない。親が参照するフィールドが異なるため、サブエージェント返答の構造検証が困難 [impact: low] [effort: low]

#### パターン準拠サマリ
| パターン | 状態 | 備考 |
|---------|------|------|
| テンプレート外部化 | 準拠 | 全サブエージェント指示がテンプレートファイルに外部化されている（最短12行、最長215行）。SKILL.md 内のインライン指示は5行以下 |
| サブエージェント委譲 | 準拠 | 全フェーズで「Read template + follow instructions + path variables」パターンを一貫使用。モデル選択も適切（Phase 6A deploy のみ haiku、他は全て sonnet） |
| ナレッジ蓄積 | 準拠 | 反復最適化ループあり。knowledge.md（有界: 改善考慮事項 最大20行）と proven-techniques.md（有界: Section 1-3 各最大8/8/7エントリ）で知見蓄積。保持+統合方式を採用（phase6a-knowledge-update.md:17-18, phase6b-proven-techniques-update.md:32） |
| エラー耐性 | 部分的 | Phase 0（ファイル不在時フォールバック）、Phase 3/4（部分失敗時の再試行/除外/中断分岐）は定義済み。Phase 3/4 の再試行失敗時の処理が曖昧（無限ループリスク）、Phase 1B の audit 結果検索失敗時の処理が未定義 |
| 成果物の構造検証 | 部分的 | knowledge.md（必須セクション検証: SKILL.md:132-133）、perspective（必須セクション検証: SKILL.md:125）は検証あり。prompts/v{NNN}-*.md（Benchmark Metadata の Variation ID 存在確認）、answer-key.md、reports/round-{NNN}-comparison.md は構造検証なし |
| ファイルスコープ | 部分的 | スキル外参照: `.agent_audit/{agent_name}/run-*/audit-*.md`（SKILL.md:193）、`.claude/skills/agent_bench_new/perspectives/{target}/{key}.md`（SKILL.md:64）。audit 結果は外部スキル、perspectives は自スキル内だが {target}/{key} の動的パス解決が必要 |

#### 良い点
- [サブエージェント間のファイル経由データフロー]: 全フェーズで詳細データをファイル保存し、サブエージェント間で直接参照。親は累計ラウンド数・パス変数のみ保持。3ホップパターンなし（analysis.md:98 確認済み）
- [並列実行の積極活用]: Phase 0（perspective 批評 4並列）、Phase 3（プロンプト数×2回並列）、Phase 4（プロンプト数並列）で並列 Task 実行。コンテキスト効率最適化
- [部分完了時の継続可能性設計]: Phase 3/4 で全失敗でなければ成功プロンプトのみで継続可能（SD = N/A で処理）。ベースライン失敗時のみ中断。実用性重視の設計
