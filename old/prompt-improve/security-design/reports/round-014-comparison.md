# Round 014 Comparison Report

## Executive Summary

**Test Date**: 2026-02-10
**Test Document**: 企業文書管理システム (Round 12-14 同一文書)
**Variants Tested**: baseline, hierarchical-table, adversarial-scoped

---

## Test Conditions

### Variants

| Variant | Variation ID | Description |
|---------|--------------|-------------|
| **baseline** | - | S6c (free-table-hybrid) を含む現行プロンプト |
| **hierarchical-table** | V014-hierarchical-table | 階層化されたテーブル構造によるインフラコンポーネント評価の明示化 |
| **adversarial-scoped** | V014-adversarial-scoped | 攻撃者視点STRIDE分析に範囲制約を追加（既存仕様のみ検証） |

### Test Document Coverage

**主要問題カテゴリ**: 認証・認可設計、データ保護、入力検証設計、監査ログ設計、インフラ・依存関係

**埋め込み問題 (9件)**:
- P01: JWTトークン有効期限が24時間と長すぎる
- P02: パスワードリセットトークンの仕様不明確
- P03: 注文ステータス更新APIの認可設計不足
- P04: 決済APIの冪等性保証欠如
- P05: カード情報のPCI DSS違反リスク
- P06: 配達先住所の入力検証とインジェクション対策欠如
- P07: APIレート制限の仕様不明確
- P08: ログの機密情報マスキング欠如
- P09: S3バケットのアクセス制御未定義

**ボーナス問題 (8件)**: B01-B08（MFA、監査ログ、暗号化、IDOR、ファイルアップロード検証、CSRF、依存関係管理、JWT storage mechanism）

---

## Problem Detection Matrix

| Problem ID | Category | baseline (Run1/Run2) | hierarchical-table (Run1/Run2) | adversarial-scoped (Run1/Run2) |
|------------|----------|----------------------|--------------------------------|-------------------------------|
| **P01** | 認証設計 | ○/△ | ×/× | ×/× |
| **P02** | 認証設計 | ×/× | ×/× | ×/× |
| **P03** | 認可設計 | ○/○ | ○/○ | ○/○ |
| **P04** | 入力検証設計 | ○/○ | ○/○ | ×/× |
| **P05** | データ保護 | ×/× | △/○ | ○/○ |
| **P06** | 入力検証設計 | △/△ | △/△ | △/△ |
| **P07** | 脅威モデリング | ○/○ | ○/○ | ○/○ |
| **P08** | データ保護 | △/△ | ○/○ | ○/○ |
| **P09** | インフラ・依存関係 | ○/○ | ○/○ | ○/○ |

### Detection Score Summary

| Variant | Run1 Detection | Run2 Detection | Mean Detection |
|---------|----------------|----------------|----------------|
| baseline | 7.5 | 6.5 | 7.0 |
| hierarchical-table | 6.0 | 7.5 | 6.75 |
| adversarial-scoped | 5.5 | 5.5 | 5.5 |

---

## Bonus/Penalty Details

### Bonus Detection Summary

| Variant | Run1 Bonus | Run2 Bonus | Total Bonus (capped) |
|---------|------------|------------|----------------------|
| baseline | 7件 → 2.5pt | 7件 → 2.5pt | 2.5pt |
| hierarchical-table | 5件 → 2.5pt | 5件 → 2.5pt | 2.5pt |
| adversarial-scoped | 5件 → 2.5pt | 5件 → 2.5pt | 2.5pt |

**baseline ボーナス内訳**: B02 (監査ログ), B03 (RDS暗号化), B04 (Redis暗号化), B05 (IDOR), B06 (ファイルアップロード), B07 (CSRF), B08 (依存関係管理)

**hierarchical-table ボーナス内訳**: JWT storage mechanism, Secret management, B02 (監査ログ), B07 (CSRF), B05 (IDOR)

**adversarial-scoped ボーナス内訳**: B05 (IDOR), JWT storage mechanism (XSS-based token theft), B03 (RDS暗号化), B04 (Redis暗号化), B02 (監査ログ)

### Penalty Assessment

