## 重大な問題

### C-1: SKILL.md が目標を超過 [efficiency]
- 対象: SKILL.md
- 内容: 415行 (目標: 250行以下) = 165行超過。親コンテキストが過剰に消費されている。ワークフローの詳細記述が冗長
- 推奨: 415行を Phase 別のサブファイルに分割可能。例: workflow-phase0.md, workflow-phase1.md 等をスキルディレクトリに配置し、SKILL.md は概要のみ記載する。各 Phase の詳細記述 (行40-398) を外部化すれば約250行削減可能
- impact: high, effort: medium

### C-2: 目的の明確性: 成功基準の一部が自己矛盾 [effectiveness]
- 対象: SKILL.md:18-24, scoring-rubric.md:65-69
- 内容: SKILL.md 18-24行の成功基準に「収束判定: 3ラウンド連続でベースラインが推奨された場合」とあるが、scoring-rubric.md 65-69行では「2ラウンド連続で改善幅 < 0.5pt」で収束判定となっており、基準が矛盾している。また「改善率上限: 初期スコアから +15% 以上」は具体的だが、初期スコアが低い場合（例: 3.0pt）の +15% は 0.45pt となり、「改善幅 < 0.5pt」の収束判定と競合する
- 推奨: 収束判定基準を統一（2ラウンド連続 vs 3ラウンド連続）し、改善率上限と収束判定の競合を解消する明確なルールを定義すべき
- impact: high, effort: low

### C-3: 欠落ステップ: Phase 6 最終サマリに記載された「ラウンド別性能推移テーブル」の生成処理が不在 [effectiveness]
- 対象: SKILL.md:400-414
- 内容: SKILL.md 400-414行の最終サマリには「## ラウンド別性能推移」テーブルを出力すると記載されているが、このテーブルを生成する処理がワークフロー内に存在しない。phase6-performance-table.md（Step 1）は AskUserQuestion で提示するテーブルを生成するが、最終サマリ用のテーブル生成は未定義。knowledge.md に「ラウンド別スコア推移」テーブルが存在するが、最終サマリで要求される形式（Round, Best Score, Δ from Initial, Applied Technique, Result）とは異なる
- 推奨: Phase 6 で最終サマリ用のラウンド別性能推移テーブル生成処理を追加するか、SKILL.md の最終サマリ形式を knowledge.md のテーブル形式に合わせるべき
- impact: high, effort: medium

### C-4: 出力フォーマット決定性: サブエージェント返答の行数指定に曖昧性 [stability]
- 対象: phase0-perspective-generation.md:61-63, phase0-perspective-generation-simple.md:25-28
- 内容: 「検証成功 → 以下の**1行のみ**を返答する（他のテキストは含めない）」と記述されているが、STEP 2とSTEP 3で中間サブエージェント（generate-perspective.md）を起動しており、最終返答が1行であることは明示されているが、中間サブエージェントの返答行数が未定義。generate-perspective.md に「サマリ」としか記載がなく行数・フォーマットが不明確
- 推奨: generate-perspective.md に「以下の1行のみを返答:」と明示すべき
- impact: medium, effort: low

### C-5: 参照整合性: 存在しないディレクトリへの参照 [stability]
- 対象: SKILL.md:210-213
- 内容: agent_audit の出力ディレクトリ `.agent_audit/{agent_name}/audit-*.md` への参照があるが、agent_audit スキルが実行されていない場合はディレクトリ自体が存在しない。Phase 1B では `test -d .agent_audit/{agent_name}` で確認しているが、ディレクトリが存在してもファイルが存在しない場合のハンドリングが不明確
- 推奨: Glob 実行時にファイルが見つからない場合のデフォルト動作を明記すべき（空文字列として扱う旨を明示）
- impact: medium, effort: low

### C-6: 冪等性: knowledge.md 更新時の並行実行リスク [stability]
- 対象: phase6-step2-workflow.md:51-67
- 内容: Step 3 で「以下の2つを Task ツールで並列実行する」とあり、A) proven-techniques.md 更新と B) 次アクション選択を並列実行する。しかし A) は knowledge.md を Read する（phase6b-proven-techniques-update.md line 4）ため、Step 2 で knowledge.md が更新された直後に並列読み込みが発生し、ファイルシステムの遅延により古い内容を読む可能性がある
- 推奨: Step 2 の knowledge.md 更新完了を明示的に待機してから Step 3 を開始するか、A) と B) の並列実行を直列化すべき
- impact: medium, effort: medium

