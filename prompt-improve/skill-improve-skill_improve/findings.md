## 重大な問題

### S-C1: 未定義の{perspective}変数 [stability]
- 対象: SKILL.md Line 92
- SKILL.md で reviewer-{perspective}.md を参照しているが、{perspective} は反復文の中で使用されており、プレースホルダとして定義されていない
- 改善案: 各レビューアー（stability, efficiency, ux, architecture）を明示的に列挙する指示に変更すべき

### S-C2: Phase 6返答フォーマット不明確 [stability]
- 対象: verify-improvements.md Line 63-71
- details フィールドの具体的な書式（カンマ区切り、項目IDの形式等）が不明確で、SKILL.md Line 213での抜粋処理が安定しない
- 改善案: 「details: {未対応項目ID（例: C-1,I-5）をカンマ区切りで列挙。リグレッションがある場合は "regression:{N}件" を追加。なければ "none"}」等の具体例を追加

### S-C3: Phase 0のファイル削除で再実行時の成果物消失 [stability]
- 対象: SKILL.md Line 43
- `rm -f {work_dir}/*.md` で作業ディレクトリ内の全.mdファイルを削除しているが、Phase 1-6の途中で失敗した場合に再実行すると既存の成果物が消失する
- 改善案: 再実行時の成果物保持またはタイムスタンプ付きバックアップの仕組みが必要

### S-C4: Phase 3 Step 2の未検出分岐が暗黙的 [stability]
- 対象: SKILL.md Line 128
- コンフリクト検出の手順1-5で「1件も検出されなかった場合」は明示されているが、検出された場合のStep 3への移行が暗黙的
- 改善案: 「コンフリクトが1件以上検出された場合、Step 3でコンフリクト解決を実行する」を明記

### S-C5: Phase 3 Step 3の判定不能時処理が不明確 [stability]
- 対象: SKILL.md Line 147
- 判定基準で解決できない場合に「のみ」AskUserQuestionでユーザーに確認とあるが、ユーザーが選択した後の処理（選択結果を分類結果に反映させる方法）が未記載
- 改善案: 「ユーザー選択を反映させてStep 4へ進む」等の処理フローを追加

## 改善提案

### S-I1: Phase 1の優先順位基準 [stability]
- 対象: analyze-skill-structure.md Line 15
- 「20ファイル超の場合」の優先順位で「アルファベット順で先頭5ファイルのみ」は情報価値が低い
- 改善案: 「ファイルサイズ降順で先頭5ファイル」または「ワークフローで頻繁に参照されるファイルを優先」に変更

### S-I2: Phase 3 Step 1のコンフリクト検出基準 [stability]
- 対象: SKILL.md Line 119
- 「コンフリクト検出が必要な場合のみ review-*.md を Read」の要否判定基準が不十分
- 改善案: 「全レビューで問題合計≥2件の場合にコンフリクト検出を実施」等の数値基準を追加

### S-I3: analysis.mdの可変行数記述 [stability]
- 対象: analysis.md
- Phase 5返答が「可変行数」とあるが、apply-improvements.mdでは具体的な形式が定義されている
- 改善案: 「可変行数」記述を「4-20行（件数に応じた詳細リスト含む）」に修正

### S-I4: 二重適用チェックで「現在の記述」未記載時 [stability]
- 対象: apply-improvements.md Line 30
- 改善計画に「現在の記述」が記載されていない場合の処理が未定義
- 改善案: 「改善計画に現在の記述がない場合は警告を出力し、変更をスキップする」を追加

### S-I5: {perspective}変数の値の明記 [stability]
- 対象: reviewer-*.md / SKILL.md
- テンプレートファイル名が reviewer-{perspective}.md だが変数名が明示的に定義されていない
- 改善案: SKILL.md に「{perspective} 変数の値: stability, efficiency, ux, architecture」を明記
- 注: S-C1 と関連。S-C1 の修正（明示的列挙への変更）で解消可能

### S-I6: Phase 4「修正要望あり」時のEdit/Write明示 [stability]
- 対象: SKILL.md Line 187
- 修正内容をimprovement-plan.mdの末尾に追記する際のツール指定が不明確
- 改善案: 「Edit で改善計画の末尾に追加する」を明示

### S-I7: Phase 6「追加修正」時の既存セクション処理 [stability]
- 対象: SKILL.md Line 214
- 追加修正の方針をimprovement-plan.mdに追記する際、既存セクション処理が不明確
- 改善案: 「既存セクションがある場合は新規エントリとして追記」を明示

