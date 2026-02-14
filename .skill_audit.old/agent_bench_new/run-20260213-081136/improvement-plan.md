# 改善計画: agent_bench_new

## 変更対象ファイル
| # | ファイル | 変更種別 | 変更概要 | 対応フィードバック |
|---|---------|---------|---------|------------------|
| 1 | SKILL.md | 修正 | 外部参照パスを内部パスに修正（19箇所） | C-1 |
| 2 | SKILL.md | 修正 | Phase 1B パス変数リストに audit_dim1_path, audit_dim2_path を追加 | C-2 |
| 3 | templates/phase1a-variant-generation.md | 修正 | 外部参照パスを内部パスに修正（3箇所）、返答行数を明示 | C-1, I-2 |
| 4 | templates/phase1b-variant-generation.md | 修正 | 外部参照パスを内部パスに修正（3箇所）、返答行数を明示 | C-1, I-2 |
| 5 | templates/phase1b-variant-generation.md | 修正 | audit_dim1_path, audit_dim2_path プレースホルダの記述を修正 | C-2 |
| 6 | templates/phase3-evaluate.md | 新規作成 | Phase 3 評価実行指示を外部化 | C-3 |
| 7 | SKILL.md | 修正 | Phase 3 評価実行指示をテンプレート参照に変更 | C-3 |
| 8 | templates/phase6-deploy.md | 新規作成 | Phase 6 デプロイ指示を外部化 | C-4 |
| 9 | SKILL.md | 修正 | Phase 6 デプロイ指示をテンプレート参照に変更 | C-4 |
| 10 | SKILL.md | 修正 | Phase 1A/1B/2 の冒頭に既存ファイル上書き方針を明記 | C-5 |
| 11 | templates/phase6b-proven-techniques-update.md | 修正 | 更新前にユーザー確認を追加 | I-1 |
| 12 | templates/phase6a-knowledge-update.md | 修正 | 更新前にバックアップ作成処理を追加 | I-3 |
| 13 | SKILL.md | 修正 | Phase 1A/1B/2/5/6A/6B のエラーハンドリングを追加 | I-4 |

## 各ファイルの変更詳細

### 1. SKILL.md（修正）
**対応フィードバック**: C-1: 外部スキル参照により独立性が損なわれている

**変更内容**:
- 行54: `.claude/skills/agent_bench/perspectives/` → `.claude/skills/agent_bench_new/perspectives/`
- 行74: `.claude/skills/agent_bench/perspectives/design/` → `.claude/skills/agent_bench_new/perspectives/design/`
- 行81: `.claude/skills/agent_bench/templates/perspective/generate-perspective.md` → `.claude/skills/agent_bench_new/templates/perspective/generate-perspective.md`
- 行92: `.claude/skills/agent_bench/templates/perspective/{テンプレート名}` → `.claude/skills/agent_bench_new/templates/perspective/{テンプレート名}`
- 行124: `.claude/skills/agent_bench/templates/knowledge-init-template.md` → `.claude/skills/agent_bench_new/templates/knowledge-init-template.md`
- 行129: `.claude/skills/agent_bench/approach-catalog.md` → `.claude/skills/agent_bench_new/approach-catalog.md`
- 行146: `.claude/skills/agent_bench/templates/phase1a-variant-generation.md` → `.claude/skills/agent_bench_new/templates/phase1a-variant-generation.md`
- 行150-151, 153: `.claude/skills/agent_bench/approach-catalog.md`, `proven-techniques.md` の3箇所を `.claude/skills/agent_bench_new/` に変更
- 行166: `.claude/skills/agent_bench/templates/phase1b-variant-generation.md` → `.claude/skills/agent_bench_new/templates/phase1b-variant-generation.md`
- 行171-173: `.claude/skills/agent_bench/approach-catalog.md`, `proven-techniques.md` の3箇所を `.claude/skills/agent_bench_new/` に変更
- 行184: `.claude/skills/agent_bench/templates/phase2-test-document.md` → `.claude/skills/agent_bench_new/templates/phase2-test-document.md`
- 行186: `.claude/skills/agent_bench/test-document-guide.md` → `.claude/skills/agent_bench_new/test-document-guide.md`
- 行249: `.claude/skills/agent_bench/templates/phase4-scoring.md` → `.claude/skills/agent_bench_new/templates/phase4-scoring.md`
- 行251: `.claude/skills/agent_bench/scoring-rubric.md` → `.claude/skills/agent_bench_new/scoring-rubric.md`
- 行272: `.claude/skills/agent_bench/templates/phase5-analysis-report.md` → `.claude/skills/agent_bench_new/templates/phase5-analysis-report.md`
- 行274: `.claude/skills/agent_bench/scoring-rubric.md` → `.claude/skills/agent_bench_new/scoring-rubric.md`
- 行324: `.claude/skills/agent_bench/templates/phase6a-knowledge-update.md` → `.claude/skills/agent_bench_new/templates/phase6a-knowledge-update.md`
- 行336: `.claude/skills/agent_bench/templates/phase6b-proven-techniques-update.md` → `.claude/skills/agent_bench_new/templates/phase6b-proven-techniques-update.md`
- 行338: `.claude/skills/agent_bench/proven-techniques.md` → `.claude/skills/agent_bench_new/proven-techniques.md`

