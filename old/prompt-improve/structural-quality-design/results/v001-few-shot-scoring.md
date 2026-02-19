# Scoring Results: v001-few-shot

## Execution Information
- **Prompt**: few-shot
- **Perspective**: structural-quality
- **Target**: design
- **Answer Key**: answer-key-round-001.md
- **Scoring Date**: 2026-02-11

---

## Run 1 Scoring

### Detection Matrix

| Problem ID | Status | Score | Rationale |
|-----------|--------|-------|-----------|
| P01 | ○ | 1.0 | LibraryServiceのSRP違反を明確に指摘し、5つの専任サービスへの分割を提案している（Issue #1） |
| P02 | △ | 0.5 | NotificationServiceの外部依存性について指摘しているが（Issue #5）、LibraryServiceがRepositoryに直接依存する問題への具体的な指摘は弱い |
| P03 | ○ | 1.0 | loansテーブルのuser_name、book_titleが冗長データであることを明示的に指摘し、正規化を推奨（Issue #2） |
| P04 | ○ | 1.0 | 動詞ベースのエンドポイント設計がRESTful原則に反することを指摘し、リソースベースの設計を提案（Issue #6） |
| P05 | ○ | 1.0 | DI設計の欠如、コンストラクタインジェクションの必要性を明示的に指摘（Issue #7） |
| P06 | ○ | 1.0 | エラー分類基準、リカバリー戦略、クライアント通知方法が不明瞭であることを詳細に指摘（Issue #4） |
| P07 | × | 0.0 | APIバージョニング戦略の欠如についての指摘なし |
| P08 | × | 0.0 | 通知機能の変更時の影響範囲について具体的な指摘なし |
| P09 | ○ | 1.0 | 環境別設定の管理範囲が限定的であることを指摘し、設定項目の網羅的管理を提案（Issue #8） |
| P10 | ○ | 1.0 | 個人情報マスキング、構造化ログ、トレーシングの欠如を明示的に指摘（Issue #9） |

**Detection Score**: 8.5/10

### Bonus Points

| ID | Category | Description | Score |
|----|----------|-------------|-------|
| B01 | SOLID原則 | UserServiceと認証処理の重複・循環依存リスクを指摘（Issue #3） | +0.5 |
| B02 | 外部依存 | NotificationServiceがJavaMailSenderに直接依存する問題を指摘（Issue #5） | +0.5 |
| B03 | YAGNI | Redisの過剰な導入可能性を指摘（Issue #9） | +0.5 |
| B04 | テスト設計 | 時刻依存のビジネスロジックのテスト困難性を指摘（Issue #6内） | +0.5 |

**Bonus Count**: 4 × 0.5 = +2.0

### Penalty Points

| ID | Category | Description | Score |
|----|----------|-------------|-------|
| P01 | スコープ外 | Issue #5でサーキットブレーカー等インフラレベルの障害回復パターンに言及 | -0.5 |

**Penalty Count**: 1 × 0.5 = -0.5

### Run 1 Total Score
```
Run 1 Score = 8.5 (detection) + 2.0 (bonus) - 0.5 (penalty) = 10.0
```

---

## Run 2 Scoring

### Detection Matrix

| Problem ID | Status | Score | Rationale |
|-----------|--------|-------|-----------|
| P01 | ○ | 1.0 | LibraryServiceのSRP違反を明確に指摘し、5つの専任サービスへの分割を提案している（Issue #1） |
| P02 | ○ | 1.0 | サービス層がRepositoryに直接依存する問題を指摘し、DIPによる抽象化を提案（Issue #4） |
| P03 | ○ | 1.0 | loansテーブルのuser_name、book_titleが冗長データであることを明示的に指摘し、正規化または履歴テーブル化を推奨（Issue #3） |
| P04 | ○ | 1.0 | 動詞ベースのエンドポイント設計がRESTful原則に反することを指摘し、リソースベースの設計を提案（Issue #7） |
| P05 | ○ | 1.0 | DI設計の欠如、リポジトリインターフェースの明示化、時刻抽象化の必要性を指摘（Issue #6） |
| P06 | ○ | 1.0 | エラー分類基準、リカバリー戦略、部分的失敗の処理が不明瞭であることを詳細に指摘（Issue #5） |
| P07 | × | 0.0 | APIバージョニング戦略の欠如についての指摘なし（Issue #10でモバイル/Web共通化に言及しているがバージョニングには触れていない） |
| P08 | ○ | 1.0 | サービス間の依存関係が不明確で変更影響範囲が予測困難であることを指摘（Issue #8） |
| P09 | ○ | 1.0 | 環境別設定の管理範囲が限定的であることを指摘し、シークレット管理・機能フラグを提案（Issue #11） |
| P10 | ○ | 1.0 | 構造化ログ、分散トレーシング、個人情報マスキング戦略の欠如を指摘（Issue #12） |

**Detection Score**: 9.0/10

### Bonus Points

| ID | Category | Description | Score |
|----|----------|-------------|-------|
| B01 | SOLID原則 | 認証処理がLibraryServiceとUserServiceに重複していることを指摘（Issue #2） | +0.5 |
| B02 | 外部依存 | NotificationServiceがJavaMailSenderに直接依存する問題を指摘（Issue #4） | +0.5 |
| B03 | YAGNI | Redisの過剰な導入可能性をYAGNI違反として指摘（Issue #9） | +0.5 |
| B04 | インターフェース契約 | モバイルとWebのAPI共通化戦略の欠如を指摘（Issue #10） | +0.5 |
| B05 | テスト設計 | 時刻依存のビジネスロジックのテスト困難性を指摘（Issue #6） | +0.5 |

**Bonus Count**: 5 × 0.5 = +2.5

### Penalty Points

| ID | Category | Description | Score |
|----|----------|-------------|-------|
| P01 | スコープ外 | Issue #5でサーキットブレーカー等インフラレベルの障害回復パターンに言及 | -0.5 |

**Penalty Count**: 1 × 0.5 = -0.5

### Run 2 Total Score
```
Run 2 Score = 9.0 (detection) + 2.5 (bonus) - 0.5 (penalty) = 11.0
```

---

## Summary Statistics

| Metric | Value |
|--------|-------|
| Run 1 Score | 10.0 |
| Run 2 Score | 11.0 |
| Mean Score | 10.5 |
| Standard Deviation | 0.5 |
| Stability | 高安定 (SD ≤ 0.5) |

### Analysis
- **検出精度**: Run 1で8.5/10、Run 2で9.0/10の高い検出率
- **安定性**: SD=0.5で高安定。結果が信頼できる
- **未検出問題**: P07（APIバージョニング戦略の欠如）が両Runで未検出
- **ボーナス傾向**: SOLID原則違反、YAGNI違反、外部依存の抽象化不足を複数検出
- **ペナルティ**: 両Runで同じペナルティ（サーキットブレーカー言及）

### 推奨判定への影響
- 平均スコア10.5は非常に高く、few-shotプロンプトが効果的に機能している
- 高安定性（SD=0.5）により、結果の信頼性が高い
- ベースラインとの比較により推奨プロンプトを判定可能