**全バリアント**: ペナルティなし（スコープ外指摘なし）

---

## Score Summary

| Variant | Run1 | Run2 | Mean | SD | Stability |
|---------|------|------|------|-----|-----------|
| **baseline** | 10.0 | 9.0 | **9.5** | 0.5 | 高安定 |
| **hierarchical-table** | 8.5 | 10.0 | **9.25** | 0.75 | 中安定 |
| **adversarial-scoped** | 8.0 | 8.0 | **8.0** | 0.0 | 高安定 |

### Score Differences vs Baseline

| Variant | Δ vs baseline | Judgment |
|---------|---------------|----------|
| hierarchical-table | -0.25pt | 有意差なし (< 0.5pt) |
| adversarial-scoped | -1.5pt | baseline推奨 (> 1.0pt差) |

---

## Recommendation

### Recommended Prompt

**baseline** (変更なし)

### Rationale

1. **hierarchical-table**: 平均スコア差 -0.25pt（9.5 → 9.25）は閾値 < 0.5pt のため有意差なし（scoring-rubric.md Section 5）
2. **adversarial-scoped**: 平均スコア差 -1.5pt（9.5 → 8.0）は閾値 > 1.0pt のため、baselineを推奨

### Convergence Assessment

**判定**: 継続推奨

- **Round 13**: baseline=11.0 → weighted-scoring=8.5 (-2.5pt), adversarial-perspective=9.0 (-2.0pt)
- **Round 14**: baseline=9.5 → hierarchical-table=9.25 (-0.25pt), adversarial-scoped=8.0 (-1.5pt)

2ラウンド連続で改善幅 < 0.5pt には該当しない。adversarial-scopedは-1.5ptの退化を示すため、収束判定は時期尚早。

---

## Detailed Analysis

### Key Findings by Variant

#### baseline の強み

1. **広範なボーナス検出**: 7件のボーナス問題を両Run共通で検出（B02-B08）
2. **P04完全検出**: 決済APIの冪等性保証欠如を両Runで安定検出（○/○）
3. **P01安定検出**: JWTトークン有効期限問題をRun1で完全検出（○）、Run2で部分検出（△）
4. **最高平均スコア**: 9.5pt（SD=0.5, 高安定）

#### baseline の弱み

1. **P05未検出**: PCI DSS準拠・トークン化戦略の欠如を両Runで見落とし（×/×）
2. **P02未検出**: パスワードリセットトークン仕様の不明確さを両Runで見落とし（×/×）
3. **P08部分検出**: ログのPIIマスキング欠如を指摘するが、リクエストボディ記録の核心的リスクを明示せず（△/△）

#### hierarchical-table の強み

1. **P05検出改善**: Run2でPCI DSS準拠・トークン化戦略の欠如を完全検出（△ → ○）、Run1では部分検出（△）
2. **P08完全検出**: ログの機密情報マスキング欠如を両Runで完全検出（○/○）
3. **階層的テーブル構造**: Infrastructure Security Assessmentテーブルでインフラコンポーネント（RDS, Redis, S3, API Gateway, Secrets管理）を体系的にカバー

#### hierarchical-table の弱み

1. **P01未検出**: JWTトークン有効期限24時間の問題を両Runで見落とし（×/×）。JWT storage mechanismの指摘はあるが有効期限には触れず
2. **P04未検出**: 決済APIの冪等性保証欠如を両Runで見落とし（×/×）。baseline（○/○）から退化
3. **検出不安定性**: Run1=8.5, Run2=10.0（SD=0.75, 中安定）。P05検出差（△ → ○）が主要因

#### adversarial-scoped の強み

1. **完璧な安定性**: SD=0.0（両Run完全同一スコア8.0）
2. **P05完全検出**: PCI DSS準拠・トークン化戦略の欠如を両Runで完全検出（○/○）
3. **認可設計の強み**: P03（注文ステータス更新の認可不足）を攻撃シナリオベースで詳細分析
4. **IDOR検出**: B05（オブジェクトレベル認可欠如）をボーナス問題として両Runで検出

#### adversarial-scoped の弱み

