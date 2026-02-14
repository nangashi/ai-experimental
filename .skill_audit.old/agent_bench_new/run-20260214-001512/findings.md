## 重大な問題

### C-1: 外部スキル参照による実行失敗 [architecture, stability]
- 対象: SKILL.md:全フェーズ
- 内容: 全テンプレート参照が `.claude/skills/agent_bench/templates/` を指しているが、正しいパスは `.claude/skills/agent_bench_new/templates/`。perspective自動生成、Phase 1〜6の全処理で参照エラーが発生する可能性がある。具体的には行81, 92（perspective templates）, 行130, 156-157, 177-178, 194, 259, 282, 332, 340, 344（approach-catalog.md, templates/, proven-techniques.md, test-document-guide.md, scoring-rubric.md）
- 推奨: 全ての `.claude/skills/agent_bench/` 参照を `.claude/skills/agent_bench_new/` に変更する
- impact: high, effort: low

### C-2: perspective.md の冪等性違反 [stability]
- 対象: SKILL.md:Phase 0 行59-60
- 内容: perspective-source.mdから問題バンクを除いたコピーをperspective.mdに保存する処理があるが、既存ファイルの存在確認がない。再実行時に常にperspective.mdが上書きされ、意図しない動作となる可能性がある
- 推奨: Write前にReadで既存ファイル確認を追加し、存在する場合はスキップする条件分岐を記述する
- impact: medium, effort: low

### C-3: バリアント再実行時の重複 [stability]
- 対象: SKILL.md:Phase 1A 行8-12, Phase 1B 行19
- 内容: プロンプトファイル保存時に既存ファイルの存在確認がない。同じラウンドを再実行した場合、既存バリアントが上書きされる
- 推奨: バリアントファイル保存前にRead/存在確認の条件分岐を追加。既存の場合はファイル名をv{NNN}a, v{NNN}b等にインクリメント、またはAskUserQuestionで上書き確認する
- impact: medium, effort: medium

### C-4: critic返答の集約ロジック未定義 [stability]
- 対象: templates/perspective/critic-*.md 行58-73他, SKILL.md Phase 0 Step 4 行88-105
- 内容: 各criticテンプレートの返答がSendMessage形式と記載されているが、SKILL.md Phase 0 Step 4には返答形式の処理が定義されていない。4つの並列サブエージェントからの返答をどう集約するかが不明確
- 推奨: SKILL.md Phase 0 Step 5で、4件のcriticsからの返答を統合するロジックを明示する。または各criticの返答形式を構造化（重大N件/改善N件のカウント等）し、Step 5での判定基準を記述する
- impact: high, effort: medium

### C-5: 出力ディレクトリの存在確認欠落 [stability]
- 対象: SKILL.md:Phase 1A/1B, Phase 2, Phase 3, Phase 4, Phase 5
- 内容: prompts/, results/, reports/ ディレクトリへのWrite操作があるが、ディレクトリ存在確認の記述がない。初回実行時にエラーとなる可能性がある
- 推奨: Phase 0で.agent_bench/{agent_name}/配下の必要ディレクトリ（prompts, results, reports）を事前作成する処理を追加する
- impact: medium, effort: low

## 改善提案

### I-1: Phase 6 Step 2 の並列実行依存関係 [effectiveness]
- 対象: SKILL.md:Phase 6
- 内容: Phase 6 Step 2 で A（knowledge更新）と B（proven-techniques更新）を並列実行しているが、B は A の更新結果（knowledge.md の最新効果テーブル）を参照する必要がある（phase6b-proven-techniques-update.md の Step 1 で {knowledge_path} を読み込む）。A の更新完了前に B が knowledge.md を読み込むと、古いデータを参照する可能性がある
- 推奨: Step 2A の完了後に Step 2B を開始するよう、逐次実行に変更する
- impact: medium, effort: low

### I-2: エージェント定義不足の判断基準曖昧 [stability]
- 対象: SKILL.md:Phase 0 行67-71
- 内容: 「エージェント定義が実質空または不足がある場合」の判断基準が曖昧。「実質空」「不足」の具体的な閾値が定義されていない
- 推奨: 具体的な判定基準を追加する（例「行数が10行未満」「目的・入力/出力・評価基準のいずれかのセクションが欠落」）
- impact: medium, effort: low

