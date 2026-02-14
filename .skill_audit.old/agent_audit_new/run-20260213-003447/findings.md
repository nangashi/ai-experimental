## 重大な問題

### C-1: Phase 2 Step 1 失敗時の処理フローが未定義 [architecture, effectiveness, stability]
- 対象: SKILL.md:89
- 内容: analysis.md の記述「Phase 2 Step 1 失敗: 未定義（SKILL.md に記載なし）」を確認。findings 収集失敗時の処理フロー（中止/継続判定、エラーメッセージ）が定義されていない。Phase 1 部分失敗と異なり、Phase 2 Step 1 失敗は findings-summary.md が生成されないため Step 2 以降の処理が継続できない
- 推奨: Phase 2 Step 1 のサブエージェント完了後に、findings-summary.md の存在確認と Read 成否を判定する処理を追加。失敗時: 「✗ エラー: findings の収集に失敗しました: {エラー詳細}\nPhase 1 で生成された findings ファイルを手動で確認してください: .agent_audit/{agent_name}/audit-*.md」とエラー出力し、処理を終了する
- impact: high, effort: low

### C-2: Fast mode の部分失敗時の扱いが未定義 [stability]
- 対象: SKILL.md:93, 195-199
- 内容: Phase 0 で fast_mode フラグを設定するが、Phase 1 部分失敗時の継続確認（AskUserQuestion）が Fast mode でスキップされるかが不明。Fast mode の設計思想（中間確認スキップ）から推測すると自動継続が妥当だが、明示的な記述がないため実装の一貫性が担保されない
- 推奨: Phase 1 の部分失敗判定後、Fast mode 時の処理を明示: 「{fast_mode} が true の場合、継続確認をスキップし、成功次元のみで自動的に Phase 2 へ進む（テキスト出力: "Fast mode: {成功数}次元で Phase 2 へ自動継続します"）。{fast_mode} が false の場合、AskUserQuestion で継続/中止をユーザーに確認する」
- impact: high, effort: low

### C-3: Phase 2 Step 4 のサブエージェント処理中の進捗表示が不足 [ux]
- 対象: SKILL.md:289
- 内容: 289行目で「改善を適用しています...」とのみ出力し、サブエージェント開始・完了の表示がない。実際の処理内容（何件の findings を処理中か、どの finding ID を処理中かなど）が不明
- 推奨: サブエージェント開始前に「{承認数}件の改善を適用中（finding IDs: {ID リスト}）...」、完了時に「✓ 改善適用完了: {変更数}件の変更を実施」と出力する
- impact: high, effort: low

### C-4: Phase 2 Step 1 失敗時の処理が未定義（重複） [ux]
- 対象: Phase 2 Step 1
- 内容: analysis.md の F.エラーハンドリングパターンで「Phase 2 Step 1 失敗: 未定義（SKILL.md に記載なし）」と記載されている。findings 収集失敗時の挙動（中止/継続/リトライ）が不明
- 推奨: Phase 2 Step 1 失敗時のエラーメッセージと処理フロー（中止）を明示する
- impact: high, effort: medium

### C-5: SKILL.md 行数超過 [efficiency]
- 対象: SKILL.md
- 内容: SKILL.md は352行で、目標の250行を102行超過している。主な原因: Phase 2 Step 1 のサブエージェント prompt が17行（L224-240）、Phase 2 Step 2a の詳細ロジックが3行（L279）、検証ステップの詳細ロジックが15行（L311-323）。これらを外部化すべき
- 推奨: Phase 2 Step 1 の findings 収集ロジックを `templates/collect-findings.md` に外部化（17行削減）、検証ステップを `templates/validate-agent-structure.md` に外部化（15行削減）することで合計32行削減し、目標（250行）に近づける
- impact: high, effort: medium

### C-6: 7行超の inline prompt [efficiency]
- 対象: SKILL.md:224-240
- 内容: Phase 2 Step 1 のサブエージェント prompt が17行の inline 記述。テンプレート外部化の原則（7行超はテンプレート化）に違反
- 推奨: `templates/collect-findings.md` を作成し、「Read template + follow instructions + path variables」パターンに変更する
- impact: medium, effort: low

### C-7: analysis.md 参照の未定義ケース処理が不完全 [stability]
- 対象: SKILL.md:319-322
- 内容: Phase 2 検証ステップで analysis.md が存在しない場合の外部参照整合性検証はスキップするが、存在する場合の Read 失敗時の処理が未定義
- 推奨: 検証ステップで Read 前にファイル存在確認を追加し、Read 失敗時はスキップではなく警告を出力する処理を明示する。例: "Read 失敗時: 「⚠ 警告: analysis.md の読み込みに失敗しました。外部参照整合性検証をスキップします」とテキスト出力し、検証は継続"
- impact: medium, effort: low

### C-8: 曖昧な判定基準（必須次元の定義） [stability]
- 対象: SKILL.md:194
- 内容: 「必須次元」の定義が暗黙的。「IC 次元が失敗 かつ 成功数 = 1」という条件は明示されているが、なぜ IC が必須なのかが説明されていない
- 推奨: Phase 0 で「IC（指示明確性）は全グループで共通の必須次元です」と明示し、Phase 1 の中止条件説明を「IC は全エージェントの基盤となる次元であるため、IC 失敗+他1次元のみ成功の場合は分析精度が不十分と判断し中止します」と具体化する
- impact: medium, effort: low

