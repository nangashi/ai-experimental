# 改善計画: agent_audit_new

## 変更対象ファイル
| # | ファイル | 変更種別 | 変更概要 | 対応フィードバック |
|---|---------|---------|---------|------------------|
| 1 | SKILL.md | 修正 | Phase 1 サブエージェント返答フォーマットを拡張し、findings メタデータを直接返答させる。Phase 2 Step 1 の findings 収集ロジックを変更し、全文 Read の代わりにメタデータのみを使用する | I-5: findings 収集時のコンテキスト肥大化リスク |

## 各ファイルの変更詳細

### 1. /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.claude/skills/agent_audit_new/SKILL.md（修正）
**対応フィードバック**: I-5: findings 収集時のコンテキスト肥大化リスク

**変更内容**:

#### 変更箇所1: Phase 1 サブエージェント返答フォーマット（137行目付近）
**現在の記述**:
```
> 分析完了後、以下のフォーマットで返答してください（次元名を引用符で囲む）: `dim: "{次元名}", critical: {N}, improvement: {M}, info: {K}`
```

**改善後の記述**:
```
> 分析完了後、以下のフォーマットで返答してください:
> ```
> dim: "{次元名}", critical: {N}, improvement: {M}, info: {K}
> findings_metadata: [
>   {"id": "{ID}", "severity": "critical|improvement", "title": "{title}"},
>   ...
> ]
> ```
>
> - `findings_metadata` は critical + improvement の finding のみを含む（info は除外）
> - JSON 配列形式で返答し、各要素は `id`, `severity`, `title` の3フィールドを持つ
> - findings の順序は critical → improvement、各 severity 内では findings ファイルの出現順とする
```

#### 変更箇所2: Phase 1 完了後のメタデータ収集（141-162行目）
**現在の記述**:
```
全サブエージェントの完了を待ち、各返答サマリを収集する。

**エラーハンドリング**: 各サブエージェントの成否を以下で判定する:
- 対応する findings ファイル（`.agent_audit/{agent_name}/audit-{ID_PREFIX}.md`）が存在し、空でない → 成功。件数はファイル内の `## Summary` セクションから抽出する（抽出失敗時は findings ファイル内の `### {ID_PREFIX}-` ブロック数から推定する）
- findings ファイルが存在しない、または空 → 失敗。Task ツールの返答から例外情報（エラーメッセージの要約、スタックトレースの最終行等）を抽出し、該当次元は「分析失敗（{エラー概要}）」として扱う。具体例: 「Read 失敗: ファイルが見つかりません」「解析エラー: YAML パースエラー」

全て失敗した場合: 「Phase 1: 全次元の分析に失敗しました。」とエラー出力して終了する。

テキスト出力:
```
Phase 1 完了: {成功数}/{dim_count}
- {次元名}: critical {N}, improvement {M}, info {K}（または「分析失敗（{エラー概要}）」）
（各次元を1行ずつ表示）

失敗した次元がある場合は、以下を追加表示:
```
リトライ方法: `/agent_audit {agent_path}` を再実行してください
失敗の原因として、サブエージェント定義ファイルの不在、findings ファイル保存権限の不足等が考えられます。
```
```

全次元の critical + improvement の合計が 0 の場合、「対象となる指摘はありませんでした。」とテキスト出力し、Phase 2 をスキップして Phase 3 へ直行する。
```

**改善後の記述**:
```
全サブエージェントの完了を待ち、各返答から件数とメタデータを収集する:

1. 各 Task 返答から `dim:`, `critical:`, `improvement:`, `info:`, `findings_metadata:` を抽出する
2. `findings_metadata` の JSON 配列をパースし、メモリに保持する（全次元の findings メタデータを統合リストとして保持）
3. 親コンテキストに保持するデータ:
   - 各次元の件数サマリ（`dim`, `critical`, `improvement`, `info`）
   - 統合 findings メタデータリスト（critical → improvement の順でソート済み）

**エラーハンドリング**: 各サブエージェントの成否を以下で判定する:
- Task 返答に `dim:` と `critical:`, `improvement:`, `info:` が含まれる → 成功。`findings_metadata` の欠落は許容（空配列として扱う）
- Task 返答に `dim:` がない、または対応する findings ファイル（`.agent_audit/{agent_name}/audit-{ID_PREFIX}.md`）が存在しない → 失敗。Task 返答から例外情報（エラーメッセージの要約、スタックトレースの最終行等）を抽出し、該当次元は「分析失敗（{エラー概要}）」として扱う

全て失敗した場合: 「Phase 1: 全次元の分析に失敗しました。」とエラー出力して終了する。

テキスト出力:
```
Phase 1 完了: {成功数}/{dim_count}
- {次元名}: critical {N}, improvement {M}, info {K}（または「分析失敗（{エラー概要}）」）
（各次元を1行ずつ表示）

失敗した次元がある場合は、以下を追加表示:
```
リトライ方法: `/agent_audit {agent_path}` を再実行してください
失敗の原因として、サブエージェント定義ファイルの不在、findings ファイル保存権限の不足等が考えられます。
```
```

