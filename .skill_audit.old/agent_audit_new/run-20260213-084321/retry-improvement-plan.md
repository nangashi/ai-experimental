# 改善計画: agent_audit_new

## 変更対象ファイル
| # | ファイル | 変更種別 | 変更概要 | 対応フィードバック |
|---|---------|---------|---------|------------------|
| 1 | templates/apply-improvements.md | 修正 | パス変数定義セクションの追加 | stability (C-1): テンプレート内のパス変数が未定義 |

## 各ファイルの変更詳細

### 1. /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.claude/skills/agent_audit_new/templates/apply-improvements.md（修正）
**対応フィードバック**: stability (C-1): 参照整合性: テンプレート内のパス変数が未定義

**変更内容**:
- ファイル先頭（1行目の前）: なし → 以下のパス変数定義セクションを追加
  ```markdown
  ## パス変数
  - `{approved_findings_path}`: 承認済み findings ファイルのパス（`.agent_audit/{agent_name}/audit-approved.md`）
  - `{agent_path}`: エージェント定義ファイルのパス（分析対象ファイル）

  ```

## 新規作成ファイル
該当なし

## 削除推奨ファイル
該当なし

## 実装順序
1. templates/apply-improvements.md にパス変数定義セクションを追加（テンプレート内の参照整合性を確保するため）

## 注意事項
- パス変数定義セクションを先頭に追加することで、既存の手順説明との整合性を保つ
- SKILL.md では既に `{approved_findings_path}` と `{agent_path}` が定義されているため、SKILL.md の変更は不要
- テンプレート内の手順説明（3-4行目）はそのまま維持し、定義セクションのみを追加する
