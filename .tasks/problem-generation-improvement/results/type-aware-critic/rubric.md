# Evaluation Rubric: critic-effectiveness Test Scenarios

## Overview

This rubric provides scoring guidelines for evaluating the critic-effectiveness agent's performance across 7 test scenarios. Each scenario tests the agent's ability to evaluate perspective definitions for effectiveness (contribution to review quality) and boundary clarity.

---

## Scenario Rubrics

### T01: Clear Value Proposition with Minor Boundary Ambiguity

**Total Weight**: 3.0

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T01-C1 | Value contribution identification | 観点なしで見逃される3つ以上の具体的問題を列挙し(例: GDPR準拠チェック欠如、削除権実装漏れ、匿名化戦略不足)、各問題が修正可能な改善に繋がることを確認 | 見逃される問題を列挙するが2つ以下、または改善可能性の検証が不足 | 問題列挙が抽象的(「プライバシーリスク」等)または見逃される問題の特定なし | 1.0 |
| T01-C2 | Boundary overlap detection | 「データアクセス制御」(in-scope)と「システム全体のアクセスログ管理」(out-of-scope, Reliabilityに委譲)の範囲曖昧性を具体的に指摘 | アクセス関連の曖昧性に言及するが具体的な重複項目(アクセス制御 vs アクセスログ)を特定せず | 境界曖昧性を検出せず | 1.0 |
| T01-C3 | Cross-reference verification | Security観点への参照(認証・暗号化)が適切か検証し、Security観点に含まれるか確認する手順を実施 | 参照先の確認に言及するが検証手順が不明確 | 相互参照の検証なし | 0.5 |
| T01-C4 | Actionability assessment | 5つのスコープ項目(収集・保存・削除ポリシー、規制準拠、アクセス制御、同意取得、匿名化)が具体的改善に繋がるか評価し、「注意すべき」で終わる指摘がないことを確認 | 実行可能性に言及するがスコープ項目との対応が不明確 | 実行可能性の評価なし | 0.5 |

**Scoring Notes**:
- **Expected output category**: 「改善提案」(Minor boundary ambiguity)
- **Key detection**: アクセス制御とアクセスログの境界曖昧性
- **Anti-pattern**: 境界曖昧性を見逃す、抽象的な問題列挙

---

### T02: Significant Scope Overlap with Existing Perspective

**Total Weight**: 4.0

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T02-C1 | Scope overlap detection | 「命名規則一貫性」(スコープ項目2)「エラーレスポンス統一性」(スコープ項目4)がConsistency観点の「命名規則・エラーハンドリングパターン一貫性」と重複することを具体的に指摘 | 一貫性関連の重複に言及するが具体的項目(命名規則、エラーレスポンス)を特定せず | スコープ重複を検出せず | 1.0 |
| T02-C2 | Overlap with Best Practices | 「OpenAPI仕様採用」(ボーナス)「APIドキュメント生成ツール選定」(out-of-scope)がBest Practices観点の「業界標準採用・ドキュメント充実度」と重複する可能性を指摘 | Best Practices観点との関連に言及するが重複の具体性(OpenAPI、ドキュメント)不足 | Best Practicesとの重複を見逃す | 1.0 |
| T02-C3 | Critical boundary issue identification | 複数観点(Consistency, Best Practices)との重複により観点の独自性が不明確であることを「重大な問題」として判定 | 重複を指摘するが重大性の判断が不明確(「改善提案」レベルで留まる) | 重複を軽微な問題として扱う | 1.0 |
| T02-C4 | Refactoring recommendation | スコープを「RESTful設計原則(リソース指向、HTTPメソッド適切性)」に限定し、命名規則→Consistency観点、OpenAPI/ドキュメント→Best Practices観点に委譲する具体的改善提案 | 改善提案があるが実行可能性が不明確(どの項目をどの観点に委譲するか不明) | 改善提案なし | 1.0 |

