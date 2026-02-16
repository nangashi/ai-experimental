## 重大な問題

### C-1: 外部スキル（agent_bench）への直接参照 [architecture, stability]
- 対象: SKILL.md:全フェーズ
- 内容: `.claude/skills/agent_bench/` ディレクトリへの11箇所の直接参照を検出。実際のスキルディレクトリは `.claude/skills/agent_bench_new` であり、パスが不整合。agent_bench スキルの変更時に agent_bench_new が破損するリスクがある
- 推奨: 全ての `.claude/skills/agent_bench/` を `.claude/skills/agent_bench_new/` に置換する。長期的には全テンプレートを agent_bench_new 内にコピーして外部依存を排除する
- impact: high, effort: medium

### C-2: Phase 1B の NNN 変数未定義 [effectiveness]
- 対象: SKILL.md:Phase 1B L16
- 内容: Phase 1B のプロンプト保存先パスで `v{NNN}-baseline.md` と記載されているが、`{NNN}` の計算方法（累計ラウンド数 + 1）が SKILL.md 内のどこにも明記されていない。Phase 1A では L149 に明記されているが Phase 1B では欠落
- 推奨: Phase 1B の手順説明内に「{NNN} = 累計ラウンド数 + 1」の定義を追加する
- impact: high, effort: low

### C-3: 目的の明確性 — 成功基準の推定が困難 [effectiveness]
- 対象: SKILL.md:使い方セクション
- 内容: 「構造最適化」の定義が曖昧。スキル完了時に「最適化完了」と判定できる基準（最小ラウンド数、収束判定の必須適用、最小改善幅等）が明記されていない。ユーザーは任意のタイミングで終了を選択できるため、目的達成の判定が困難
- 推奨: 「構造最適化」の定義を「テスト性能の反復改善により、収束判定基準を満たすか、ユーザー指定ラウンド数に達するまで最適化を継続する」等に修正し、最低ラウンド数や推奨終了条件を明記する
- impact: high, effort: low

### C-4: 参照整合性 — 未定義パス変数 [stability]
- 対象: phase1b-variant-generation.md:8-9行
- 内容: `{audit_dim1_path}`, `{audit_dim2_path}` プレースホルダがテンプレート内に記載されているが、SKILL.md の Phase 1B のパス変数リストに定義されていない。SKILL.md line 174 で Glob による動的検索後に `{audit_findings_paths}` として渡すと記載されているが、テンプレート側は個別の `{audit_dim1_path}`, `{audit_dim2_path}` を期待している
- 推奨: SKILL.md を修正して個別変数として定義するか、テンプレートを `{audit_findings_paths}` に統一する
- impact: medium, effort: low

### C-5: 条件分岐の完全性 — デフォルト処理の欠落 [stability]
- 対象: SKILL.md:233-236行, 262-264行
- 内容: Phase 3/4 評価実行失敗時の分岐で「再試行」を選択したがそれも失敗した場合の処理が未定義。「再試行は1回のみ」と記載されているが、再試行失敗後の動作（再度ユーザー確認か、自動中断か）が明示されていない
- 推奨: 再試行失敗後の動作を明示する（例: 「再試行失敗時は再度確認を求める」または「再試行失敗時は自動中断する」）
- impact: medium, effort: low

### C-6: Phase 3 インライン指示が長すぎる [architecture]
- 対象: SKILL.md:213-221行
- 内容: Phase 3 のサブエージェント指示が9行。テンプレートファイルへの外部化が必要
- 推奨: Phase 3 の指示を templates/phase3-evaluation.md として外部化する
- impact: medium, effort: low

### C-7: Phase 6 Step 1 インライン指示が長すぎる [architecture]
- 対象: SKILL.md:307-314行
- 内容: Phase 6 デプロイサブエージェントの指示が8行。テンプレートファイルへの外部化が必要
- 推奨: Phase 6 デプロイの指示を templates/phase6a-deploy.md として外部化する
- impact: medium, effort: low

## 改善提案

### I-1: perspective 問題バンクと採点の依存関係不明確 [effectiveness]
- 対象: SKILL.md:Phase 0→Phase 4
- 内容: Phase 0 ステップ5で「perspective.md から問題バンクセクションを除去」と記載されているが、Phase 4 採点時にサブエージェントが perspective.md を参照する目的が不明確。採点では answer_key のみで検出判定可能なはず
- 推奨: 採点処理で perspective.md を参照する理由を SKILL.md のフェーズ説明に明記する。または参照が不要であればテンプレート phase4-scoring.md から削除する
- impact: medium, effort: low

