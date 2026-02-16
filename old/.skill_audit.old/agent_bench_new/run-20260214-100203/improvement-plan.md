# 改善計画: agent_bench_new

## 変更対象ファイル
| # | ファイル | 変更種別 | 変更概要 | 対応フィードバック |
|---|---------|---------|---------|------------------|
| 1 | SKILL.md | 修正 | 外部パス参照を `.claude/skills/agent_bench/` から `.claude/skills/agent_bench_new/` に一括修正 | C-1 |
| 2 | SKILL.md | 修正 | Phase 0 Step 68 の「実質空または不足」の具体的判断基準を追加 | I-2 |
| 3 | SKILL.md | 修正 | Phase 0 Step 67 で agent_path 読み込み成功時も `{user_requirements}` を構成する処理を追加 | I-1 |
| 4 | SKILL.md | 修正 | Phase 1B の audit ファイル名を `audit-ce.md`/`audit-sa.md` から実際の agent_audit 出力ファイル名に修正 | I-3 |
| 5 | templates/phase1a-variant-generation.md | 修正 | 9行目の `{user_requirements}` 参照を削除（agent_path から直接読み込む方式に統一） | I-1 |
| 6 | templates/phase1b-variant-generation.md | 修正 | 14行目のパス参照を `.claude/skills/agent_bench/approach-catalog.md` から `.claude/skills/agent_bench_new/approach-catalog.md` に修正 | C-2 |

## 各ファイルの変更詳細

### 1. SKILL.md（修正）
**対応フィードバック**: C-1: 外部パス参照の不一致

**変更内容**:
- 54行目: `.claude/skills/agent_bench/perspectives/{target}/{key}.md` → `.claude/skills/agent_bench_new/perspectives/{target}/{key}.md`
- 74行目: `.claude/skills/agent_bench/perspectives/design/*.md` → `.claude/skills/agent_bench_new/perspectives/design/*.md`
- 81行目: `.claude/skills/agent_bench/templates/perspective/generate-perspective.md` → `.claude/skills/agent_bench_new/templates/perspective/generate-perspective.md`
- 92-95行目: `.claude/skills/agent_bench/templates/perspective/{critic-*.md}` → `.claude/skills/agent_bench_new/templates/perspective/{critic-*.md}`
- 126行目: `.claude/skills/agent_bench/approach-catalog.md` → `.claude/skills/agent_bench_new/approach-catalog.md`
- 149行目: `.claude/skills/agent_bench/approach-catalog.md` → `.claude/skills/agent_bench_new/approach-catalog.md`
- 150行目: `.claude/skills/agent_bench/proven-techniques.md` → `.claude/skills/agent_bench_new/proven-techniques.md`
- 168行目: `.claude/skills/agent_bench/approach-catalog.md` → `.claude/skills/agent_bench_new/approach-catalog.md`
- 169行目: `.claude/skills/agent_bench/proven-techniques.md` → `.claude/skills/agent_bench_new/proven-techniques.md`
- 184行目: `.claude/skills/agent_bench/test-document-guide.md` → `.claude/skills/agent_bench_new/test-document-guide.md`
- 249行目: `.claude/skills/agent_bench/scoring-rubric.md` → `.claude/skills/agent_bench_new/scoring-rubric.md`
- 272行目: `.claude/skills/agent_bench/scoring-rubric.md` → `.claude/skills/agent_bench_new/scoring-rubric.md`
- 336行目: `.claude/skills/agent_bench/proven-techniques.md` → `.claude/skills/agent_bench_new/proven-techniques.md`

### 2. SKILL.md（修正）
**対応フィードバック**: I-2: 曖昧表現: 「実質空または不足」の判断基準なし

**変更内容**:
- 68行目: `エージェント定義が実質空または不足がある場合` → `エージェント定義が50文字未満、または目的・評価基準・入力型・出力型のいずれかが明示されていない場合`

### 3. SKILL.md（修正）
**対応フィードバック**: I-1: フェーズ間データフロー: Phase 0 → Phase 1A でのパス変数未定義

**変更内容**:
- 67行目「Step 1: 要件抽出」セクションを以下に修正:

