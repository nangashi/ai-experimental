### アーキテクチャレビュー結果

#### 重大な問題
なし

#### 改善提案
- [Phase 3 直接指示の外部化]: [SKILL.md Line 235-242] 評価実行サブエージェントに7行の直接指示を渡している。テンプレートファイルへの外部化を推奨 [impact: medium] [effort: low]
- [Phase 6 Step 1 直接指示の外部化]: [SKILL.md Line 328-335] デプロイサブエージェントに8行の直接指示を渡している。テンプレートファイルへの外部化を推奨 [impact: medium] [effort: low]
- [Phase 0 perspective.md 重複書込み]: [SKILL.md Line 72] perspective.md の存在確認後、「存在しない場合のみ」Write で保存するとあるが、同一ラウンドで再実行時に Read → Write が複数回発生する可能性がある。既に resolved-issues.md で冪等性が記録されているが、記述が「存在しない場合のみ」に留まり、冪等性保証のロジックが不明確 [impact: low] [effort: low]
- [Phase 1B Deep モード時のカタログ読込み条件]: [templates/phase1b-variant-generation.md Line 17] Deep モード選択時に approach_catalog_path を Read するとあるが、SKILL.md Line 191 では変数として渡されている。テンプレート側で「Deep モードの場合のみ Read」という条件分岐が記述されているが、親が常に変数を渡すため、テンプレート側での条件分岐が機能しない [impact: medium] [effort: low]
- [Phase 0 Step 4 批評結果の統合ロジック]: [SKILL.md Line 120-122] 4つの批評ファイルから「重大な問題」「改善提案」セクションを抽出して統合する処理が記述されているが、抽出・統合の具体的手順（セクション見出しの判定、重複の判定基準「最も具体的な記述」の定義）が曖昧 [impact: low] [effort: low]

#### パターン準拠サマリ
| パターン | 状態 | 備考 |
|---------|------|------|
| テンプレート外部化 | 部分的 | Phase 3, Phase 6 Step 1 の直接指示（7-8行）が未外部化。他は全て外部化済み |
| サブエージェント委譲 | 準拠 | 全フェーズで「Read template + follow instructions + path variables」パターンを使用。Phase 3/6 Step 1 のみ直接指示だが、モデル指定（sonnet/haiku）は適切 |
| ナレッジ蓄積 | 準拠 | 反復ループあり。knowledge.md で知見を蓄積（有界サイズ: 改善のための考慮事項は20行上限、保持+統合方式を採用）。proven-techniques.md もサイズ制限（Section 1/2: 8件、Section 3: 7件）と統合ルールあり |
| エラー耐性 | 準拠 | Phase 3/4 で部分失敗時の続行閾値（各プロンプト最低1回成功）を定義。過剰なエラー耐性記述なし。Phase 0 perspective 自動生成の再生成は1回のみに制限 |
| 成果物の構造検証 | 準拠 | Phase 0 Step 6 で perspective.md の必須セクション検証を実施。他の成果物（プロンプト、テスト文書、レポート等）はサブエージェントに委譲されており、テンプレート側で検証が記述されている |
| ファイルスコープ | 準拠 | 外部参照は `.agent_audit/{agent_name}/audit-*.md` のみ（agent_audit スキルとの連携、設計意図）。perspectives/ および templates/ への参照は全て agent_bench_new 配下 |

#### 良い点
- [委譲モデルの一貫性]: Phase 0 perspective 自動生成の4並列批評、Phase 3 の並列評価、Phase 4 の並列採点で委譲パターンが統一されている。サブエージェント間のデータ受け渡しは全てファイル経由で行われ、親コンテキストに大量データを保持しない設計
- [コンテキスト節約の徹底]: SKILL.md で「コンテキスト節約の原則」を明示し、サブエージェント返答を最小限（1-7行サマリ）に制限。詳細はファイル保存。Phase 5 の7行サマリ、Phase 4 のスコアサマリ（2行）等、全フェーズで原則を遵守
- [ナレッジ統合ルールの明示]: Phase 6 Step 2A の「保持+統合方式」（preserve + integrate、20行上限）と Phase 6 Step 2B の昇格条件（Tier 1/2/3）により、知見が無制限に蓄積されない設計。統合ロジックも具体的（類似度判定、エビデンス強度）
