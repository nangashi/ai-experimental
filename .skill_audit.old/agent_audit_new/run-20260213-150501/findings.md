## 重大な問題

### C-1: findings ファイルの Summary セクション形式が未定義 [effectiveness]
- 対象: SKILL.md Phase 1 Step エラーハンドリング (line 162)
- 内容: サブエージェント返答からの件数抽出失敗時、findings ファイルの「## Summary セクション内の件数を抽出する」と記載されているが、findings ファイルに含まれるべき Summary セクションの形式がテンプレート・次元エージェント定義のいずれにも記載されていない。次元エージェントが findings を保存する際の必須構造が未定義のため、フォールバック処理が実行不能である
- 推奨: analyze-dimensions.md テンプレートまたは各次元エージェント定義に、findings ファイルの必須セクション構造として「## Summary」セクションを追加し、形式を明示する（例: "critical: N件, improvement: M件, info: K件"）
- impact: high, effort: low

### C-2: 前回承認済み findings からの ID 抽出方法が未定義 [effectiveness]
- 対象: SKILL.md Phase 3 前回比較 (line 330)
- 内容: 「{previous_approved_path} を Read し、finding ID セットを抽出（{previous_ids}）」と記載されているが、抽出方法が未定義である。audit-approved.md の構造は Step 3 で定義されているが（line 236-253）、この構造から finding ID を抽出する具体的な正規表現・パース方法が記載されていない。Phase 3 実行時に抽出失敗のリスクがある
- 推奨: Phase 3 内に抽出方法を明示する（例: "### {ID}: {title} 形式の行から ID 部分を抽出"）
- impact: medium, effort: low

## 改善提案

### I-1: Phase 1 findings ファイル読込時の2次抽出失敗処理が不明確 [stability]
- 対象: SKILL.md Phase 1 エラーハンドリング (lines 161-163)
- 内容: 「抽出失敗時は findings ファイルを Read し、`## Summary` セクション内の件数を抽出する」とあるが、この2次抽出も失敗した場合の処理が未定義
- 推奨: 2次抽出失敗時の処理を追加（例: 該当次元を「分析失敗（返答形式不一致）」として記録し、Phase 2 で除外する）
- impact: medium, effort: low

### I-2: Phase 2 Step 1 severity フィールドのバリデーションが不足 [stability]
- 対象: SKILL.md Phase 2 Step 1 (lines 183-193)
- 内容: 「severity が `critical` または `improvement` の finding のみを対象とする」とあるが、severity フィールドが欠落している場合や認識できない値（例: "warning", "info"）が記載されている場合の処理が未定義
- 推奨: severity フィールド欠落時・不正値時の処理を追加（例: 「severity フィールドが欠落または不正な finding はスキップし、警告を表示」）
- impact: medium, effort: low

### I-3: 共通フレームワーク要約展開の残骸プレースホルダを削除 [architecture, efficiency]
- 対象: agents/shared/instruction-clarity.md, agents/evaluator/criteria-effectiveness.md, agents/producer/workflow-completeness.md 等
- 内容: 全次元エージェントファイル内に「{親エージェントが analysis-framework.md から抽出した要約がここに展開されます}」というプレースホルダーが残存している。resolved-issues.md の C-1（run: 20260213-145225）で「要約展開処理を削除、各次元エージェントが自身のファイル内セクションを参照する方式に変更」と記載されているが、実際には analysis-framework.md を読み込むように変更されていない
- 推奨: 各次元エージェントは analysis-framework.md を直接 Read するか、プレースホルダーを削除して自己完結型のドキュメントにすべき
- impact: medium, effort: low

### I-4: Phase 0 グループ分類サブエージェントは直接実装可能 [efficiency]
- 対象: SKILL.md Phase 0 Step 4
- 内容: haiku サブエージェントで4特徴の分類を実行しているが、親が直接 analysis-framework.md 以外の全体構造を把握しているため、簡易的な文字列検出（"Findings" セクション有無、"Phase"/"Workflow" 有無の2チェック）で分類可能。サブエージェント委譲が過剰
- 推奨: 親エージェントが直接グループ分類を実施する（推定節約量: ~50行/実行）
- impact: medium, effort: low

### I-5: Phase 2 Step 2a の「残りすべて承認」選択肢を分割 [ux]
- 対象: SKILL.md Phase 2 Step 2a (line 228)
- 内容: 「残りすべて承認」は severity に関係なく全指摘を承認する設計。critical を個別確認していたユーザーが誤って選択すると、未確認の critical が自動承認される
- 推奨: 「残りの critical のみ承認」「残りの improvement のみ承認」に分割するか、確認ダイアログを追加することで誤操作を防げる
- impact: medium, effort: low

### I-6: Phase 0 グループ分類抽出失敗時の理由表現を明確化 [stability]
- 対象: SKILL.md Phase 0 グループ分類 Step 4 (lines 90-93)
- 内容: 「理由: {形式不一致/不正な値/複数行存在}」という表現で、3種類のうちどれかを選択して展開する処理が明示されていない
- 推奨: 抽出処理の直後に、失敗理由を明示的に判定・設定するロジックを追加する（例: 形式不一致なら "pattern not found"、不正な値なら "invalid value: {value}"、複数行存在なら "multiple lines detected"）
- impact: low, effort: medium

### I-7: Phase 1 analyze-dimensions.md テンプレートは冗長 [efficiency]
- 対象: templates/analyze-dimensions.md
- 内容: テンプレートが実質的にパス変数展開のみで、各次元エージェントが既に返答フォーマットセクションを持つ。親が直接次元エージェントに委譲すればテンプレート不要（group-classification.md と同様の二重参照パターン）
- 推奨: テンプレートを削除し、親が直接次元エージェントに委譲する（推定節約量: ~30行/次元）
- impact: low, effort: low

### I-8: Phase 3 前回比較のID抽出失敗時の処理を明示 [stability, effectiveness]
- 対象: SKILL.md Phase 3 前回比較 (lines 326-333)
- 内容: 前回実行が古いバージョンで行われた場合や、ファイルが手動編集された場合、finding ID 抽出が失敗する可能性がある。抽出失敗時の処理（警告表示して比較スキップ、または解決済み指摘0件として扱う）が未定義。「finding ID セットを抽出」とあるが、ID 抽出の正規表現パターンや失敗時の処理が未定義
- 推奨: ID 抽出方法を明示（例: `### {ID}:` 形式の行から ID を抽出、抽出失敗時は空セットとして扱う）し、抽出失敗時の処理を定義する
- impact: low, effort: low

### I-9: Phase 3 前回比較サマリの形式を明示 [stability]
- 対象: SKILL.md Phase 3 完了サマリ (lines 326-333)
- 内容: 「解決済み指摘: {解決済み指摘 ID のリスト}」「新規指摘: {新規指摘 ID のリスト}」の形式が不定（リストが空の場合の表示形式や区切り文字が未指定）
- 推奨: リスト形式を明示（例: カンマ区切り、なければ "なし"）
- impact: low, effort: low