**Scoring Notes**:
- **Expected output category**: 「重大な問題」(Significant overlap)
- **Key detection**: Consistency(命名規則、エラーレスポンス)、Best Practices(OpenAPI、ドキュメント)との複数重複
- **Anti-pattern**: 重複を「改善提案」レベルで留める、具体的委譲先を示さない

---

### T03: Overly Narrow Scope Limiting Usefulness

**Total Weight**: 4.0

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T03-C1 | Narrow scope identification | スコープがデータベース設計の一部分(インデックスのみ)に限定され過ぎており、クエリ最適化、データモデル、パーティション等の関連領域が除外されていることを指摘 | 狭隘性に言及するが具体的範囲の問題(インデックスのみ)を特定せず | 狭隘性を検出せず、または「焦点が絞られている」として誤評価 | 1.0 |
| T03-C2 | Performance overlap analysis | 「検索クエリパターン」(スコープ項目2)「複合インデックス」(スコープ項目3)がPerformance観点の「クエリ最適化」(out-of-scope参照)と境界曖昧/重複することを指摘 | Performance観点との関連に言及するが重複の具体性(クエリパターン、複合インデックス)不足 | Performance観点との重複を見逃す | 1.0 |
| T03-C3 | Value limitation assessment | インデックス設計のみでは見逃される重要な問題(データモデル正規化、パーティション戦略、クエリ最適化、接続プール設計等)を3つ以上列挙 | 見逃される問題に言及するが2つ以下または具体性不足 | 観点の価値制限を評価せず | 1.0 |
| T03-C4 | Scope expansion recommendation | Performance観点に統合しデータベース最適化全般に拡張する、または独立性を保つ明確な理由(インデックス専門性の価値等)を提示する具体的提案 | 改善提案があるが統合/拡張の判断基準が不明確 | 改善提案なし | 1.0 |

**Scoring Notes**:
- **Expected output category**: 「改善提案」または「重大な問題」(判断による)
- **Key detection**: 狭隘性(インデックスのみ)、Performance観点との境界曖昧性、価値制限
- **Anti-pattern**: 狭隘性を肯定的に評価、Performance観点との関係を分析しない

---

### T04: Ambiguous Cross-Reference and Verification Gaps

**Total Weight**: 5.0

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T04-C1 | Invalid cross-reference detection | 「Monitoring観点」「Validation観点」が既存観点リストに存在しないことを検出し、参照エラーとして指摘 | 存在しない観点への言及があるが検証せず(既存観点リストとの照合なし) | 無効な参照を見逃す | 1.0 |
| T04-C2 | Consistency overlap detection | 「エラーメッセージの分かりやすさ」(スコープ項目2)がConsistency観点の「エラーメッセージ形式」と重複/境界曖昧(ユーザー向け vs システム向け)であることを指摘 | エラーメッセージ関連の重複に言及するが具体的境界(分かりやすさ vs 形式)を分析せず | Consistencyとの重複を見逃す | 1.0 |
| T04-C3 | Performance overlap analysis | 「レスポンス時間とユーザー待機時間の設計」(スコープ項目4)がPerformance観点の「レスポンスタイム」と重複することを指摘し、どちらがユーザー視点/システム視点かの境界を明確化する必要性を提示 | Performance観点との関連に言及するが境界明確化の必要性(ユーザー視点 vs システム視点)を示さず | Performanceとの重複を見逃す | 1.0 |
| T04-C4 | Critical issue determination | 無効参照(Monitoring/Validation)と複数重複(Consistency/Performance)により観点定義に重大な問題があると判定 | 問題を指摘するが重大性の判断が不明確(「改善提案」レベルで留まる) | 問題を軽微として扱う | 1.0 |
| T04-C5 | Corrective recommendations | 無効参照(Monitoring/Validation)の削除、エラーメッセージ範囲の明確化(ユーザー向けメッセージのみ)、レスポンス時間のPerformance観点への委譲を含む具体的改善提案 | 改善提案があるが実行可能性が不明確(どの項目をどう修正するか不明) | 改善提案なし | 1.0 |

