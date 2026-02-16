## 重大な問題

### C-1: Phase 1B audit ファイル検索処理の else 節欠落 [stability, architecture]
- 対象: SKILL.md:188-190
- 内容: audit-ce-*.md と audit-sa-*.md を Glob で検索する際、「見つからない場合は空文字列を渡し、Phase 1B は knowledge.md の過去知見のみでバリアント生成を行う」とあるが、テンプレート側で空文字列判定の処理が明示されていない。また、スキルディレクトリ外（.agent_audit/{agent_name}/）への参照となっている
- 推奨: (1) 見つからない場合の変数設定を明示: "{audit_dim1_path} = "" および {audit_dim2_path} = "" として渡す。テンプレート側で空文字列判定（if パスが空でない場合のみ Read）を明記する" (2) スキルディレクトリ内に参照用コピーを配置する設計を検討
- impact: medium, effort: medium

### C-2: Phase 0 Step 4 perspective 検索フローの分岐不完全 [stability, effectiveness]
- 対象: SKILL.md:54-57
- 内容: ファイル名パターン一致時の処理として「一致したがファイル不在の場合: パースペクティブ自動生成を実行する」のみ記載されており、「一致しファイル存在の場合」の処理が抜けている。Glob 結果0件時の変数未定義問題も関連
- 推奨: 分岐を明示: "一致しファイル存在の場合: perspective-source.md にコピー後、Step 5 に進む。一致したがファイル不在の場合: パースペクティブ自動生成を実行する。一致しない場合: reviewer_create テンプレートによる自動生成を実行する"
- impact: high, effort: low

### C-3: テンプレート内未定義変数の参照整合性欠如 [stability]
- 対象: templates/phase1a-variant-generation.md:9
- 内容: {user_requirements} を参照しているが、SKILL.md では Phase 1A (164-167行) でエージェント定義が新規作成時のみ渡すと記載。テンプレート内で未定義時の処理が不明
- 推奨: テンプレートに「{user_requirements} が渡されない場合は {agent_path} の内容をベースとする」を明記する
- impact: high, effort: low

### C-4: Phase 3 再試行時の Run 番号割り当て未定義 [stability]
- 対象: SKILL.md:249-252
- 内容: 失敗したタスクのみ再実行する際、失敗タスクの Run 番号が Run1/Run2 のどちらで再実行されるか未指定
- 推奨: "失敗したタスクを元の Run 番号で再実行する（Run1 失敗ならば Run1 で再実行）。再失敗時は当該 Run を欠損とみなし、Phase 4 で SD=N/A として処理する" を明記
- impact: high, effort: medium

### C-5: Phase 2 で perspective.md と perspective-source.md の両方を読み込む [efficiency]
- 対象: templates/phase2-test-document.md
- 内容: 推定コンテキスト浪費量: perspective-source.md の全文 (平均40行)。perspective-source.md は問題バンク参照のためだけに読み込まれるが、問題バンクは perspective.md から除去されているため、perspective.md だけでは問題埋め込みができない。perspective.md から問題バンクを除去する設計が不要な2回読み込みを招いている
- 推奨: perspective.md に問題バンクを含めたまま保持し、Phase 4 採点時に Read 済み perspective から問題バンクセクションをスキップする指示をテンプレートに追記すれば、Phase 2 で2回 Read する必要がなくなる
- impact: medium, effort: medium

### C-6: Phase 0 perspective 検証で Read 後に必須セクション確認のみ [efficiency]
- 対象: SKILL.md:118-120
- 内容: 推定コンテキスト浪費量: perspective 全文を親が保持 (40-80行)。perspective 生成後の検証で親が Read → セクション存在確認だけを行い、詳細は使用しない
- 推奨: サブエージェントに Read + 検証を委譲すべき
- impact: medium, effort: low

### C-7: 成功基準が冒頭で推定不能 [effectiveness]
- 対象: SKILL.md 冒頭
- 内容: ワークフロー完了時に「目的を達成した」と判定できる条件が明示されていない。「性能向上の知見を蓄積する」「反復的に改善する」とあるが、何をもって「最適化完了」とするかの基準が推定できない。Phase 6 で収束判定の言及はあるが、冒頭の使い方セクションに成果物（最終的に何が得られるか）の記述が不足している
- 推奨: 冒頭に「エージェント定義ファイルの改善版と性能評価レポート（knowledge.md）を生成し、収束または指定ラウンド数完了まで反復する」などの記述を追加
- impact: high, effort: low

## 改善提案

### I-1: Phase 0 Step 2 ファイル名パターン判定と Step 5 フィードバック統合ロジックがインライン記述 [architecture]
- 対象: SKILL.md:50-57, 113-115
- 内容: ファイル名パターン判定ロジック（`*-design-reviewer` / `*-code-reviewer` パターン抽出）と批評統合・再生成分岐ロジック（「重大な問題」フィールドの非空判定と再生成の1回のみ制限）が SKILL.md にインライン記述されている（それぞれ7-10行）
- 推奨: テンプレートファイルに外部化すべき
- impact: low, effort: medium

