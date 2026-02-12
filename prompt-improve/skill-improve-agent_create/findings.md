## 重大な問題

### C-1: Phase 3 失敗時の処理が未定義 [ux, stability, effectiveness, architecture]
- 対象: SKILL.md Phase 3 (L111, L226-230)
- 内容: サブエージェント失敗時の処理が「未定義」。成功数/総数のみ報告し、失敗タスクの情報・対処法が提示されない。成功数 < 総数 の場合の後続処理（Phase 4 へ進むのか、エラー終了か、部分的に採点か）が未定義。続行/中止の判定基準と処理フローが明示されていない。例: ベースライン Run1 が失敗した場合、そのプロンプトの採点は実行不可能だが、Phase 4 では全プロンプトについて並列採点サブエージェントを起動する指示となっている
- 推奨: 成功率閾値（< 50%: 中止、50-80%: 警告付き続行、80%+: 正常続行）を定義し、Phase 4 の指示を「Phase 3 で成功したプロンプトのみについて採点サブエージェントを起動する」に修正。失敗原因の特定とリカバリーが可能なエラー通知を追加
- impact: high, effort: medium

### C-2: Phase 2 scenario モードのテストセット承認が一括 [ux, architecture, effectiveness]
- 対象: SKILL.md Phase 2 scenario (L150)
- 内容: テストセット全体を一括承認させるが、個別シナリオの品質判断ができない。不適切なシナリオが含まれても受け入れるか全拒否の2択のみ。品質基準 Section 3 の「提案ごとの個別承認」に照らすと、シナリオが5-8個ある場合に全承認/全却下の二択になる。不承認の場合の処理フローが定義されていない（再生成手順が記載されていない）
- 推奨: サブエージェントがシナリオごとの表形式サマリを提示し、ユーザーが修正要求するシナリオを選択できる対話フローに変更。不承認の場合: サブエージェントを再実行してテストセットを再生成し、再度承認を求める（最大2回まで試行）
- impact: high, effort: medium

### C-3: Phase 2 detection モードの条件分岐完全性不足 [stability]
- 対象: SKILL.md Phase 2 (L137)
- 内容: scenario モードで test-set.md 存在時は Phase 3 へスキップするが、detection モードの Phase 2 実行条件が「毎ラウンド実行」のみで、ファイル存在時の重複生成防止処理がない
- 推奨: 「detection モードでは test-document-round-{NNN}.md の存在確認を行い、存在すれば Phase 3 へ」と明記
- impact: high, effort: low

### C-4: SKILL.md 行数超過 [efficiency]
- 対象: SKILL.md
- 内容: 365行 - 目標250行 = 115行超過。品質基準の目標値250行を46%超過。親コンテキスト負荷が高い
- 推奨: Phase 0 の不要な先読み削減（約40行）、Phase 3 のテンプレート外部化（約60行）、Phase 6 Step 1 のテンプレート外部化（約8行）により目標範囲内に収める
- impact: high, effort: medium

## 改善提案

### I-1: Phase 2 detection モードのテスト文書承認が欠落 [architecture]
- 対象: SKILL.md Phase 2 detection (L152-167)
- 内容: Phase 2 detection ではテスト対象文書と正解キーを毎ラウンド生成するが、ユーザー承認プロセスがない。scenario モードは承認があるが、detection モードには承認ステップがない。問題の埋め込み状況や難易度バランスをユーザーが確認できない
- 推奨: Phase 2 完了後に「テスト文書サマリ（埋め込み問題一覧、ドメイン、行数）」を提示し、AskUserQuestion で承認を得る処理を追加する
- impact: medium, effort: low

### I-2: Phase 5 baseline_prompt_path の重複読み込み [efficiency]
- 対象: SKILL.md Phase 5 (L270)、phase5-analysis-report.md (L12)
- 内容: Phase 5 でベースラインを読み込んでサブエージェント切り出し候補を分析しているが、この分析結果は knowledge.md にも proven-techniques.md にも反映されない。分析が後続フェーズで使用されないなら削除すべき
- 推奨: サブエージェント切り出し候補の分析を削除し、Phase 5 はスコア比較と推奨判定のみに集中する
- impact: medium, effort: low

### I-3: フェーズ間データフロー: deploy_info の未使用 [effectiveness]
- 対象: Phase 5 → Phase 6A
- 内容: Phase 5 のサブエージェントが返す7行サマリの `deploy_info` フィールド（推奨プロンプトの Variation ID と独立変数）が Phase 6 Step 2A の knowledge.md 更新に使用されることが期待されるが、Phase 6A のテンプレート（phase6a-knowledge-update.md）には `{recommended_name}` と `{judgment_reason}` のみが渡され、`{deploy_info}` は渡されていない。結果として、knowledge.md の「効果が確認された構造変化」テーブルに記録する際、レポートファイルから再度 Variation ID を抽出する必要があり、データフローが非効率
- 推奨: Phase 6A のテンプレートに `{deploy_info}` パス変数を追加し、knowledge.md 更新時に直接使用する
- impact: medium, effort: low

