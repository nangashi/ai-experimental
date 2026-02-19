# Round 001 Comparison Report: agents/security-design-reviewer

Generated: 2026-02-18

---

## スコア比較テーブル

| Prompt | Mean | SD | cross_doc_gap | adjusted_diff |
|--------|------|----|---------------|---------------|
| v001-baseline (current best) | 11.125 | 0.41 | 0.25 | — |
| v002-input-validation-stable | 10.625 | 0.74 | 1.25 | -0.50 |
| v002-data-protection-tde-limits | 11.375 | 0.82 | 1.25 | +0.25 |

スコア内訳:
- v002-input-validation-stable: doc1=(Run1=11.5, Run2=11.0, mean=11.25) / doc2=(Run1=9.5, Run2=10.5, mean=10.00)
- v002-data-protection-tde-limits: doc1=(Run1=10.0, Run2=11.5, mean=10.75) / doc2=(Run1=12.0, Run2=12.0, mean=12.00)

---

## カテゴリ別検出率比較マトリクス

| Category | v001-baseline | v002-input-validation-stable | v002-data-protection-tde-limits |
|----------|---------------|-----------------------------|---------------------------------|
| 認証・認可設計 | 1.000 | 0.938 (-0.063) | 0.875 (-0.125) |
| データ保護 | 0.875 | 1.000 (+0.125) | 1.000 (+0.125) |
| 入力検証・攻撃防御 | 0.800 | 1.000 (+0.200) | 0.800 (±0.000) |
| 脅威モデリング | 1.000 | 1.000 (±0.000) | 1.000 (±0.000) |
| インフラ・依存関係・監査 | 1.000 | 1.000 (±0.000) | 0.900 (-0.100) |

回帰判定（閾値: -0.15以上の低下）: 両バリアントとも回帰なし

### カテゴリ別検出率の計算詳細

**v002-input-validation-stable:**
- 認証・認可設計: doc1=(○4/△0, 2q×2runs=4) 4/4=1.00, doc2=(○3/△1, 2q×2runs=4) 3.5/4=0.875 → combined 7.5/8 = **0.938**
- データ保護: doc1=4/4=1.00, doc2=4/4=1.00 → combined 8/8 = **1.000**
- 入力検証・攻撃防御: doc1=(○6, 3q×2runs=6) 6/6=1.00, doc2=(○4, 2q×2runs=4) 4/4=1.00 → combined 10/10 = **1.000**
- 脅威モデリング: doc1=2/2=1.00, doc2=2/2=1.00 → combined 4/4 = **1.000**
- インフラ・依存関係・監査: doc1=(○4, 2q×2runs=4) 4/4=1.00, doc2=(○6, 3q×2runs=6) 6/6=1.00 → combined 10/10 = **1.000**

**v002-data-protection-tde-limits:**
- 認証・認可設計: doc1=4/4=1.00, doc2=(P01=○○, P03=△△ → ○2/△2, 2q×2runs=4) 3/4=0.75 → combined 7/8 = **0.875**
- データ保護: doc1=4/4=1.00, doc2=4/4=1.00 → combined 8/8 = **1.000**
- 入力検証・攻撃防御: doc1=(○6, 3q×2runs=6) 6/6=1.00, doc2=(P04=××, P05=○○ → ○2/×2, 2q×2runs=4) 2/4=0.50 → combined 8/10 = **0.800**
- 脅威モデリング: doc1=2/2=1.00, doc2=2/2=1.00 → combined 4/4 = **1.000**
- インフラ・依存関係・監査: doc1=(P08=×○, P10=○○ → ○3/×1, 2q×2runs=4) 3/4=0.75, doc2=(○6, 3q×2runs=6) 6/6=1.00 → combined 9/10 = **0.900**

---

## バリアント別分析

### v002-input-validation-stable

**変更内容と期待効果:**
- Change: Add frontend-validation-dependency and JWT-only-CSRF detection criteria to Input Validation section
- Target: 入力検証・攻撃防御
- Rationale: Doc1-P09（フロントエンド検証依存、識別力高）とDoc2-P04（JWT単独CSRF対策、識別力中）が不安定検出。具体的な設計欠陥パターンをチェックリストに追加することで評価の足場を与え安定性を向上させる意図。
- Predicted-regression: none

**実績スコアとカテゴリ別変化:**
- Mean=10.625 (SD=0.74), vs current-best -0.50pt
- 入力検証・攻撃防御: 0.80 → 1.00 (+0.20) — ターゲットカテゴリで期待通りの改善
- データ保護: 0.875 → 1.00 (+0.125) — 副次的改善
- 認証・認可設計: 1.00 → 0.938 (-0.063) — 軽微な低下（回帰閾値未満）

**回帰予測 vs 実際:**
- 予測: none
- 実際: 回帰なし（全カテゴリで0.15未満の低下）
- 予測と実績は一致

