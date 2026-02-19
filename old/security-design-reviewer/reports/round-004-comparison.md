# Round 004 Comparison Report: security-design-reviewer

## スコア比較テーブル

| Prompt | Mean | SD | cross_doc_gap | vs current-best |
|--------|------|----|---------------|-----------------|
| current-best (v004-input-finding-separation) | 11.625 | 0.41 | 0.25 | — |
| v005-audit-log-finding-separation | 11.50 | 0.354 | 0.50 | -0.125pt |
| v005-cors-bypass-output | 11.125 | 0.217 | 0.25 | -0.500pt |

### スコア詳細（run別）

| Prompt | doc1_run1 | doc1_run2 | doc1_mean | doc2_run1 | doc2_run2 | doc2_mean |
|--------|-----------|-----------|-----------|-----------|-----------|-----------|
| v005-audit-log-finding-separation | 11.0 | 11.5 | 11.25 | 11.5 | 12.0 | 11.75 |
| v005-cors-bypass-output | 11.0 | 11.0 | 11.00 | 11.0 | 11.5 | 11.25 |

---

## カテゴリ別検出率比較マトリクス

カテゴリ検出率: `(Σ○ + 0.5×Σ△) / (category_questions × total_runs)` (2文書合算)

| Category | current-best | v005-audit-log-finding-separation | v005-cors-bypass-output |
|----------|-------------|-----------------------------------|------------------------|
| 認証・認可設計 | 1.000 | 0.938 | 1.000 |
| データ保護 | 1.000 | 1.000 | 1.000 |
| 入力検証・攻撃防御 | 0.900 | 0.800 | 1.000 |
| 脅威モデリング | 1.000 | 1.000 | 1.000 |
| インフラ・依存関係・監査 | 0.900 | 0.950 | 0.950 |

回帰判定（現在ベストから 0.15 以上低下）:
- v005-audit-log-finding-separation: 全カテゴリ回帰なし（認証・認可設計は -0.062、入力検証・攻撃防御は -0.100 でいずれも閾値未満）
- v005-cors-bypass-output: 全カテゴリ回帰なし

カテゴリ変化の注目点:
- v005-audit-log-finding-separation: インフラ・依存関係・監査 +0.050（Doc1-P08 が△→○ へ改善）、入力検証・攻撃防御 -0.100（Doc2-P04,P05,P03 が不安定化）
- v005-cors-bypass-output: 入力検証・攻撃防御 +0.100（Doc2-P04,P05 が完全検出）、インフラ・依存関係・監査 +0.050

---

## バリアント別分析

### v005-audit-log-finding-separation

- 変更内容: Output Guidelinesに「不十分な監査ログ設計を肯定評価と混在させず独立Findingとして報告する」指示（Audit Log Gap Separation ルール）を追加
- ターゲット: インフラ・依存関係・監査
- 実績: Mean=11.50(SD=0.354), vs current-best -0.125pt
- カテゴリ変化:
  - インフラ・依存関係・監査: 0.900 → 0.950 (+0.050) — Doc1-P08（△安定部分検出）が両Runで○に改善
  - 入力検証・攻撃防御: 0.900 → 0.800 (-0.100) — Doc2-P04（CSRF: Run1で×）、Doc2-P05（CORS正規表現: 両Runで△）が残存
  - 認証・認可設計: 1.000 → 0.938 (-0.062) — Doc2-P03（Run2で△）が発生
- 回帰予測: none → 実際: 回帰なし（最大低下 -0.100 < 閾値 0.15）
- cross_doc_gap: 0.50pt（Doc1 mean=11.25 vs Doc2 mean=11.75 で doc2 が優勢）
- adjusted_diff: -0.125 - 1.5×0 = **-0.125pt**

**評価**: Audit Log Gap Separation ルールの追加は、ターゲットのインフラ・依存関係・監査カテゴリに対して期待通りの効果（Doc1-P08 の△→○）を発揮した。しかし、Output Guidelinesへの追加指示がDoc2において入力検証・攻撃防御カテゴリのCSRF検出を不安定化させた可能性がある。cross_doc_gap=0.50ptはcurrent-best(0.25pt)の2倍であり、Doc1への特化の傾向が見られる。全体スコアはcurrent-bestを下回り、推奨基準を満たさない。

---

### v005-cors-bypass-output

- 変更内容: Output Guidelinesに「CORS設定が明示されている場合、具体的なバイパス可能性（ワイルドカード・正規表現の危険パターン）を評価した結果を報告する」指示（CORS Configuration Bypass Analysis ルール）を追加
- ターゲット: 入力検証・攻撃防御
- 実績: Mean=11.125(SD=0.217), vs current-best -0.500pt
- カテゴリ変化:
  - 入力検証・攻撃防御: 0.900 → 1.000 (+0.100) — Doc2-P04（CSRF）、Doc2-P05（CORS正規表現バイパス）が両Runで完全検出
  - インフラ・依存関係・監査: 0.900 → 0.950 (+0.050)
  - 認証・認可設計: 1.000 → 1.000 (変化なし)
  - データ保護: 1.000 → 1.000 (変化なし)
  - 脅威モデリング: 1.000 → 1.000 (変化なし)
