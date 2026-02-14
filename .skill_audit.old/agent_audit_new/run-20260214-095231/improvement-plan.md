# 改善計画: agent_audit_new

## 変更対象ファイル
| # | ファイル | 変更種別 | 変更概要 | 対応フィードバック |
|---|---------|---------|---------|------------------|
| 1 | SKILL.md | 修正 | 外部スキルパス参照を同スキル内パスに修正 | C-1 |

## 各ファイルの変更詳細

### 1. /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.claude/skills/agent_audit_new/SKILL.md（修正）
**対応フィードバック**: architecture, efficiency, stability, effectiveness: 外部スキルパス参照（旧スキル名）

**変更内容**:
- line 64: `.claude/skills/agent_audit/group-classification.md` → `.claude/skills/agent_audit_new/group-classification.md`
- line 221: `.claude/skills/agent_audit/templates/apply-improvements.md` → `.claude/skills/agent_audit_new/templates/apply-improvements.md`

## 新規作成ファイル
該当なし

## 削除推奨ファイル
該当なし

## 実装順序
1. SKILL.md のパス参照修正（依存関係なし、単独変更可能）

## 注意事項
- 変更によって既存のワークフローが壊れないこと
- 修正後、スキル実行時にファイル不在エラーが発生しないことを確認すること
- 参照先ファイル（group-classification.md, templates/apply-improvements.md）が実際に存在することを確認済み