### I-4: エラー通知: メッセージに動的情報が不足 [ux]
- 対象: SKILL.md Phase 0 detection モード (L41)
- 内容: 「パースペクティブファイルが見つかりません。`/reviewer_create {perspective} {target}` で作成してください」は対処法を示しているが、動的情報（試行されたパス）が含まれていない。ユーザーがスペルミスや存在確認ができず、デバッグが困難
- 推奨: エラーメッセージに試行されたパスを含める（例: 「パースペクティブファイル `.claude/skills/agent_create/perspectives/{target}/{perspective}.md` が見つかりません...」）
- impact: medium, effort: low

### I-5: Phase 6 Step 1 プロンプト選択の判断材料が不完全 [ux]
- 対象: SKILL.md Phase 6 Step 1 (L280-296)
- 内容: 性能推移テーブルと推奨理由は提示されるが、各バリアントの適用テクニックや特性が示されない。トレードオフ（例: 精度 vs 速度、一般化 vs 専門化）の説明がない
- 推奨: AskUserQuestion の前に、各バリアントの適用テクニック（approach-catalog.md の Variation ID）とトレードオフ情報を提示する
- impact: medium, effort: low

### I-6: Phase 0 scenario の新規作成時ヒアリングが一括 [architecture]
- 対象: SKILL.md Phase 0 scenario 新規 (L49-53)
- 内容: 「目的・役割、入力と出力、使用ツール・制約」を1回の AskUserQuestion で全て収集している。品質基準 Section 3 の「提案ごとの個別承認」に照らすと、複数要素を同時に確認する一括方式
- 推奨: 各要素を段階的にヒアリングする設計に変更し、ユーザーが要素ごとに明確に回答できるようにする
- impact: medium, effort: medium

### I-7: エラー通知: Phase 4 採点サブエージェント失敗時の通知が未定義 [ux]
- 対象: SKILL.md Phase 4 (L256)
- 内容: Phase 4 の採点サブエージェントが失敗した場合のエラー通知が定義されていない。Phase 5 へ進む前に部分完了の扱いを明示すべき
- 推奨: Phase 4 完了時に「採点完了: {成功数}/{総数}」を報告し、失敗タスクがある場合は警告を表示
- impact: medium, effort: low

### I-8: 条件分岐の完全性: バリアント選定のデフォルト処理不在 [stability]
- 対象: templates/phase1b-variant-generation.md (L8-11)
- 内容: バリアント選定の条件分岐で、全ての UNTESTED が枯渇した場合の処理が未定義
- 推奨: 「全バリエーションが TESTED の場合は、最も効果が高かった EFFECTIVE バリエーションの派生（カタログにない新規バリエーション）を生成する」を追加
- impact: medium, effort: high

### I-9: 冪等性: ファイル重複生成のリスク [stability]
- 対象: templates/phase1b-variant-generation.md (L14)
- 内容: バリアントファイル保存前に既存ファイルの存在確認がない。再実行時に同じラウンド番号で上書きされるが、ラウンド番号インクリメントのタイミングが Phase 6A のため、Phase 1B 失敗再実行時に重複の可能性
- 推奨: 「既存ファイル確認後、存在すればエラー」または「Phase 0 でラウンド番号を確定してからプロンプトファイル生成」を明記
- impact: medium, effort: medium

### I-10: 参照整合性: 未定義変数の使用 [stability]
- 対象: SKILL.md (L105)
- 内容: `{reference_agent_path}` が定義されているが、line 12 の検出モードのパース例に "new" のハンドリングが不明確
- 推奨: 明示的に「detection モードでは新規作成時も .claude/agents/ 配下を参照」と記載する
- impact: medium, effort: low

### I-11: 指示の具体性: バリアント選定基準の曖昧表現 [stability]
- 対象: templates/phase1a-variant-generation.md (L7)
- 内容: 「ギャップが大きい次元の2つの独立変数を選定」→ より具体的な基準が必要
- 推奨: 「ギャップスコアが最大の上位2次元から各1つの独立変数を選定」に変更
- impact: medium, effort: low

### I-12: Phase 3 直接指示の冗長性 [efficiency, architecture]
- 対象: SKILL.md (L188-217)
- 内容: scenario/detection で2つの長文指示が重複、テンプレート化で約60行削減可能。Phase 3 の scenario 評価指示は11行、detection 評価指示は10行と長く、7行閾値を超過している
- 推奨: 独立したテンプレートファイル（phase3-scenario-eval.md、phase3-detection-eval.md）に外部化し、「Read template + follow instructions + path variables」パターンに統一
- impact: medium, effort: low

