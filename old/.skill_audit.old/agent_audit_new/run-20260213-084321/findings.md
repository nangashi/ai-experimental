## 重大な問題

### C-1: 参照整合性: テンプレート内のパス変数が未定義 [stability]
- 対象: templates/apply-improvements.md:3-4
- 内容: パス変数 `{approved_findings_path}` と `{agent_path}` を参照しているが、テンプレートファイルにパス変数の定義セクションがない。現在は SKILL.md のみで定義され、サブエージェントがテンプレートを読むときに変数定義を参照できない
- 推奨: テンプレート先頭に `## パス変数` セクションを追加し、`{agent_path}` と `{approved_findings_path}` の説明を明記する
- impact: high, effort: low

### C-2: 条件分岐の完全性: Phase 0 Step 6 で既存ディレクトリが存在する場合の処理が曖昧 [stability]
- 対象: SKILL.md:94
- 内容: 「既存ディレクトリが存在する場合はそのまま使用する。既存ファイルは上書きせず、各Phaseで必要に応じて新規作成または更新する」とあるが、「必要に応じて」が曖昧で、どのファイルが上書きされどのファイルが保持されるか不明確
- 推奨: 各フェーズで生成するファイルと、既存ファイルの扱いを明示する。例: 「audit-{ID_PREFIX}.md は Phase 1 で常に新規作成（既存同名ファイルは上書き）、audit-approved.md は Phase 2 で常に新規作成、verification.md は Phase 2 Step 4 検証時に常に新規作成」と具体的な挙動を記述する
- impact: high, effort: medium

### C-3: 冪等性: Phase 1 で findings ファイルが既存の場合の挙動が未定義 [stability]
- 対象: SKILL.md:128-135
- 内容: サブエージェントが `.agent_audit/{agent_name}/audit-{ID_PREFIX}.md` に Write で保存する際、既存ファイルが存在する場合の挙動が未指定
- 推奨: Phase 1 の Task prompt に「findings の保存は Write を使用し、既存ファイルは上書きする（再実行時に古い分析結果を残さないため）」と明記する。または Phase 0 で既存 findings ファイルの削除ステップを追加する
- impact: high, effort: medium

### C-4: 条件分岐の完全性: Phase 2 Step 1 で成功次元が0の場合の処理が未定義 [stability]
- 対象: SKILL.md:168-170
- 内容: 「Phase 1 で成功した全次元の findings ファイルを Read する」とあるが、Phase 1 で部分成功判定により成功次元が0件（全次元失敗または IC 失敗+固有次元全失敗）の場合、Phase 1 でエラー終了するためこのパスには到達しない。しかし、行160では「critical + improvement の合計が 0 の場合」のみ Phase 2 スキップと記載されており、成功次元0件の場合との整合性が不明確
- 推奨: Phase 1 の部分成功判定（行146-151）を明確化: 「成功次元が1つでもあればPhase 2へ継続、成功次元が0の場合はエラー出力して終了」と明記し、Phase 2 Step 1 の前提条件を「Phase 1 で成功次元が1件以上存在する」と記述する
- impact: medium, effort: low

### C-5: エッジケース処理記述: バックアップコマンド失敗時の処理記述なし [effectiveness]
- 対象: SKILL.md - Phase 2 Step 4 バックアップ作成
- 内容: `cp` コマンド失敗時（ディスク容量不足、アクセス権不足）の処理が記述されていない。バックアップなしで改善適用を続行すると、失敗時のロールバックが不可能になる
- 推奨: バックアップ作成失敗時は "バックアップ作成に失敗しました: {エラー詳細}。改善適用を中止します。" と出力して Phase 3 へ直行することを推奨
- impact: high, effort: low

## 改善提案

### I-1: Phase 0 グループ分類での読み込み重複 [efficiency]
- 対象: SKILL.md:68, 75
- 内容: 約350行の二重読み込み。Phase 0でエージェント定義を一度Readしてagent_contentに保持（行68）し、次にgroup-classification.mdをRead（行75）してから分類を行うが、次元サブエージェントは各自が再度agent_pathをReadするため、親での保持が実質不要。agent_contentは分類後即座に破棄される（行85の明示的破棄）が、分類処理自体がgroup-classification.mdの内容を親コンテキストに保持した上でagent_contentと突合する形になっており、分類をサブエージェントに委譲してgroup-classification.mdのパスのみ渡せば親コンテキストを節約可能
- 推奨: 分類をサブエージェントに委譲してgroup-classification.mdのパスのみ渡す方式に変更
- impact: medium, effort: medium

### I-2: エッジケース処理記述: group-classification.md 不在時の処理フローが不完全 [effectiveness]
- 対象: Phase 0 Step 4
- 内容: group-classification.md が存在しない場合、"エラー出力して終了する" と記載されているが、エラーメッセージの内容、ユーザーへのリカバリー手順（group-classification.md の場所や期待される内容）が記述されていない。スキルが正しくインストールされていない場合に有用なガイダンスがないため、ユーザーがこの問題を自力で解決できない可能性がある
- 推奨: エラーメッセージに「group-classification.md が .claude/skills/agent_audit_new/ 配下に見つかりません。スキルファイルを確認してください。」のような具体的な案内を含める
- impact: medium, effort: low

