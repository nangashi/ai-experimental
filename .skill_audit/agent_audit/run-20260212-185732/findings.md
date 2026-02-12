## 重大な問題

### C-1: SKILL.mdが目標行数超過 [efficiency]
- 対象: SKILL.md
- 内容: SKILL.md が 254行で目標（250行以下）を超過している（+4行）。Phase 0 のグループ分類基準（行60-82）とテキスト出力例（行108-115, 142-147, 165-172, 242-273）が主な原因
- 推奨: グループ分類基準の外部化（推定節約量: ~30行）およびテキスト出力例の簡略化（推定節約量: ~15行）を優先的に実施する
- impact: low, effort: low

### C-2: 出力フォーマット決定性: サブエージェント返答フォーマット未明示 [stability]
- 対象: SKILL.md:128-129, Phase 1
- 内容: Phase 1 のサブエージェント起動時、「`.claude/skills/agent_audit/agents/{dim_path}.md` を Read し、その指示に従って分析を実行してください。」とあるが、サブエージェント返答の行数・フィールド名を明示していない。返答フォーマットが一貫しない可能性がある
- 推奨: サブエージェント返答フォーマットを明示する。例: 「分析完了後、以下のフォーマットで返答してください: `dim: {次元名}, critical: {N}, improvement: {M}, info: {K}`」
- impact: high, effort: low

### C-3: 参照整合性: テンプレート内プレースホルダ未定義 [stability]
- 対象: templates/apply-improvements.md:3-4, SKILL.md Phase 2 Step 4
- 内容: templates/apply-improvements.md で {approved_findings_path} および {agent_path} を使用しているが、SKILL.md のパス変数リストで定義されていない。サブエージェントがこれらの変数を解決できない
- 推奨: SKILL.md Phase 2 Step 4 の Task 起動箇所（行228-233）で「パス変数:」として明示する。`{approved_findings_path}`: `.agent_audit/{agent_name}/audit-approved.md` の絶対パス, `{agent_path}`: エージェント定義ファイルの絶対パス
- impact: high, effort: low

### C-4: 条件分岐の完全性: else 節未定義 [stability]
- 対象: SKILL.md:88-92, Phase 0
- 内容: `agent_path` が `.claude/` 配下の場合とそれ以外の分岐があるが、プロジェクトルートが不明な場合の処理が未定義。プロジェクトルート検出失敗時にスキルが停止する可能性がある
- 推奨: プロジェクトルートの検出ロジック（git root または pwd）を明示し、検出失敗時のデフォルト処理（エラー出力 or カレントディレクトリをルートとする）を追加する
- impact: medium, effort: medium

### C-5: 冪等性: 再実行時のファイル重複 [stability]
- 対象: SKILL.md:226, Phase 2 Step 4
- 内容: Phase 2 Step 4 のバックアップ作成 `cp {agent_path} {agent_path}.backup-$(date +%Y%m%d-%H%M%S)` は再実行のたびに新規ファイルを作成する。再実行時のバックアップファイル蓄積問題がある
- 推奨: バックアップファイルが既に存在する場合の処理を明示する。例: 「既存バックアップがある場合は上書きせず新規作成する」または「最新1件のみ保持する」
- impact: medium, effort: low

## 改善提案

### I-1: Phase 1 エラーハンドリングの不完全性 [architecture, efficiency]
- 対象: SKILL.md:136-140, Phase 1
- 内容: サブエージェントの findings ファイル存在チェックと Summary セクション抽出に依存しているが、ファイルが存在してもフォーマット不正の場合の処理フローが不明確。現在は「件数はファイル内の `## Summary` セクションから抽出する（抽出失敗時は findings ファイル内の `### {ID_PREFIX}-` ブロック数から推定する）」という2段階フォールバックだが、サブエージェント返答形式が固定（4行: dim, critical, improvement, info）なら Summary セクション抽出は不要
- 推奨: findings ファイルの構造検証（必須セクション確認）を追加する。フォーマット不正時はエラー出力し、該当次元を「分析失敗」として扱う
- impact: medium, effort: low

### I-2: グループ分類基準の外部化 [efficiency]
- 対象: SKILL.md:64-82, Phase 0
- 内容: Phase 0 のグループ分類基準（evaluator 特徴4項目 + producer 特徴4項目 + 判定ルール）を SKILL.md にインライン記述している。推定節約量: ~30行
- 推奨: 別ファイル（例: group-classification.md）に外部化し、SKILL.mdでは「詳細は {file} 参照」と簡潔に記載する。グループ分類はメインコンテキストで実行するため参照頻度が低く、外部化によるコンテキスト節約効果が大きい
- impact: medium, effort: low

