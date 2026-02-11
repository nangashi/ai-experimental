# Scoring Report: v004-baseline

## Summary Scores

- **Mean Score**: 7.25
- **Standard Deviation**: 0.25
- **Run1 Score**: 7.0 (検出7.0 + bonus1.0 - penalty1.0)
- **Run2 Score**: 7.5 (検出6.5 + bonus1.5 - penalty0.5)

---

## Run 1 Detailed Scoring

### Detection Matrix

| Problem ID | Category | Severity | Detection | Score | Notes |
|-----------|----------|----------|-----------|-------|-------|
| P01 | 命名規約（データモデル） | 重大 | × | 0.0 | テーブル名の単数/複数形混在の指摘なし |
| P02 | 命名規約（データモデル） | 重大 | ○ | 1.0 | Issue C1 で詳細に検出（User: userId vs created_at, Video: camelCase, Course/Enrollment: snake_case） |
| P03 | API設計 | 中 | △ | 0.5 | Issue S1 でレスポンス形式に言及、既存パターンとの具体的比較なし |
| P04 | API設計 | 中 | △ | 0.5 | Issue S2 で複数形エンドポイント指摘、既存が単数形という不一致は未指摘 |
| P05 | 実装パターン（情報欠落） | 重大 | ○ | 1.0 | Issue C2 でエラーハンドリング実装パターンの欠落を明確に指摘 |
| P06 | 実装パターン（情報欠落） | 重大 | ○ | 1.0 | Issue C3 でデータアクセスパターン・トランザクション管理の欠落を明確に指摘 |
| P07 | 実装パターン | 軽微 | △ | 0.5 | Issue M1 で SQS/Lambda 指摘、既存 Bull/Redis との比較は条件付き |
| P08 | 設定管理（情報欠落） | 軽微 | ○ | 1.0 | Issue M2 で環境変数命名規則の欠落を指摘 |
| P09 | 実装パターン（ログ出力） | 軽微 | △ | 0.5 | Issue M3 でログフィールド名指摘、既存パターンとの具体的比較なし |

**検出スコア合計**: 7.0

### Bonus Points

| ID | Category | Description | Score |
|----|----------|-------------|-------|
| B-1 | 実装パターン | Issue A1: Repository層実装詳細の欠落（B02 ディレクトリ構造関連） | +0.5 |
| B-2 | ディレクトリ構造 | Issue M1: Directory Structure Not Specified（B02 該当） | +0.5 |

**ボーナス合計**: +1.0 (2件、上限5件)

### Penalty Points

| ID | Category | Description | Score |
|----|----------|-------------|-------|
| P-1 | スコープ外 | Issue API1: RESTful vs Action-based の設計原則（structural-quality スコープ） | -0.5 |
| P-2 | スコープ外 | Issue A2: Service 依存方向の設計原則（structural-quality スコープ） | -0.5 |

**ペナルティ合計**: -1.0 (2件)

### Run 1 Total Score

```
Run1 = 7.0 (検出) + 1.0 (bonus) - 1.0 (penalty) = 7.0
```

---

## Run 2 Detailed Scoring

### Detection Matrix

| Problem ID | Category | Severity | Detection | Score | Notes |
|-----------|----------|----------|-----------|-------|-------|
| P01 | 命名規約（データモデル） | 重大 | × | 0.0 | テーブル名の単数/複数形混在の指摘なし |
| P02 | 命名規約（データモデル） | 重大 | ○ | 1.0 | Issue C1 で mixed case styles 詳細検出 |
| P03 | API設計 | 中 | △ | 0.5 | Issue S1 で既存パターン検証必要と指摘、具体的不一致なし |
| P04 | API設計 | 中 | △ | 0.5 | Issue S2 で複数形エンドポイント指摘、既存単数形との比較なし |
| P05 | 実装パターン（情報欠落） | 重大 | ○ | 1.0 | Issue I2 でエラーハンドリングパターン未定義を指摘 |
| P06 | 実装パターン（情報欠落） | 重大 | ○ | 1.0 | Issue A1+I3 でデータアクセス・トランザクション管理欠落を指摘 |
| P07 | 実装パターン | 軽微 | △ | 0.5 | Issue I4 で非同期処理パターン指摘、既存比較は可能性レベル |
| P08 | 設定管理（情報欠落） | 軽微 | ○ | 1.0 | Issue M2 で環境変数命名規則欠落を指摘 |
| P09 | 実装パターン（ログ出力） | 軽微 | ○ | 1.0 | Issue M3 でログフィールド名（courseId vs user_id 等）の既存パターンとの不一致可能性を指摘 |

**検出スコア合計**: 6.5