### C-7: 条件分岐の完全性: フォールバック検索失敗時のエラーメッセージ不足 [stability]
- 対象: phase0-perspective-resolution.md:22-23, 29
- 内容: Step 2 でパターン一致しない場合とStep 3 で読み込み失敗時に「失敗として返答し終了」とあるが、具体的なエラーメッセージ内容が定義されていない。SKILL.md line 71-72 では「サブエージェント失敗時: パースペクティブ自動生成（後述）を実行する」とあるため、失敗の種類（パターン不一致 vs ファイル不在）を区別できる返答が必要
- 推奨: 失敗理由を明示した返答フォーマットを定義すべき（例: 「失敗: パターン不一致」「失敗: ファイル不在 - {path}」）
- impact: medium, effort: low

### C-8: 参照整合性: SKILL.md で定義されていない変数を使用 [stability]
- 対象: phase0-perspective-generation.md:11-12
- 内容: エージェント定義が不足している場合に AskUserQuestion でヒアリングして `{user_requirements}` に追加するとあるが、この変数は SKILL.md の Phase 0 で「Phase 0 の perspective 自動生成で `{user_requirements}` を参照する」と言及されているものの、パス変数リストには含まれていない（line 66-69）。またこのテンプレートに渡される user_requirements は Phase 0 で収集したものだが、phase0-perspective-generation.md はその後にさらに AskUserQuestion で追加収集する動作が定義されており、変数のスコープが不明確
- 推奨: user_requirements のスコープと更新フローを SKILL.md のパス変数セクションで明確化すべき
- impact: medium, effort: medium

### C-9: データフロー妥当性: Phase 6 Step 2の並列実行で次アクション選択の依存関係が不明確 [effectiveness]
- 対象: SKILL.md:209-216, phase6-step2-workflow.md
- 内容: SKILL.md 209-216行では「Phase 1B で agent_audit の分析結果を参照」と記載されているが、phase6-step2-workflow.md（Step 3）では proven-techniques 更新（A）と次アクション選択（B）を並列実行し、Step 4 で「A の完了を待ってから返答」と指定している。しかし次アクション選択（B）は AskUserQuestion を含むため非同期実行が前提だが、A の完了待ちとの整合性が不明確。B が A より先に完了した場合の処理フローが定義されていない
- 推奨: AskUserQuestion を含む並列実行は真の並列化の恩恵がないため、A) proven-techniques.md 更新 → B) 次アクション選択の逐次処理に変更すべき
- impact: medium, effort: medium

## 改善提案

### I-1: Phase 3 の親コンテキスト保持 [efficiency]
- 対象: SKILL.md:285, templates/phase3-error-handling.md
- 内容: Phase 3 で全サブエージェント完了後、親が error-handling テンプレートを Read して直接実行する設計。エラーハンドリングロジック (45行) が親コンテキストに展開される。親がサブエージェント管理と分岐ロジック両方を保持。推定浪費: 約45行のテンプレート展開
- 推奨: 親が直接実行するロジック (45行) をサブエージェント化し、返答として分岐判定 (1行: continue/retry/abort) のみ受け取る設計に変更可能。親コンテキスト節約: 約40行
- impact: medium, effort: medium

### I-3: エッジケース処理記述: Phase 3 の部分失敗時の Run 単位情報が phase4-scoring.md に伝達されない [effectiveness]
- 対象: phase3-error-handling.md, phase4-scoring.md
- 内容: phase3-error-handling.md の条件3（ベースライン成功・バリアント部分失敗）では「Run が1回のみのプロンプトは SD = N/A」と記載されているが、phase4-scoring.md では Run1/Run2 の両方を Read で読み込むことを前提としている。Run が1回のみの場合のファイル不在処理が記述されていない
- 推奨: phase4-scoring.md に Run が1回のみの場合のファイル不在処理ロジックを追加すべき
- impact: medium, effort: medium

