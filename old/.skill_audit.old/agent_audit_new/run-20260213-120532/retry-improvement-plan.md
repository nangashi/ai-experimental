# 改善計画: agent_bench_new

## 変更対象ファイル
| # | ファイル | 変更種別 | 変更概要 | 対応フィードバック |
|---|---------|---------|---------|------------------|
| 1 | SKILL.md | 修正 | L135の外部スキル参照パスを現行スキルのパスに修正 | stability: C-1 外部スキル（agent_bench）への直接参照 — 残存1件 |

## 各ファイルの変更詳細

### 1. SKILL.md（修正）
**対応フィードバック**: stability: C-1 外部スキル（agent_bench）への直接参照 — 残存1件

**変更内容**:
- L135: approach-catalog.md 参照パス修正
  - 現在: `- `{approach_catalog_path}`: `.claude/skills/agent_bench/approach-catalog.md` の絶対パス`
  - 修正後: `- `{approach_catalog_path}`: `.claude/skills/agent_bench_new/approach-catalog.md` の絶対パス`

## 新規作成ファイル
（なし）

## 削除推奨ファイル
（なし）

## 実装順序
1. SKILL.md の L135 のパス修正（単一変更のため他ファイルへの依存なし）

## 注意事項
- 変更によって既存のワークフローが壊れないこと
- パス変数が正しく解決されることを確認すること
