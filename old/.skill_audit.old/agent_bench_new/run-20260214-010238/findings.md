## 重大な問題

なし

## 改善提案

### I-1: Phase 0 perspective 自動生成 Step 4 統合フィードバックの処理未定義 [stability, architecture]
- 対象: SKILL.md:行102-124
- 内容: critic-completeness.md で統合フィードバックを生成しているが、SKILL.md 側で4つの批評エージェント完了後に統合ファイルを読み込む処理が欠落している。また、統合フィードバックの構造（重大な問題と改善提案の有無判定方法）が未定義
- 推奨: (1) SKILL.md に4つの Task 完了待機後に perspective-critique-completeness.md を読み込む処理を追記 (2) critic-completeness.md の Phase 7 で生成する統合フィードバックのフォーマット（「#### 重大な問題」「#### 改善提案」セクションの有無）を明示 (3) Step 5 での判定条件を「重大な問題」または「改善提案」セクションが「なし」以外の内容を含む場合と明記
- impact: medium, effort: low

### I-2: Phase 6 最終サマリの情報取得ステップ欠落 [effectiveness]
- 対象: Phase 6 Step 2C
- 内容: 最終サマリに含まれる「効果のあったテクニック」を knowledge.md から抽出する処理が明示されていない。また、ラウンド別性能推移テーブルの「Applied Technique」フィールドの情報源が不明
- 推奨: knowledge.md の効果テーブルおよびラウンド別テクニック情報を読み込むステップを Phase 6 Step 2C に追加し、最終サマリに含まれる「効果のあったテクニック」の抽出範囲（全体 or 上位N件）と抽出方法を明示
- impact: medium, effort: low

### I-3: Phase 5 → Phase 6 のサブエージェント返答フィールド名不一致 [effectiveness]
- 対象: Phase 5 → Phase 6 Step 2
- 内容: Phase 5 テンプレートは「recommended」「reason」を返すが、Phase 6 Step 2A では「recommended_name」「judgment_reason」として参照している。親がフィールド名変換を行う必要があるが、SKILL.md 内に明示的な変換処理が記述されていない
- 推奨: Phase 6 Step 2A の処理フローに Phase 5 返答からフィールド名を抽出する処理（recommended → recommended_name, reason → judgment_reason）を明記
- impact: medium, effort: low

### I-4: Phase 0 Step 4c ヒアリング後の処理フロー未定義 [stability]
- 対象: SKILL.md:行81-85
- 内容: エージェント定義不足時のヒアリング後、user_requirements への追加方法が暗黙的。AskUserQuestion の返答を user_requirements に追記し、改めてエージェント定義が200文字以上になったか再判定するフローが不明確
- 推奨: AskUserQuestion の返答を user_requirements に追記し、改めてエージェント定義が200文字以上になったか再判定するフローを明示
- impact: medium, effort: low

### I-5: Phase 6 Step 2C 再試行後の処理フロー未定義 [stability]
- 対象: SKILL.md:行355-364
- 内容: 再試行しても失敗が継続する場合の処理が未記述。無限ループまたは処理停止の可能性がある
- 推奨: 再試行後も失敗した場合は「警告を出力し、該当更新をスキップして次アクション選択に進む」旨を明記
- impact: medium, effort: low

### I-6: Phase 0 Step 6 検証失敗時の再試行フロー暗黙的 [ux]
- 対象: Phase 0 Step 6
- 内容: 検証失敗時に「手動修正/再試行/中断」の3択を一度に提示しているが、手動修正を選択した場合の修正完了後の再試行フローが暗黙的
- 推奨: 手動修正完了を確認してから再試行するか、修正後に自動的に検証を再実行する明示的フローを追加
- impact: medium, effort: low

### I-7: Phase 1A/1B プロンプトファイル上書き確認の複数回実行 [stability]
- 対象: phase1a-variant-generation.md:行10-11, phase1b-variant-generation.md:行23-24
- 内容: ベースラインとバリアントで個別に存在確認と AskUserQuestion を実行するため、ユーザーに複数回確認を求める可能性がある
- 推奨: Phase 1A/1B の冒頭で {prompts_dir} 配下の v{NNN}-*.md の一括存在確認を行い、1つでも存在する場合に一度だけ AskUserQuestion で確認する方式に変更
- impact: low, effort: medium

