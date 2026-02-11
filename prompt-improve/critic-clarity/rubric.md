# Evaluation Rubric for critic-clarity Agent

This rubric consolidates the scoring criteria for all test scenarios.

---

## T01: Simple Security Perspective with Clear Criteria

**Category**: Baseline clarity assessment | **Difficulty**: Easy

### Scoring Criteria

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T01-C1 | Ambiguity detection completeness | 曖昧な表現がないことを明確に指摘している、または「曖昧な表現はない」と判定している | 一部の明確な表現について言及しているが、全体の評価が不明確 | 曖昧性についての評価がない | 1.0 |
| T01-C2 | Consistency verification | 各評価スコープ項目について「AIが一意に解釈可能か」を検証している | 一部の項目についてのみ一貫性を確認している | 一貫性についての検証がない | 1.0 |
| T01-C3 | Executability assessment | 検出可能性（実行可能性）について各項目を評価している | 一部の項目についてのみ実行可能性を評価している | 実行可能性についての言及がない | 1.0 |
| T01-C4 | Output format compliance | SendMessage形式で「重大な問題」「改善提案」「確認」のセクションを含む | 一部のセクションが欠けている、またはフォーマットが不正確 | 指定されたフォーマットに従っていない | 0.5 |

### Expected Key Behaviors
- 明確な基準（カッコ内の具体例）を「良い点」として認識する
- スコープ外が明確に定義されていることを評価する
- 問題バンクの具体例が深刻度判定の参考になることを認識する

### Anti-patterns
- 明確な基準を「曖昧」と誤判定する
- カッコ内の具体例を無視して評価する
- 出力フォーマットの指示を無視する

---

## T02: Vague Perspective with Subjective Language

**Category**: Ambiguity detection | **Difficulty**: Medium

### Scoring Criteria

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T02-C1 | Identification of subjective terms | 「適切」「最適化」「妥当」「効果的」等の主観的表現を3個以上特定している | 主観的表現を1-2個特定している | 主観的表現の指摘がない | 1.0 |
| T02-C2 | Concrete alternative suggestions | 各曖昧な表現に対して具体的な代替案（数値基準、測定方法等）を提案している | 一部の表現についてのみ代替案がある | 代替案の提案がない | 1.0 |
| T02-C3 | Problem bank vagueness detection | 問題バンクの「非常に遅い」「一部のコードに改善の余地」等の曖昧さを指摘している | 問題バンクの曖昧さに触れているが不完全 | 問題バンクの評価がない | 1.0 |
| T02-C4 | AI consistency impact analysis | 曖昧な表現が複数AIの判断にどう影響するかを説明している | 一貫性への影響に触れているが浅い | 一貫性への影響分析がない | 0.5 |

### Expected Key Behaviors
- 「適切」「最適化」「妥当」等の判断基準が不明確な表現を検出する
- 数値基準や測定方法の欠如を指摘する
- 問題バンクの例も曖昧性チェックの対象にする

### Anti-patterns
- 全体的に「曖昧」とだけ述べて具体的な箇所を示さない
- 代替案なしで批判だけする
- 評価スコープのみに注目し、問題バンクを見落とす

---

## T03: Boundary Case Ambiguity

**Category**: Consistency testing (boundary conditions) | **Difficulty**: Hard

