以下の手順で実装レビュー結果を統合してください:

## 手順

### 1. レビュー結果の読み込み

以下のファイルを Read で読み込む:
{review_paths}

### 2. 指摘の統合

全レビュー結果から指摘を収集し、統合する:

1. **重複検出**: 同一の問題を複数の観点が指摘している場合、1つにマージする
   - マージ時は最も高い重要度を採用する
   - 検出した観点を全て記録する（例: `[security, quality]`）
2. **重要度でソート**: Critical > Significant > Moderate > Minor の順に整理する
3. **採番**: 各指摘に連番 ID を付与する（CR-001, SG-001, MD-001, MN-001）

### 3. 設計問題の判別

各 Critical/Significant 指摘について、設計自体の問題か実装の問題かを判別する:
- **設計の問題**: 設計仕様自体に矛盾がある、設計で考慮されていないケースがある、API仕様が不整合
- **実装の問題**: 設計仕様どおりに実装されていない、バグ、コーディングミス

指摘ごとに `issue_type: design / implementation` を記録する。

### 4. 全体判定

以下の基準で全体判定を決定する:
- Critical が **1件以上** → `needs_revision`
- Significant が **2件以上** → `needs_revision`
- それ以外 → `pass`

設計の問題が含まれる場合、`has_design_issues: true` を記録する。

### 5. 結果の保存

統合結果を {consolidated_save_path} に Write で保存する:

```markdown
# 実装レビュー統合結果

## 全体判定

verdict: {pass / needs_revision}
has_design_issues: {true / false}
critical: {数}, significant: {数}, moderate: {数}, minor: {数}

## Critical（修正必須）

### {ID}: {指摘タイトル} [{検出観点}]
- **issue_type**: {design / implementation}
- **ファイル**: {ファイルパス:行番号}
- **内容**: {問題の説明}
- **影響**: {具体的な影響}
- **推奨**: {改善案}

（Critical が複数ある場合は繰り返す。なければ「なし」と記載）

## Significant（修正推奨）

（Critical と同じフォーマット。なければ「なし」と記載）

## Moderate

### {ID}: {指摘タイトル} [{検出観点}]
- **ファイル**: {ファイルパス:行番号}
- **内容**: {問題の説明}
- **推奨**: {改善案}

（なければ「なし」と記載）

## Minor

- {ID}: {改善提案} [{検出観点}]

（なければ「なし」と記載）
```

### 6. 返答

以下のフォーマットで返答する:

```
verdict: {pass / needs_revision}
has_design_issues: {true / false}
critical: {Critical の件数}
significant: {Significant の件数}
total: {全指摘数（重複マージ後）}
summary: {統合結果の1行サマリ}
```