統合 findings メタデータリストの合計が 0 の場合、「対象となる指摘はありませんでした。」とテキスト出力し、Phase 2 をスキップして Phase 3 へ直行する。
```

#### 変更箇所3: Phase 2 Step 1 findings 収集ロジック（171-175行目）
**現在の記述**:
```
#### Step 1: Findings の収集

Phase 1 で成功した全次元の findings ファイル（`.agent_audit/{agent_name}/audit-{ID_PREFIX}.md`）を Read する。
各ファイルから severity が critical または improvement の finding（`###` ブロック単位）を抽出し、critical → improvement の順にソートする。
`{total}` = 対象 finding の合計件数。
```

**改善後の記述**:
```
#### Step 1: Findings メタデータの使用

Phase 1 で収集した統合 findings メタデータリスト（親コンテキストに保持済み）を使用する。
この時点で findings ファイルは Read しない（詳細表示時のみ必要に応じて Read）。
`{total}` = メタデータリストの要素数。
```

#### 変更箇所4: Phase 2 Step 2a per-item 承認での詳細表示（196-206行目）
**現在の記述**:
```
#### Step 2a: Per-item 承認（「1件ずつ確認」選択時のみ）

各 finding に対して以下をテキスト出力する:
```
### [{N}/{total}] {ID}: {title} ({severity})
- 次元: {次元名}
- 内容: {description}
- 根拠: {evidence}
- 推奨: {recommendation}

---
```
```

**改善後の記述**:
```
#### Step 2a: Per-item 承認（「1件ずつ確認」選択時のみ）

各 finding のメタデータ（`id`, `severity`, `title`）に対して、以下の処理を実行する:

1. `id` から次元の `ID_PREFIX` を抽出（例: `CE-1` → `CE`）
2. 対応する findings ファイル（`.agent_audit/{agent_name}/audit-{ID_PREFIX}.md`）を Read する
3. ファイル内から `### {id}:` で始まるブロックを検索し、`description`, `evidence`, `recommendation` を抽出する
4. 以下をテキスト出力する:
```
### [{N}/{total}] {ID}: {title} ({severity})
- 次元: {次元名}
- 内容: {description}
- 根拠: {evidence}
- 推奨: {recommendation}

---
```

**注**: findings ファイルの Read は per-item 承認時のみ実行される（一括承認選択時は Read をスキップ）。
```

## 新規作成ファイル
（なし）

## 削除推奨ファイル
（なし）

## 実装順序
1. SKILL.md の Phase 1 サブエージェント返答フォーマット拡張（変更箇所1）
   - 理由: サブエージェントが新フォーマットで返答するための仕様定義
2. SKILL.md の Phase 1 メタデータ収集ロジック（変更箇所2）
   - 理由: サブエージェント返答を受け取り、メタデータを抽出・保持する親側の処理
3. SKILL.md の Phase 2 Step 1 findings 収集ロジック（変更箇所3）
   - 理由: Phase 1 で保持したメタデータを使用する後続処理
4. SKILL.md の Phase 2 Step 2a per-item 承認での詳細表示（変更箇所4）
   - 理由: メタデータベースの一覧表示後、詳細表示が必要な時のみ findings ファイルを Read する遅延ロード処理

依存関係:
- 変更箇所1（返答フォーマット定義）→ 変更箇所2（返答パース処理）→ 変更箇所3・4（メタデータ使用）

## 注意事項
- **サブエージェント定義ファイルの更新も必要**: SKILL.md の変更に合わせて、各次元のサブエージェント定義ファイル（`agents/{dim_path}.md`）の返答フォーマット指示も更新する必要がある。具体的には、最終返答に `findings_metadata:` JSON 配列を含めるよう指示を追加する
- **後方互換性**: 古いフォーマット（`dim:`, `critical:`, `improvement:`, `info:` のみ）で返答されたサブエージェントにも対応するため、`findings_metadata` の欠落時は Phase 2 Step 1 で findings ファイルを Read するフォールバック処理を残すことを推奨
- **JSON パースエラーハンドリング**: `findings_metadata` の JSON 配列パースに失敗した場合、該当次元のメタデータを空配列として扱い、警告を出力する（処理は継続）
- **遅延ロード最適化**: per-item 承認時のみ findings ファイルを Read することで、一括承認選択時（「全て承認」「critical のみ承認」等）は findings ファイルの Read を完全にスキップできる。ただし、Phase 2 Step 3 の承認結果保存時に `description`, `evidence`, `recommendation` が必要な場合は、その時点で Read を実行する必要がある
- **コンテキスト削減効果**: 50 findings × 平均 200 文字/finding = 10,000 文字の削減が見込まれる。メタデータのみ（50 findings × 平均 80 文字）なら 4,000 文字に削減
