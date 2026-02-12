### 安定性レビュー結果

#### 重大な問題
- [参照整合性: 未定義の{perspective}変数]: [SKILL.md] [Line 92] SKILL.md で reviewer-{perspective}.md を参照しているが、{perspective} は反復文の中で使用されており、プレースホルダとして定義されていない → 各レビューアー（stability, efficiency, ux, architecture）を明示的に列挙する指示に変更すべき
- [出力フォーマット決定性: Phase 6返答フォーマット不明確]: [verify-improvements.md] [Line 63-71] details フィールドの具体的な書式（カンマ区切り、項目IDの形式等）が不明確で、SKILL.md Line 213での抜粋処理が安定しない → 「details: {未対応項目ID（例: C-1,I-5）をカンマ区切りで列挙。リグレッションがある場合は "regression:{N}件" を追加。なければ "none"}」等の具体例を追加
- [冪等性: Phase 0のファイル削除]: [SKILL.md] [Line 43] `rm -f {work_dir}/*.md` で作業ディレクトリ内の全.mdファイルを削除しているが、Phase 1-6の途中で失敗した場合に再実行すると既存の成果物（analysis.md, review-*.md等）が消失する → 再実行時の成果物保持またはタイムスタンプ付きバックアップの仕組みが必要
- [条件分岐の完全性: Phase 3 Step 2の未検出分岐]: [SKILL.md] [Line 128] コンフリクト検出の手順1-5で「1件も検出されなかった場合」は明示されているが、検出された場合のStep 3への移行が暗黙的 → 「コンフリクトが1件以上検出された場合、Step 3でコンフリクト解決を実行する」を明記
- [条件分岐の完全性: Phase 3 Step 3の判定不能時処理が不明確]: [SKILL.md] [Line 147] 判定基準で解決できない場合に「のみ」AskUserQuestionでユーザーに確認とあるが、ユーザーが選択した後の処理（選択結果を分類結果に反映させる方法）が未記載 → 「ユーザー選択を反映させてStep 4へ進む」等の処理フローを追加

#### 改善提案
- [指示の具体性: Phase 1の優先順位基準]: [analyze-skill-structure.md] [Line 15] 「20ファイル超の場合」の優先順位で「アルファベット順で先頭5ファイルのみ」とあるが、ファイル名のアルファベット順は実質的にランダムで情報価値が低い → 「ファイルサイズ降順で先頭5ファイル」または「ワークフローで頻繁に参照されるファイル（analysis.mdで検出）を優先」に変更
- [指示の具体性: Phase 3 Step 1の「コンフリクト検出が必要な場合のみ」]: [SKILL.md] [Line 119] 「コンフリクト検出が必要な場合のみ review-*.md を Read」とあるが、コンフリクト検出の要否を判定するためにサマリ（critical, improvement, positiveの件数）だけでは不十分 → 「全レビューで問題合計≥2件の場合にコンフリクト検出を実施」等の数値基準を追加
- [出力フォーマット決定性: Phase 5返答の「可変行数」]: [analysis.md] [Line 101] Phase 5返答が「可変行数（modified, created, skipped, delete_recommendedの件数+詳細）」とあるが、apply-improvements.mdでは具体的な行数・形式が定義されている → analysis.mdの「可変行数」記述を削除または「4-20行（件数に応じた詳細リスト含む）」に修正
- [冪等性: Phase 5の二重適用チェック]: [apply-improvements.md] [Line 30] 「現在の記述」との一致確認で二重適用を防止しているが、改善計画に「現在の記述」が記載されていない場合の処理が未定義 → 「改善計画に現在の記述がない場合は警告を出力し、変更をスキップする」を追加
- [参照整合性: テンプレート内の{reviewer-name}形式の不一致]: [reviewer-stability.md, reviewer-efficiency.md, reviewer-ux.md, reviewer-architecture.md] 各テンプレートのファイル名が reviewer-{perspective}.md だが、SKILL.md Line 92で使用される変数名は明示的に定義されていない → SKILL.md に「{perspective} 変数の値: stability, efficiency, ux, architecture」を明記
- [指示の具体性: Phase 4の「修正要望あり」時の処理]: [SKILL.md] [Line 187] 修正内容をimprovement-plan.mdの末尾に追記する際、Edit を使うべきか Write を使うべきかが不明確 → 「Edit で改善計画の末尾に追加する」を明示
- [指示の具体性: Phase 6の「追加修正」時の処理]: [SKILL.md] [Line 214] 追加修正の方針をimprovement-plan.mdに追記する際、既存の「ユーザー追加修正」セクションがある場合の処理（上書き/追記）が不明確 → 「既存セクションがある場合は新規エントリとして追記」を明示

#### 良い点
- [出力フォーマット決定性]: 全テンプレートが「保存後、以下のサマリのみ返答してください」で明確な返答フォーマット（行数・フィールド名）を指定している
- [冪等性]: Phase 5の二重適用チェック（apply-improvements.md Line 30）により、再実行時の重複変更を防止する仕組みが組み込まれている
- [参照整合性]: 全テンプレートのパス変数セクション（各テンプレート冒頭）で使用する変数を明示的に列挙し、SKILL.md の各Phase で全て定義されている