### Scoring Criteria

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T03-C1 | Boundary case identification | 「3階層以内を推奨」と「4-5階層は中程度問題」の間の境界（3.5階層？）の曖昧さを指摘している | ネストの基準について触れているが境界の曖昧さに言及していない | ネストの基準についての評価がない | 1.0 |
| T03-C2 | Subjective balance detection | 「適度に削減」「バランスを考慮」「十分なカバレッジ」等の判断基準が不明確であることを指摘している | これらの表現のうち1-2個について指摘している | 主観的バランス表現の指摘がない | 1.0 |
| T03-C3 | Bonus/Penalty clarity assessment | ボーナス/ペナルティの「高い設計」「過度な使用」の判定基準が曖昧であることを指摘している | ボーナス/ペナルティに触れているが曖昧性の指摘が不十分 | ボーナス/ペナルティの評価がない | 1.0 |
| T03-C4 | Condition-based criteria ambiguity | 「テストコードがある場合」の条件付き基準がAI判断を分岐させる可能性を指摘している | 条件付き基準に触れているが影響分析が浅い | 条件付き基準についての言及がない | 1.0 |
| T03-C5 | Numerical threshold consistency | 「200行」等の数値基準は明確だが、「1文字変数名（ループカウンタ除く）」の例外処理がAI間で一貫するか検証している | 数値基準の明確性または例外処理について触れている | 数値基準についての評価がない | 0.5 |

### Expected Key Behaviors
- 推奨基準と問題基準の間のグレーゾーンを検出する
- 条件付き基準（「〜の場合」）がAI判断を分岐させることを指摘する
- 数値基準は明確だが、例外処理の記述が曖昧になりうることを認識する

### Anti-patterns
- 数値基準があるから「明確」と安易に判断する
- 境界ケース（3階層 vs 4階層の間）の曖昧さを見落とす
- ボーナス/ペナルティセクションを無視する

---

## T04: Multi-layered Scope Definition

**Category**: Executability analysis | **Difficulty**: Medium

### Scoring Criteria

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T04-C1 | Detection method clarity | 「循環依存」は検出方法が明確（依存グラフ分析）だが、「責務の明確性」「適切なインターフェース」は検出方法が不明確であることを指摘している | 一部の項目について検出方法の明確性を評価している | 検出方法についての評価がない | 1.0 |
| T04-C2 | Abstract concept executability | 「予測可能な状態管理」「副作用の適切な管理」等の抽象的概念について、AIが何を具体的に確認すべきか不明確であることを指摘している | 抽象的概念に触れているが実行可能性への影響分析が不十分 | 抽象的概念についての評価がない | 1.0 |
| T04-C3 | Necessity judgment ambiguity | 「双方向の必然性があるか」という判断基準がAI間で一致しない可能性を指摘している | 必然性判断に触れているが曖昧性の指摘が浅い | 必然性判断についての言及がない | 1.0 |
| T04-C4 | Future-oriented criteria difficulty | 「新機能追加時に変更が最小限」という未来予測的基準の評価困難性を指摘している | 拡張性基準に触れているが評価困難性への言及が不十分 | 拡張性基準についての評価がない | 1.0 |
| T04-C5 | Scope boundary clarity | スコープ外の「実装の詳細」と評価スコープの「インターフェース定義」の境界が曖昧であることを指摘している | スコープ境界について触れているが曖昧性の分析が浅い | スコープ境界についての言及がない | 0.5 |

### Expected Key Behaviors
- 抽象的な概念（「予測可能」「適切」等）が検出可能な具体基準に落とし込まれていないことを指摘する
- 未来予測的な基準（拡張性等）の評価困難性を認識する
- スコープとスコープ外の境界が曖昧な箇所を検出する

### Anti-patterns
- 「循環依存」のような明確な基準だけを評価し、抽象的基準を見落とす
- 技術的に正しいかどうかで評価し、「AI が一意に判断できるか」を無視する
- 問題バンクの例が評価スコープの曖昧さを補完できていないことを見落とす

---

## T05: Minimal Scope with Edge Cases

**Category**: Edge case handling | **Difficulty**: Easy

### Scoring Criteria

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T05-C1 | Concrete criteria recognition | カッコ内の具体的基準（「1-3文」「手順番号付き」「コマンド例を含む」）を明確性の良い例として認識している | 一部の具体基準について言及している | 具体基準の評価がない | 1.0 |
| T05-C2 | Conditional clarity assessment | 「LICENSE ファイルまたは README 内」の OR 条件がAI判断に影響しないことを確認している | OR 条件について触れているが影響分析が不十分 | OR 条件についての言及がない | 1.0 |
| T05-C3 | Scope-out clarity | スコープ外が明確に定義されており、AIが迷わず判断できることを評価している | スコープ外について触れているが評価が浅い | スコープ外についての評価がない | 0.5 |
| T05-C4 | Severity consistency | 問題バンクの深刻度分類が評価スコープと整合していることを確認している | 深刻度について触れているが整合性の確認が不十分 | 深刻度についての言及がない | 0.5 |

