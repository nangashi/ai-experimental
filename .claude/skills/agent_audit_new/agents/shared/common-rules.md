# 共通ルール定義

全次元エージェントが使用する共通のルール定義。

## Severity Rules

- **critical**: エージェントの実行が不可能、または実行結果が信頼できないレベルの致命的な問題（矛盾する指示、必須コンテキストの欠落、逆効果の基準、実行不可能な要求等）
- **improvement**: エージェントは実行できるが、品質・効率・信頼性に改善の余地がある問題（曖昧な基準、S/N比の低い基準、コンテキスト浪費、情報構造の最適化余地等）
- **info**: エージェントの動作に影響しないマイナーな最適化機会（軽微な冗長性、構造の微調整等）

## Impact Definition

- **High**: 実行不可能、信頼性に直接影響、またはコンテキスト浪費が 100 行以上
- **Medium**: 実行可能だが品質・効率に影響、コンテキスト浪費 30-100 行
- **Low**: マイナーな最適化機会、コンテキスト浪費 30 行未満

## Effort Definition

- **Low**: 1-2 行の修正、セクション削除、単純な統合
- **Medium**: セクション追加、5-10 行の修正、ファイル間の構造調整
- **High**: 大規模な構造変更、複数ファイルの調整、新規エージェント設計

## 検出戦略の共通パターン

### 2 フェーズアプローチ

**Phase 1: Comprehensive Problem Detection**
- 目的: 組織化やフォーマットを気にせず、すべての問題を網羅的に検出する
- 出力: 構造化されていない、包括的な問題リスト（箇条書き）

**Phase 2: Organization & Reporting**
- 目的: Phase 1 で検出した問題を整理し、優先順位付けされたレポートにする
- 出力: Severity でソートされた、構造化された findings レポート

### Adversarial Thinking

検出時は「指示に技術的には従いつつ、低品質な出力を生成しようとするエージェント実装者」の視点を採用する。

以下の adversarial questions を各検出戦略で使用する:
- "Can I technically satisfy this instruction while producing poor output?"
- "Can I claim to fulfill this requirement while actually doing something completely different?"
- "Does this instruction allow me to choose the easiest interpretation when ambiguous?"
- "Can I point to this instruction and explain what specific behavior it adds that wouldn't happen without it?"