### C-9: findings ファイル上書き時の情報欠損リスク [stability]
- 対象: SKILL.md:156-158
- 内容: Phase 1 で既存 findings ファイルを上書きする際、過去の分析結果が消失するが、ユーザーが中断・再実行した場合のデータ復旧方法が提示されていない
- 推奨: 上書き前に既存ファイルを .agent_audit/{agent_name}/audit-{ID_PREFIX}.md.prev にバックアップし、「⚠ 既存の findings ファイル {M}件を上書きします（バックアップ: .prev 拡張子で保存）」とテキスト出力する処理を追加
- impact: medium, effort: low

## 改善提案

### I-1: Phase 2 Step 1 サブエージェント prompt の長さ（31行） [architecture]
- 対象: SKILL.md:223-256
- 内容: 「Read template + follow instructions」パターンを使用せず、31行の直接 prompt を渡している。テンプレート外部化（例: `templates/collect-findings.md`）を推奨
- 推奨: 外部化により、findings 抽出ロジックの改善時に SKILL.md の行数を削減でき、コンテキスト効率が向上する
- impact: medium, effort: medium

### I-2: テンプレートの細分化不足 [efficiency]
- 対象: SKILL.md
- 内容: Phase 2 Step 1 の findings 収集ロジック（境界検出、severity 抽出、title/次元名抽出、ソート、フォーマット）が17行の inline prompt に含まれる。検証ステップ（L311-323）も inline 記述
- 推奨: `templates/collect-findings.md` に Phase 2 Step 1 を外部化（17行削減）、検証ステップを `templates/validate-agent-structure.md` に外部化（15行削減）で合計32行削減
- impact: high, effort: medium

### I-3: 検証失敗時の自動ロールバック処理が宣言されていない [effectiveness]
- 対象: Phase 2 検証ステップ
- 内容: 「期待される成果物」で「変更済みエージェント定義」が宣言されているが、検証失敗時の自動ロールバック処理がワークフローに記述されていない。現在の実装では検証失敗時に警告を出力するのみで、破損した定義ファイルが残る可能性がある
- 推奨: 検証失敗時に自動ロールバックを実行し、Phase 3 サマリで「ロールバック実施」を報告する処理を追加することで、「変更済みエージェント定義」の成果物が常に構造的に有効である保証が強化できる
- impact: medium, effort: medium

### I-4: Phase 0 グループ分類の inline 処理 [efficiency]
- 対象: SKILL.md:100-108
- 内容: グループ分類は group-classification.md を参照するが、判定ロジック自体は親コンテキストで実行される。agent_content は平均157行あるため、これを保持すると親コンテキストが肥大化する
- 推奨: グループ分類をサブエージェント委譲に変更すれば、返答は `group: {agent_group}` の1行のみで済む（推定150行のコンテキスト節約）
- impact: medium, effort: medium

### I-5: Fast mode での Phase 1 部分失敗時の扱いが未記載 [architecture]
- 対象: analysis.md:74
- 内容: Fast mode での Phase 1 部分失敗時（成功数≧1かつ（IC成功 or 成功数≧2））の継続/中止処理が SKILL.md に明記されていない。Fast mode の設計思想（中間確認スキップ）から推測すると自動継続が妥当だが、明示的な記述がないため実装の一貫性が担保されない
- 推奨: SKILL.md に Fast mode での部分失敗時の自動継続処理を明記する
- impact: medium, effort: low

### I-6: 検証ステップの構造検証が最小限 [architecture]
- 対象: SKILL.md:314-317
- 内容: 現在の検証は YAML frontmatter と見出し行の存在確認のみ。最終成果物（変更後エージェント定義）に対する必須セクション（## Task, ### Steps 等）の存在確認、破損した Edit 操作の検出（不完全な置換、二重適用）が実装されていない
- 推奨: apply-improvements.md の「二重適用チェック」が存在するが、検証ステップでの最終確認がないため、サブエージェントのバグが検出されないリスクがある。必須セクション検証と破損検出を追加する
- impact: medium, effort: medium

### I-7: Phase 1 並列処理の進捗表示が不足 [ux]
- 対象: Phase 1:160
- 内容: 160行目で「{dim_count}次元を並列分析中...」と出力するが、各次元の開始・完了のタイミングが不明。Task の返答待ち中に何も表示されない
- 推奨: 各次元のサブエージェント開始時・完了時に進捗メッセージを出力する。例: 「次元 {次元名} 分析開始...」「✓ {次元名} 完了（{件数}件検出）」
- impact: medium, effort: low

### I-8: Phase 0 Step 4 のグループ分類結果の確認が欠落 [ux]
- 対象: Phase 0:100-107
- 内容: 100-107行目でグループ分類を自動実行するが、分類結果に対するユーザー確認がない。誤分類時に後続の分析次元が不適切になる可能性
- 推奨: グループ分類結果を出力後、AskUserQuestion でユーザーに確認を取る。例: 「グループ: {agent_group} と判定しました。正しいですか？（y/n/手動入力）」
- impact: medium, effort: low

### I-9: Phase 2 Step 1 のサブエージェント処理中の進捗表示が不足 [ux]
- 対象: Phase 2 Step 1:222
- 内容: 222行目で Task 起動するが、処理開始・完了のメッセージがない。findings 収集の対象ファイル数や処理状況が不明
- 推奨: サブエージェント開始前に「{次元数}次元から findings を収集中...」、完了時に「✓ findings 収集完了: critical {件数}件, improvement {件数}件」と出力する
- impact: medium, effort: low