**Scoring Notes**:
- **Expected output category**: 「重大な問題」(Invalid references + multiple overlaps)
- **Key detection**: 無効参照(Monitoring/Validation)、Consistency/Performanceとの重複、境界曖昧性
- **Anti-pattern**: 無効参照を検証しない、重複を見逃す、問題を軽微として扱う

---

### T05: Well-Defined Perspective with Good Boundaries

**Total Weight**: 4.0

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T05-C1 | Clear value proposition | 観点なしで見逃される3つ以上の具体的問題(構造化ログ欠如、SLI未定義、トレースID伝播欠如、アラート閾値不明確等)を列挙 | 見逃される問題を列挙するが2つ以下、または具体性不足 | 問題列挙が抽象的(「可視性が不足」等) | 1.0 |
| T05-C2 | Clear boundary with Reliability | エラーハンドリング/リトライ/ログ保管がReliability観点に委譲され、可観測性は運用診断に焦点を絞っており境界が明確であることを確認 | 境界に言及するが明確性の評価が不足(なぜ明確か説明なし) | 境界確認なし | 1.0 |
| T05-C3 | Clear boundary with Security | 監査証跡がSecurity観点に委譲され、可観測性は運用診断に焦点を絞っていることを確認 | 境界に言及するが焦点の明確性(運用診断 vs 監査)が不足 | 境界確認なし | 1.0 |
| T05-C4 | Actionability confirmation | 5つのスコープ項目すべてが具体的改善(ログフォーマット追加、メトリクス定義、トレースID実装、ヘルスチェック追加、アラート設定等)に繋がることを確認 | 実行可能性に言及するが項目との対応が不明確 | 実行可能性の評価なし | 0.5 |
| T05-C5 | Positive assessment | 重大な問題なし、境界明確、実行可能、として観点が有効であることを「確認(良い点)」として評価 | 肯定的評価があるが根拠が不明確(なぜ有効か説明不足) | 肯定的評価なし、または無理に改善提案を生成 | 0.5 |

**Scoring Notes**:
- **Expected output category**: 「確認(良い点)」
- **Key detection**: 明確な価値提案、Reliability/Securityとの明確な境界、行動可能性
- **Anti-pattern**: 良い観点に対して改善提案を無理に生成、境界確認を省略

---

### T06: Actionability Issues - Recognition Without Improvement

**Total Weight**: 5.0

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T06-C1 | Non-actionable pattern detection | スコープ5項目が「認識」(項目1)「特定」(項目2)「識別」(項目3)「評価」(項目4)「考慮」(項目5)という非行動的動詞で構成され、具体的改善(モジュール分割実施、リファクタリング実施等)に繋がらないパターンを検出 | 非行動的パターンに言及するが全項目の体系的分析なし(一部項目のみ指摘) | 非行動的パターンを検出せず、または「認識は重要」として誤評価 | 1.0 |
| T06-C2 | Scoring guideline mismatch | Scoring Guidelinesが「認識があること」「評価が含まれている」を評価基準としており、改善実施を求めていない不整合を指摘 | 評価基準の問題に言及するが具体的不整合(認識のみを求める)を特定せず | 評価基準の問題を見逃す | 1.0 |
| T06-C3 | Value limitation due to non-actionability | 「複雑性があることを認識せよ」「リスクを評価せよ」で終わる指摘はレビュー価値が限定的(修正可能な改善に繋がらない)であることを指摘 | 価値制限に言及するが根拠が不明確(なぜ価値が限定的か説明不足) | 価値制限を評価せず | 1.0 |
| T06-C4 | Best Practices overlap analysis | 「保守性」「技術的負債」「拡張性」がBest Practices観点の「保守性・リファクタリング」と重複することを指摘 | Best Practices観点との関連に言及するが重複の具体性不足 | Best Practicesとの重複を見逃す | 1.0 |
| T06-C5 | Actionable refactoring recommendation | スコープを「循環依存の検出と解消策の提示」「モジュール分割の具体的提案」「リファクタリング優先順位の決定」等の行動的項目(実施を求める動詞)に変更する具体的提案 | 改善提案があるが行動可能性の確保が不明確(依然として認識レベルの提案) | 改善提案なし | 1.0 |