### 2. SKILL.md（修正）
**対応フィードバック**: C-2: プレースホルダ未定義によるテンプレート実行エラーの可能性

**変更内容**:
- Phase 1B パス変数リスト（行166-174の前後）に以下を追加:
```markdown
- Glob で `.agent_audit/{agent_name}/audit-*.md` を検索し、見つかった全ファイルのうち:
  - 基準有効性分析（audit-ce-*.md または audit-dim1-*.md）の最新ファイルを {audit_dim1_path} として渡す（なければ空文字列）
  - スコープ整合性分析（audit-sa-*.md または audit-dim2-*.md）の最新ファイルを {audit_dim2_path} として渡す（なければ空文字列）
  - その他の承認済みファイル（audit-approved.md など）を {audit_findings_paths} として渡す
```

### 3. templates/phase1a-variant-generation.md（修正）
**対応フィードバック**: C-1: 外部スキル参照により独立性が損なわれている, I-2: サブエージェント返答形式が不統一

**変更内容**:
- 行9の3箇所: `proven-techniques.md`, `approach-catalog.md`, `perspective-source.md` のパス変数コメントに「スキル内パス」と明示
- 行9: 「以下のフォーマットで結果サマリのみ返答する」を「以下の26行フォーマットで返答する（プロンプト本文は含めない）」に変更し、フォーマット構成を明示（ヘッダ1行+見出し1行+空行+内容22行+空行+バリアント2×9行）

### 4. templates/phase1b-variant-generation.md（修正）
**対応フィードバック**: C-1: 外部スキル参照により独立性が損なわれている, C-2: プレースホルダ未定義, I-2: サブエージェント返答形式が不統一

**変更内容**:
- 行6: `proven-techniques_path` のコメントに「スキル内パス」と明示
- 行8-9: 以下に変更:
```markdown
   - {audit_dim1_path} が空でない場合: Read で読み込む（agent_audit の基準有効性分析結果 — 改善推奨をバリアント生成の参考にする）
   - {audit_dim2_path} が空でない場合: Read で読み込む（agent_audit のスコープ整合性分析結果 — スコープ改善をバリアント生成の参考にする）
```
- 行14: `approach_catalog_path` のコメントに「スキル内パス」と明示
- 行19: 「以下のフォーマットで結果サマリのみ返答する」を「以下の14行フォーマットで返答する」に変更し、フォーマット構成を明示（見出し1行+モード2行+空行+見出し1行+バリアント2×5行）

### 5. templates/phase3-evaluate.md（新規作成）
**対応フィードバック**: C-3: Phase 3 評価実行指示のインライン化によるコンテキスト節約原則違反

**変更内容**:
```markdown
以下の手順でタスクを実行してください:

1. Read で {prompt_path} を読み込み、その内容に従ってタスクを実行してください
2. Read で {test_doc_path} を読み込み、処理対象としてください
3. 処理結果を Write で {result_path} に保存してください
4. 最後に「保存完了: {result_path}」とだけ返答してください
```

