# 改善計画: agent_audit_new

## 変更対象ファイル
| # | ファイル | 変更種別 | 変更概要 | 対応フィードバック |
|---|---------|---------|---------|------------------|
| 1 | .claude/skills/agent_audit_new/SKILL.md | 修正 | Phase 0 Step 6a に `{previous_approved_path}` 変数定義を追加 | I-4: 知見蓄積の不在（部分的解決） |
| 2 | .claude/skills/agent_audit_new/templates/apply-improvements.md | 削除推奨 | インライン化済みの孤立ファイルを削除 | I-5: テンプレート外部化の過剰適用（部分的解決） |

## 各ファイルの変更詳細

### 1. .claude/skills/agent_audit_new/SKILL.md（修正）
**対応フィードバック**: architecture: I-4: Phase 1 Task prompt で `{previous_approved_path}` 変数を参照しているが、Phase 0 で定義されていない

**変更内容**:
- Phase 0 Step 6a（行86-88）: `{previous_approved_count}` の抽出後に `{previous_approved_path}` 変数を定義
  - 現在の記述: `{previous_approved_count}` のみ定義
  - 改善後の記述: `{previous_approved_count}` と `{previous_approved_path}` の両方を定義

**具体的な変更箇所**:
```markdown
6a. 前回実行履歴の確認:
   - `.agent_audit/{agent_name}/audit-approved.md` が存在する場合、Read で読み込み、`{previous_approved_count}` を抽出する
   - 存在しない場合は、`{previous_approved_count} = 0` とする
   - `{previous_approved_path}` = `.agent_audit/{agent_name}/audit-approved.md` の絶対パス
   - `{previous_approved_count} > 0` の場合、テキスト出力: `前回実行で {previous_approved_count} 件の指摘が承認されています。解決済み指摘として次元エージェントに渡します。`
```

### 2. .claude/skills/agent_audit_new/templates/apply-improvements.md（削除推奨）
**対応フィードバック**: architecture: I-5: SKILL.md Phase 2 Step 4 にインライン化されたが、元テンプレートファイルが削除されていない（孤立ファイル）

**変更内容**:
- ファイル全体を削除
  - 理由: SKILL.md Phase 2 Step 4（行228-261）に完全にインライン化されており、外部テンプレートファイルは参照されていない
  - Phase 2 Step 4 の Task prompt 内に全ての指示内容（手順、ルール、返答フォーマット）が埋め込まれているため、外部ファイルは不要

## 新規作成ファイル
（なし）

## 削除推奨ファイル
| ファイル | 理由 | 対応フィードバック |
|---------|------|------------------|
| .claude/skills/agent_audit_new/templates/apply-improvements.md | SKILL.md Phase 2 Step 4 にインライン化済み。参照されていない孤立ファイル | I-5: テンプレート外部化の過剰適用（部分的解決） |

## 実装順序
1. `.claude/skills/agent_audit_new/SKILL.md`（変更）— Phase 0 Step 6a に `{previous_approved_path}` 変数定義を追加
   - 理由: Phase 1 で使用される変数の定義を先に完了する必要がある
2. `.claude/skills/agent_audit_new/templates/apply-improvements.md`（削除）— 孤立ファイルを削除
   - 理由: SKILL.md の変更完了後、不要ファイルをクリーンアップする

依存関係の検出方法:
- SKILL.md の変更は独立しているため、削除作業より先に実施可能
- 削除作業は SKILL.md の変更に依存しないが、SKILL.md の変更完了を確認してから実施することで、誤削除を防ぐ

## 注意事項
- 変更によって既存のワークフローが壊れないこと
  - `{previous_approved_path}` の定義追加により、Phase 1 Task prompt の変数参照エラーが解消される
  - 孤立ファイル削除は参照されていないため、ワークフローに影響しない
- Phase 0 Step 6a の変更箇所は、既存の `{previous_approved_count}` 定義ロジックの直後に追加する
- Phase 1 Task prompt（行124）で使用されている `{previous_approved_path}` 変数が正しく解決されることを確認する
