### 安定性レビュー結果

#### 重大な問題
- [参照整合性: 外部スキル参照]: [SKILL.md] [行81, 92] SKILL.md内に`.claude/skills/agent_bench/templates/perspective/{テンプレート名}`への参照があるが、正しいパスは`.claude/skills/agent_bench_new/templates/perspective/{テンプレート名}`。perspective自動生成時に参照エラーが発生する可能性がある → [全ての`agent_bench`参照を`agent_bench_new`に統一する] [impact: high] [effort: low]
- [参照整合性: 外部スキル参照]: [SKILL.md] [行130, 156-157, 177-178, 194, 259, 282, 332, 340, 344] `.claude/skills/agent_bench/`への参照が複数存在する（approach-catalog.md, templates/, proven-techniques.md, test-document-guide.md, scoring-rubric.md）。スキル名は`agent_bench_new`であるため、全ての参照パスを統一する必要がある → [全ての`.claude/skills/agent_bench/`参照を`.claude/skills/agent_bench_new/`に変更] [impact: high] [effort: low]
- [冪等性: ファイル重複生成]: [SKILL.md] [Phase 0 行59-60] perspective-source.mdから問題バンクを除いたコピーをperspective.mdに保存する処理があるが、既存ファイルの存在確認がない。再実行時に常にperspective.mdが上書きされ、意図しない動作となる可能性がある → [Write前にReadで既存ファイル確認を追加し、存在する場合はスキップする条件分岐を記述] [impact: medium] [effort: low]
- [冪等性: バリアント再実行時の重複]: [SKILL.md] [Phase 1A 行8-12, Phase 1B 行19] プロンプトファイル保存時に既存ファイルの存在確認がない。同じラウンドを再実行した場合、既存バリアントが上書きされる → [バリアントファイル保存前にRead/存在確認の条件分岐を追加。既存の場合はファイル名をv{NNN}a, v{NNN}b等にインクリメント、またはAskUserQuestionで上書き確認] [impact: medium] [effort: medium]
- [出力フォーマット決定性: 未定義返答形式]: [templates/perspective/critic-clarity.md, critic-effectiveness.md, critic-generality.md, critic-completeness.md] [行58-73, 37-52, 50-79, 90-103] 各criticテンプレートの返答がSendMessage形式と記載されているが、SKILL.md Phase 0 Step 4（行88-105）には返答形式の処理が定義されていない。4つの並列サブエージェントからの返答をどう集約するかが不明確 → [SKILL.md Phase 0 Step 5で、4件のcriticsからの返答を統合するロジックを明示する。または各criticの返答形式を構造化（重大N件/改善N件のカウント等）し、Step 5での判定基準を記述] [impact: high] [effort: medium]

#### 改善提案
- [曖昧表現: 判断基準なし]: [SKILL.md] [Phase 0 行67-71] 「エージェント定義が実質空または不足がある場合」の判断基準が曖昧。「実質空」「不足」の具体的な閾値が定義されていない → [具体的な判定基準を追加: 例「行数が10行未満」「目的・入力/出力・評価基準のいずれかのセクションが欠落」] [impact: medium] [effort: low]
- [曖昧表現: 判断基準なし]: [templates/phase6b-proven-techniques-update.md] [行36-40] 「最も類似する2エントリをマージ」「エビデンスが最も弱いエントリを削除」の判定基準が曖昧。LLMが異なる判断をする可能性がある → [類似度判定の具体的な基準（例：同じカテゴリID、効果ptの範囲±0.5pt内）、エビデンス強度の定義（例：出典エージェント数×ラウンド数の積）を明示] [impact: medium] [effort: medium]
- [出力フォーマット決定性: フィールド未明示]: [SKILL.md] [Phase 0 行142-144] Phase 0のテキスト出力形式で「パースペクティブ: {既存 / 自動生成}」とあるが、フォールバック検索で発見した場合の出力値が定義されていない → [「既存（perspective-source.md）/ フォールバック（{target}/{key}.md）/ 自動生成」の3値を明示] [impact: low] [effort: low]
- [条件分岐: 暗黙的条件]: [templates/phase1b-variant-generation.md] [行17-18] 「Deep モードでバリエーションの詳細が必要な場合のみ {approach_catalog_path} を Read」とあるが、「詳細が必要な場合」の判定条件が定義されていない → [Deepモード選択時は常にapproach_catalog_pathを読み込むよう変更、または具体的な条件（例：選択したVariation IDがカタログに記載されていない場合）を記述] [impact: low] [effort: low]
- [条件分岐: 暗黙的条件]: [SKILL.md] [Phase 1A 行11-12] 「エージェント定義ファイルが存在しなかった場合」にベースラインを{agent_path}にデプロイする記述があるが、存在していた場合のデプロイ動作が記述されていない → [存在する場合は既存ファイルを保持する旨を明示、または「Phase 1Aでは初期デプロイのみ実施、以降はPhase 6でデプロイ」と記述] [impact: low] [effort: low]
- [参照整合性: 変数定義漏れ]: [templates/perspective/generate-perspective.md] [行56-58] {user_requirements}プレースホルダが使用されているが、このテンプレート内でのみ参照される変数であるため、SKILL.mdでの定義は不要。ただし、テンプレート内で変数が何を含むかが不明確 → [テンプレート内で「## ユーザー要件」セクションの前に、user_requirementsの構成（エージェント目的・入力/出力型・使用ツール・制約等）を明記] [impact: low] [effort: low]
- [参照整合性: ディレクトリ存在確認]: [SKILL.md] [Phase 1A/1B, Phase 2, Phase 3, Phase 4, Phase 5] prompts/, results/, reports/ ディレクトリへのWrite操作があるが、ディレクトリ存在確認の記述がない。初回実行時にエラーとなる可能性 → [Phase 0で.agent_bench/{agent_name}/配下の必要ディレクトリ（prompts, results, reports）を事前作成する処理を追加] [impact: medium] [effort: low]

#### 良い点
- [出力フォーマット決定性]: Phase 1A/1B/2/4/5/6A/6Bの全サブエージェント返答が行数・フィールド名を明示した構造化形式で定義されている（例: Phase 5の7行サマリ）
- [参照整合性]: resolved-issues.mdで既に修正済みの参照整合性問題（C-1〜C-4, I-4, I-5, I-7）が明確に記録されており、重複指摘を回避できた
- [冪等性]: Phase 6A knowledge.md更新処理（templates/phase6a-knowledge-update.md 行16-22）で「保持+統合」方式が明示されており、再実行時のデータ破壊を防ぐ設計になっている