### I-2: Phase 6 Step 2B の proven-techniques 更新承認が曖昧 [ux, architecture]
- 対象: Phase 6 Step 2B, templates/phase6b-proven-techniques-update.md:45-48
- 内容: proven-techniques.md はスキル横断の共有知見ファイルであるため、更新内容の確認が記載されているが、「E. ユーザーインタラクションポイント」によると AskUserQuestion で承認を取る設計になっている。ただし、SKILL.md 本文（行374）では「B が失敗: 警告メッセージを出力するが、スキルは継続する（proven-techniques 更新は任意処理のため）」とあり、成功時の承認フローが明確でない。また、テンプレート内で AskUserQuestion を実行する設計となっており、親の責務との境界が曖昧
- 推奨: AskUserQuestion を含む処理は親（SKILL.md）の責務として設計し、サブエージェントは更新候補の抽出と検証のみを担当すべき。AskUserQuestion 失敗時（タイムアウト・ユーザー未応答）の処理フローを明示すべき
- impact: medium, effort: high

### I-3: Phase 1B の audit ファイル検索で Glob 検索が非効率 [efficiency]
- 対象: SKILL.md:188-190
- 内容: 推定コンテキスト浪費量: 不要な Glob 処理。audit-ce-*.md と audit-sa-*.md を毎回 Glob で検索しているが、audit 結果のファイル名は .agent_audit/{agent_name}/ 配下で一意に決まるため、直接 Read で存在確認すれば済む
- 推奨: Glob の代わりに直接パス構成で Read し、ファイル不在時のエラー処理で判定する
- impact: low, effort: low

### I-4: Phase 0 perspective 自動生成 Step 5 の条件分岐不足 [effectiveness]
- 対象: Phase 0 Step 5
- 内容: 4件の批評のうち1件以上で「重大な問題」フィールドが空でない場合に再生成するが、再生成後の批評が再び「重大な問題」を含む場合の処理が未定義。「1回のみ」再生成とあるが、再生成後に Step 6 検証で失敗した場合はエラー終了となり、初回生成も再生成も問題がある場合にスキル継続不能になる
- 推奨: 再生成後も「重大な問題」が残る場合の処理フロー（警告を出力してユーザー確認、または条件付き継続）を明示すべき
- impact: medium, effort: medium

### I-5: Phase 6 Step 2A knowledge.md バックアップが再実行時に累積 [stability]
- 対象: templates/phase6a-knowledge-update.md:4
- 内容: 読み込んだ内容を {knowledge_path}.backup-{timestamp}.md に Write で保存するため、バックアップが累積する
- 推奨: バックアップディレクトリ {knowledge_path}/.backups/ を使用し、最新10件のみ保持する。Bash で ls | head -n -10 | xargs rm 等で古いバックアップを削除する
- impact: low, effort: medium

### I-6: Phase 0 自動生成 Step 5 フィードバック統合の返答フォーマット未指定 [stability]
- 対象: SKILL.md:113-115
- 内容: 4件の批評を受信後の処理について、批評エージェントからの返答が「SendMessage で報告」とあるが、受信側（親エージェント）の待機パターンが不明
- 推奨: 各批評エージェントは TaskUpdate でタスクを completed に更新し、その際に metadata.critical_issues = "{あればリスト、なければ なし}" を設定する。親は TaskGet で metadata を読み取る
- impact: medium, effort: high

### I-7: Phase 4 採点失敗時の「ベースラインが失敗した場合は中断」判定の手順不明 [stability]
- 対象: SKILL.md:277-280
- 内容: ベースラインが失敗した場合は中断する条件について、失敗プロンプト一覧からベースラインを検出する処理が記載されていない
- 推奨: 失敗プロンプト名に "baseline" を含むか判定する。含む場合は AskUserQuestion で「再試行」「中断」の2択（除外選択肢は提示しない）を提示
- impact: medium, effort: low

### I-8: Phase 5 返答行数検証の失敗処理が曖昧 [stability]
- 対象: SKILL.md:295
- 内容: 不一致の場合は1回リトライするが、リトライ時にサブエージェントへのフィードバック内容が不明
- 推奨: 不一致の場合: 返答内容をログ出力し、"返答フォーマットが不一致です。7行フォーマット（recommended, reason, convergence, scores, variants, deploy_info, user_summary）で再返答してください" とサブエージェントに再指示する
- impact: low, effort: low

### I-9: Phase 1B の audit ファイル検索結果の判定基準が曖昧 [effectiveness]
- 対象: Phase 1B
- 内容: audit-ce-*.md と audit-dim1-*.md の両方が存在する場合にどちらを優先するか未定義。「最新ファイルはファイル名の run タイムスタンプまたは更新日時で判定する」とあるが、2つの判定基準（ファイル名 vs 更新日時）の優先順位が不明
- 推奨: 最新ファイル判定: (1) ファイル名に run-YYYYMMDD-HHMMSS パターンがあればタイムスタンプで比較、(2) パターンなしの場合は Bash の stat -c %Y で更新日時を比較
- impact: low, effort: low
