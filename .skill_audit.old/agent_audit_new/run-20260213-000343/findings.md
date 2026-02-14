## 重大な問題

### C-1: 出力フォーマット決定性: サブエージェント返答フォーマット検証の欠落 [stability]
- 対象: SKILL.md Phase 1 Line 139-156
- 内容: サブエージェント返答から件数を抽出する処理で「抽出失敗時は findings ファイル内の `### {ID_PREFIX}-` ブロック数から推定する」とあるが、推定処理の実装指示がない
- 推奨: 推定処理の具体的手順を明示する: "サブエージェント返答から数値抽出を試行 → 失敗時は Grep で findings ファイル内の `^### {ID_PREFIX}-` パターンをカウント → 0件の場合はファイル存在確認とサイズ確認"
- impact: high, effort: low

### C-2: 条件分岐の完全性: Phase 0 Step 3 の処理継続条件が不明確 [stability]
- 対象: SKILL.md Phase 0 Step 3 Line 66
- 内容: frontmatter 欠落時に「処理は継続する」と記載されているが、後続ステップでの取り扱いが未定義（グループ分類に影響するか、Phase 2 検証で追加処理が必要か等）
- 推奨: 継続時の動作を明示: "frontmatter が存在しない場合でもグループ分類と分析は実行する。Phase 2 検証ステップで frontmatter の欠落を critical finding として扱う"
- impact: high, effort: medium

### C-3: 参照整合性: テンプレート内プレースホルダの定義欠落 [stability]
- 対象: templates/apply-improvements.md Line 4, 5, 17
- 内容: {approved_findings_path}, {agent_path}, {backup_path} の3つのプレースホルダが使用されているが、SKILL.md のパス変数リスト（Phase 2 Step 4 Line 214-217）でのみ定義され、テンプレート冒頭に変数定義セクションがない
- 推奨: テンプレート冒頭に「## パス変数」セクションを追加し、各プレースホルダの説明を記載する（agents/*.md と同様の形式）
- impact: high, effort: low

### C-4: 条件分岐の完全性: Phase 2 Step 2 Fast mode 分岐の実装指示不足 [stability]
- 対象: SKILL.md Phase 2 冒頭 Line 163
- 内容: 「Fast mode が有効な場合、Step 2 の承認確認をスキップし、全 findings を自動承認として Step 3 へ進む」とあるが、Fast mode フラグの取得方法・判定条件が未記載
- 推奨: Phase 0 冒頭に追加: "引数から `--fast` フラグの有無を確認し、`{fast_mode} = true/false` として保持する"。Phase 2 冒頭に追加: "if {fast_mode} == true: 「Fast mode: 全 findings を自動承認します」とテキスト出力し、Step 2 をスキップして Step 3 へ進む"
- impact: high, effort: medium

### C-5: 冪等性: Phase 1 既存 findings 上書き動作の明示不足 [stability]
- 対象: SKILL.md Phase 1 Line 117
- 内容: 「既存 findings ファイルが存在する場合、サブエージェントが Write で上書きする」とあるが、親コンテキストでの事前確認・警告出力の指示がない
- 推奨: Phase 1 冒頭に追加: "既存 findings ファイルを Glob で検索し、存在する場合は「既存の分析結果を上書きします: {ファイルリスト}」とテキスト出力する"
- impact: medium, effort: low

### C-6: SKILL.md が目標行数を超過 [efficiency]
- 対象: SKILL.md
- 内容: ~12行超過（262行/目標250行）。Phase 0 のグループ分類セクション（行70-80付近）に判定ルール概要が記載されているが、詳細は group-classification.md に外部化されている。この中間的な記述が冗長性を生んでいる
- 推奨: Phase 0 Step 4 の「判定ルール（概要）」（行74-78）を削除し、group-classification.md への参照に置換する。現状では SKILL.md に概要が記述されているが、実際の判定は親コンテキストで直接行うため、group-classification.md の詳細基準を読み込む必要がある。概要記述を削除し、group-classification.md を Read して判定させることで、SKILL.md を目標行数以下に収めつつ判定ロジックを一元化できる
- impact: low, effort: low

## 改善提案