1. **P01未検出**: JWTトークン有効期限24時間をRun2で肯定的に評価（"24-hour token expiration limits stolen token lifetime"）。長すぎることを指摘せず
2. **P02未検出**: パスワードリセットトークン仕様の不明確さを両Runで見落とし
3. **P04未検出**: 決済APIの冪等性保証欠如を両Runで見落とし（×/×）。baseline（○/○）から退化
4. **検出スコア低下**: 平均検出5.5pt（baseline 7.0pt, hierarchical-table 6.75ptに劣る）

---

## Independent Variable Effects Analysis

### 1. 階層的テーブル構造の効果 (hierarchical-table)

**変更内容**: Infrastructure Security Assessmentテーブルにより、各インフラコンポーネント（RDS, Redis, S3, API Gateway, Secrets）×評価軸（認証、暗号化、アクセス制御、監視）のマトリクスを明示化

**効果**:
- **P05検出改善**: PCI DSS準拠の欠如をRun2で完全検出（△ → ○）、+0.5pt
- **P08検出改善**: ログのPIIマスキング欠如を両Runで完全検出（△ → ○）、+1.0pt
- **P01/P04退化**: JWTトークン有効期限（○ → ×）、決済API冪等性（○ → ×）で-2.5pt
- **ボーナス検出維持**: 5件（上限）のボーナス問題を検出、ただしB06 (ファイルアップロード)、B08 (依存関係管理) が脱落

**トレードオフ**: インフラコンポーネント体系的カバレッジ向上（P05/P08）vs 認証・API設計の注意低下（P01/P04）

**知見**:
- テーブル構造の明示化は、該当カテゴリの検出を改善するが、注意バジェット制約により他カテゴリの検出が低下する可能性
- Round 8 table-centric (+2.5pt, SD=0.0) の効果がRound 14 hierarchical-table (-0.25pt, SD=0.75) で再現せず。テーブル構造の効果は問題セット依存

### 2. 攻撃者視点STRIDE分析+範囲制約の効果 (adversarial-scoped)

**変更内容**: 攻撃者視点でSTRIDE分析を実施し、設計文書に明示された情報のみを検証対象とする範囲制約を追加（推測分析を制限）

**効果**:
- **P05完全検出**: PCI DSS準拠の欠如を両Runで完全検出（× → ○）、+2.0pt
- **P08完全検出**: ログのPIIマスキング欠如を両Runで完全検出（△ → ○）、+1.0pt
- **P01/P04退化**: JWTトークン有効期限（○/△ → ×/×）、決済API冪等性（○/○ → ×/×）で-3.25pt
- **完璧な安定性**: SD=0.0（両Run完全同一スコア）

**トレードオフ**: データ保護問題の完全検出（P05/P08）vs 認証・API設計の検出低下（P01/P04）、完璧な安定性 vs 検出スコア低下

**知見**:
- 攻撃者視点はデータ保護の問題検出を改善するが、認証・API設計の注意を低下させる
- 範囲制約により推測分析ペナルティは回避されたが、検出スコア全体が低下（Round 13 adversarial-perspective 9.0pt → Round 14 adversarial-scoped 8.0pt）
- SD=0.0の完璧な安定性は、決定論的な検出パターンを示すが、上昇余地が限定的

### 3. ボーナス検出パターンの比較

| Variant | B02 | B03 | B04 | B05 | B06 | B07 | B08 | JWT storage | Secret mgmt | Total (capped) |
|---------|-----|-----|-----|-----|-----|-----|-----|-------------|-------------|----------------|
| baseline | ○ | ○ | ○ | ○ | ○ | ○ | ○ | - | - | 7件 → 2.5pt |
| hierarchical-table | ○ | - | - | ○ | - | ○ | - | ○ | ○ | 5件 → 2.5pt |
| adversarial-scoped | ○ | ○ | ○ | ○ | - | - | - | ○ | - | 5件 → 2.5pt |

**知見**:
- baselineは最も広範なボーナス検出（7件）を達成
- hierarchical-tableはインフラ暗号化（B03/B04）を検出せず、代わりにJWT storage/Secret mgmtを検出
- adversarial-scopedはCSRF（B07）、ファイルアップロード（B06）を検出せず、データ保護に集中

