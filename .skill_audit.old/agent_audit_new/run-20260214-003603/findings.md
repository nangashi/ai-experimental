## 重大な問題

### C-1: スキルディレクトリ外への参照 [architecture]
- 対象: SKILL.md:174 (agent_bench 出力ディレクトリへの直接参照)
- 内容: Phase 1 で `.agent_audit/{agent_name}/audit-*.md` を参照しているが、これは `.agent_bench/` スキルの成果物を外部参照している。2つのスキルが結合しており、agent_bench 単独での動作が不可能
- 推奨: agent_audit_new スキル内で独立した構造にすべき
- impact: high, effort: high

### C-2: 大規模外部スキル埋め込み [architecture]
- 対象: agent_audit_new/agent_bench/ (agent_bench スキル全体が内包)
- 内容: agent_audit_new ディレクトリ内に agent_bench スキル全体（372行のSKILL.md + 20個以上のテンプレート・補助ファイル）が埋め込まれている。これは「スキルディレクトリ外のパスを参照する代わりにスキル内へのコピー」の原則を誤適用したもの
- 推奨: 別スキルは独立ディレクトリに配置すべき
- impact: high, effort: high

## 改善提案

### I-1: 欠落ステップ: agent_bench 連携のデータフロー検証欠落 [effectiveness, stability]
- 対象: SKILL.md:174 (Phase 1B)
- 内容: SKILL.md 174行目で agent_bench の audit findings 参照が外部参照リストに記載されているが、実際にこのデータフローを使用するロジックが Phase 1 に存在しない。agent_bench の audit-*.md を読み込んで次元エージェントに渡す処理が Phase 1 に明示されていないため、agent_bench との連携機能が動作しない
- 推奨: Phase 1 で `.agent_bench/{agent_name}/audit-*.md` を検索し、存在する場合は各次元エージェントに additional_context として渡す処理を追加すべき。または、この機能が不要な場合は参照リストから削除すべき
- impact: medium, effort: medium

### I-2: 出力フォーマット決定性: Phase 1サブエージェント返答解析の脆弱性 [stability]
- 対象: SKILL.md:141-146 (Phase 1)
- 内容: Phase 1サブエージェントに「以下の1行フォーマット**のみ**で返答してください」と指示しているが、サブエージェントが実際にこのフォーマット以外の出力を含む可能性がある。親エージェントはfindingsファイルの存在のみで成否判定するため、「返答の最終行を抽出」等の解析指示がない場合、Phase 1完了サマリで表示される件数情報（critical/improvement/info）の取得が不安定になる
- 推奨: 返答からフォーマット行を抽出する明示的指示を追加するか、またはサマリ表示をfindingsファイルのGrepベースに変更すべき
- impact: medium, effort: low

### I-3: 条件分岐の適正化: Phase 1部分失敗時の主経路不明 [stability]
- 対象: SKILL.md:148-160 (Phase 1エラーハンドリング)
- 内容: 全失敗時は終了、critical+improvement=0時はPhase 2スキップという分岐は明示されているが、「部分失敗かつcritical+improvement>0」の場合の主経路（Phase 2へ進むか、警告後に続行確認するか）が暗黙的。現在の記述では「部分失敗時は警告継続」（行153）とあるが、これが成功した次元のfindingsでPhase 2へ進むという意味なのか、警告表示後にAskUserQuestionで確認するのかが曖昧
- 推奨: 主経路を明示すべき
- impact: medium, effort: low

### I-4: 条件分岐の適正化: Phase 2 Step 2a per-item承認の「残りすべて承認」後の動作 [stability]
- 対象: SKILL.md:189-206 (Phase 2 Step 2a)
- 内容: per-item承認ループで「残りすべて承認」を選択した場合、「ループを終了する」（行205）とあるが、ループ終了後の処理（未確認のfindingsをどう扱うか、承認リストに追加するかスキップするか）が明示されていない。「残りすべて承認」は「未確認の全指摘を承認としてループを終了」（行205）と記述されているが、この承認状態をどう記録してStep 3へ渡すかが暗黙的
- 推奨: 明示的な処理記述を追加すべき
- impact: medium, effort: low

### I-5: 条件分岐の適正化: Phase 2検証失敗時の「いいえ」選択後の動作 [stability]
- 対象: SKILL.md:253-263 (Phase 2検証ステップ)
- 内容: 検証失敗時にロールバック確認で「いいえ」を選択した場合、「Phase 3で警告のみ表示」（行263）とあるが、この警告の具体的内容と、バックアップパスの記録を維持するかが明示されていない。Phase 3のテキスト出力フォーマット（行282-293）には検証失敗時の警告表示が含まれていないため、Phase 3のフォーマットにこのケースの出力仕様を追加すべき
- 推奨: Phase 3のフォーマットにこのケースの出力仕様を追加すべき
- impact: medium, effort: low

### I-6: アンチパターンカタログの読み込みタイミング [efficiency]
- 対象: agents/*/*.md (各次元エージェント)
- 内容: 各次元サブエージェントが個別にアンチパターンカタログを Read しているが、同一カタログ（例: instruction-clarity.md）を全グループが読み込むケースがある
- 推奨: 親が Phase 0 で共通カタログを Read し、サブエージェント起動時にファイルパスのみ渡す方式に変更することで、重複 Read を削減できる（推定節約量: サブエージェントあたり約70-90トークン × 6次元 = 420-540トークン）
- impact: medium, effort: high

### I-7: エージェント定義の重複 Read [efficiency]
- 対象: SKILL.md:Phase 0 Step 2, Phase 2 検証ステップ (行256)
- 内容: SKILL.md Phase 0 Step 2でエージェント定義を読み込んで `{agent_content}` に保持するが、Phase 2 検証ステップ（行256）で再度 Read している。グループ分類後、親コンテキストにエージェント定義全文を保持する必要はなく、検証時の1回 Read のみで十分
- 推奨: Phase 0 での Read を削除し、検証時の1回 Read のみに変更すべき（推定節約量: 約300-500トークン）
- impact: medium, effort: low

### I-8: 冪等性: Phase 2 audit-approved.md再実行時の扱い [stability]
- 対象: SKILL.md:210 (Phase 2 Step 3)
- 内容: Phase 2で`.agent_audit/{agent_name}/audit-approved.md`を保存する際、既存のaudit-approved.mdの扱いが未定義。Phase 7aでaudit-*.mdを削除しているが、audit-approved.mdは削除されない。再実行時に前回の承認結果が上書きされるのか、累積されるのか、エラーになるのかが不明
- 推奨: 再実行時の動作を明示するか、Phase 0でaudit-approved.mdも削除すべき
- impact: low, effort: low
