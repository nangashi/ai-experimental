# Round 004 Comparison Report

## Execution Conditions

- **Round**: 4
- **Test Document**: 地域医療機関統合患者向けリアルタイム医療予約システム (287 lines, 15 embedded problems)
- **Current Best**: v003-auth-ratelimit (Mean=12.8, SD=0.5)
- **Variants**:
  - v004-compress-csrf: Compress output guidelines + add explicit CSRF/CORS/internal-encryption checkpoints
  - v004-split-web: Split Input Validation section into Injection Defense and Web Security subsections

## Score Comparison Table

| Prompt | Mean | SD | Run1 | Run2 | Run3 | vs Current Best |
|--------|------|-----|------|------|------|-----------------|
| v003-auth-ratelimit (current) | 12.8 | 0.5 | 12.8 | 13.3 | 12.3 | — |
| v004-compress-csrf | 13.2 | 0.2 | 13.0 | 13.5 | 13.0 | +0.4pt |
| v004-split-web | 10.2 | 0.4 | 10.5 | 10.5 | 9.5 | -2.6pt |

## Category-Level Detection Matrix

### v004-compress-csrf vs Current Best

| Category | Current Best | v004-compress-csrf | Change |
|----------|--------------|-------------------|--------|
| 認証・認可設計 (2問) | 6/6 ○ | 5/6 ○, 1/6 △ | -0.5pt (P01 deterioration in Run3) |
| 入力検証・攻撃防御 (5問) | 7/15 ○, 6/15 △, 2/15 × | 11/15 ○, 3/15 △, 1/15 × | +2.5pt (P02, P03, P04 improved) |
| データ保護 (4問) | 9/12 ○, 3/12 △ | 8/15 ○, 6/15 △, 1/15 × | -0.5pt (P06 deterioration, P08 improvement) |
| 脅威モデリング(I/R) (2問) | 6/6 ○ | 6/6 ○ | stable |
| 脅威モデリング(T) (1問) | 0/3 × | 0/3 × | stable |
| インフラ・依存関係・監査 (3問) | 6/9 ○, 3/9 △ | 6/9 ○, 3/9 △ | stable |
| **ボーナス獲得** | ~1.5pt | 4/3 (Run2で4件獲得) | +1.0pt (B01, B04, B05, B06) |

### v004-split-web vs Current Best

| Category | Current Best | v004-split-web | Change |
|----------|------------|----------------|--------|
| 認証・認可設計 (2問) | 6/6 ○ | 6/6 ○ | stable |
| 入力検証・攻撃防御 (5問) | 7/15 ○, 6/15 △, 2/15 × | 13/15 ○, 0/15 △, 2/15 × | +3.0pt (P02, P03, P04 fully stable, P15 deterioration) |
| データ保護 (4問) | 9/12 ○, 3/12 △ | 9/12 ○, 3/12 △ | stable |
| 脅威モデリング(I/R) (2問) | 6/6 ○ | 6/6 ○ | stable |
| 脅威モデリング(T) (1問) | 0/3 × | 0/3 × | stable |
| インフラ・依存関係・監査 (3問) | 6/9 ○, 3/9 △ | 9/9 ○ | +1.5pt (P12 improvement) |
| **ボーナス獲得** | ~1.5pt | 0pt | -1.5pt (no bonus) |

## Variant-Level Analysis

### v004-compress-csrf

**変更内容**: Compress output guidelines (12→6 lines) + add explicit CSRF/CORS/internal-encryption checkpoints

**期待効果**: History shows blind content addition causes attention dispersion. Compression creates space for specific CSRF/CORS items without increasing total length. Internal encryption checkpoint addresses P08 gap.

**実績**: Mean=13.2 (SD=0.2), vs current-best +0.4pt

**解釈**: 期待効果と実績が部分的に一致。CSRF/CORS/レート制限カテゴリ(P02, P03, P04)で全Run○に改善し、狙った効果を達成。内部通信暗号化(P08)も全Run○に改善。しかし、データ保護カテゴリのP06(ログの機密データマスキング)で○→△に悪化し、認証・認可カテゴリのP01でRun3のみ○→△に悪化。**注意分散のトレードオフは完全には解消されていない**。一方、ボーナス獲得(Run2で4件)により総合スコアは+0.4pt改善。検出スコア改善(+2.0pt)とボーナス獲得(+1.0pt)が相乗効果を発揮した。