### Bonus Points

| ID | Category | Description | Score |
|----|----------|-------------|-------|
| B-1 | ディレクトリ構造 | Issue M1: Directory Structure Not Specified（B02 該当） | +0.5 |
| B-2 | API設計 | Issue API2: データモデル timestamp と API response timestamp の不整合 | +0.5 |
| B-3 | 命名規約（データモデル） | Issue C2: Primary key 命名の不整合（userId vs course_id） | +0.5 |

**ボーナス合計**: +1.5 (3件、上限5件)

### Penalty Points

| ID | Category | Description | Score |
|----|----------|-------------|-------|
| P-1 | スコープ外 | Issue API1: RESTful vs Action-based の設計原則（structural-quality スコープ） | -0.5 |

**ペナルティ合計**: -0.5 (1件)

### Run 2 Total Score

```
Run2 = 6.5 (検出) + 1.5 (bonus) - 0.5 (penalty) = 7.5
```

---

## Statistical Analysis

### Score Distribution

- **Mean (平均)**: (7.0 + 7.5) / 2 = **7.25**
- **Standard Deviation (標準偏差)**: √[((7.0-7.25)² + (7.5-7.25)²) / 2] = √(0.0625 + 0.0625) / 2 = √0.0625 = **0.25**
- **Range (範囲)**: 7.5 - 7.0 = 0.5

### Stability Assessment

| 標準偏差 (SD) | 判定 | 評価 |
|--------------|------|------|
| SD = 0.25 | **高安定** | SD ≤ 0.5 の基準を満たす。結果が非常に信頼できる。 |

---

## Detection Pattern Analysis

### Consistent Detections (両実行で○)

- **P02**: カラム名 snake_case/camelCase 混在（両方とも Issue C1 で詳細検出）
- **P05**: エラーハンドリング実装パターン欠落（Run1: C2, Run2: I2）
- **P06**: データアクセス・トランザクション管理欠落（Run1: C3, Run2: A1+I3）
- **P08**: 環境変数命名規則欠落（両方とも Issue M2）

**安定して検出できた問題**: 4問 / 9問 (44.4%)

### Variance in Detections

- **P03, P04, P07**: 両方とも △（部分検出）で安定
- **P09**: Run1 △ → Run2 ○ に改善（既存パターンとの比較の深さが向上）
- **P01**: 両方とも × 未検出（テーブル名の単数/複数形混在の検出漏れ）

### Bonus/Penalty Variance

- **Run1 ボーナス**: 2件（Repository 実装、ディレクトリ構造）
- **Run2 ボーナス**: 3件（ディレクトリ構造、API timestamp 不整合、Primary key 命名）
- **Run1 ペナルティ**: 2件（API1, A2）
- **Run2 ペナルティ**: 1件（API1）

Run2 の方がより多くの追加問題を検出し、スコープ外指摘が少ない（-0.5 改善）。

---

## Key Findings

### Strengths

1. **Critical issues の検出率が高い**: P02, P05, P06（全て重大度 Critical/重大）は両実行で確実に検出
2. **情報欠落の検出に強い**: P05, P06, P08（全て「情報欠落」タイプ）の検出率 100%
3. **高い安定性**: SD = 0.25 は非常に低く、実行間のばらつきが少ない

### Weaknesses

1. **P01 の未検出**: テーブル名の命名規則（単数/複数形）は両実行とも検出できず
2. **部分検出の多さ**: P03, P04, P07 は両方とも △（既存パターンとの具体的比較が不足）
3. **スコープ外指摘**: API1（RESTful vs Action-based）が両実行で -0.5 ペナルティ

### Recommendations for Improvement

1. **テーブル名の命名規則チェック強化**: 正解キーに「テーブル名が単数形だが既存は複数形」という視点を明示的に追加する必要がある
2. **既存パターン比較の精度向上**: コードベースアクセスがない場合の部分検出を減らすため、「既存パターンが不明な場合は情報欠落として扱う」指針を明確化
3. **スコープ境界の明確化**: RESTful 設計原則の評価が structural-quality と consistency の境界にあることをプロンプトで明示

---

## Conclusion

v004-baseline は **安定した高スコア**（Mean=7.25, SD=0.25）を記録し、特に Critical な実装パターン欠落の検出に優れている。ただし、テーブル名命名規則の検出漏れと、既存パターン比較の深さに改善余地がある。

次回バリアントでは以下の改善が期待される:
- P01 検出率向上（テーブル名命名規則の視点追加）
- 部分検出（△）の減少（既存パターン比較の明確化）
- スコープ外指摘の削減（consistency vs structural-quality の境界明確化）