### I-2: 冪等性 — Phase 3 再実行時のファイル重複リスク [stability]
- 対象: SKILL.md:Phase 3 207-228行
- 内容: 並列評価実行でファイルを Write で保存する前に、既存ファイルの存在確認や Read 呼び出しがない。Phase 3 を再実行した場合、既存の results/ ファイルが上書きされるが、Phase 4 採点で古い結果ファイルが残っている場合に不整合が発生する可能性がある
- 推奨: Phase 3 開始時に該当ラウンドの results/ ファイルを削除するか、既存ファイル確認を行う
- impact: medium, effort: medium

### I-3: Phase 1B での audit ファイル読み込みの非効率 [efficiency]
- 対象: SKILL.md:174行
- 内容: `audit-*.md` を Glob 検索して全ファイル読み込みをサブエージェントに委譲しているが、audit ファイルが大量にある場合（複数ラウンド実行後）にコンテキスト浪費が発生。最新ラウンドのみ、または approved のみに制限すべき
- 推奨: 最新ラウンドの audit ファイルのみ、または audit-approved.md のみを読み込むように制限する
- impact: medium, effort: low

### I-4: Phase 1B audit findings パスの存在確認不足 [stability]
- 対象: SKILL.md:174行
- 内容: Glob で `.agent_audit/{agent_name}/audit-*.md` を検索するが、見つからなかった場合の処理フローが未定義。空リストの場合も正常動作するかサブエージェント側で確認が必要
- 推奨: ファイルが存在する場合のみ Read し、存在確認後に条件付きでパス変数を渡す。Phase 1B テンプレート側で audit findings が渡されない場合のハンドリング指示を追加
- impact: medium, effort: low

### I-5: Phase 6 Step 2 並列実行の依存関係が不明確 [architecture]
- 対象: SKILL.md:330-352行
- 内容: B) スキル知見フィードバック（行334-341）と C) 次アクション選択（行343-351）が「同時に実行」とあるが、C) は B) の完了を待つ必要がある。並列実行の範囲と依存関係を明確化すべき
- 推奨: 並列実行可能な処理と依存関係のある処理を明確に分離して記述する
- impact: medium, effort: low

### I-6: Phase 3 並列評価の冗長実行 [efficiency]
- 対象: SKILL.md:207-228行
- 内容: 各プロンプトを2回ずつ並列実行しているが、SDが不要なケースでも2回実行が強制される。Phase 5で収束判定後は1回実行への自動切り替えが可能。推定節約量: サブエージェント実行数の50%削減（収束後のラウンド）
- 推奨: 収束後は1回実行に自動切り替えする仕組みを追加する
- impact: medium, effort: medium

### I-7: perspective 自動生成時の一括確認 [ux]
- 対象: SKILL.md:Phase 0 Step 5
- 内容: perspective の再生成時、4件の批評結果をまとめて「重大な問題または改善提案がある場合」に自動再生成する。ユーザーは個別の批評内容を確認できず、どの指摘が反映されるか不明
- 推奨: 4件の批評結果を要約提示し、再生成するか確認する AskUserQuestion を追加する
- impact: medium, effort: low

### I-8: Phase 0 reference perspective 読み込みの非効率 [efficiency]
- 対象: SKILL.md:74行
- 内容: `.claude/skills/agent_bench/perspectives/design/*.md` を Glob で列挙し「最初に見つかったファイル」のみ使用。最初の1ファイルのみ必要なら Glob の結果を先頭1件で打ち切るか、固定ファイルパスを指定すべき。推定節約量: Glob処理のコンテキスト消費削減（微小）
- 推奨: 固定ファイルパスを指定するか、Glob 結果の先頭1件のみを使用する旨を明記する
- impact: low, effort: low

### I-9: Phase 0 Step 6 エラーハンドリング不足 [architecture]
- 対象: SKILL.md:116-118行
- 内容: knowledge.md 読み込み失敗時の分岐は明示されているが、読み込み成功時に内容が破損している場合の検証処理がない。必須セクション（バリエーションステータステーブル、ラウンド別スコア推移等）の存在確認を追加すべき
- 推奨: knowledge.md 読み込み成功後に必須セクションの存在確認を追加する
- impact: medium, effort: medium
