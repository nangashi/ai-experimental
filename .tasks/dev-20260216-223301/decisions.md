# 判断記録

## スキル vs CLAUDE.md規約

**選択**: CLAUDE.md規約（スキルを作らない）

**理由**:
- 実装コストゼロ。CLAUDE.mdとディレクトリを用意するだけで即日使える
- 自然言語で「記録して」と言うだけで動作する柔軟なインターフェース
- スキルは収集プロトコルが複雑化した場合の将来オプションとして残す

## ストレージ構造

**選択**: `.claude/instructions/knowledge/` サブディレクトリ

**理由**:
- 既存の手書きinstructionsファイルと蓄積知識を物理的に分離
- 既存のCLAUDE.md Instructions テーブル機構にそのまま乗る
- トピック別ファイル分割でファイル肥大化を防止

## エントリ形式

**選択**: 既存のscope/action/rationale形式 + added日付

**理由**:
- 既に.claude/instructions/で実績のある形式
- addedフィールドで棚卸し時の鮮度判断が可能
- sourceは任意（口頭指示の場合は不要）