### I-3: 欠落ステップ: 最終成果物の構造検証がない [architecture, effectiveness]
- 対象: SKILL.md Phase 2 Step 4
- 内容: Phase 2 で承認された findings が改善適用サブエージェントによって実際に適用されたか、エージェント定義が破損していないかの検証ステップがない。サブエージェントの返答（modified, skipped）のみを信頼する設計だが、サブエージェントが Edit/Write を失敗した場合の検出がない。全 Phase で生成される最終成果物（audit-*.md, audit-approved.md）に対する構造検証の記述が欠落している
- 推奨: Phase 2 Step 4 完了時に agent_path を再読み込みし、YAML frontmatter の存在確認と必須セクション（description）の確認を行う。検証失敗時は backup からのロールバック手順をユーザーに提示する
- impact: medium, effort: low

### I-4: Phase 2 Step 4 サブエージェント失敗時の処理未定義 [architecture, ux, stability]
- 対象: SKILL.md:236, analysis.md:71, SKILL.md Phase 2 Step 4:228-235
- 内容: Phase 2 Step 4 のサブエージェント返答が期待形式（modified, skipped）に一致しない場合の明示的処理が未定義。サブエージェントの返答内容をそのままテキスト出力するが、期待形式に一致しない場合の処理が未定義
- 推奨: 返答検証と失敗時のフォールバック（エラー出力 + バックアップから復旧指示）を追加する。返答パース失敗時に「⚠ 改善適用の結果が不正です: {返答}」とエラー出力し、ユーザーに手動確認を促す。または、返答が期待形式に一致しない場合は警告を出力し、返答内容をそのまま表示する
- impact: high, effort: medium

### I-5: バックアップ失敗時の処理未定義 [architecture, ux]
- 対象: SKILL.md:226, Phase 2 Step 4
- 内容: Phase 2 Step 4 でバックアップを作成するが、Bash 実行失敗時の処理が未定義。Bash ツールの失敗を検出した場合にユーザーへの警告が必要
- 推奨: 失敗時は改善適用を中止し、エラー出力する。Bash 失敗時に「⚠ バックアップ作成に失敗しました。続行しますか？」と AskUserQuestion で確認する
- impact: medium, effort: low

### I-6: Phase 1 findings 抽出ロジックの脆弱性 [architecture, effectiveness]
- 対象: SKILL.md:159-161, Phase 2 Step 1
- 内容: Phase 2 Step 1 で「severity が critical または improvement の finding を抽出」とあるが、抽出方法（正規表現パターン、セクション境界判定）が未定義。findings ファイルの構造（`### {ID}: {title} [severity: {level}]` 形式）は SKILL.md に記述されていない。各次元のエージェント定義（agents/*/md）にはこの形式が定義されているが、SKILL.md からは「Phase 1 サブエージェントが findings ファイルを生成する」という情報のみで、フォーマットの詳細が欠落している
- 推奨: 抽出失敗時のフォールバックを追加する。SKILL.md の Phase 1 セクションに「findings ファイルのフォーマット要件」を明示する（例: 「各次元のサブエージェントは `### {ID_PREFIX}-NN: {title} [severity: {level}]` 形式で findings を記述する」）
- impact: medium, effort: medium

### I-7: 進捗可視性: 並列サブエージェント実行の開始通知欠落 [ux]
- 対象: SKILL.md Phase 1
- 内容: Phase 1 の冒頭でテキスト出力 `## Phase 1: コンテンツ分析 ({agent_group})` を行うが、並列起動する {dim_count} 個のサブエージェントの開始タスク数を事前に通知していない。ユーザーは処理が何個起動したかを把握できない
- 推奨: `## Phase 1: コンテンツ分析 ({agent_group}) — {dim_count}次元を並列分析中...` のように起動数を含めることで進捗予測が可能になる
- impact: medium, effort: low

### I-8: 進捗可視性: Phase 2 の所要時間予測不能 [ux]
- 対象: SKILL.md Phase 2 Step 2
- 内容: 対象 findings 一覧を表示する際、各 finding の severity 別内訳（critical N件, improvement M件）を事前に表示していない。ユーザーは全体像を把握できず、確認作業の所要時間を見積もれない
- 推奨: Step 2 の冒頭で `対象 findings: 計{total}件（critical {N}, improvement {M}）` のようにサマリを追加する
- impact: medium, effort: low

### I-9: エラー通知: サブエージェント失敗時の原因不明 [ux]
- 対象: SKILL.md Phase 1
- 内容: サブエージェント失敗時に「分析失敗」とだけ表示し、失敗原因（エラー内容、例外メッセージ）を出力していない。ユーザーは手動再実行すべきか判断できない
- 推奨: 失敗時に Task ツールの返答から例外情報を抽出し、「分析失敗（{エラー概要}）」のように原因を含める
- impact: medium, effort: medium