### Expected Key Behaviors
- 具体的な数値基準（「1-3文」）や形式指定（「手順番号付き」）を良い点として評価する
- OR 条件（「〜または〜」）が複数の正解パターンを許容していることを認識する
- スコープが狭く明確な場合、それを肯定的に評価する

### Anti-patterns
- 具体基準があっても「改善の余地がある」と過度に批判する
- OR 条件を曖昧性の原因と誤解する
- スコープが狭いことを「不十分」と批判する（狭いことは明確性には有利）

---

## T06: Inconsistent Problem Bank

**Category**: Executability analysis + Consistency testing | **Difficulty**: Hard

### Scoring Criteria

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T06-C1 | Scope-bank inconsistency detection | 評価スコープは「主要な機能」「エッジケース」と記載しているが、問題バンクには「カバレッジ50%未満」という数値基準があり、不整合を指摘している | スコープと問題バンクの差異に触れているが不整合の指摘が不十分 | スコープと問題バンクの整合性についての言及がない | 1.0 |
| T06-C2 | Subjective term in scope | 「主要な機能」「適切に使われている」「具体的なアサーション」等の主観的表現を指摘している | 一部の主観的表現について指摘している | 主観的表現の指摘がない | 1.0 |
| T06-C3 | Problem bank concrete criteria recognition | 問題バンクの「カバレッジ50%未満」「5秒以上」等の具体基準を良い例として認識している | 一部の具体基準について言及している | 具体基準の認識がない | 1.0 |
| T06-C4 | Severity boundary ambiguity | 「カバレッジ50%未満は中」だが、「49%と51%」の境界ケースがAI間で一致するか、および「主要な機能のみカバー」との関係が曖昧であることを指摘している | 深刻度境界について触れているが曖昧性の分析が不十分 | 深刻度境界についての言及がない | 1.0 |
| T06-C5 | Example-based clarity | 問題バンクの「例: assertTrue のみ」のような具体例がAI判断を補助することを評価している | 具体例について触れているが効果の評価が浅い | 具体例についての言及がない | 0.5 |
| T06-C6 | Multi-dimensional ambiguity | 「エッジケースのテスト」と「一部のエッジケースにテストがない（軽微）」の関係が曖昧（どの程度のエッジケース欠落が許容されるか）であることを指摘している | エッジケース基準について触れているが曖昧性の分析が不十分 | エッジケース基準についての言及がない | 0.5 |

### Expected Key Behaviors
- 評価スコープと問題バンクの間の不整合（主観的表現 vs 数値基準）を検出する
- 問題バンクに具体的な数値基準がある場合、それを肯定的に評価しつつ、スコープ側の曖昧さを指摘する
- 境界ケース（50%のカバレッジの前後）でのAI判断の一貫性を検証する

### Anti-patterns
- 問題バンクの具体例だけに注目し、評価スコープとの整合性を確認しない
- 数値基準があるから「全体として明確」と判断する
- 深刻度の境界値（50%、5秒等）がエッジケースになることを見落とす

---

## Scoring Summary

| Scenario | Total Criteria | Total Weight | Max Score |
|----------|---------------|--------------|-----------|
| T01 | 4 | 3.5 | 7.0 |
| T02 | 4 | 3.5 | 7.0 |
| T03 | 5 | 4.5 | 9.0 |
| T04 | 5 | 4.5 | 9.0 |
| T05 | 4 | 3.0 | 6.0 |
| T06 | 6 | 5.0 | 10.0 |
| **Total** | **28** | **24.0** | **48.0** |