```markdown
**Step 1: 要件抽出**
- Read で agent_path を読み込み、エージェント定義ファイルの内容（目的、評価基準、入力/出力の型、スコープ情報）を `{user_requirements}` として構成する
- エージェント定義が50文字未満、または目的・評価基準・入力型・出力型のいずれかが明示されていない場合: `AskUserQuestion` で以下をヒアリングし `{user_requirements}` に追加する
  - エージェントの目的・役割
  - 想定される入力と期待される出力
  - 使用ツール・制約事項
```

### 4. SKILL.md（修正）
**対応フィードバック**: I-3: 参照整合性: Phase 1B audit ファイル名不整合

**変更内容**:
- 171行目: `{audit_dim1_path}`: `.agent_audit/{agent_name}/audit-ce.md` → `.agent_audit/{agent_name}/audit-dim1.md`
- 172行目: `{audit_dim2_path}`: `.agent_audit/{agent_name}/audit-sa.md` → `.agent_audit/{agent_name}/audit-dim2.md`

**注**: agent_audit スキルの実際の出力ファイル名が `audit-dim1.md`, `audit-dim2.md` であることを前提としています。これらが `audit-ce.md`, `audit-sa.md` の場合は変更不要です。

### 5. templates/phase1a-variant-generation.md（修正）
**対応フィードバック**: I-1: フェーズ間データフロー: Phase 0 → Phase 1A でのパス変数未定義

**変更内容**:
- 9行目の `{user_requirements} を基に、proven-techniques.md の「ベースライン構築ガイド」に従って生成する` を削除
- 代わりに以下の記述に修正:

```markdown
- 存在しなければ: エージェント定義ファイルが存在しないため、perspective-source.md の評価スコープと proven-techniques.md の「ベースライン構築ガイド」に従って生成する。アプローチカタログの推奨構成を参考にする。指示文は英語で記述し、テーブル/マトリクス構造を活用する
```

**理由**: `{user_requirements}` 変数への依存を除去し、perspective-source.md を直接参照する方式に統一。これにより Phase 0 での変数構成処理が不要になる。

### 6. templates/phase1b-variant-generation.md（修正）
**対応フィードバック**: C-2: テンプレート内の外部参照

**変更内容**:
- 14行目: `{approach_catalog_path} を Read で読み込む` のパスを `.claude/skills/agent_bench/approach-catalog.md` から `.claude/skills/agent_bench_new/approach-catalog.md` に修正

**注**: 実際のテンプレートファイルではパス変数 `{approach_catalog_path}` が使用されており、この変数は SKILL.md の 168行目で定義されているため、SKILL.md 側のパス修正（変更1）で対応済みです。テンプレート側では修正不要です。

## 新規作成ファイル
（該当なし）

## 削除推奨ファイル
（該当なし）

## 実装順序
1. **SKILL.md の一括パス修正（変更1）** — 全ての外部パス参照を修正。他の変更の前提条件
2. **SKILL.md の判断基準明確化（変更2）** — Phase 0 Step 68 の曖昧表現を修正。変更3の前提
3. **SKILL.md の要件抽出修正（変更3）** — Phase 0 Step 67 で常に user_requirements を構成。変更5の前提
4. **SKILL.md の audit ファイル名修正（変更4）** — Phase 1B のファイル参照を実際の出力名に修正
5. **templates/phase1a-variant-generation.md の修正（変更5）** — user_requirements 依存を除去。変更3と連動

**依存関係**:
- 変更3（SKILL.md 要件抽出）→ 変更5（phase1a テンプレート）: 変数構成方式の変更がテンプレート側に影響
- 変更2（判断基準）→ 変更3（要件抽出）: 判断基準の定義が要件抽出の条件分岐で使用される

## 注意事項
- 変更1（パス修正）は SKILL.md の13箇所で一括置換が必要。置換漏れに注意
- 変更4（audit ファイル名）は agent_audit スキルの実際の出力ファイル名を確認してから実施すること
- 変更6（phase1b テンプレート）はテンプレートがパス変数を使用しているため、SKILL.md 側の修正（変更1）で対応済み。テンプレート本文の修正は不要
- 全ての変更後、Phase 0 の perspective 自動生成とテンプレート読み込みが正常に動作するか確認すること
- 特に Phase 1A/1B のバリアント生成でアプローチカタログと proven-techniques が正しく読み込まれるか検証すること