### 6. SKILL.md（修正）
**対応フィードバック**: C-3: Phase 3 評価実行指示のインライン化によるコンテキスト節約原則違反

**変更内容**:
- 行211-220: インライン指示を削除し、以下に置換:
```markdown
各サブエージェントへの指示:

`.claude/skills/agent_bench_new/templates/phase3-evaluate.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{prompt_path}`: 評価対象プロンプトの絶対パス
- `{test_doc_path}`: `.agent_bench/{agent_name}/test-document-round-{NNN}.md`
- `{result_path}`: `.agent_bench/{agent_name}/results/v{NNN}-{name}-run{R}.md`
- `{NNN}`: プロンプトのバージョン番号
- `{name}`: プロンプトの名前部分
- `{R}`: 実行回数（1 または 2）
```

### 7. templates/phase6-deploy.md（新規作成）
**対応フィードバック**: C-4: Phase 6 デプロイ指示のインライン化により変更管理が困難

**変更内容**:
```markdown
以下の手順でプロンプトをデプロイしてください:

1. Read で {selected_prompt_path} を読み込む
2. ファイル先頭の <!-- Benchmark Metadata ... --> ブロックを除去する
3. {agent_path} に Write で上書き保存する
4. 「デプロイ完了: {agent_path}」とだけ返答する
```

### 8. SKILL.md（修正）
**対応フィードバック**: C-4: Phase 6 デプロイ指示のインライン化により変更管理が困難

**変更内容**:
- 行306-313: インライン指示を削除し、以下に置換:
```markdown
- **ベースライン以外を選択した場合**: `Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "haiku"`）:

  `.claude/skills/agent_bench_new/templates/phase6-deploy.md` を Read で読み込み、その内容に従って処理を実行してください。
  パス変数:
  - `{selected_prompt_path}`: ユーザーが選択したプロンプトファイルの絶対パス
  - `{agent_path}`: デプロイ先のエージェント定義ファイルの絶対パス
```

### 9. SKILL.md（修正）
**対応フィードバック**: C-5: ファイル重複生成により再実行時の挙動が不明確

**変更内容**:
- Phase 1A（行142の直後）に追加:
```markdown
既存のプロンプトファイルが存在する場合は上書き保存します（ラウンド番号ごとに独立したディレクトリ構成のため安全）。
```
- Phase 1B（行162の直後）に追加:
```markdown
既存のプロンプトファイルが存在する場合は上書き保存します（ラウンド番号ごとに独立したディレクトリ構成のため安全）。
```
- Phase 2（行180の直後）に追加:
```markdown
既存のテスト文書・正解キーファイルが存在する場合は上書き保存します（ラウンド番号ごとに独立したディレクトリ構成のため安全）。
```

### 10. templates/phase6b-proven-techniques-update.md（修正）
**対応フィードバック**: I-1: proven-techniques.md 更新前のユーザー確認がない

**変更内容**:
- 手順の末尾（Write の前）に追加:
```markdown
5. 更新内容をユーザーに提示し、AskUserQuestion で承認を得る:
   - 提示内容: Tier 1/2/3 への昇格対象テクニック、追加される効果データ、変更される一般化原則
   - 選択肢: 「承認して更新」「キャンセル」
   - 承認された場合のみ Write を実行する
6. Write で {proven_techniques_path} に保存する（承認時のみ）
7. 「更新完了: {承認/スキップ}」とだけ返答する
```

### 11. templates/phase6a-knowledge-update.md（修正）
**対応フィードバック**: I-3: knowledge.md 更新前のバックアップがない

**変更内容**:
- 手順1の前に追加:
```markdown
1. {knowledge_path} を Read で読み込む
2. 読み込んだ内容を {knowledge_path}.backup-{timestamp}.md に Write で保存する（timestamp は YYYYMMDD-HHMMSS 形式）
3. バックアップ完了を確認してから更新処理に進む
```
- 元の手順番号を繰り下げ（1→4, 2→5, ...）

### 12. SKILL.md（修正）
**対応フィードバック**: I-4: エラー処理の非対称性により障害対応が不明確

