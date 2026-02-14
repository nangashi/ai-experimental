### 安定性レビュー結果

#### 重大な問題
- [出力フォーマット決定性: サブエージェント返答行数が未定義]: [templates/phase0-perspective-generation.md] [Step 6行62] [「perspective 自動生成完了: {perspective_save_path}」とだけ返答する] → [「以下の1行を返答する:\n```\nperspective 自動生成完了: {perspective_save_path}\n```」に修正し、改行を含まないことを明示] [impact: medium] [effort: low]
- [出力フォーマット決定性: テンプレート内の返答フォーマットが曖昧]: [templates/perspective/critic-completeness.md] [L90-102] [「Report your findings to the coordinator using SendMessage in this format」後のフォーマットで、Missing Element Detection Evaluation テーブルの行数が未定義] → [「Table with 5+ rows:」を「Table with exactly 5-8 rows (one per essential design element):」に修正] [impact: medium] [effort: low]
- [参照整合性: 未定義変数の使用]: [templates/perspective/critic-effectiveness.md] [L22] [{existing_perspectives_summary} がパス変数リストで定義されていない] → [SKILL.md Phase 0 の perspective/critic-* サブエージェント起動箇所（L38-48）にパス変数として追加、または当該変数参照を削除] [impact: high] [effort: medium]
- [冪等性: ファイル上書き前の存在確認なし]: [SKILL.md] [Phase 1A L111, Phase 1B L133] [prompts_dir に Write でバリアント保存時、既存ファイルの存在確認がなく再実行時に重複生成される可能性] → [各 Phase で「Glob で {prompts_dir}/v{NNN}-*.md を検索し、既存ファイルがある場合は AskUserQuestion で上書き/スキップを選択する」処理を追加] [impact: high] [effort: medium]
- [条件分岐の完全性: 暗黙的条件の存在]: [templates/phase1b-variant-generation.md] [L8-10] [「audit_dim1_path が指定されている場合: Read で読み込む」の else 節（指定されていない場合の処理）が不明確] → [「指定されている場合」の後に「指定されていない場合: audit 統合候補セクションは省略し、次の手順へ進む」を追加] [impact: medium] [effort: low]

#### 改善提案
- [曖昧表現: 数値基準なしの判断指示]: [templates/phase1b-variant-generation.md] [L10] [「audit ファイルを読み込んだ場合: 検出された改善提案のリスト（各項目: 次元、カテゴリ、指摘内容）を生成し、ファイル末尾に ## Audit 統合候補 セクションとして記載する」の「リスト」が何件まで含めるべきか不明確] → [「検出された改善提案のうち、impact=high かつ effort=low/medium の項目（最大5件）を抽出し、ファイル末尾に記載する」に修正] [impact: medium] [effort: low]
- [曖昧表現: 「適切に」等の表現]: [templates/phase1b-variant-generation.md] [L19] [「各ファイルに Benchmark Metadata コメントを記載する（Variation ID を必ず含める）」の「記載する」形式が不明確] → [「ファイル先頭に以下の形式で Benchmark Metadata コメントを記載する:\n<!-- Benchmark Metadata\nVariation ID: {id}\n-->」に修正] [impact: medium] [effort: low]
- [出力フォーマット決定性: 可変フォーマット]: [templates/phase1b-variant-generation.md] [L34] [「2. （あれば2つ目）」の記述が曖昧で、バリアント数が1個の場合と2個の場合の出力フォーマットが異なる] → [「1個または2個のバリアントを生成し、それぞれに対して上記フォーマットで記述する」に修正] [impact: low] [effort: low]
- [参照整合性: ファイルパスの実在確認]: [SKILL.md] [Phase 0 L208, Phase 4 L221] [templates/phase3-error-handling.md を Read で読み込む指示があるが、このテンプレートは親エージェントが直接実行するため、サブエージェント用テンプレートとしての構造が不適切] → [phase3-error-handling.md を親エージェント向けの手順書として明示し、「サブエージェントに委譲」ではなく「親が直接実行」であることをコメントで明記] [impact: low] [effort: low]
- [冪等性: 状態蓄積処理の再実行]: [templates/phase6a-knowledge-update.md] [L16-24] [「改善のための考慮事項」セクションの更新で「既存の原則を全て保持する」と「20行を超える場合は削除」の条件が併存し、再実行時に削除判定が変わる可能性] → [「削除基準は累積ラウンド数に基づき固定する（例: Round 10 以前のデータで |effect| < 1.0pt かつ後続ラウンドで再現なしの場合削除）」に修正] [impact: medium] [effort: medium]
- [条件分岐の完全性: フェーズ再開の扱い]: [SKILL.md] [全体] [途中失敗時の再開手順が不明（Phase 2 で中断した場合、Phase 1 から再実行すべきか Phase 2 から再開可能か）] → [各 Phase の開始時に「このフェーズは冪等です。再実行時は既存ファイルを上書きします」または「このフェーズは累積的です。再実行時は前回の続きから実行します」を明示] [impact: low] [effort: medium]
- [曖昧表現: 「過去と異なる」の判定基準]: [templates/phase2-test-document.md] [L7] [「knowledge_path を確認し、過去と異なるドメインを選択する」の「異なる」の判定基準が不明確] → [「過去3ラウンドで使用されていないドメイン/業界カテゴリを選択する。全カテゴリを使用済みの場合は、最も古いドメインを再利用する」に修正] [impact: low] [effort: low]

#### 良い点
- [出力フォーマット決定性]: templates/phase4-scoring.md, templates/phase5-analysis-report.md でサブエージェント返答の行数・フィールド名が明確に定義されている（phase4: 2行固定、phase5: 7行固定フォーマット）
- [参照整合性]: SKILL.md のパス変数が全テンプレートで一貫して `{variable}` 形式で使用され、パターンマッチが容易
- [冪等性]: Phase 0 の perspective 解決で既存ファイルの Read → 失敗時フォールバック → 失敗時自動生成の3段階フォールバック構造により、再実行時の安定性が確保されている
