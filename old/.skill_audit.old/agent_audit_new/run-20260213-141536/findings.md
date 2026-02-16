## 重大な問題

なし

## 改善提案

### I-1: Phase 0 グループ分類のコンテキスト保持 [efficiency]
- 対象: SKILL.md:Phase 0 Step 2
- 内容: Phase 0 Step 2 で `{agent_content}` として対象エージェント定義全文を親コンテキストに保持しているが、グループ分類（Step 4）以降は使用されない。分類判定のみに使用するため、分類完了後は保持不要
- 推奨: グループ分類をサブエージェントに委譲してファイル経由で結果のみ受け取るか、分類後に変数を破棄する明示的な指示を追加する
- impact: high, effort: medium

### I-2: agent_name導出ルールで「プロジェクトルート」が未定義 [stability]
- 対象: SKILL.md:Phase 0 共通初期化 Step 5
- 内容: 「プロジェクトルートからの相対パス」と記述されているが、「プロジェクトルート」が何を指すか（git repository root / current working directory / .claude/ の親ディレクトリ等）が未定義。LLMの解釈に依存する
- 推奨: 明示的な基準（例: "current working directory"）への置換
- impact: medium, effort: low

### I-3: 構造検証の範囲不足 [architecture]
- 対象: SKILL.md:Phase 2 検証ステップ
- 内容: 改善適用後の検証が YAML frontmatter の存在確認のみ。以下の構造破壊を検出できない: (1) Findings セクションの消失（次元エージェント定義の場合）、(2) Workflow Phase セクションの消失（SKILL.md の場合）、(3) 必須フィールド（name, description）の削除
- 推奨: エージェントグループに応じた必須セクション/フィールドリストを定義し、検証ステップで確認する
- impact: medium, effort: medium

### I-4: 知見蓄積の不在 [architecture]
- 対象: SKILL.md
- 内容: スキルは反復的な最適化ループを持たない（1回実行で完結）が、同一エージェント定義に対して複数回 `/agent_audit` が実行される可能性がある。現在は `.agent_audit/{agent_name}/audit-approved.md` に承認結果を保存するが、次回実行時に前回の指摘を参照する仕組みがない。ユーザーが同じ指摘を繰り返し承認する可能性がある
- 推奨: Phase 0 で `.agent_audit/{agent_name}/audit-approved.md` を Read し、前回承認済み findings を resolved-issues.md 形式で次元エージェントに渡す
- impact: medium, effort: medium

### I-5: テンプレート外部化の過剰適用 [architecture]
- 対象: templates/apply-improvements.md
- 内容: 40行のテンプレートは7行超の基準を満たすが、内容の80%が変更適用ルール（二重適用チェック、優先順序、ツール選択）の詳細であり、サブエージェントが Read で毎回取得するには冗長
- 推奨: SKILL.md Phase 2 Step 4 に主要ルール（5-7行）をインライン化し、テンプレートを削除するか、テンプレートを参照カタログとして `.claude/skills/agent_audit_new/reference/` に移動する
- impact: medium, effort: low

### I-6: Phase 2 Step 2aの"Other"選択後のループ継続条件が未定義 [stability]
- 対象: SKILL.md:Phase 2 Step 2a
- 内容: ユーザーが「Other」で修正内容を入力した場合、「次の指摘へ進む」と記述されているが、入力内容が不明確な場合の処理（再確認/スキップ/強制承認）が未定義。現在はskippedに記録するとtemplate側で定義されているが、SKILL.md側にも記述すべき
- 推奨: 入力不明確時の処理を SKILL.md に明記する
- impact: medium, effort: low

### I-7: 次元エージェントファイルの冗長性 [efficiency]
- 対象: agents/
- 内容: 6つの次元エージェントファイル（CE, IC, WC, SA, DC, OF）に共通の2段階プロセス説明（Detection-First, Reporting-Second）と5つの Detection Strategy セクションが重複している
- 推奨: Phase 1/2の構造とDetection Strategyのフレームワークを共通テンプレートに外部化し、各エージェントは次元固有の検出ロジックのみ定義すべき
- impact: medium, effort: high

### I-8: グループ分類での「主たる機能」判定基準が曖昧 [stability]
- 対象: SKILL.md:Phase 0 グループ分類
- 内容: 「エージェント定義の主たる機能に注目して分類する」とあるが、evaluator特徴とproducer特徴が同数（例: 各3個）の場合の優先順位が未定義。group-classification.mdには「hybrid → evaluator → producer → unclassified の順に評価し、最初に該当したグループに分類」とあり整合しているが、SKILL.md側にもこの評価順序を明記すべき
- 推奨: SKILL.md に評価順序を明記する
- impact: low, effort: low

### I-9: Phase 1 findings ファイル読み込みの重複 [efficiency]
- 対象: SKILL.md:Phase 1, Phase 2 Step 1
- 内容: Phase 1 完了後のエラーハンドリング（Step 132-135）で各 findings ファイルを Read して Summary セクションを抽出し、Phase 2 Step 1（Step 154-157）で再度全 findings ファイルを Read している
- 推奨: Phase 1 の Summary 抽出結果を変数として保持し、Phase 2 で再利用できる。ただし Phase 1 で全文読み込みが必要な場合、節約効果は限定的
- impact: low, effort: low
