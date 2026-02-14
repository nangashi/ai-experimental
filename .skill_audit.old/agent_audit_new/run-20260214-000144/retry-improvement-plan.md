# 改善計画: agent_audit_new

## 変更対象ファイル
| # | ファイル | 変更種別 | 変更概要 | 対応フィードバック |
|---|---------|---------|---------|------------------|
| 1 | group-classification.md | 削除推奨 | SKILL.mdへの埋め込み完了後に未削除の冗長ファイルを削除 | R-1: group-classification.mdが削除されていない |

## 各ファイルの変更詳細

### 1. /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.claude/skills/agent_audit_new/group-classification.md（削除推奨）
**対応フィードバック**: R-1: group-classification.mdが削除されていない [regression]

**変更内容**:
- ファイル全体を削除
- 理由: SKILL.md の Phase 0（行42-62）にグループ分類基準が埋め込まれており、外部参照は完全に削除されている。group-classification.md は実行時に参照されないため、冗長ファイルとして削除可能

## 新規作成ファイル
該当なし

## 削除推奨ファイル
| ファイル | 理由 | 対応フィードバック |
|---------|------|------------------|
| group-classification.md | SKILL.mdへの埋め込み完了後に未削除。実行時に参照されないため冗長 | R-1 |

## 実装順序
1. group-classification.md の削除
   - 理由: 単独の変更で、他ファイルへの依存関係なし

## 注意事項
- 変更によって既存のワークフローが壊れないこと
  - SKILL.md の Phase 0（行42-62）にグループ分類ロジックが埋め込まれているため、group-classification.md 削除は実行時の動作に影響しない
- C-5（agent_bench サブディレクトリのスコープ外参照）について:
  - 本フィードバックは承認されたが、改善案として「agent_bench ファイルをスキルディレクトリ外に移動するか、スキル構造を明確に分離する」が提示されている
  - 現状では `/home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.claude/skills/` に `agent_bench` と `agent_bench_new` の2つの独立したスキルが存在する
  - `agent_audit_new/agent_bench/` サブディレクトリは、スキル作成時の構造分析で参照される外部スキルデータとして残されている可能性がある
  - **推奨アクション**: このサブディレクトリを削除するか、`.claude/skills/agent_bench_new` への参照に変更するかをユーザーに確認すべき。本改善計画では構造的な変更が大きいため、group-classification.md の削除のみを実施し、C-5 への対応は別途ユーザー判断を求める