**Scoring Notes**:
- **Expected output category**: 「重大な問題」(Non-actionability)
- **Key detection**: 非行動的動詞(認識/特定/識別/評価/考慮)、評価基準の不整合、価値制限、Best Practices重複
- **Anti-pattern**: 非行動的パターンを見逃す、「認識は重要」として肯定的評価

---

### T07: Vague Value Proposition and Unclear Scope

**Total Weight**: 4.5

| Criterion ID | Criterion | Full (2) | Partial (1) | Miss (0) | Weight |
|-------------|-----------|----------|-------------|----------|--------|
| T07-C1 | Vague value proposition detection | 「技術的負債の蓄積リスクが考慮されているか」という目的が曖昧で、観点なしで見逃される具体的問題(例: どのような負債が検出されるのか)が不明であることを指摘 | 目的の曖昧性に言及するが具体的問題の欠如を指摘せず | 目的の曖昧性を検出せず | 1.0 |
| T07-C2 | Non-actionable scope analysis | スコープ4項目が「認識」(項目1)「文書化」(項目2)「特定」(項目3)「評価」(項目4)で構成され、T06と同様の非行動的パターン(改善実施を求めない)であることを指摘 | 非行動的パターンに言及するが項目との対応が不明確 | 非行動的パターンを検出せず | 1.0 |
| T07-C3 | Best Practices complete overlap | スコープ全体(トレードオフ認識、制約文書化、リファクタリング機会、レガシー統合)がBest Practices観点の「リファクタリング・保守性・コード品質」と完全に重複し独自性がないことを指摘 | Best Practices観点との重複に言及するが完全重複の指摘なし(部分重複として扱う) | Best Practicesとの重複を見逃す | 1.0 |
| T07-C4 | Insufficient item count | スコープが4項目のみで、他の観点の標準5項目より少なく網羅性が不足していることを指摘 | 項目数に言及するが網羅性への影響を評価せず | 項目数の問題を見逃す | 0.5 |
| T07-C5 | Critical issue determination and recommendation | Best Practices観点への統合または観点の廃止を「重大な問題」として提案(独自性がないため) | 統合/廃止に言及するが重大性の判断が不明確(「改善提案」レベルで留まる) | 統合/廃止の提案なし | 1.0 |

**Scoring Notes**:
- **Expected output category**: 「重大な問題」(Complete overlap + vague value)
- **Key detection**: 曖昧な目的、非行動的パターン、Best Practicesとの完全重複、項目数不足
- **Anti-pattern**: 完全重複を部分重複として扱う、問題を「改善提案」レベルで留める

---

## Scoring Summary

| Scenario | Difficulty | Total Weight | Key Focus |
|---------|-----------|--------------|-----------|
| T01 | Easy | 3.0 | Value contribution + Minor boundary ambiguity |
| T02 | Medium | 4.0 | Significant scope overlap detection |
| T03 | Medium | 4.0 | Narrow scope + Value limitation |
| T04 | Hard | 5.0 | Invalid cross-reference + Multiple overlaps |
| T05 | Easy | 4.0 | Well-defined perspective (positive case) |
| T06 | Hard | 5.0 | Non-actionable pattern detection |
| T07 | Medium | 4.5 | Vague value + Complete overlap |

**Total Weight**: 29.5

---

## Difficulty Distribution

- **Easy**: 2 scenarios (T01, T05) - 7.0 points (23.7%)
- **Medium**: 3 scenarios (T02, T03, T07) - 12.5 points (42.4%)
- **Hard**: 2 scenarios (T04, T06) - 10.0 points (33.9%)

---

## Capability Coverage

- **Boundary verification**: T01, T02, T03, T04, T05
- **Value contribution**: T01, T03, T05, T06, T07
- **Cross-reference accuracy**: T01, T04
- **Scope appropriateness**: T03, T06, T07
- **Actionability**: T01, T05, T06, T07