**cross_doc_gap評価:**
- 1.25pt（ベースライン0.25ptから大幅拡大）
- doc1=11.25 vs doc2=10.00。doc2のRun1=9.5が特に低く、doc2の認証・認可設計P03（部分検出）が影響。
- cross_doc_gapの拡大は汎化性能の低下を示唆する。doc2での性能が不安定で文書特性への感度が増している可能性がある。
- 入力検証の強化によってdoc1では一貫して恩恵を受けたが、doc2では認証P03の部分検出問題が相殺された形。

**総合評価:**
- ターゲットカテゴリの改善は達成できたが、doc2でのスコア低下によってoverall_meanがベースラインを下回った。改善の効果がdoc1に偏在しており、cross_doc_gapが拡大した。

---

### v002-data-protection-tde-limits

**変更内容と期待効果:**
- Change: Add transparent encryption (TDE/disk-level) limitation assessment and field-level PII encryption criteria to Data Protection section
- Target: データ保護
- Rationale: Doc2-P07（RDS TDEのみで十分とする設計、識別力高）が不安定検出（Run1×/Run2○）。TDE/透過的暗号化の保護範囲の限界とフィールドレベル暗号化の必要性を評価フレームとして明示することで検出を安定化させる意図。
- Predicted-regression: none

**実績スコアとカテゴリ別変化:**
- Mean=11.375 (SD=0.82), vs current-best +0.25pt
- データ保護: 0.875 → 1.00 (+0.125) — ターゲットカテゴリで期待通りの改善
- 脅威モデリング: 変化なし
- 認証・認可設計: 1.00 → 0.875 (-0.125) — 軽微な低下（回帰閾値未満）、doc2-P03が両Runで△
- インフラ・依存関係・監査: 1.00 → 0.90 (-0.10) — doc1-P08のRun1未検出が影響（回帰閾値未満）
- 入力検証・攻撃防御: 0.80 → 0.80 (±0) — doc2-P04が両Runで×（ベースライン同率だが問題パターンが安定して固定された）

**回帰予測 vs 実際:**
- 予測: none
- 実際: 回帰なし（全カテゴリで0.15未満の低下）
- 予測と実績は一致

**cross_doc_gap評価:**
- 1.25pt（ベースライン0.25ptから大幅拡大）
- doc1=10.75 vs doc2=12.00。doc2が高得点でボーナスを5件/Run獲得している一方、doc1はP08未検出の影響でdoc1_meanが低い。
- cross_doc_gapの拡大はdoc2のボーナス過多による高得点に起因しており、主問題の検出能力の不均一さではなく文書特性の違いが主因の可能性がある。
- ただし、doc1のインフラカテゴリの安定性低下（P08のRun1未検出）は懸念材料。

**総合評価:**
- overall_meanはベースラインを+0.25pt上回ったが、幅が小さくadjusted_diff<0.5のため推奨基準を満たさない。データ保護の安定化は達成できたが、doc2のボーナスに依存したスコア構造は過学習リスクを内包する。

---

## リスク評価

### 過学習リスク

| バリアント | リスク | 根拠 |
|-----------|--------|------|
| v002-input-validation-stable | 低〜中 | ターゲット改善は達成したが、追加したAnti-Patternsの記述が汎用的であり特定文書への過適合は少ない |
| v002-data-protection-tde-limits | 中 | doc2のボーナス5件/Runは高く、TDE限界評価の強化がdoc2特有の問題（RDS/ECシステム）に過剰に適合している可能性がある。doc1での恩恵が限定的な点もリスク要因 |

### 注意分散リスク

| バリアント | リスク | 根拠 |
|-----------|--------|------|
| v002-input-validation-stable | 低 | Anti-Patternsセクションは入力検証の補足として適切な位置に配置。他カテゴリへの干渉は軽微 |
| v002-data-protection-tde-limits | 低〜中 | Encryption Depth Assessmentの追加はデータ保護セクションを拡張したが、評価者が暗号化レイヤー分析に注意を割きすぎてインフラカテゴリの他問題（P08）への集中が薄れた可能性がある |

### 回帰リスク

| バリアント | リスク | 根拠 |
|-----------|--------|------|
| v002-input-validation-stable | 低 | 全カテゴリで回帰閾値（0.15）を下回る。認証・認可設計の軽微な低下（-0.063）は許容範囲内 |
| v002-data-protection-tde-limits | 低〜中 | 回帰閾値未満だが、認証・認可設計(-0.125)、インフラ(-0.10)の両カテゴリで低下が観測されており、次ラウンドで改善が続かない場合に閾値超過の可能性がある |

---

## 推奨判定

### 判定プロセス（scoring-rubric.md 推奨判定基準に基づく）

