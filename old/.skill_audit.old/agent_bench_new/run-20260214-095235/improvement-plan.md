# 改善計画: agent_bench_new

## 変更対象ファイル
| # | ファイル | 変更種別 | 変更概要 | 対応フィードバック |
|---|---------|---------|---------|------------------|
| 1 | SKILL.md | 修正 | Phase 1B のパス変数記述を個別パス変数方式に変更 | C-1: audit_findings_paths 変数の未定義 |
| 2 | SKILL.md | 修正 | Phase 1A のパス変数リストから {user_requirements} を削除 | C-2: 未使用パス変数 user_requirements |
| 3 | SKILL.md | 修正 | Phase 0 Step 5 の再生成条件を明確化 | C-3: perspective 自動生成 Step 5 の条件判定が曖昧 |

## 各ファイルの変更詳細

### 1. /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.claude/skills/agent_bench_new/SKILL.md（修正）
**対応フィードバック**: C-1: audit_findings_paths 変数の未定義

**変更内容**:
- 行174: `- Glob で `.agent_audit/{agent_name}/audit-*.md` を検索し（`audit-approved.md` は除外）、見つかった全ファイルのパスをカンマ区切りで `{audit_findings_paths}` として渡す` → `- `{audit_dim1_path}`: `.agent_audit/{agent_name}/audit-ce.md` の絶対パス（ファイル不在時は空文字列を渡す）`
- 行174 に以下を追加: `- `{audit_dim2_path}`: `.agent_audit/{agent_name}/audit-sa.md` の絶対パス（ファイル不在時は空文字列を渡す）`

### 2. /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.claude/skills/agent_bench_new/SKILL.md（修正）
**対応フィードバック**: C-2: 未使用パス変数 user_requirements

**変更内容**:
- 行155-156: `- エージェント定義が新規作成の場合:` および `  - `{user_requirements}`: Phase 0 で収集した要件テキスト` を削除

### 3. /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.claude/skills/agent_bench_new/SKILL.md（修正）
**対応フィードバック**: C-3: perspective 自動生成 Step 5 の条件判定が曖昧

**変更内容**:
- 行105-107: `- 4件の批評から「重大な問題」「改善提案」を分類する`<br>`- 重大な問題または改善提案がある場合: フィードバックを `{user_requirements}` に追記し、Step 3 と同じパターンで perspective を再生成する（1回のみ）`<br>`- 改善不要の場合: 現行 perspective を維持する` → `- 4件の批評から「重大な問題」セクションを抽出し、1件以上の重大な問題がある場合: フィードバックを `{user_requirements}` に追記し、Step 3 と同じパターンで perspective を再生成する（1回のみ）`<br>`- 重大な問題が0件の場合: 現行 perspective を維持する（改善提案のみでは再生成しない）`

## 新規作成ファイル
（なし）

## 削除推奨ファイル
（なし）

## 実装順序
1. SKILL.md（変更2）— Phase 1A のパス変数リストから未使用変数を削除。他の変更と独立
2. SKILL.md（変更3）— Phase 0 Step 5 の再生成条件を明確化。他の変更と独立
3. SKILL.md（変更1）— Phase 1B のパス変数をテンプレートと一致させる。依存なし

依存関係の検出方法:
- 改善Aの成果物（新規ファイル、変更後の内容）を改善Bが参照する場合、Aを先に実施
- 例: テンプレート新規作成（A）→ SKILL.md でのテンプレート参照追加（B）→ Aが先

## 注意事項
- 変更1: Phase 1B サブエージェント起動時に、`.agent_audit/{agent_name}/audit-ce.md` と `.agent_audit/{agent_name}/audit-sa.md` の存在確認を行い、不在の場合は空文字列を渡す実装が必要
- 変更2: エージェント新規作成時の要件情報は Phase 0 の `{user_requirements}` 変数に保持されており、Phase 1A サブエージェントには直接渡されない。テンプレート phase1a-variant-generation.md では `{user_requirements}` を使用していないため、この削除は整合性を保つ
- 変更3: 再生成判定基準を「重大な問題が1件以上」に限定することで、過度な再生成を防ぎつつ、品質上のブロッカーには対応する