### I-13: Phase 6 Step 1 直接指示 [efficiency, architecture]
- 対象: SKILL.md (L299-306、L300-306)
- 内容: 約8行の指示を直接記述、テンプレート化で削減可能。7行超のサブエージェント指示はテンプレートファイルに外部化すべきだが、Phase 6 Step 1 デプロイ処理は直接記述されている。7行ちょうどで、単純なファイル操作（Read→メタデータ除去→Write）のため haiku サブエージェントに委譲されているが、メタデータ除去の詳細（正規表現パターン等）が明示されていない
- 推奨: 処理が単純ならインライン化（5行以下に圧縮）、処理が複雑なら外部化してパターンを明記すべき
- impact: medium, effort: low

### I-14: Phase 0 不要な先読み [efficiency]
- 対象: SKILL.md Phase 0 (約40行削減可能)
- 内容: Phase 0 で全参照ファイルパスの存在確認・説明を記述しているが、各ファイルは使用する Phase でのみ読み込むべき
- 推奨: Phase 0 は eval_mode 判定と作業ディレクトリ確認のみに集中
- impact: medium, effort: low

### I-15: 目的の明確性: 成功基準の推定性が弱い [effectiveness]
- 対象: SKILL.md 冒頭
- 内容: スキルの目的が「エージェント定義ファイルを作成・評価・改善し、性能向上の知見を蓄積する」と記載されているが、「性能向上」の定義と測定方法が明示されていない。scenario モードでは「テストシナリオに対する評価スコア」、detection モードでは「問題検出率+ボーナス-ペナルティ」という異なる成功基準があるが、これらが使い方セクションから読み取れない
- 推奨: 「使い方」セクションに「期待される成果」サブセクションを追加し、「scenario: テストシナリオセット（ルーブリック付き）で評価された0-10スケールのスコア向上」「detection: 埋め込み問題の検出率向上（0-10スケール、ボーナス/ペナルティ含む）」と明記する
- impact: medium, effort: low

### I-16: Phase 0 における eval_mode 判定の明示性不足 [effectiveness]
- 対象: SKILL.md Phase 0 eval_mode 判定
- 内容: 引数2つの場合に「perspective ファイル存在確認」を行い、存在する場合は detection モード、存在しない場合はエラー終了としているが、このロジックが eval_mode 判定の手段として適切かどうかは使い方セクションから判断できない。ユーザーが「引数2つ = detection モード」という対応を理解していても、ファイル不在時にスキル全体が終了するのはエラーハンドリングとしては適切だが、eval_mode 判定の説明としては明確性不足
- 推奨: Phase 0 の Step 1 を「引数パターンで eval_mode を判定する」と「detection モードの場合はファイル存在確認」の2ステップに分離し、判定ロジックを明確化する
- impact: low, effort: low

### I-17: Phase 2 scenario の承認確認の位置 [efficiency]
- 対象: SKILL.md (L150)
- 内容: テストセット生成後すぐに承認を求めているが、承認却下時の再生成コストが高い
- 推奨: テンプレート内でバリデーション結果を提示し、親で承認を求める設計に変更すれば、サブエージェント返答にバリデーション結果を含めることで判断材料が明確になる
- impact: low, effort: medium

### I-18: Phase 4 result_paths 収集の非効率 [efficiency]
- 対象: SKILL.md (L233-234)
- 内容: scenario モードのみ Glob 実行。detection モードでは result_paths が直接構築されるのに、scenario モードだけ Phase 3 完了後に Glob で収集している
- 推奨: Phase 3 のサブエージェント起動時にパスリストを構築すれば Glob が不要になる
- impact: low, effort: low

### I-19: Phase 6A と 6B の逐次実行 [efficiency]
- 対象: SKILL.md (L311-323)
- 内容: 6A 完了待ち → 6B/6C 並列実行。6B は 6A の更新済み knowledge.md を参照するため逐次実行は正しいが、6B と 6C の並列実行により 6C の AskUserQuestion が 6B 完了前に表示される可能性がある
- 推奨: ユーザー体験として、6B 完了（proven-techniques.md 更新結果の通知）→ 6C 次アクション確認の順が自然
- impact: low, effort: low

### I-20: サブエージェント返答の冗長性 [efficiency]
- 対象: テンプレート全般
- 内容: テンプレートのほとんどが「サマリのみ返答」を指示しているが、phase1a は「構造分析テーブル+バリアント情報（可変）」と返答長が明示されていない
- 推奨: 返答行数の上限を明示すればコンテキスト予測可能性が向上する
- impact: low, effort: low