### I-8: Phase 6 Step 2A/2B 失敗時のユーザー通知不明 [architecture]
- 対象: SKILL.md:行351-352
- 内容: A) と B) のサブエージェントタスクのいずれかが失敗した場合でも次アクション選択に進むとあるが、失敗時のユーザー通知が不明
- 推奨: 失敗したステップ名を出力してから次アクション選択に進む旨を明記
- impact: low, effort: low

### I-9: Phase 0 Step 4 {target} 変数の未導出リスク [stability]
- 対象: SKILL.md:行110
- 内容: パス変数リストに {target} が定義されているが、Phase 0 Step 4b で perspective フォールバック判定が失敗した場合に {target} が未導出のままとなる可能性がある
- 推奨: Step 3（perspective 自動生成）実行時に {target} をデフォルト値（例: "design"）で設定するか、{existing_perspectives_summary} の Glob パターンから {target} を除外
- impact: low, effort: medium

### I-10: Phase 3 再試行ループの無限再帰防止 [stability]
- 対象: SKILL.md:行245
- 内容: 再試行1回後も失敗した場合は自動中断とあるが、再試行処理自体が親コンテキストで実行されるため、サブエージェント失敗→親が再試行→再失敗→自動中断の流れが暗黙的
- 推奨: 再試行回数のカウンタを明示し、「1回目の再試行で失敗した場合は2回目を実行せずエラー出力して中断」を明記
- impact: low, effort: low

### I-11: Phase 1B audit_findings_paths 空判定の曖昧性 [architecture]
- 対象: phase1b-variant-generation.md:行8-13
- 内容: {audit_findings_paths} が空でない場合の処理は記述されているが、「空の場合」の明示的な分岐がない。空文字列の場合の動作が不明確
- 推奨: 空文字列の場合は Read をスキップすることを明記
- impact: low, effort: low

### I-12: knowledge-init-template.md の approach_catalog_path の冗長読込 [architecture]
- 対象: knowledge-init-template.md:行3
- 内容: {approach_catalog_path} を読み込んでいるが、テンプレート内でバリエーションID抽出以外に使用していない。抽出ロジックが明示されておらず、カタログの全文を読む必要性が不明
- 推奨: Phase 0 初期化では全 ID 一覧のみが必要なため、SKILL.md 側で ID リストを抽出してテンプレートに渡す
- impact: low, effort: medium

### I-13: Phase 0 Step 5 統合済みフィードバックの返答処理冗長 [efficiency]
- 対象: Phase 0 Step 5
- 内容: critic-completeness.md から統合済みフィードバックを Read した後、Step 3 サブエージェントに戻って再生成する処理がある。統合処理は completeness テンプレート内で実行済みなので、親が再度読み込んで判定するのは冗長
- 推奨: 統合フィードバックファイルの有無または「重大な問題あり」フラグをファイル名で表現する（例: perspective-critique-needs-regeneration.flag）、または completeness サブエージェントの返答に「再生成必要/不要」の1行を追加
- impact: low, effort: low

### I-14: Phase 1B Broad/Deep モード判定後のカタログ読込最適化 [efficiency]
- 対象: Phase 1B
- 内容: Deep モード時のみ approach-catalog.md を読み込む設計は既に最適化済みだが、さらに効率化するには、Deep モード選択時にカテゴリ名（S/C/N/M）を親から渡し、テンプレート側で該当カテゴリのセクションのみ Read する方法がある（現状は全202行を読込）
- 推奨: Deep モード選択時にカテゴリ名を渡し、該当カテゴリのみ読み込む設計を検討（ただし、実装コストに対する効果が限定的）
- impact: low, effort: medium

### I-15: Phase 2 knowledge.md の参照範囲最適化 [efficiency]
- 対象: Phase 2 テンプレート
- 内容: Phase 2 テンプレートで knowledge.md の「テストセット履歴」セクションのみを参照するが、親から該当セクションの内容を直接渡す方がサブエージェントのコンテキスト消費を削減できる
- 推奨: 親で knowledge.md から該当セクションを抽出し、{test_history_summary} 変数として渡す
- impact: low, effort: low

### I-16: Phase 0 perspective 自動生成 Step 2 reference_perspective_path 収集最適化 [efficiency]
- 対象: Phase 0 Step 2
- 内容: Glob で perspectives/design/*.md を列挙し、最初の1ファイルを選択する処理。既存 perspective の構造参照が目的なので、固定ファイル（例: perspectives/design/security.md）を使用することで Glob 処理を省略できる
- 推奨: 将来的に参照用の「標準テンプレート」ファイルを明示的に用意し、固定パスで参照
- impact: low, effort: low