### I-2: テンプレート間の説明重複 [efficiency]
- 対象: agents/ 配下の各分析エージェント定義ファイル
- 内容: 各分析エージェント定義ファイル（agents/配下）に共通の「Detection-First, Reporting-Second」プロセス説明（Phase 1/Phase 2 の概念説明、約30-40行）が重複している
- 推奨: この説明を shared/ ディレクトリの共通テンプレート（例: analysis-process.md）に外部化し、各エージェント定義では「Read {shared_template} を参照」と1行で済ませることで、サブエージェントの初期コンテキスト消費を大幅に削減できる（~20-30行/ファイル削減、全8ファイル合計で160-240行削減）
- impact: high, effort: medium

### I-3: データフロー: Phase 1 サブエージェント失敗時の部分成功続行ルールが検証ステップと不整合 [effectiveness]
- 対象: SKILL.md Phase 1, Phase 2 検証ステップ
- 内容: Phase 1 では「部分失敗の場合は警告を出力して継続（成功した次元のみで Phase 2 へ進む）」とあるが、Phase 2 Step 4 の検証ステップ（line 223-230）では YAML frontmatter の存在のみを確認しており、部分適用された findings がエージェント定義に矛盾を生じさせていないかの構造的検証は行われていない。例えば IC 次元で「役割定義の追加」が適用され、CE 次元が失敗して基準が未修正の場合、役割と基準のミスマッチが発生する可能性がある
- 推奨: 検証ステップで部分適用の整合性チェック（最低限、各次元の必須セクションの存在確認）を追加すべき
- impact: medium, effort: medium

### I-4: グループ分類ロジックの外部化 [architecture, efficiency]
- 対象: SKILL.md Phase 0 Step 4
- 内容: グループ分類ルール（evaluator 特徴・producer 特徴の判定）がインラインで記述されているが、group-classification.md に既に基準が存在する。実装ガイド（判定の手順・カウント方法）のみを SKILL.md に残し、基準定義への参照を追加することで一元化が可能
- 推奨: Phase 0 Step 4 の「判定ルール（概要）」（行74-78）を削除し、group-classification.md への参照に置換する（~10-15行削減）
- impact: medium, effort: low

### I-5: エッジケース処理記述: group-classification.md 不在時の処理が未記述 [effectiveness]
- 対象: SKILL.md Phase 0 Step 4
- 内容: group-classification.md への参照は analysis.md line 14 で確認できるが、SKILL.md 内にこのファイルが存在しない場合のフォールバック処理（デフォルトグループへの分類、またはエラー終了）が記述されていない。外部参照ファイルの不在は「4. アーキテクチャ」でエラーハンドリングパターンとして扱われるべきだが、現状ではエージェント定義ファイル自体の不在（Phase 0 Step 2）のみが明示的に処理されている
- 推奨: group-classification.md 不在時のエラー処理を明示する
- impact: medium, effort: low

### I-6: エラー通知: Phase 1部分失敗時の原因詳細不足 [ux]
- 対象: SKILL.md Phase 1: 並列分析 行145-146
- 内容: 「分析失敗（{エラー概要}）」と出力するが、エラー概要の抽出元（Task返答）が明示的に定義されていない。ユーザーがエラー原因を理解するには、具体的なエラー内容（ファイル不在、権限エラー、内部例外等）と対処法（パス確認、権限確認、再実行等）を含めるべき
- 推奨: エラー概要に具体的な原因と対処法を含める
- impact: medium, effort: low

### I-7: 検証ステップの構造検証強化 [architecture]
- 対象: SKILL.md Phase 2 Step 4 検証ステップ（L223-230）
- 内容: YAML frontmatter の存在確認のみ実施。最終成果物（変更済みエージェント定義）に対する構造検証として、frontmatter 内の必須フィールド（`name`, `description`）の存在確認、各分析次元エージェント定義で必須セクション（`## Task`, `## Output Format`）の確認を追加することで、破損検出の精度が向上する
- 推奨: 必須フィールドおよび必須セクションの存在確認を追加
- impact: medium, effort: medium

### I-8: 並列サブエージェント失敗時の部分続行判定基準の明示化 [architecture]
- 対象: SKILL.md Phase 1 エラーハンドリング（L141-155）
- 内容: 「全次元失敗→終了、部分失敗→継続」と記載されているが、継続可否の判定基準（例: 成功数≥2、または共通次元 IC が成功）が明示されていない。現状は「成功数>0」で継続と読めるが、1次元のみ成功で Phase 2 へ進む有用性は低い
- 推奨: 継続可否の判定基準を明示する
- impact: medium, effort: low

---
注: 改善提案を 13 件省略しました（合計 22 件中上位 9 件を表示）。省略された項目は次回実行で検出されます。
