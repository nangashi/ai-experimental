# タスクリスト

## 1. [x] 既存スキルの退避

**やること**
- `arch_design/` を `old/arch_design.old/` に移動
- `process_design/` を `old/process_design.old/` に移動

**完了条件**
- `old/arch_design.old/` に全ファイルが存在する
- `old/process_design.old/` に全ファイルが存在する
- 元の `arch_design/`, `process_design/` が存在しない

**成果物**
- `.claude/skills/old/arch_design.old/`
- `.claude/skills/old/process_design.old/`

**申し送り**
特になし

## 2. [x] 新 arch_design スキルの実装

**やること**
- SKILL.md を 04 設計書に基づいて新規作成
- `references/p1-decision-catalog.md` を classification.md の P1 項目と 04 設計書のグループ編成に基づいて新規作成
- `references/output-template.md` を 04 設計書のテンプレート構成に基づいて新規作成
- `templates/generate-design.md` を 04 設計書の用語（設計次元→議論グループ）に合わせて新規作成
- `templates/review.md` を旧 arch_design から流用（変更なし）
- `templates/consolidate-reviews.md` を旧 arch_design から流用（変更なし）
- `templates/fix-design.md` を旧 arch_design から流用（変更なし）

**完了条件**
- 全 7 ファイルが `.claude/skills/arch_design/` に存在する
- SKILL.md が P1 カタログベースのワークフロー（動的次元導出を廃止）になっている
- Phase 4 の次のステップが `/standards_design` を案内している

**成果物**
- `.claude/skills/arch_design/SKILL.md`
- `.claude/skills/arch_design/references/p1-decision-catalog.md`
- `.claude/skills/arch_design/references/output-template.md`
- `.claude/skills/arch_design/templates/generate-design.md`
- `.claude/skills/arch_design/templates/review.md`
- `.claude/skills/arch_design/templates/consolidate-reviews.md`
- `.claude/skills/arch_design/templates/fix-design.md`

**申し送り**
特になし

## 3. [x] 新 standards_design スキルの実装

**やること**
- SKILL.md を 05 設計書に基づいて新規作成
- `references/p2-decision-catalog.md` を classification.md の P2 項目と 05 設計書のグループ編成に基づいて新規作成
- `references/output-template.md` を 05 設計書のテンプレート構成に基づいて新規作成
- `templates/generate-document.md` を旧 process_design から流用・P2 規約文書向けに改変
- `templates/check-consistency.md` を旧 process_design から流用・P2 向けチェック観点に改変
- `templates/fix-document.md` を旧 process_design から流用（変更なし）

**完了条件**
- 全 6 ファイルが `.claude/skills/standards_design/` に存在する
- Phase 4 の次のステップが `/process_design` を案内している

**成果物**
- `.claude/skills/standards_design/SKILL.md`
- `.claude/skills/standards_design/references/p2-decision-catalog.md`
- `.claude/skills/standards_design/references/output-template.md`
- `.claude/skills/standards_design/templates/generate-document.md`
- `.claude/skills/standards_design/templates/check-consistency.md`
- `.claude/skills/standards_design/templates/fix-document.md`

**申し送り**
特になし

## 4. [x] 新 process_design スキルの実装

**やること**
- SKILL.md を 06 設計書に基づいて新規作成（`dev_process` → `process_design` の命名変更を反映）
- `references/p3-decision-catalog.md` を classification.md の P3 項目と 06 設計書のグループ編成に基づいて新規作成
- `references/output-template.md` を 06 設計書のテンプレート構成に基づいて新規作成
- `templates/generate-document.md` を旧 process_design から流用・P3 向けに改変（入力に standards.md 追加、セクション構成変更）
- `templates/check-consistency.md` を旧 process_design から流用・P3 向けチェック観点に改変（standards.md との整合性追加）
- `templates/fix-document.md` を旧 process_design から流用（変更なし）

**完了条件**
- 全 6 ファイルが `.claude/skills/process_design/` に存在する
- スキル名・パス変数・work_dir が `process_design` になっている（06 設計の `dev_process` から変更）
- Phase 4 の次のステップが `/extract_decisions` を案内している

**成果物**
- `.claude/skills/process_design/SKILL.md`
- `.claude/skills/process_design/references/p3-decision-catalog.md`
- `.claude/skills/process_design/references/output-template.md`
- `.claude/skills/process_design/templates/generate-document.md`
- `.claude/skills/process_design/templates/check-consistency.md`
- `.claude/skills/process_design/templates/fix-document.md`

**申し送り**
06 設計書の `dev_process` → `process_design` に命名変更済み。スキル名・パス変数・work_dir・完了出力すべて `process_design` で統一。

