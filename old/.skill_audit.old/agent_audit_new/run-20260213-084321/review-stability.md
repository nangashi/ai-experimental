### 安定性レビュー結果

#### 重大な問題
- [参照整合性: テンプレート内のパス変数が未定義]: [templates/apply-improvements.md] [行3-4] [パス変数 `{approved_findings_path}` と `{agent_path}` を参照しているが、テンプレートファイルにパス変数の定義セクションがない] → [テンプレート先頭に `## パス変数` セクションを追加し、`{agent_path}` と `{approved_findings_path}` の説明を明記する。現在は SKILL.md のみで定義され、サブエージェントがテンプレートを読むときに変数定義を参照できない。] [impact: high] [effort: low]
- [条件分岐の完全性: Phase 0 Step 6 で既存ディレクトリが存在する場合の処理が曖昧]: [SKILL.md] [行94] [「既存ディレクトリが存在する場合はそのまま使用する。既存ファイルは上書きせず、各Phaseで必要に応じて新規作成または更新する」とあるが、「必要に応じて」が曖昧で、どのファイルが上書きされどのファイルが保持されるか不明確] → [各フェーズで生成するファイルと、既存ファイルの扱いを明示する。例: 「audit-{ID_PREFIX}.md は Phase 1 で常に新規作成（既存同名ファイルは上書き）、audit-approved.md は Phase 2 で常に新規作成、verification.md は Phase 2 Step 4 検証時に常に新規作成」と具体的な挙動を記述する。] [impact: high] [effort: medium]
- [冪等性: Phase 1 で findings ファイルが既存の場合の挙動が未定義]: [SKILL.md] [行128-135] [サブエージェントが `.agent_audit/{agent_name}/audit-{ID_PREFIX}.md` に Write で保存する際、既存ファイルが存在する場合の挙動が未指定] → [Phase 1 の Task prompt に「findings の保存は Write を使用し、既存ファイルは上書きする（再実行時に古い分析結果を残さないため）」と明記する。または Phase 0 で既存 findings ファイルの削除ステップを追加する。] [impact: high] [effort: medium]
- [条件分岐の完全性: Phase 2 Step 1 で成功次元が0の場合の処理が未定義]: [SKILL.md] [行168-170] [「Phase 1 で成功した全次元の findings ファイルを Read する」とあるが、Phase 1 で部分成功判定により成功次元が0件（全次元失敗または IC 失敗+固有次元全失敗）の場合、Phase 1 でエラー終了するためこのパスには到達しない。しかし、行160では「critical + improvement の合計が 0 の場合」のみ Phase 2 スキップと記載されており、成功次元0件の場合との整合性が不明確] → [Phase 1 の部分成功判定（行146-151）を明確化: 「成功次元が1つでもあればPhase 2へ継続、成功次元が0の場合はエラー出力して終了」と明記し、Phase 2 Step 1 の前提条件を「Phase 1 で成功次元が1件以上存在する」と記述する。] [impact: medium] [effort: low]
- [参照整合性: SKILL.md で定義されたパス変数 `{backup_path}` がテンプレートで未使用]: [SKILL.md] [行29] [`{backup_path}` を Phase 2 で定義しているが、templates/apply-improvements.md では参照していない。テンプレートではバックアップ作成・ロールバックの責務がないためこれは正常だが、定義箇所が親エージェント専用であることが不明確] → [パス変数定義に「（親エージェント専用）」等の注記を追加するか、「サブエージェントが参照するパス変数」と「親エージェント内部で使用するパス変数」を分けて記載する。] [impact: low] [effort: low]