---

## Insights for Next Round

### 1. P04 (決済API冪等性) 検出の課題

**問題**: hierarchical-table と adversarial-scoped は P04 を両Runで未検出（baseline は ○/○）

**仮説**:
- テーブル構造や攻撃者視点は、インフラ/データ保護に注意を集中させ、API設計の冪等性要件を見落とす
- 冪等性は STRIDE の Tampering/Replay Attack に該当するが、明示的なチェックポイントがないと検出困難

**次回候補**:
- 冪等性チェックポイントの明示的追加（S5c: idempotency-checks のアプローチ）
- ただし、Round 5 では視野狭窄リスク（P02で-1.0pt）が観測されており、バランスが重要

### 2. P01 (JWTトークン有効期限) 検出の不安定性

**問題**: baseline Run1=○, Run2=△、hierarchical-table/adversarial-scoped は両Run ×

**仮説**:
- JWTトークン有効期限は認証設計の詳細要件であり、より広範な認証・認可問題（IDOR, JWT storage, CSRF等）に注意が向くと見落とされる
- adversarial-scoped Run2 では "24-hour token expiration limits stolen token lifetime" と肯定的に評価（長すぎることを指摘せず）

**次回候補**:
- 認証設計チェックポイントにトークン有効期限の適切性を明示
- ただし、明示的チェックの視野狭窄リスク（Round 11 log-masking-explicit -1.5pt）に注意

### 3. 安定性とスコア上限のトレードオフ

**観測**:
- baseline: Mean=9.5pt, SD=0.5 (高安定)
- hierarchical-table: Mean=9.25pt, SD=0.75 (中安定)
- adversarial-scoped: Mean=8.0pt, SD=0.0 (完璧な安定性)

**知見**:
- SD=0.0の完璧な安定性（adversarial-scoped）は、決定論的な検出パターンを示すが、検出スコアは最低（8.0pt）
- SD=0.5の中程度変動（baseline）は、ボーナス検出varianceに起因し、最高スコア（9.5pt）を達成
- 完璧な安定性は「限定的上昇余地」を示す可能性（知見#21）

**次回候補**:
- SD=0.5-1.0の適度な変動を許容し、ボーナス検出の多様性を維持
- 決定論的な検出パターン（SD=0.0）を追求するのではなく、高天井パフォーマンス（高平均スコア）を優先

### 4. 明示的チェックポイントの最適量

**観測**:
- Round 5 missing-detection (3-4領域): +2.5pt, SD=0.0（視野狭窄リスク限定的）
- Round 11 log-masking-explicit (単一領域): -1.5pt（ボーナス-5.0pt、横断的要件崩壊）
- Round 14 hierarchical-table (テーブル構造でインフラ明示): -0.25pt（P01/P04退化）

**知見**:
- 3-4領域までの明示的チェックは効果的（知見#5）
- 単一領域や過度な構造化は視野狭窄リスク（知見#6, #20）
- テーブル構造のインフラ明示化は、該当領域の検出改善（P05/P08）と他領域の注意低下（P01/P04）のトレードオフ

**次回候補**:
- 複数領域（認証設計・API設計・データ保護）を横断する3-4個のチェックポイントを追加
- 単一領域への過度な詳細化を避ける

---

## Conclusion

**Round 014 の結果**:
- **hierarchical-table**: 有意差なし（-0.25pt < 0.5pt閾値）。P05/P08検出改善（+1.5pt）とP01/P04退化（-2.5pt）のトレードオフ
- **adversarial-scoped**: baseline推奨（-1.5pt > 1.0pt閾値）。完璧な安定性（SD=0.0）だが検出スコア最低（8.0pt）

**推奨アクション**:
- baseline (S6c: free-table-hybrid) を維持
- 次回は P04 (冪等性) と P01 (JWTトークン有効期限) の検出改善を目指し、3-4領域の明示的チェックポイントを追加したバリアントを試験

**収束判定**: 継続推奨（2ラウンド連続で改善幅 < 0.5pt に該当せず）
