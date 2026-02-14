## 重大な問題

### C-1: 外部パス参照の不整合 [efficiency, stability, architecture, effectiveness]
- 対象: SKILL.md 全体、全テンプレート
- 内容: 全ての外部参照が `.claude/skills/agent_bench/` を指しているが、実際のスキルディレクトリは `.claude/skills/agent_bench_new/` である。これにより perspective フォールバック検索（Phase 0 Step 4-c）、テンプレート読み込み（全Phase）、外部ファイル参照（approach-catalog.md、proven-techniques.md等）が全て失敗し、スキルが正常に機能しない
- 推奨: 全ての `.claude/skills/agent_bench/` を `.claude/skills/agent_bench_new/` に置換する。該当箇所は54行、74行、81行、92-95行、124行、128行、146行、151行、165行、174行、184行、186行、249行、251行、272行、324行、336行を含む全参照
- impact: high, effort: low

### C-2: Phase 0/1/2/5/6 のサブエージェント失敗時の処理フローが未定義 [architecture]
- 対象: SKILL.md（Phase 0, 1A, 1B, 2, 5, 6）
- 内容: Phase 3 と Phase 4 は失敗時の分岐フロー（再試行/除外/中断）が明示されているが、他のフェーズは「暗黙的にエラー伝播」と推測されるのみ。perspective 自動生成（Step 3-6）、knowledge 初期化、Phase 1A/1B、Phase 2、Phase 5 の委譲サブエージェントが失敗した場合、失敗時のユーザー向けメッセージ（原因説明、対処選択肢、復旧手順）が存在せず、サブエージェント失敗時にスキルが異常終了する可能性がある
- 推奨: 各フェーズに明示的なエラーハンドリング分岐を追加する。最低限「エラー内容を出力し、AskUserQuestion で (1)再試行、(2)該当ステップを中断してファイルを手動修正、(3)スキルを終了、から選択させる」を記載する
- impact: high, effort: medium

### C-4: Phase 1B の大規模変更を一括承認（audit 統合） [ux]
- 対象: Phase 1B（audit 統合）
- 内容: `.agent_audit/{agent_name}/audit-*.md` の分析結果を統合する際、複数の改善提案を個別承認なしで一括処理する可能性がある。audit で検出された問題は独立した提案であり、個別に承認・却下を判断すべきだが、現状は全て自動統合される
- 推奨: audit 統合時に検出された改善提案のリストをユーザーに提示し、AskUserQuestion で「全て統合/個別選択/統合をスキップ」を選択させる。個別選択の場合は各提案に対して「統合/除外」を確認する
- impact: high, effort: medium

### C-5: Phase 3 エラーハンドリングの条件分岐不完全 [stability]
- 対象: SKILL.md 229-236行（Phase 3 エラーハンドリング）
- 内容: 「各プロンプトに最低1回の成功結果がある」場合と「成功結果が0回」の分岐はあるが、「ベースラインが失敗したが一部バリアントは成功」のケースの明示的な処理がない。ベースライン失敗時にスコア比較ができないため、該当ラウンドの評価が無効になる
- 推奨: ベースライン失敗時の分岐を追加する。「ベースラインの成功結果が0回の場合: AskUserQuestion で (1)ベースライン再試行、(2)該当ラウンドを中断してエージェント定義を修正、(3)スキルを終了、から選択させる」を記載
- impact: high, effort: medium

### C-6: Phase 1B パス変数の未定義（audit_findings_paths） [stability]
- 対象: SKILL.md 174行、templates/phase1b-variant-generation.md 8-9行
- 内容: テンプレート側で `{audit_dim1_path}` と `{audit_dim2_path}` が言及されているが、SKILL.md の Phase 1B のパス変数リストでは `{audit_findings_paths}` というカンマ区切りの1変数として定義されている。変数名の不一致によりテンプレートが正しく動作しない
- 推奨: SKILL.md 174行を修正する。「`{audit_findings_paths}` として渡す」を削除し、「`{audit_ce_path}`: audit-ce-*.md の検出結果（見つからない場合は空文字列）、`{audit_sa_path}`: audit-sa-*.md の検出結果（見つからない場合は空文字列）」に変更。テンプレート側も対応する変数名に修正
- impact: high, effort: medium

### C-7: SKILL.md が目標行数を超過 [efficiency]
- 対象: SKILL.md 全体
- 内容: 372行 > 目標250行で122行のオーバー。親コンテキストに不要な詳細が含まれている可能性がある
- 推奨: 詳細な処理手順をテンプレートファイルに移動し、SKILL.md では各フェーズの概要・パス変数・分岐条件のみを記載する。特に Phase 0 の perspective 自動生成（64-112行）、Phase 6 の性能推移テーブル生成ロジック（287-299行）を外部化候補とする
- impact: medium, effort: medium

### C-8: knowledge.md 更新の累積リスク（冪等性） [stability]
- 対象: templates/phase6a-knowledge-update.md 16-22行
- 内容: 「既存の原則を全て保持する（削除しない）」と「20行を超える場合は…統合または削除する」が並立しており、何回も実行すると削除基準が曖昧になる。累積実行で knowledge.md が肥大化または不整合になる可能性がある
- 推奨: 削除基準を明確化する。「20行を超える場合は、effect pt が最小かつ SD が最大の原則から優先的に統合/削除する。統合は同一カテゴリ内の2原則をマージする」と具体化
- impact: medium, effort: low

### C-9: Phase 6 サマリの上位項目件数が未定義 [stability]
- 対象: SKILL.md 356-371行（Phase 6 最終サマリ）
- 内容: 最終サマリのフォーマットで「効果のあったテクニック: {knowledge.md の上位項目}」とあるが、上位項目の件数が定義されていない。実行ごとに出力フォーマットが変動する可能性がある
- 推奨: 「効果のあったテクニック: {knowledge.md の効果確認テーブルから上位3件、形式: テクニック名(+効果pt)}」と具体化
- impact: medium, effort: low

## 改善提案

---
注: 改善提案を 7 件省略しました（合計 7 件中上位 0 件を表示）。省略された項目は次回実行で検出されます。