**副作用**: 想定=Low (Compression targets verbose non-criteria section. Additions are independent items in weak categories. Preserves all strength areas.) → 実際=**Medium** (P06とP01で部分的に悪化。圧縮対象の「Output Guidelines」セクションは非基準セクションだが、P01の悪化(認証・認可カテゴリ)とP06の悪化(データ保護カテゴリ)は予想外。圧縮により暗黙的な優先順位付けや出力構造化の指示が失われた可能性)

### v004-split-web

**変更内容**: Split Input Validation section into Injection Defense and Web Security subsections with attention anchors

**期待効果**: CSRF/CORS detection instability suggests these items are buried in large mixed section. Subsection headers create attention anchors for web-layer attacks (CSRF, CORS, file upload) separate from injection attacks, forcing explicit evaluation of each subcategory.

**実績**: Mean=10.2 (SD=0.4), vs current-best -2.6pt

**解釈**: 期待効果と実績が完全に乖離。CSRF/CORS/レート制限(P02, P03, P04)は全Run○に改善したが、**ボーナス獲得が完全に消失**(-1.5pt)し、P15(XSS対策・ファイルアップロード)でRun3のみ○→×に悪化(-0.5pt)。総合スコアは-2.6ptの大幅悪化。セクション分割により入力検証カテゴリへの注意が過度に集中し、他カテゴリでの有益な追加指摘(B01: パスワードポリシー, B04: 依存ライブラリ脆弱性管理, B05: バックアップ暗号化, B06: トークン失効)が完全に漏れた。**注意の集中と引き換えに包括的カバレッジを失った典型例**。

**副作用**: 想定=Medium (Section splitting might fragment attention. Mitigation: Keep unified section number (4), use non-numbered subsection headers as anchors only.) → 実際=**High** (ボーナス獲得が完全消失。セクション分割がアンカーとして機能した一方、包括的カバレッジへの意識を破壊。緩和策(統一セクション番号、非番号サブヘッダ)は不十分だった)

## Risk Assessment

### 過学習リスク

| Metric | v003-auth-ratelimit | v004-compress-csrf | v004-split-web |
|--------|---------------------|-------------------|----------------|
| ボーナス依存度 (bonus/total) | ~11.7% (1.5/12.8) | 12.1% (1.6/13.2) | 0% (0/10.2) |
| 検出スコア vs 総合スコアの乖離 | 検出11.3 + bonus1.5 | 検出11.6 + bonus1.6 | 検出10.2 + bonus0 |

**v004-compress-csrf**: ボーナス依存度は現在ベストとほぼ同等(11.7% vs 12.1%)。検出スコア改善(+2.0pt)とボーナス獲得(+1.0pt)の両方で貢献しており、**過学習リスクは低い**。固定テスト文書への特化ではなく、汎用的な検出能力の向上と判断できる。

**v004-split-web**: ボーナス獲得が完全消失。検出スコアは10.2ptで、入力検証カテゴリへの注意集中により他領域のカバレッジが低下。**狭い領域への過適合リスクがある**。

### 注意分散リスク

**v004-compress-csrf**: 入力検証・攻撃防御(+2.5pt)とデータ保護(-0.5pt)、認証・認可(-0.5pt)でトレードオフが観察される。圧縮によりスペースを確保したが、**完全にはトレードオフを解消していない**。ただし、ボーナス獲得により総合的には改善。

**v004-split-web**: 入力検証・攻撃防御(+3.0pt)とボーナス獲得(-1.5pt)で明確なトレードオフ。セクション分割により入力検証への注意が過度に集中し、他領域での有益な追加指摘が完全に消失。**注意分散リスクが顕在化**。

### 汎化リスク