### E-I1: Phase 3 Step 1の不要なファイル読み込み [efficiency]
- 対象: Phase 3 Step 1 / Phase 2 レビューアー返答
- 推定節約量: ~15,000トークン/実行
- コンフリクト検出のために全review-*.mdをReadする必要がある
- 改善案: Phase 2の各レビューアーが返答時に「重大/改善の各項目の対象ファイル:セクション」を追加で返答し、親が保持することでPhase 3 Step 1でのファイル読み込みを回避

### E-I2: Phase 4のサブエージェント返答行数拡張 [efficiency]
- 対象: Phase 4 / consolidate-findings.md
- 推定節約量: ~3,000トークン/実行（ただし効果限定的）
- 改善案: サブエージェント返答を7-10行に拡張し計画サマリを含める（ユーザー詳細確認時は結局全Readが必要）

### E-I3: Phase 6のリトライループの重点チェック [efficiency]
- 対象: Phase 5-6 のリトライループ
- Phase 5→6の2回目実行時にリトライモードフラグを設定し、前回未解決項目を重点チェック
- 改善案: verify-improvements.md にリトライモード対応を追加

### U-I1: Phase 4の一括承認パターン [ux]
- 対象: Phase 4
- 「全て承認」/「修正要望あり」/「キャンセル」の3択で個別承認/却下ができない
- 品質基準「提案ごとの個別承認」に抵触
- 改善案: 各改善項目に対する個別承認ループを追加

### U-I2: Phase 2の失敗情報提示タイミング [ux]
- 対象: Phase 2
- 成功数≥3の場合、失敗レビューアー情報の確認タイミングが不明確
- 改善案: 成功数<4の場合は常に失敗レビューアー名と理由を先にテキスト出力

### U-I3: Phase 6の再試行上限の数値明示 [ux]
- 対象: Phase 6
- 「再試行上限に達しました」と出力するが上限値が不明確
- 改善案: 「再試行上限（1回）に達しました」形式で出力

### U-I4: Phase 6のNEEDS_ATTENTION時の影響説明 [ux]
- 対象: Phase 6
- 「このまま受け入れる」選択の影響が十分に説明されていない
- 改善案: 選択肢提示前に「未解決項目: {件数}件、影響範囲: {概要}」を出力

### U-I5: Phase 5のStandard mode詳細出力 [ux]
- 対象: Phase 5
- Standard modeでも変更ファイルリストが省略される
- 改善案: Standard modeでは変更ファイルリスト（ファイル名+変更種別）を出力

### U-I6: 使い方ドキュメントの概要不足 [ux]
- 対象: SKILL.md 冒頭
- 各フェーズで何が起きるか、完了時に何が得られるかの概要が不足
- 改善案: 「期待される動作」サブセクションを追加

### U-I7: Phase 0のFast mode説明不足 [ux]
- 対象: Phase 0
- Fast modeの具体的なスキップ内容が不明確
- 改善案: 選択肢の説明を具体的に変更

### A-I1: Phase 3のコンフリクト検出ロジックのテンプレート化検討 [architecture]
- 対象: SKILL.md Phase 3
- Phase 3 Step 2-3のコンフリクト検出・解決ロジック（約25行）のテンプレート化を検討
- 自己判定: 親が直接実行する判断ロジックのため、現状のインライン配置が適切の可能性が高い

### A-I2: Phase 3のレビューファイルRead失敗時の処理 [architecture]
- 対象: SKILL.md Phase 3 Step 1
- Read失敗時の処理が未定義
- 改善案: コンフリクト検出スキップとしてPhase 4へ進む処理を明示

### A-I3: ナレッジ蓄積の仕組み [architecture]
- 対象: skill_improve スキル全体
- 改善知見を蓄積する仕組みがあると将来の提案の質が向上する可能性
- 自己判定: 現状の1回実行で完結する設計では不要

### A-I4: サブエージェントモデル指定の最適化 [architecture]
- 対象: SKILL.md Phase 1-6
- Phase 5はファイル操作主体でhaikuでも可能な可能性
- 自己判定: 二重適用チェック等の解釈が必要なため現状のsonnetが適切

### A-I5: Phase 5の自己検証追加 [architecture]
- 対象: apply-improvements.md
- 改善適用後に変更箇所を再Readして軽量自己検証を追加
- 改善案: Phase 6の検証コスト削減の可能性
