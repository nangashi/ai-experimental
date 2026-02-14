# Findings 収集テンプレート

Phase 1 で成功した全次元の findings ファイルを収集し、severity が critical または improvement の finding を抽出してください。

## 入力

- `.agent_audit/{agent_name}/audit-*.md`: Phase 1 で各次元エージェントが生成した findings ファイル
- 抽出対象: severity が `critical` または `improvement` の finding（`###` ブロック単位）

## 処理手順

1. `.agent_audit/{agent_name}/` ディレクトリ内の `audit-*.md` ファイルを Glob で検索する
2. 各ファイルを Read し、`### {ID}:` ブロックを抽出する
3. 各ブロックから以下の情報を抽出する:
   - ID: ブロックの見出し（例: `CE-001`）
   - severity: `**Severity**:` 行の値（critical / improvement / info）
   - title: ブロックの見出しの `:` 以降の部分
   - description: `**Description**:` 行以降、次の `**` 見出しまでの内容
   - evidence: `**Evidence**:` 行以降、次の `**` 見出しまでの内容
   - recommendation: `**Recommendation**:` 行以降、次の `###` または `##` 見出しまでの内容
   - 次元名: ファイル名から導出（`audit-CE.md` → `CE`）
4. severity が `critical` または `improvement` の finding のみをリストに含める
5. critical findings を先に、improvement findings を後にソートする（各グループ内では ID の昇順）

## 出力

### 返答フォーマット

以下のフォーマットで返答してください:

```
total: {N}
critical: {M}
improvement: {K}
```

- `{N}`: critical + improvement の合計件数
- `{M}`: critical の件数
- `{K}`: improvement の件数

### ファイル保存

findings の詳細テーブルを `.agent_audit/{agent_name}/findings-summary.md` に Write で保存してください。

フォーマット:
```
# Findings Summary

## 対象: {total}件（critical {M}, improvement {K}）

| # | ID | severity | title | 次元 |
|---|-----|----------|-------|------|
| 1 | {ID} | {severity} | {title} | {次元名} |
| 2 | {ID} | {severity} | {title} | {次元名} |
...

## 詳細

### {#}: {ID}: {title}
- **Severity**: {severity}
- **次元**: {次元名}
- **Description**: {description}
- **Evidence**: {evidence}
- **Recommendation**: {recommendation}

（全 finding について同様に記述）
```

## エラーハンドリング

- findings ファイルが1つも見つからない場合: `total: 0, critical: 0, improvement: 0` を返答し、findings-summary.md は作成しない
- ファイルの読み込みに失敗した場合: そのファイルをスキップして処理を続行する
