# 改善計画: agent_bench_new

## 変更対象ファイル
| # | ファイル | 変更種別 | 変更概要 | 対応フィードバック |
|---|---------|---------|---------|------------------|
| 1 | templates/phase1a-variant-generation.md | 修正 | 未定義の {perspective_path} 参照を削除 | C-3/R-1: Phase 1A テンプレートの未定義 perspective_path 参照 |

## 各ファイルの変更詳細

### 1. templates/phase1a-variant-generation.md（修正）
**対応フィードバック**: C-3/R-1: Phase 1A テンプレートの未定義 perspective_path 参照 [stability]

**変更内容**:
- 行10: `3. {perspective_path} が存在することを Read で確認する` → 削除

**変更理由**:
SKILL.md から {perspective_path} パス変数が削除されたため、テンプレート内に残存する未定義変数参照を削除する必要がある。この手順は不要（perspective-source.md が既に存在し、手順1で読み込まれている）。

## 新規作成ファイル
（なし）

## 削除推奨ファイル
（なし）

## 実装順序
1. templates/phase1a-variant-generation.md の修正
   - 単一ファイルの修正のため、他の変更への依存関係はなし

## 注意事項
- Phase 1A のワークフローは変更なし（perspective-source.md は既に手順1で読み込まれている）
- 削除される手順3は冗長確認であり、ワークフローに影響を与えない