- 回帰予測: none → 実際: 回帰なし
- cross_doc_gap: 0.25pt（Doc1 mean=11.00 vs Doc2 mean=11.25）
- adjusted_diff: -0.500 - 1.5×0 = **-0.500pt**

**評価**: CORS Bypass Analysis ルールはターゲットカテゴリ（入力検証・攻撃防御）で完全検出を達成し、Doc2-P05のCORS正規表現バイパス問題を安定検出した。カテゴリ検出率の改善は見られるが、全体スコアはcurrent-bestを0.50pt下回る。ボーナス獲得数の相対的な低下（特にDoc1）が原因であり、具体的なCORS分析指示追加がDoc1における多角的な追加指摘を抑制した可能性がある。cross_doc_gapはcurrent-bestと同等（0.25pt）で汎化性は維持されている。adjusted_diff=-0.500ptのため推奨基準を満たさない。

---

## リスク評価

| リスク種別 | v005-audit-log-finding-separation | v005-cors-bypass-output |
|-----------|-----------------------------------|------------------------|
| 過学習リスク | 中（Doc2でcross_doc_gap増加、Doc1特化の兆候） | 低（cross_doc_gap=0.25ptで安定） |
| 注意分散リスク | 低（Audit Log出力指示はスコープが明確） | 中（CORS分析指示の具体化がDoc1ボーナス取得に干渉した可能性） |
| 回帰リスク | 低（全カテゴリ閾値未満） | 低（全カテゴリ改善または維持） |

---

## 推奨判定

**推奨: current-best（v004-input-finding-separation）を維持**

### 判定根拠

両バリアントともにadjusted_diffが推奨基準（>1.0pt または 0.5〜1.0pt）を下回る：
- v005-audit-log-finding-separation: adjusted_diff = -0.125pt（< 0.5pt）
- v005-cors-bypass-output: adjusted_diff = -0.500pt（< 0.5pt）

scoring-rubric.md の推奨判定基準「adjusted_diff < 0.5pt → 現在ベストを推奨」に該当する。

### 補足観察

- **v005-audit-log-finding-separation の部分的成功**: ターゲットカテゴリ（インフラ・依存関係・監査）ではDoc1-P08 の△→○改善を達成。ただし、出力指示追加のトレードオフとして入力検証・攻撃防御のDoc2スコアが悪化し、全体スコアが current-best を下回った。
- **v005-cors-bypass-output の検出改善**: 入力検証・攻撃防御カテゴリを 0.900→1.000 に引き上げ、Doc2-P05（CORS正規表現バイパス）の完全検出を達成した。検出率の観点では改善だが、全体スコアはボーナス獲得数の減少により current-best を下回った。
- **カテゴリ検出率 vs 全体スコアのトレードオフ**: 両バリアントとも特定カテゴリの検出率は改善しているが、Output Guidelines への追加指示が他の観点（ボーナス取得、他カテゴリの検出安定性）に干渉するパターンが繰り返し観察されている。

---

## 考察

### 現在の最優先エラーパターンと次ラウンドの方向性

現時点で残存する主要エラーは以下の2点：
1. **Doc2-P05（入力検証・攻撃防御・中・medium）**: CORS正規表現バイパスの具体的手法 — v005-cors-bypass-output が doc2 で完全検出を達成したが、v005 全体スコアは current-best を下回った。v005-cors-bypass-output の CORS Bypass Analysis ルールを current-best に組み込む形（既存 Defense Layer Separation ルールとの共存）の検討が有効。
2. **Doc2-P04（入力検証・攻撃防御・中・medium）、Doc2-P03（認証・認可設計・重大・hard）**: v005-audit-log-finding-separation において新たに不安定化。これらは Output Guidelines への指示追加が他カテゴリの注意分散を引き起こすことを示している。

### Output Guidelines 追加アプローチの限界

R3〜R4を通じて、Output Guidelines への独立指示追加は以下のパターンを示す：
- 特定問題への検出率は改善するが、ボーナス取得や他カテゴリの安定性が低下するトレードオフが発生
- 個別問題への具体化指示は「出力の焦点」を狭める副作用を持つ可能性がある

次ラウンドでは、特定カテゴリへの narrow な出力指示ではなく、評価基準セクション（§4、§5）における観点追加（Anti-Patterns回避を意識した簡潔な表現）や、ボーナス取得を阻害しない汎用的な評価軸の強化を検討すべきである。

---

## 収束判定: 継続推奨

R3で+0.50ptの改善があり、3ラウンド連続で改善幅 < 0.5pt の条件を満たしていない（R3が境界値相当）。継続推奨。