### I-21: 進捗可視性: Phase 0 の開始メッセージがない [ux]
- 対象: SKILL.md Phase 0
- 内容: Phase 1-6 には進捗メッセージがあるが、Phase 0 には eval_mode 判定、初期化の開始を示すメッセージがない
- 推奨: Phase 0 開始時に「## Phase 0: 初期化と eval_mode 判定」を出力
- impact: low, effort: low

### I-22: 進捗可視性: Phase 4 の開始メッセージがない [ux]
- 対象: SKILL.md Phase 4 (L238-240)
- 内容: Phase 4 開始時にフェーズ名・採点タスク数の出力がない。Phase 3 のような「## Phase 4: 採点」の明示がない
- 推奨: Phase 4 開始時に「## Phase 4: 採点 ({採点タスク数} プロンプト)」を出力
- impact: low, effort: low

### I-23: 進捗可視性: Phase 5, 6 の開始メッセージがない [ux]
- 対象: SKILL.md Phase 5, 6
- 内容: Phase 5（分析）、Phase 6（デプロイ・ナレッジ更新）の開始を示すメッセージがない
- 推奨: 各フェーズ開始時に「## Phase 5: 分析とレポート」「## Phase 6: デプロイとナレッジ更新」を出力
- impact: low, effort: low

### I-24: ユーザーインタラクション: Phase 0 scenario 新規作成のヒアリングに情報提示がない [ux]
- 対象: SKILL.md Phase 0 scenario 新規 (L48-52)
- 内容: AskUserQuestion で目的・入出力・ツール・制約をヒアリングするが、事前に例示やガイドラインを提示していない
- 推奨: ヒアリング前に「エージェント定義の標準形式」や「記載例」を簡単に提示する
- impact: low, effort: low

### I-25: 使い方ドキュメント: 期待される動作の具体例がない [ux]
- 対象: SKILL.md (L8-18)
- 内容: 使い方セクションに構文とパラメータはあるが、各モードで何が起こるか（生成されるファイル、ラウンドの流れ、終了条件）の概要が記載されていない
- 推奨: 「期待される動作」サブセクションを追加し、ワークフロー概要とファイル成果物を記載
- impact: low, effort: low

### I-26: 指示の具体性: 不足要素ヒアリングの曖昧表現 [stability]
- 対象: SKILL.md (L54)
- 内容: 「不足要素がある場合は AskUserQuestion でヒアリングする」→ より具体的な表現が必要
- 推奨: 「不足要素（目的/ロール定義、実行基準、出力ガイドライン、行動姿勢）がある場合は、その不足要素を列挙し AskUserQuestion でヒアリングする」に変更
- impact: low, effort: low

### I-27: 参照整合性: ファイルパス実在確認 [stability]
- 対象: SKILL.md (L105)
- 内容: `{reference_agent_path}` が `.claude/agents/security-design-reviewer.md` を指すが、このファイルの実在確認が必要
- 推奨: Glob で確認し、存在しない場合は別の参考ファイルを使用するか、エラー通知
- impact: low, effort: medium

### I-28: 冪等性: 再実行時の状態整合性 [stability]
- 対象: templates/phase6a-knowledge-update.md (L8-14)
- 内容: 累計ラウンド数を +1 するが、Phase 6A が複数回実行された場合（Phase 6B 失敗後の再実行等）に重複カウントの可能性
- 推奨: 「ラウンド別スコア推移テーブルの最終行のラウンド番号 + 1 を累計ラウンド数とする」を明記
- impact: low, effort: low

### I-29: 出力フォーマット決定性: 行数不定 [stability]
- 対象: templates/phase1a-variant-generation.md (L9-24)
- 内容: 返答フォーマットが「構造分析結果」テーブルの行数を指定していない
- 推奨: 「6行（見出し数、サブ項目粒度、出力形式詳細度、原則/制約の明示度、具体例の有無、スコアリング基準の有無）」と明記
- impact: low, effort: low

### I-30: 出力フォーマット決定性: フィールド順序不定 [stability]
- 対象: templates/phase5-analysis-report.md (L18-26)
- 内容: 7行サマリのフィールド順序は指定されているが、各フィールドの値の形式（特に variants の「変更内容要約」の文字数制限）が未指定
- 推奨: 「variants: 各バリアントの変更内容要約は最大20単語」を追加
- impact: low, effort: low

### I-31: 指示の具体性: 収束判定基準の参照先不明 [stability]
- 対象: SKILL.md (L294)
- 内容: 収束判定で「該当する場合は『最適化が収束した可能性あり』を付記」→ 判断基準が不明確
- 推奨: scoring-rubric.md の収束判定基準を SKILL.md にも明記、または「scoring-rubric.md の Section 3 に従って収束判定を行う」と参照先を明示
- impact: low, effort: low
