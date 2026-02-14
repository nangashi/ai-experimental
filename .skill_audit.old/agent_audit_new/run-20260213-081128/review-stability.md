### 安定性レビュー結果

#### 重大な問題
- [参照整合性: 外部パス参照が実際のスキル名と不一致]: [SKILL.md] [行64, 116, 221] [`.claude/skills/agent_audit/` への参照] → [全ての外部参照を `.claude/skills/agent_audit_new/` に修正する。または、スキル内の相対パスとして `group-classification.md`, `agents/{dim_path}.md`, `templates/apply-improvements.md` と記載する] [impact: high] [effort: low]

- [条件分岐の完全性: エラーハンドリング不完全]: [SKILL.md] [Phase 2 Step 4, 行214-226] [apply-improvements サブエージェントの失敗時の処理が未定義] → [apply-improvements サブエージェント失敗時のフォールバック処理を追加する: 「サブエージェント完了確認: 返答内容に `modified:` または `skipped:` が含まれるか検証。検証失敗時は「改善適用に失敗しました。詳細: {サブエージェント返答}」とテキスト出力し、バックアップからのロールバック手順を提示してPhase 3へ進む」] [impact: high] [effort: medium]

- [冪等性: バックアップファイルの重複生成]: [SKILL.md] [Phase 2 Step 4, 行217] [バックアップコマンド `cp {agent_path} {agent_path}.backup-$(date +%Y%m%d-%H%M%S)` が再実行時に毎回新規ファイルを作成] → [バックアップ作成前に既存バックアップの存在確認を追加する: 「Bash で `ls {agent_path}.backup-* 2>/dev/null | tail -n 1` を実行し、最新バックアップが存在する場合はその時刻を表示して `AskUserQuestion` で新規バックアップ作成の要否を確認する。存在しない、またはユーザーが承認した場合のみ新規バックアップを作成する」] [impact: medium] [effort: medium]

#### 改善提案
- [出力フォーマット決定性: サブエージェント返答形式が部分的に未指定]: [SKILL.md] [Phase 1, 行118] [サブエージェントの返答フォーマット `dim: {次元名}, critical: {N}, improvement: {M}, info: {K}` が指定されているが、次元名の形式が未定義] → [次元名を ID_PREFIX に統一する指示を追加: 「`dim: {ID_PREFIX}` (例: `dim: CE`) の形式で返答してください」] [impact: low] [effort: low]

- [参照整合性: プレースホルダ不一致]: [templates/apply-improvements.md] [行4, 5] [プレースホルダ `{approved_findings_path}` と `{agent_path}` が使用されているが、SKILL.md のパス変数リストには記載がない] → [SKILL.md Phase 2 Step 4 (行219-224) のパス変数リストを「## パス変数」として独立セクション化し、`{agent_path}`, `{approved_findings_path}` を明示的に定義する] [impact: medium] [effort: low]

- [条件分岐の完全性: per-item 承認の "Other" 分岐処理が曖昧]: [SKILL.md] [Phase 2 Step 2a, 行181] [「"Other" で修正内容をテキスト入力した場合は「修正して承認」として扱い、改善計画に含める」とあるが、その後の Step 3 保存フォーマットでは「修正内容」の記録方法が説明されているが、入力の検証・解析方法が未定義] → [Step 2a の "Other" 処理を明確化: 「ユーザーが "Other" を選択した場合、入力されたテキストを `{user_modification}` として記録し、finding の `recommendation` を `{user_modification}` で置き換える。入力が空または "skip" 等の明示的な拒否を示す場合は「スキップ」として扱う」] [impact: medium] [effort: low]

- [冪等性: 出力ディレクトリの重複作成防止が未記載]: [SKILL.md] [Phase 0, 行81] [`mkdir -p` により冪等性は確保されているが、既存ディレクトリ内のファイル（前回実行の成果物）との競合が未考慮] → [Phase 0 で出力ディレクトリ作成時に既存ファイルの警告を追加: 「`mkdir -p .agent_audit/{agent_name}/` 実行後、Bash で `ls .agent_audit/{agent_name}/ 2>/dev/null | wc -l` を実行し、0でない場合は「⚠ 出力ディレクトリには前回実行の成果物が残っています（{ファイル数}件）。上書きされる可能性があります」とテキスト出力する」] [impact: low] [effort: low]

- [指示の具体性: "エラー概要" の抽出方法が曖昧]: [SKILL.md] [Phase 1, 行127] [「Task ツールの返答から例外情報（エラーメッセージの要約）を抽出し」とあるが、抽出ルールが未定義] → [エラー概要抽出ルールを明示: 「Task 返答の最初の `Error:` または `Exception:` で始まる行、またはそれがない場合は返答の最後の段落の先頭50文字を {エラー概要} とする」] [impact: low] [effort: low]

- [指示の具体性: findings ブロック数からの推定ルールが曖昧]: [SKILL.md] [Phase 1, 行126] [「findings ファイル内の `### {ID_PREFIX}-` ブロック数から推定する」とあるが、推定方法の詳細が未定義] → [推定ルールを明確化: 「Grep で `^### {ID_PREFIX}-` を検索し、行数を件数とする。severity の内訳は不明として `critical: ?, improvement: ?, info: ?` と表示する」] [impact: low] [effort: low]

- [条件分岐の完全性: frontmatter 検証の失敗時の処理が部分的]: [SKILL.md] [Phase 0, 行58] [frontmatter 不在時は警告表示して継続するが、Phase 2 検証失敗時（行235）はロールバック手順を提示するのみで、Phase 3 での警告表示の具体的内容が未定義] → [Phase 3 の検証失敗時の警告内容を明示: 「Phase 3 冒頭（Phase 2 実行時のみ）に検証ステータスを確認し、失敗時は「⚠ 検証失敗: エージェント定義が破損している可能性があります。バックアップからのロールバック推奨: `cp {backup_path} {agent_path}`」を追加表示する」] [impact: low] [effort: low]

#### 良い点
- [参照整合性: テンプレートのプレースホルダが明示的]: templates/apply-improvements.md 内の全プレースホルダ (`{approved_findings_path}`, `{agent_path}`) が文書冒頭で明示されており、SKILL.md からの委譲時に変数展開ルールが明確
- [条件分岐の完全性: Phase 1 エラーハンドリングが充実]: Phase 1 でサブエージェントの成否判定に複数のフォールバック（Summary セクション → ブロック数推定）を用意し、部分完了時も継続する設計が明確
- [冪等性: バックアップ機構]: Phase 2 Step 4 で改善適用前にバックアップを作成し、検証失敗時のロールバック手順を提示する設計により、破壊的変更のリスクが低減されている