### I-4: データフロー妥当性: Phase 5 で参照する scoring_file_paths が Phase 4 で除外されたプロンプトを含む可能性 [effectiveness]
- 対象: SKILL.md:325-326, phase5-analysis-report.md
- 内容: Phase 4 で「失敗プロンプトを除外して続行」を選択した場合、SKILL.md 325-326行の scoring_file_paths にはどのプロンプトが含まれるかが明示されていない。Phase 5 は scoring_file_paths を全て Read するが、除外されたプロンプトのファイルが存在しない場合のエラー処理が phase5-analysis-report.md に記述されていない
- 推奨: Phase 5 テンプレートに、除外されたプロンプトのファイル不在時のエラー処理を追加すべき
- impact: medium, effort: low

### I-5: エラー通知: Phase 5のエラーメッセージが不十分 [ux]
- 対象: SKILL.md Phase 5
- 内容: サブエージェント失敗時の処理が「エラー内容を出力してスキルを終了する」のみで、対処法が記載されていない。Phase 1や Phase 2と同様に、具体的な対処法（比較レポート手動作成、採点ファイル再確認等）をエラーメッセージに含めるべき
- 推奨: エラーメッセージに具体的な対処法を追加する
- impact: medium, effort: low

### I-6: 出力フォーマット決定性: Phase 3 の並列実行完了後の集計方法が不明確 [stability]
- 対象: SKILL.md:271-290
- 内容: 「全サブエージェント完了後、親が templates/phase3-error-handling.md を Read で読み込み」とあるが、並列実行の成功数をどのように集計するのか（Task ツールの返答形式、エラー検出方法）が明記されていない。「成功数を集計し分岐する」とあるだけで、成功/失敗の判定基準が不明
- 推奨: 並列実行の成功数集計方法（Task ツールの返答形式、エラー検出方法）を明記すべき
- impact: medium, effort: low

### I-7: 冪等性: バリアント生成時の既存ファイル確認のタイミング [stability]
- 対象: SKILL.md:142-154, 185-197
- 内容: Phase 1A/1B でサブエージェント実行前に Glob で既存ファイルを確認し、AskUserQuestion で上書き確認を行うが、「上書き」選択後にサブエージェントが失敗した場合、次回実行時に再度上書き確認が表示される。サブエージェント失敗時のリトライフローが定義されていないため、ユーザーは手動で再実行する必要があり、同じ確認を繰り返すことになる
- 推奨: サブエージェント失敗時のリトライフローを定義し、上書き確認の繰り返しを防ぐべき
- impact: medium, effort: medium

### I-8: 条件分岐の完全性: Phase 6 Step 2 の knowledge.md 更新承認で却下後の再承認フローが不明確 [stability]
- 対象: phase6-step2-workflow.md:48-49
- 内容: 「却下の場合: AskUserQuestion で修正内容を確認し、手動で knowledge.md を Edit で修正する。再度サマリを提示し、承認を得る（1回のみ）」とあるが、再承認で再び却下された場合の動作が定義されていない。「1回のみ」が「修正の試行回数」を指すのか「再承認の試行回数」を指すのか曖昧
- 推奨: 再承認で却下された場合は警告を出力して元の内容を維持するか、スキルを終了するか、明示的に定義すべき
- impact: medium, effort: low

### I-9: 出力フォーマット決定性: Phase 5 の7行サマリのフォーマット詳細が不明確 [stability]
- 対象: SKILL.md:332-343, phase5-analysis-report.md
- 内容: 「サブエージェントの返答（7行サマリ）をテキスト出力してユーザーに提示する」とあり、phase5-analysis-report.md では「推奨判定基準に基づく7行サマリ返答」と記載されているが、7行の具体的なフィールド名と順序が SKILL.md の line 391-393 でしか定義されていない（recommended, reason, convergence, scores, variants, deploy_info, user_summary）。テンプレート側にフォーマット定義がないため、サブエージェントが異なる順序で返答する可能性がある
- 推奨: phase5-analysis-report.md にフォーマット定義を追加し、7行の順序を明確化すべき
- impact: medium, effort: low