| バリアント | raw_mean_diff | 回帰数 | adjusted_diff | 判定条件 |
|-----------|--------------|--------|---------------|---------|
| v002-input-validation-stable | -0.500 | 0 | -0.500 | adjusted_diff < 0.5 → 現在ベストを推奨 |
| v002-data-protection-tde-limits | +0.250 | 0 | +0.250 | adjusted_diff < 0.5 → 現在ベストを推奨 |

両バリアントともadjusted_diff < 0.5ptのため、推奨判定基準に従いv001-baselineを推奨とする。

---

## 考察

### ターゲットカテゴリの改善効果

両バリアントはそれぞれのターゲットカテゴリで改善を達成した。

- v002-input-validation-stable: 入力検証・攻撃防御 0.80→1.00(+0.20) — ベースラインのエラー分析が特定していたDoc1-P09、Doc2-P04の問題をいずれも解消
- v002-data-protection-tde-limits: データ保護 0.875→1.00(+0.125) — ベースラインのエラー分析が特定していたDoc2-P07の不安定検出を安定化

ターゲット問題の解消という意味では両バリアントとも設計意図どおりに機能した。

### スコアが伸びなかった要因

v002-input-validation-stable の overall_mean がベースラインを下回った主因はdoc2での性能低下（mean=10.00 vs ベースライン推計11.0相当）である。doc2-P03（認証・認可設計）のRun1△は入力検証強化とは直接関係ないが、プロンプト変更後に評価リソース配分が変化した可能性がある。cross_doc_gapの拡大（0.25→1.25）は特定文書への過依存の可能性を示唆する。

v002-data-protection-tde-limits の+0.25ptの改善はdoc2のボーナス獲得（5件×0.5=2.5pt/run）に依存しており、主問題の検出改善（+0.125）だけでは改善幅は小さい。ボーナス依存のスコア構造は次ラウンドでの再現性に不確実性をもたらす。

### 次ラウンドの改善方向

ベースラインに残る未解決問題は:

1. **認証・認可設計（ヘッダー注入/バイパス経路）**: doc2-P03（両バリアントで△または△△）— 信頼境界の検証方針（ゲートウェイ依存リスク）を評価するフレームが両バリアントとも不十分。「外部から内部サービスへの直接アクセス経路の設計的保証」を評価軸として追加する方向が有効。

2. **入力検証・攻撃防御（CSRF設計批判的評価）**: doc2-P04（v002-data-protection-tde-limits で両Run×に固定化）— JWT単独CSRF対策への批判的評価はv002-input-validation-stableのAnti-Patternsで対応済みだが、v002-data-protection-tde-limits（ベースラインベース）では依然として未解決。次ラウンドでのバリアントは入力検証強化を継承した上でヘッダー注入問題に対処する方向を検討すべき。

3. **インフラ・依存関係・監査（監査ログ粒度）**: doc1-P08（v002-data-protection-tde-limits のRun1で×）— セキュリティイベント専用ログと一般ログの区別を評価する観点。ベースラインでは安定して検出できていたが、TDE強化後に注意が分散した可能性がある。

---

## 推奨

```
## バリアント別分析

### v002-input-validation-stable
- 変更内容: 入力検証セクションにフロントエンド検証依存とJWT単独CSRFのAnti-Patternsを追加
- 実績: Mean=10.625 (SD=0.74), vs current-best -0.50pt
- カテゴリ変化: 入力検証・攻撃防御 +0.200, データ保護 +0.125, 認証・認可設計 -0.063
- 回帰予測: none → 実際: 回帰なし
- cross_doc_gap: 1.25pt（ベースライン比 +1.00pt）

### v002-data-protection-tde-limits
- 変更内容: データ保護セクションにTDE/透過的暗号化の限界とフィールドレベル暗号化評価基準を追加
- 実績: Mean=11.375 (SD=0.82), vs current-best +0.25pt
- カテゴリ変化: データ保護 +0.125, 認証・認可設計 -0.125, インフラ・依存関係・監査 -0.100
- 回帰予測: none → 実際: 回帰なし
- cross_doc_gap: 1.25pt（ベースライン比 +1.00pt、doc2ボーナス過多に起因）

## 推奨
- recommended: v001-baseline
- reason: 両バリアントともadjusted_diff < 0.5ptのため推奨判定基準により現在ベストを維持。v002-input-validation-stable はadjusted_diff=-0.50ptでベースライン未達。v002-data-protection-tde-limits はadjusted_diff=+0.25ptと改善傾向を示すが改善幅が閾値に到達していない（いずれも回帰なし）。
- adjusted_diff: v002-input-validation-stable=-0.50pt, v002-data-protection-tde-limits=+0.25pt
- convergence: 継続推奨（Round 1のみのため3ラウンド連続判定基準は未達）
- scores: current-best(v001-baseline)=11.125(SD=0.41), v002-input-validation-stable=10.625(SD=0.74), v002-data-protection-tde-limits=11.375(SD=0.82)
```
