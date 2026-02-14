## 重大な問題

### C-1: 外部参照 - 他スキルのフォールバックパス [architecture]
- 対象: SKILL.md:54
- 内容: Phase 0 perspective フォールバック処理で `.claude/skills/agent_bench/perspectives/{target}/{key}.md` を参照する。これは agent_bench スキル（旧版）への依存を意味し、スキルディレクトリ外のファイルへの参照に該当する
- 推奨: フォールバックパスを `.claude/skills/agent_bench_new/perspectives/{target}/{key}.md` に修正する
- impact: medium, effort: low

### C-2: 外部参照 - 他スキルのデータファイル [architecture]
- 対象: SKILL.md:74
- 内容: Phase 0 perspective 自動生成で `.claude/skills/agent_bench/perspectives/design/*.md` を参照する。これも旧版への依存であり、スキルディレクトリ外のファイルへの参照に該当する
- 推奨: `.claude/skills/agent_bench_new/perspectives/design/*.md` に修正する
- impact: medium, effort: low

### C-3: 外部参照 - クロススキル参照 [architecture]
- 対象: SKILL.md:174, templates/phase1b-variant-generation.md:8
- 内容: Phase 1B で `.agent_audit/{agent_name}/audit-*.md` を参照する。これは agent_audit スキルへの依存を意味し、スキルディレクトリ外のファイルへの参照に該当する
- 推奨: agent_audit の結果を agent_bench_new のディレクトリ内にコピーするか、パラメータ化（明示的な有無フラグ）すべき
- impact: medium, effort: medium

### C-4: 参照整合性: 未定義変数 [stability, effectiveness, architecture]
- 対象: templates/phase1b-variant-generation.md:8-9
- 内容: `{audit_dim1_path}`, `{audit_dim2_path}` プレースホルダ使用しているが、SKILL.md line 174 では Glob で `.agent_audit/{agent_name}/audit-*.md` を検索してカンマ区切りで `{audit_findings_paths}` として渡すと記載されており、変数名が不一致
- 推奨: テンプレート側の変数名を `{audit_findings_paths}` に統一するか、SKILL.md 側で個別変数として渡すよう修正する
- impact: high, effort: medium

## 改善提案

### I-1: knowledge.md の累計ラウンド数導出 [architecture]
- 対象: SKILL.md:116-117, templates/phase6a-knowledge-update.md:8
- 内容: knowledge.md の読み込み成否で Phase 1A/1B を分岐するが、累計ラウンド数の導出方法が SKILL.md に明示されていない。Phase 6A で累計ラウンド数を +1 するルールはあるが、Phase 0 で読み込み時にどのフィールドから取得するか不明確
- 推奨: Phase 0 で knowledge.md から累計ラウンド数を読み込む際の具体的なフィールド名（例: 「最新サマリ」セクションの「累計ラウンド数」）を明示する
- impact: medium, effort: low

### I-2: Phase 1B の条件付きファイル読込 [efficiency]
- 対象: templates/phase1b-variant-generation.md:9行目
- 内容: 現在「audit_dim1_path が指定されている場合: Read で読み込む」との記載だが、SKILL.md では Glob で検索したパス一覧を `{audit_findings_paths}` として渡している（174行目）。テンプレート側で各パスを Read する処理が不明確
- 推奨: テンプレート側で各パスを Read する処理に統一する
- impact: medium, effort: low

### I-3: Phase 5 の採点ファイル読込 [efficiency]
- 対象: templates/phase5-analysis-report.md:6行目
- 内容: 採点結果ファイルを全て Read しているが、各ファイルは詳細な問題別検出マトリクスを含む（行数が多い）。phase4-scoring.md のサブエージェント返答（2行スコアサマリ）は親が保持しているため、比較レポート生成時にスコアサマリのみを使用することが可能
- 推奨: 比較レポート生成時にスコアサマリのみを使用する旨を明記し、詳細が必要な場合のみファイルを Read する方式に変更する
- impact: medium, effort: medium

### I-4: perspective 批評テンプレートの未定義変数 [stability]
- 対象: templates/perspective/critic-completeness.md:23
- 内容: `{target}` プレースホルダが使用されているが、SKILL.md の Step 3-5 パス変数リストに `{target}` は存在しない
- 推奨: SKILL.md の perspective 自動生成セクションで `{target}` 変数を定義するか、テンプレート内で `{target}` を使わない表現に変更する
- impact: medium, effort: low

### I-5: perspective 自動生成 Step 4 の critic テンプレート読込 [efficiency]
- 対象: templates/perspective/critic-effectiveness.md, critic-completeness.md
- 内容: 各 critic テンプレートに `{existing_perspectives_summary}` 変数があるが（critic-effectiveness.md 23行目）、SKILL.md では perspective 自動生成時にこの変数を渡していない。変数が未定義の場合、既存観点との境界検証がスキップされる可能性がある
- 推奨: SKILL.md で `{existing_perspectives_summary}` 変数を定義し、渡す処理を追加する
- impact: medium, effort: medium

### I-6: Phase 1A の perspective_path 参照 [efficiency]
- 対象: templates/phase1a-variant-generation.md:10行目
- 内容: perspective_path を Read で確認するステップ（ステップ3）があるが、この結果は後続処理で使用されていない。Phase 0 で既に perspective.md の存在は保証されているため、このステップは削除可能
- 推奨: perspective_path を Read するステップを削除する
- impact: low, effort: low

### I-7: Phase 0 Step 2 の参照データ収集 [efficiency]
- 対象: SKILL.md:74-76行目
- 内容: 「.claude/skills/agent_bench/perspectives/design/*.md を Glob で列挙」し「最初に見つかったファイルを reference_perspective_path として使用」とあるが、perspectives/design/ 配下には old/ ディレクトリも存在し、古い定義が参照される可能性がある
- 推奨: `perspectives/design/*.md` の Glob パターンで old/ を除外するか、特定のファイル（例: security.md）を明示的に指定する
- impact: low, effort: low

### I-8: Phase 2 の knowledge.md 読込 [efficiency]
- 対象: templates/phase2-test-document.md:7行目
- 内容: knowledge.md を読み込んでいるが、使用箇所は「過去と異なるドメインを選択する」のみ。knowledge.md の「テスト対象文書履歴」セクションから最低限の情報（過去のテーマリスト）のみ参照すればよい旨を明記し、全文読込を避ける記述があるとよい
- 推奨: knowledge.md の「テスト対象文書履歴」セクションから最低限の情報のみ参照する旨を明記する
- impact: low, effort: low

### I-9: Phase 6 Step 2 の並列実行順序 [efficiency]
- 対象: SKILL.md:318-352行目
- 内容: 現在「A) ナレッジ更新を実行→完了を待つ」→「B) スキル知見フィードバック と C) 次アクション選択を並列実行」→「B完了を待つ」となっているが、A と B は独立しているため A と B を同時並列起動し、C のみユーザー待ち中に実行する方式に変更可能（コンテキスト節約には影響しないが実行時間短縮に寄与）
- 推奨: A と B を同時並列起動し、C のみユーザー待ち中に実行する方式に変更する
- impact: low, effort: low