**v004-compress-csrf**: 検出スコア改善(+2.0pt)は主にCSRF/CORS/レート制限(P02, P03, P04)と内部通信暗号化(P08)の明示的チェックポイント追加による。これらは汎用的なセキュリティ原則であり、固定テスト文書への特化ではない。**汎化リスクは低い**。

**v004-split-web**: 入力検証カテゴリへの注意集中により、他カテゴリでの包括的カバレッジが低下。セクション構造が固定テスト文書の問題分布に最適化されている可能性があり、**汎化リスクは中程度**。

## Recommended Decision

**推奨プロンプト**: v004-compress-csrf

**判定根拠**:
- 平均スコア差は+0.4pt（0.5pt未満）だが、標準偏差が0.2と現在ベスト(0.5)より大幅に低く、**安定性が向上**している
- 検出スコア改善(+2.0pt)とボーナス獲得(+1.0pt)の両方で貢献しており、過学習リスクが低い
- CSRF/CORS/レート制限(P02, P03, P04)と内部通信暗号化(P08)で目標通りの改善を達成
- P06とP01で部分的に悪化しているが、ボーナス獲得により総合的には改善
- v004-split-webは-2.6ptの大幅悪化であり、明確に非推奨

**収束判定**: 継続推奨

- R2→R3→R4で+1.1pt→-1.4pt(v002)→+0.4pt(v004-compress-csrf)と変動しており、収束判定基準(2ラウンド連続で改善幅 < 0.5pt)を満たさない
- 入力検証・攻撃防御カテゴリに改善余地あり(P15が安定△、P02/P03/P04は改善したが他問題は残存)
- データ保護カテゴリのP07(保持期間・分類方針)、P14(データ完全性検証)が全Run×で未解決
- 次回は「注意分散を抑制しつつデータ保護カテゴリを強化する方向」を探索すべき

**リスク評価**: 過学習リスク=低、注意分散リスク=中、汎化リスク=低

- ボーナス依存度は現在ベストと同等(12.1%)で、検出スコアとボーナスの両方で改善しており、過学習リスクは低い
- P06とP01で部分的に悪化しており、注意分散のトレードオフが完全には解消されていないため、注意分散リスクは中程度
- 改善カテゴリ(CSRF/CORS/内部通信暗号化)は汎用的なセキュリティ原則であり、汎化リスクは低い

## Insights for Next Round

1. **圧縮戦略の有効性**: Output Guidelines圧縮により基準セクションにスペースを確保する戦略は有効だった。ただし、P06とP01で部分的に悪化しており、圧縮対象の選定と圧縮後の内容保持に改善余地がある。

2. **セクション分割の失敗**: 入力検証セクションの分割は、注意アンカーとして機能した一方で、包括的カバレッジへの意識を破壊した。セクション構造の変更は慎重に行うべき。

3. **ボーナス獲得の重要性**: v004-compress-csrfは検出スコア改善(+2.0pt)とボーナス獲得(+1.0pt)の両方で貢献し、v004-split-webはボーナス獲得が完全消失(-1.5pt)により大幅悪化した。**ボーナス獲得を維持しつつ検出精度を改善する戦略が重要**。

4. **データ保護カテゴリの難易度**: P07(保持期間・分類方針)は4ラウンド連続で全Run×。「データライフサイクル管理」を明示的にチェック項目として追加する必要がある。P06(ログの機密データマスキング)はv003では○だったが、v004-compress-csrfで△に悪化。圧縮により詳細性が失われた可能性。

5. **脅威モデリング(Tampering)の難易度**: P14(データ完全性検証)は4ラウンド連続で全Run×。STRIDE-Tの「データ完全性検証」を抽象的な記述から具体的な技術要素(ハッシュ、デジタル署名、監査証跡)に展開する必要がある。

6. **次回の方向性**: 「圧縮+明示的チェックポイント」戦略を継続しつつ、データ保護カテゴリ(P06, P07, P08)と脅威モデリング(T)(P14)に焦点を当てる。ただし、v004-split-webの失敗から学び、セクション構造の大幅変更は避け、既存セクション内での具体化とチェックリスト追加に限定すべき。
