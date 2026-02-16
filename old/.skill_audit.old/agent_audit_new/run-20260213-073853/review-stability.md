### 安定性レビュー結果

#### 重大な問題
- [参照整合性: 未定義変数の使用]: [SKILL.md] [Line 328] `{analysis_path}` プレースホルダが validate-agent-structure.md テンプレートに渡されているが、analysis.md が存在しない場合の挙動が不明確。→ Phase 2 検証ステップで "存在する場合のみ" と記載されているが、実際の渡し方（条件分岐の実装方法）が未指定。具体的に「analysis.md が存在する場合は `- {analysis_path}: ...` を含める、存在しない場合はこの行を省略する」と明記すべき [impact: high] [effort: low]
- [出力フォーマット決定性: サブエージェント返答の曖昧さ]: [templates/apply-improvements.md] [Line 36-42] サブエージェントの返答が「上限: 30行以内」となっているが、上限を超える場合の処理（切り捨て? エラー? 要約?）が未指定。→ 「30行を超える場合は重要度順に上位30行まで記載」等の明示的ルールを追加すべき [impact: medium] [effort: low]
- [条件分岐の完全性: else節の欠落]: [SKILL.md] [Line 265-268] Phase 2 Step 1 の整合性チェックで「存在する場合は」エラー出力とあるが、存在しない（正常）場合の処理が未記述。→ 「存在しない場合は次のステップへ進む」と明記すべき [impact: medium] [effort: low]
- [冪等性: 既存ファイル上書き時のバックアップ不備]: [SKILL.md] [Line 163-167] Phase 1 で既存 findings ファイルを `.prev` でバックアップするが、`.prev` 自体が既に存在する場合の処理が未指定（2回目の実行で前回のバックアップが上書きされる）。→ タイムスタンプ付きバックアップ（`.prev-{timestamp}`）に変更、または「.prev が既に存在する場合は .prev.1, .prev.2 とナンバリング」等の明示的ルールを追加すべき [impact: high] [effort: medium]
- [参照整合性: ファイル実在確認の欠落]: [SKILL.md] [Line 102-106] classify-agent-group.md テンプレートで `{classification_guide_path}` として `group-classification.md` を参照しているが、このファイルの実在確認（Read 失敗時の処理）が SKILL.md に記載されていない。→ Phase 0 Step 4 の前に「Bash で group-classification.md の存在確認を実行し、不在時はエラー出力して終了」を追加すべき [impact: high] [effort: low]

#### 改善提案
- [指示の具体性: 曖昧な基準]: [SKILL.md] [Line 199] 「findings ファイルが空でない（0バイトでなく、かつ `## Summary` セクションを含む）」は基準が曖昧（Summary セクションが存在すれば0バイトでもOKか?）。→ 「0バイトでない、かつ `## Summary` セクションを含む」と AND 条件を明確化すべき [impact: low] [effort: low]
- [指示の具体性: 「適切な」等の曖昧表現]: [templates/classify-agent-group.md] [Line 3] "適切なグループ" という表現が曖昧。→ "グループ分類基準に従って最も該当するグループ" に変更すべき [impact: low] [effort: low]
- [出力フォーマット決定性: 件数取得失敗時の処理不足]: [SKILL.md] [Line 199] 「抽出失敗時は『件数取得失敗』として記録し、Phase 2 Step 1 で findings ファイルから直接件数を再取得する」とあるが、Phase 2 Step 1 には findings ファイルから件数を抽出する指示が存在しない（collect-findings.md サブエージェントに委譲されているため、親が直接抽出する処理がない）。→ collect-findings.md テンプレートに「各 finding から critical/improvement を集計し、total/critical/improvement 件数をカウントする」指示を明記すべき [impact: medium] [effort: low]
- [条件分岐の完全性: 部分適用時の skipped 記録ルール未指定]: [templates/apply-improvements.md] [Line 26] 「二重適用チェック」で既に改善済みの場合は skipped に記録するとあるが、skipped のフォーマット（finding ID + 理由のみ? ファイルパス・セクション名も含める?）が未指定。→ 返答フォーマットのセクションに「skipped: {finding ID}: {理由}（{ファイルパス}:{セクション名}）」等の具体例を追加すべき [impact: low] [effort: low]
- [冪等性: バックアップパス記録の明示不足]: [SKILL.md] [Line 300] 「生成された完全な絶対パスを `{backup_path}` として記録する」とあるが、「記録する」の実装方法（変数として保持? ファイルに書き出す?）が未指定。→ 「親コンテキストの変数として保持する」と明記すべき [impact: low] [effort: low]
- [参照整合性: テンプレート内変数の未使用検出]: [templates/validate-agent-structure.md] 全プレースホルダ（{agent_path}, {backup_path}, {analysis_path}）が SKILL.md で定義済み。未使用変数なし。[impact: low] [effort: low]
- [参照整合性: SKILL.md 定義変数の未使用検出]: [SKILL.md] で定義された変数のうち、`{agent_content}` は classify-agent-group.md でのみ使用され、他のテンプレートでは使用されていない（各次元エージェントは agent_path から直接 Read する構造）。これは設計上意図的と思われるが、consistency のため確認を推奨。[impact: low] [effort: low]

#### 良い点
- 全サブエージェント返答フォーマットが行数・フィールド名・区切りを明示しており、決定性が高い（2行返答、3行返答、4行返答の形式が統一されている）
- Phase 1 のエラーハンドリングで全失敗・部分失敗の判定基準（IC 成功 or 成功数≧2）が明確に定義されている
- バックアップ作成後の検証ステップで自動ロールバック機能が実装されており、改善適用失敗時の復旧が保証されている
