### 安定性レビュー結果

#### 重大な問題

- [参照整合性: 未定義パス変数]: [phase1b-variant-generation.md] [8-9行] `{audit_dim1_path}`, `{audit_dim2_path}` プレースホルダがテンプレート内に記載されているが、SKILL.md の Phase 1B (line 165-175) のパス変数リストに定義されていない → SKILL.md line 174 で Glob による動的検索後に `{audit_findings_paths}` として渡すと記載されているが、テンプレート側は個別の `{audit_dim1_path}`, `{audit_dim2_path}` を期待している。SKILL.md を修正して個別変数として定義するか、テンプレートを `{audit_findings_paths}` に統一する必要がある [impact: medium] [effort: low]

- [条件分岐の完全性: デフォルト処理の欠落]: [SKILL.md] [233-236行] Phase 3 評価実行失敗時の分岐で「再試行」を選択したがそれも失敗した場合の処理が未定義 → 「再試行は1回のみ」と記載されているが、再試行失敗後の動作（再度ユーザー確認か、自動中断か）が明示されていない。同様に Phase 4 (line 262-264) の再試行失敗時も未定義 [impact: medium] [effort: low]

- [参照整合性: 存在しないファイルパス]: [SKILL.md] [54行] `.claude/skills/agent_bench/perspectives/{target}/{key}.md` への参照があるが、実際のスキルディレクトリは `.claude/skills/agent_bench_new` であり、パスが不整合 → 正しいパスは `.claude/skills/agent_bench_new/perspectives/{target}/{key}.md` に修正すべき [impact: high] [effort: low]

- [参照整合性: 存在しないファイルパス]: [SKILL.md] [74, 81-96, 123, 146-175, 182-256, 270-341行] テンプレート・補助ファイルへの全パス参照が `.claude/skills/agent_bench/` で始まっているが、実際のスキルディレクトリは `.claude/skills/agent_bench_new` → 全ての `.claude/skills/agent_bench/` を `.claude/skills/agent_bench_new/` に置換する必要がある [impact: high] [effort: medium]

- [指示の具体性: サブエージェント返答フォーマット未指定]: [SKILL.md] [158行] Phase 1A の指示「サブエージェントの返答をテキスト出力し、Phase 2 へ進む」で、phase1a-variant-generation.md は複数セクション形式の返答を指定しているが、親が何行出力するかが明示されていない → 「サブエージェントの返答（複数セクション形式）をそのままテキスト出力し」と明示するか、返答行数の上限を記載すべき [impact: low] [effort: low]

#### 改善提案

- [出力フォーマット決定性: 曖昧な返答指示]: [phase1b-variant-generation.md] [20行] 「以下のフォーマットで結果サマリのみ返答する」と記載されているが、テーブル部分の行数が可変（バリアント数に依存）。親コンテキストへの負荷を一定にするため、「最大8行以内」等の制限を明示すべき [impact: low] [effort: low]

- [冪等性: 再実行時のファイル重複リスク]: [SKILL.md] [Phase 3, line 207-228] 並列評価実行でファイルを Write で保存する前に、既存ファイルの存在確認や Read 呼び出しがない。Phase 3 を再実行した場合、既存の results/ ファイルが上書きされるが、Phase 4 採点で古い結果ファイルが残っている場合に不整合が発生する可能性がある → Phase 3 開始時に該当ラウンドの results/ ファイルを削除するか、既存ファイル確認を行うべき [impact: medium] [effort: medium]

- [条件分岐の完全性: else節の欠落]: [SKILL.md] [106行] パースペクティブ再生成判定で「重大な問題または改善提案がある場合」のみ再生成すると記載されているが、else節（改善不要の場合）の処理が「現行 perspective を維持する」とあるものの、具体的な動作（ファイル操作なし、次ステップへ進む等）が不明確 → 「改善不要の場合: perspective ファイルはそのまま維持し、Step 6 検証に進む」と明示すべき [impact: low] [effort: low]

- [指示の具体性: 曖昧な判定基準]: [SKILL.md] [68行] 「エージェント定義が実質空または不足がある場合」の判定基準が曖昧 → 「ファイルが50行未満、または必須セクション（目的、評価基準、入力/出力）が欠落している場合」等の具体的基準を提示すべき [impact: low] [effort: low]

- [参照整合性: 未使用変数]: [SKILL.md] [phase1a-variant-generation.md への指示, line 146-157] パス変数リストに `{perspective_path}` が含まれているが、phase1a-variant-generation.md のテンプレート本文（line 1-41）では `{perspective_path}` は使用されていない（`{perspective_source_path}` のみ使用） → 不要な変数定義を削除するか、テンプレート側で実際に使用すべき [impact: low] [effort: low]

- [効率性: 不要なファイル読み込み]: [phase1b-variant-generation.md] [8-9行] `{audit_dim1_path}`, `{audit_dim2_path}` を「指定されている場合」のみ読み込むとあるが、指定有無の判定基準が不明確。SKILL.md line 174 では Glob で検索した全ファイルパスを渡すため、ファイルが存在しない場合の Read エラーハンドリングが必要 → テンプレート内で「ファイルが存在する場合のみ Read」と明示するか、SKILL.md 側で存在確認後にパス変数を条件付きで渡すべき [impact: medium] [effort: medium]

- [UX: 不可逆操作前の確認不足]: [SKILL.md] [306-313行] プロンプトデプロイで `{agent_path}` を上書きする前に、ユーザーが選択肢を選んでいるものの、上書き直前に再確認がない。誤選択時のリスクが高い → 「{agent_path} を上書きしますか？」の最終確認を追加すべき（ただし、Phase 6 Step 1 の選択肢が既に意思確認を兼ねている可能性あり。その場合は現状維持でも可） [impact: low] [effort: low]

#### 良い点

- [出力フォーマット決定性]: phase4-scoring.md (line 9-12) と phase5-analysis-report.md (line 14-22) のサブエージェント返答フォーマットが明確に行数・フィールド名を指定しており、親コンテキストの予測可能性が高い
- [冪等性]: Phase 0 の knowledge.md 初期化（line 116-130）で、ファイル不在時のみ初期化を実行する明確な分岐があり、再実行時の状態破壊リスクが低い
- [参照整合性]: テンプレートファイルが全て "Read template + follow instructions + path variables" パターンで統一されており、保守性が高い