### I-3: proven-techniques.mdのマージ基準曖昧 [stability]
- 対象: templates/phase6b-proven-techniques-update.md:行36-40
- 内容: 「最も類似する2エントリをマージ」「エビデンスが最も弱いエントリを削除」の判定基準が曖昧。LLMが異なる判断をする可能性がある
- 推奨: 類似度判定の具体的な基準（例：同じカテゴリID、効果ptの範囲±0.5pt内）、エビデンス強度の定義（例：出典エージェント数×ラウンド数の積）を明示する
- impact: medium, effort: medium

### I-4: Phase 0 批評結果の親コンテキスト圧迫 [efficiency]
- 対象: SKILL.md:Phase 0 perspective自動生成 Step 4
- 内容: 4並列の批評エージェントからの返答（SendMessage形式）を親が保持する必要がある。Step 5 で「重大な問題」「改善提案」を分類するため、返答サイズが大きい場合コンテキストを圧迫する
- 推奨: 批評結果をファイル保存し、Step 5 で読み込む方式に変更する（推定節約量: 批評詳細の親コンテキスト保持を回避）
- impact: medium, effort: medium

### I-5: 最終成果物と成功基準の明示不足 [effectiveness]
- 対象: SKILL.md:冒頭・使い方セクション
- 内容: SKILL.md の説明文は「テストに対する性能を反復的に比較評価して最適化」としているが、最終的に何を持って「最適化完了」とするかの基準が明示されていない。収束判定はあるものの、それが必須の終了条件か任意の参考情報かが不明。また、期待される成果物（最適化されたエージェント定義ファイル、knowledge.md、proven-techniques.md、テスト文書群、レポート群）のうち主要成果物が何かが不明確
- 推奨: 使い方セクションに「最終成果物: 評価スコアが収束したエージェント定義ファイル + 累積的な知見（knowledge.md, proven-techniques.md）」および「期待される成果物」として主要成果物と副次的成果物を列挙する
- impact: medium, effort: low

### I-6: Deep モード条件の暗黙的判定 [stability]
- 対象: templates/phase1b-variant-generation.md:行17-18
- 内容: 「Deep モードでバリエーションの詳細が必要な場合のみ {approach_catalog_path} を Read」とあるが、「詳細が必要な場合」の判定条件が定義されていない
- 推奨: Deepモード選択時は常にapproach_catalog_pathを読み込むよう変更、または具体的な条件（例：選択したVariation IDがカタログに記載されていない場合）を記述する
- impact: low, effort: low

### I-7: Phase 0 パースペクティブ出力値の未定義 [stability]
- 対象: SKILL.md:Phase 0 行142-144
- 内容: Phase 0のテキスト出力形式で「パースペクティブ: {既存 / 自動生成}」とあるが、フォールバック検索で発見した場合の出力値が定義されていない
- 推奨: 「既存（perspective-source.md）/ フォールバック（{target}/{key}.md）/ 自動生成」の3値を明示する
- impact: low, effort: low

### I-8: Phase 1A デプロイ動作の未記述 [stability]
- 対象: SKILL.md:Phase 1A 行11-12
- 内容: 「エージェント定義ファイルが存在しなかった場合」にベースラインを{agent_path}にデプロイする記述があるが、存在していた場合のデプロイ動作が記述されていない
- 推奨: 存在する場合は既存ファイルを保持する旨を明示、または「Phase 1Aでは初期デプロイのみ実施、以降はPhase 6でデプロイ」と記述する
- impact: low, effort: low

### I-9: user_requirements 変数の構成不明 [stability]
- 対象: templates/perspective/generate-perspective.md:行56-58
- 内容: {user_requirements}プレースホルダが使用されているが、テンプレート内で変数が何を含むかが不明確
- 推奨: テンプレート内で「## ユーザー要件」セクションの前に、user_requirementsの構成（エージェント目的・入力/出力型・使用ツール・制約等）を明記する
- impact: low, effort: low