#### 改善提案
- [指示の具体性: 「必要に応じて」の曖昧表現]: [SKILL.md] [行94] [「各Phaseで必要に応じて新規作成または更新する」は実行判断を委ねており曖昧] → [既述の重大な問題で対処] [impact: high] [effort: medium]
- [出力フォーマット決定性: Phase 1 サブエージェント返答のフォーマット検証が不完全]: [SKILL.md] [行140-141] [「返答フォーマット不正時は件数を『?』表示」とあるが、不正フォーマットの具体的な定義がない。正規表現や必須フィールドのリストが未記載] → [フォーマット検証の具体的なルールを追加: 「返答が `dim: {次元名}, critical: {数値}, improvement: {数値}, info: {数値}` の形式に一致しない場合は不正とする。数値は非負整数のみ許可し、欠落フィールドや不正な文字列が含まれる場合も不正とする」と明記する。] [impact: medium] [effort: low]
- [条件分岐の完全性: Phase 2 Step 2a の per-item 承認で入力検証ルールが部分的]: [SKILL.md] [行208] [「入力が空または不明確な場合は『スキップ』として扱う」とあるが、「不明確」の具体的な基準がない] → [不明確の基準を定義: 「修正内容が5文字未満、または推奨アクションを特定できない場合（例: 『修正』『OK』等の単一語）は不明確とする」など、具体的な閾値を設定する。] [impact: medium] [effort: low]
- [冪等性: Phase 2 Step 4 バックアップ作成の既存バックアップ検出方法が環境依存]: [SKILL.md] [行254] [`ls {agent_path}.backup-* 2>/dev/null | tail -1` はシェル環境に依存し、ファイル名の辞書順に依存する。タイムスタンプ順でソートされていない可能性がある] → [Bash コマンドを `ls -t {agent_path}.backup-* 2>/dev/null | head -1` に変更し、最新のバックアップを確実に取得する（-t は更新時刻順ソート、head -1 で最新を取得）。または `find {agent_path}.backup-* -type f -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-` で更新時刻順に確実にソートする。] [impact: medium] [effort: low]
- [指示の具体性: Phase 2 Step 4 サブエージェント完了確認の検証条件が曖昧]: [SKILL.md] [行273] [「返答内容に `modified:` または `skipped:` が含まれているか検証」とあるが、部分一致か完全一致か、大文字小文字を区別するか等が未指定] → [検証条件を具体化: 「返答に `modified:` または `skipped:` を含む行が存在し（大文字小文字を区別）、かつ行の先頭が `modified:` または `skipped:` で始まる場合に成功とする」など、正規表現レベルで記述する。] [impact: medium] [effort: low]
- [条件分岐の完全性: Phase 2 検証ステップで frontmatter 検証失敗時の処理が未定義]: [SKILL.md] [行280] [「YAML frontmatter の存在確認」を行うが、存在しない場合の処理フローが未記載] → [検証失敗のカテゴリを追加: 「frontmatter 不在」「finding 適用失敗」「diff 検証失敗」を個別に記録し、各失敗タイプに応じたロールバック推奨度を Phase 3 で表示する（frontmatter 不在は critical、finding 適用失敗は medium 等）。] [impact: medium] [effort: medium]
- [参照整合性: 次元エージェント定義ファイルのパス変数セクションの不一致]: [agents/evaluator/detection-coverage.md] [行88-90] [このファイルのみ「Input Variables」セクションが Phase 2 の後（行88-90）に配置され、他の次元エージェントファイル（行15-19近辺）と構造が異なる] → [detection-coverage.md の構造を他の次元ファイルと統一し、「Input Variables」セクションを Phase 1 の前（Tasks セクション内、Steps の直前）に移動する。] [impact: low] [effort: low]

#### 良い点
- Phase 1 のサブエージェント返答が1行の定型フォーマット（`dim: {次元名}, critical: {N}, improvement: {M}, info: {K}`）に固定され、親コンテキストの消費を最小化している
- Phase 2 Step 4 でバックアップを自動作成し、ロールバック手順を明示的に表示することで、不可逆操作のリスクを軽減している
- 全 AskUserQuestion 呼び出しでタイムアウト時のデフォルト動作（キャンセル）が明記され、無限待機を防いでいる
