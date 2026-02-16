## 重大な問題

### C-1: 外部スキルパス参照（旧スキル名） [architecture, efficiency, stability, effectiveness]
- 対象: SKILL.md:64, 221
- 内容: `.claude/skills/agent_audit/` 配下のファイルを参照しているが、実際は同スキル内 `.claude/skills/agent_audit_new/` を使用すべき。実行時にファイル不在エラーが発生する
- 推奨: line 64の `.claude/skills/agent_audit/group-classification.md` を `.claude/skills/agent_audit_new/group-classification.md` に変更。line 221の `.claude/skills/agent_audit/templates/apply-improvements.md` を `.claude/skills/agent_audit_new/templates/apply-improvements.md` に変更
- impact: high, effort: low

## 改善提案

なし

---
注: 改善提案を 6 件省略しました（合計 6 件中上位 0 件を表示）。省略された項目は次回実行で検出されます。