### I-3: エッジケース処理記述: agent_path 読み込み失敗時のエラー詳細不足 [effectiveness]
- 対象: Phase 0 Step 2
- 内容: agent_path 読み込み失敗時に "エラー出力して終了" とあるが、エラーメッセージのフォーマットや内容が不明確。ファイル不在、アクセス権不足、パス不正などの失敗理由を区別せず、ユーザーが問題を特定できない可能性がある
- 推奨: 「ファイルが見つかりません: {agent_path}」のように Read ツールのエラーメッセージを含めた出力形式を明示する
- impact: medium, effort: low

### I-4: データフロー妥当性: Phase 1 findings 抽出ロジックの詳細不足 [effectiveness]
- 対象: Phase 2 Step 1
- 内容: "各ファイルから severity が critical または improvement の finding（`###` ブロック単位）を抽出し" とあるが、抽出ロジックの詳細が不明確。findings ファイルのフォーマット（各次元エージェント定義の Output Format セクションに記載）を前提とした処理が暗黙的依存となっている
- 推奨: 各次元の findings ファイルが "### {ID_PREFIX}-{NN}: {title} [severity: {level}]" の形式であることを Phase 2 Step 1 で明示するか、抽出失敗時の処理（フォーマット不正の場合は該当 finding をスキップ）を追加する
- impact: medium, effort: low

### I-5: データフロー妥当性: 検証ステップの具体的実装ロジックが欠落 [effectiveness]
- 対象: Phase 2 検証ステップ
- 内容: 検証手順（step 3）で "承認済み findings の適用確認" を実行するとあるが、この確認方法が曖昧。"推奨されたセクション・キーワードがファイル内に存在するか確認" とあるが、セクション・キーワードをどのように findings から抽出するかが不明確。findings の recommendation フィールドから正規表現や自然言語処理で変更内容を推定する処理が暗黙的依存となっている
- 推奨: 検証ステップの具体的な手順を明示する。例: 「各承認済み finding の recommendation からキーワードを抽出し、変更後ファイル内で Grep/文字列検索で存在を確認する。部分一致で検証し、不一致の場合は '適用未確認: {finding ID}' として記録する」
- impact: medium, effort: medium

### I-6: 出力フォーマット決定性: Phase 1 サブエージェント返答のフォーマット検証が不完全 [stability]
- 対象: SKILL.md:140-141
- 内容: 「返答フォーマット不正時は件数を『?』表示」とあるが、不正フォーマットの具体的な定義がない。正規表現や必須フィールドのリストが未記載
- 推奨: フォーマット検証の具体的なルールを追加: 「返答が `dim: {次元名}, critical: {数値}, improvement: {数値}, info: {数値}` の形式に一致しない場合は不正とする。数値は非負整数のみ許可し、欠落フィールドや不正な文字列が含まれる場合も不正とする」と明記する
- impact: medium, effort: low

### I-7: Phase 2 findings ファイル再読み込み [efficiency]
- 対象: SKILL.md:170
- 内容: Phase 1で各次元のfindings返答サマリ（1行: "dim: X, critical: N, improvement: M, info: K"）を受け取り、Phase 2 Step 1で再度全findingsファイルをReadする。Phase 1のサブエージェント返答に含まれるのがサマリのみであるため、この再読み込みは必須だが、Phase 1サブエージェントの返答行数を拡張して主要findings情報（ID, severity, title）を含めれば、Phase 2での読み込み量を削減可能
- 推奨: Phase 1サブエージェントの返答行数を拡張して主要findings情報（ID, severity, title）を含める
- impact: medium, effort: medium

### I-8: 冪等性: Phase 2 Step 4 バックアップ作成の既存バックアップ検出方法が環境依存 [stability]
- 対象: SKILL.md:254
- 内容: `ls {agent_path}.backup-* 2>/dev/null | tail -1` はシェル環境に依存し、ファイル名の辞書順に依存する。タイムスタンプ順でソートされていない可能性がある
- 推奨: Bash コマンドを `ls -t {agent_path}.backup-* 2>/dev/null | head -1` に変更し、最新のバックアップを確実に取得する（-t は更新時刻順ソート、head -1 で最新を取得）。または `find {agent_path}.backup-* -type f -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-` で更新時刻順に確実にソートする
- impact: medium, effort: low

### I-9: 条件分岐の完全性: Phase 2 検証ステップで frontmatter 検証失敗時の処理が未定義 [stability]
- 対象: SKILL.md:280
- 内容: 「YAML frontmatter の存在確認」を行うが、存在しない場合の処理フローが未記載
- 推奨: 検証失敗のカテゴリを追加: 「frontmatter 不在」「finding 適用失敗」「diff 検証失敗」を個別に記録し、各失敗タイプに応じたロールバック推奨度を Phase 3 で表示する（frontmatter 不在は critical、finding 適用失敗は medium 等）
- impact: medium, effort: medium
