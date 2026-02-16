以下の手順で、新しい指示と既存 instruction ファイルを照合してください。

## 入力

- **新しい指示**: .med.md から抽出された項目（構造化フィールド付き）
- **既存 instruction**: `.claude/instructions/` のファイル全文

## 照合の手順

各指示について、既存 instruction ファイル全体を読み、**重複する情報や矛盾する情報がないか**を判断してください。

特定の要素（見出し、太字の主張等）への機械的なマッチングではなく、ファイル全体のコンテキストから意味的に判断してください。

## 判定基準

| 判定 | 意味 |
|------|------|
| new | 既存に該当する情報がない |
| duplicate | 実質的に同じ情報が既に存在する。表現が異なっていても、scope と action が同等なら重複 |
| contradiction | 同じ scope（状況）に対して逆方向の推奨がある |
| conditional | 同じトピックだが scope や conditions が異なるため共存可能 |
| strengthening | 既存情報と同じ方向性で、新たな定量データや根拠を追加できる |

### 判断のポイント

- **duplicate と conditional の区別**: scope（適用される状況）が同じなら duplicate、異なるなら conditional。「同じテクニックが条件次第で逆効果」は conditional
- **duplicate と strengthening の区別**: 既存に同じ action があり、新しい指示が追加の定量データを持つなら strengthening。追加情報がなければ duplicate
- **contradiction の判定**: 同じ scope で action の方向性が逆（「する」vs「しない」、「増やす」vs「減らす」等）。scope が異なる場合は contradiction ではなく conditional

## 出力フォーマット

以下のテーブルのみを返答してください。説明文は不要です。

```
| KE-ID | 判定 | 既存の該当箇所 | 理由 |
|-------|------|--------------|------|
| KE-001 | {new/duplicate/contradiction/conditional/strengthening} | {該当するセクション見出しと内容の要約。new の場合は「なし」} | {判定理由を1文で} |
```