**変更内容**:
- Phase 1A（行158の直後）に追加:
```markdown
サブエージェント完了後:
- **成功**: サブエージェントの返答をテキスト出力し、Phase 2 へ進む
- **失敗**: 1回リトライする。再失敗時はエラーメッセージを出力してスキルを終了する
```
- Phase 1B（行176の直後）に追加:
```markdown
サブエージェント完了後:
- **成功**: サブエージェントの返答をテキスト出力し、次の Phase へ進む
- **失敗**: 1回リトライする。再失敗時はエラーメッセージを出力してスキルを終了する
```
- Phase 2（行193の直後）に追加:
```markdown
サブエージェント完了後:
- **成功**: サブエージェントの返答をテキスト出力し、Phase 3 へ進む
- **失敗**: 1回リトライする。再失敗時はエラーメッセージを出力してスキルを終了する
```
- Phase 5（行279の直後）に追加:
```markdown
サブエージェント完了後:
- **成功**: サブエージェントの返答（7行サマリ）をテキスト出力してユーザーに提示する。Phase 6 へ進む
- **失敗**: 1回リトライする。再失敗時はエラーメッセージを出力してスキルを終了する
```
- Phase 6A（行329の直後）に追加:
```markdown
サブエージェント完了後:
- **成功**: 次のステップ（B, C）へ進む
- **失敗**: 1回リトライする。再失敗時はエラーメッセージを出力してスキルを終了する
```
- Phase 6B（行342の直後）に追加:
```markdown
サブエージェント完了後:
- **成功**: 次アクション選択（C）の完了を待つ
- **失敗**: 警告メッセージを出力するが、スキルは継続する（proven-techniques 更新は任意処理のため）
```

## 新規作成ファイル
| ファイル | 目的 | 対応フィードバック |
|---------|------|------------------|
| templates/phase3-evaluate.md | Phase 3 評価実行指示を外部化し、コンテキスト節約原則に準拠 | C-3 |
| templates/phase6-deploy.md | Phase 6 デプロイ指示を外部化し、他フェーズとの一貫性確保 | C-4 |

## 削除推奨ファイル
（なし）

## 実装順序
1. templates/phase3-evaluate.md, templates/phase6-deploy.md の新規作成（他の変更が参照するため先に作成）
2. templates/phase1a-variant-generation.md, templates/phase1b-variant-generation.md の修正（SKILL.md のパス変数定義修正より先に、テンプレート側のプレースホルダ記述を修正）
3. templates/phase6a-knowledge-update.md, templates/phase6b-proven-techniques-update.md の修正（バックアップ・確認処理の追加）
4. SKILL.md の修正（全ての外部参照パス修正、パス変数リスト追加、テンプレート参照パターン変更、エラーハンドリング追加を一括で実施）

依存関係の検出方法:
- 新規テンプレート作成（1）→ SKILL.md でのテンプレート参照追加（4）→ 1が先
- テンプレートのプレースホルダ修正（2）→ SKILL.md のパス変数定義追加（4）→ 2が先
- テンプレートのロジック追加（3）は SKILL.md に影響しないため並列可能だが、統一的な実装のため 4 の前に完了推奨

## 注意事項
- 外部参照パスの修正は `.claude/skills/agent_bench/` を全て `.claude/skills/agent_bench_new/` に置換する単純な作業だが、19箇所全てを漏れなく修正すること
- Phase 1B のパス変数リスト修正では、既存の `{audit_findings_paths}` の記述を残しつつ、`{audit_dim1_path}`, `{audit_dim2_path}` の導出ロジックを追加すること
- 新規テンプレート（phase3-evaluate.md, phase6-deploy.md）は既存のインライン指示をそのまま外部化するため、機能的な変更はないこと
- エラーハンドリングの追加は各フェーズの一貫性を保つため、Phase 3/4 の詳細な分岐パターンを Phase 1A/1B/2/5/6A/6B にも適用すること（ただし Phase 6B のみ警告のみで継続）
- proven-techniques.md 更新のユーザー確認は、スキル全体の共有リソース変更のため必須。キャンセル時は Write をスキップすること
- knowledge.md バックアップは毎ラウンド累積データの破損リスク対策。タイムスタンプ付きファイル名で履歴を保持すること
