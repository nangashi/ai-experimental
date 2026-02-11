以下の手順でエージェント定義ファイルを生成してください:

1. Read で以下のファイルを読み込む:
   - {reference_agent_path} （参照用のエージェント定義 — 構造とフォーマットを把握する）
   - {perspective_path} （観点定義 — 評価スコープと問題バンクを把握する）

2. 参照エージェント定義の構造を分析し、以下の要素を確認する:
   - YAMLフロントマター形式（name, description, tools, model）
   - ロール定義文（冒頭の役割説明）
   - 評価基準セクション（各スコープ項目に対応する評価基準）
   - 出力ガイドライン

3. 観点定義の評価スコープを基に、新しいエージェント定義を生成する

## 生成ガイドライン

### YAMLフロントマター
```yaml
---
name: {key}-{target}-reviewer
description: {1文の英語説明。観点定義の概要を基にする}
tools: Glob, Grep, Read, WebFetch, WebSearch, BashOutput, KillBash
model: inherit
---
```

### 本文構成（基本要素のみ含める）

1. **ロール定義**: 1-2文で専門家の役割を定義する（英語）
2. **評価レベルの明示**: design なら「architecture and design level」、code なら「implementation and code level」
3. **評価優先度**: 重大 → 重要 → 中程度 → 軽微の順に検出・報告する指示
4. **評価基準**: 観点定義の評価スコープ5項目をそれぞれ見出し付きで展開。各項目に1-2文の説明を付ける
5. **評価姿勢**: 3-4箇条書きで検出方針を記述
6. **出力ガイドライン**: 分析結果の報告方法を記述

### 含めないもの（reviewer_optimize の最適化プロセスで追加される可能性があるため）

- Few-shot Examples（具体的なレビュー例）
- 詳細な Scoring Criteria（5段階スコア表）
- Problem Detection Focus（問題カテゴリの詳細リスト）
- Detection Hints（検出ヒント）

### 言語
- エージェント定義本文は**英語**で記述する（参照エージェントのパターンに合わせる）
- YAMLフロントマターの description も英語

4. Write で {agent_save_path} に保存する
5. 以下のフォーマットで結果サマリのみ返答する:

- エージェント名: {key}-{target}-reviewer
- セクション数: {N}
- 推定行数: {N}行
