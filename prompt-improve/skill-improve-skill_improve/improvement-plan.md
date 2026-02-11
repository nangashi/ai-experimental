# 改善計画: skill_improve

## 変更対象ファイル
| # | ファイル | 変更種別 | 変更概要 | 対応フィードバック |
|---|---------|---------|---------|------------------|
| 1 | SKILL.md | 修正 | Phase 0 エラーメッセージ定義、Phase 2 部分失敗処理追加、Phase 3 コンフリクト検出アルゴリズム明示、Phase 1 AskUserQuestion削除、Phase 3 Fast modeフォーマット定義、Phase 3 findings.md保存追加、Phase 1/4/5/6 Task失敗時処理追加、Phase 7 クリーンアップ失敗時処理追加 | 重大-1, 重大-2, 重大-3, 重大-4, 改善-3, 改善-4, 改善-7, 改善-10, 改善-12 |
| 2 | templates/apply-improvements.md | 修正 | 二重適用チェック追加 | 改善-5 |
| 3 | templates/reviewer-stability.md | 修正 | Line 37 曖昧表現の修正 | 改善-6 |
| 4 | templates/reviewer-independence.md | 修正 | 返答長の上限指定追加 | 改善-9 |
| 5 | templates/reviewer-stability.md | 修正 | 返答長の上限指定追加 | 改善-9 |
| 6 | templates/reviewer-efficiency.md | 修正 | 返答長の上限指定追加 | 改善-9 |
| 7 | templates/reviewer-ux.md | 修正 | 返答長の上限指定追加 | 改善-9 |
| 8 | templates/reviewer-architecture.md | 修正 | 返答長の上限指定追加 | 改善-9 |

## 各ファイルの変更詳細

### 1. SKILL.md（修正）
**対応フィードバック**: 重大-1, 重大-2, 重大-3, 重大-4, 改善-3, 改善-4, 改善-7, 改善-10, 改善-12

**変更内容**:
- **Phase 0 Step 4 (Line 36)**: `ファイルが0件の場合はエラー終了する` → `ファイルが0件の場合は「{skill_path} 内に .md ファイルが見つかりません。SKILL.md を含むスキルディレクトリを指定してください。」とテキスト出力し、スキルを終了する`

- **Phase 1 (Line 60-61)**: Standard mode の AskUserQuestion を削除
  - 現在: `Standard mode: テキスト出力後、AskUserQuestion で「分析結果を確認して続行しますか？」と確認する（選択肢:「続行」/「中止」）。`
  - 変更後: `Standard mode: テキスト出力のみで続行する。`
  - Fast mode の記述（Line 61）も削除（Standard と同一処理になるため）

- **Phase 2 Step 1 (Line 67-71)**: TeamCreate 失敗時の処理を追加
  - 現在: `TeamCreate: team_name="si-{skill_name}"`
  - 変更後: 以下に置き換え
```
TeamCreate: team_name="si-{skill_name}"
TeamCreate が失敗した場合（チーム既存等）:
1. TeamDelete で既存チームを削除
2. 再度 TeamCreate を実行
3. 再度失敗した場合はエラーメッセージを出力し、スキルを終了
```

- **Phase 2 Step 3 (Line 117-120)**: 部分失敗時の処理を追加
  - 現在の「レビュー完了: {成功数}/5件」の後に以下を追加:
```
成功数が5未満の場合:
- 失敗したレビューアー名をテキスト出力する
- 成功数が3件以上: 「最低基準（3件）を満たしているため、続行します。」と出力し、Phase 3 へ進む
- 成功数が2件以下: AskUserQuestion で「レビューが{成功数}/5件のみ完了しました。」「続行」/「中止」を確認する
```

- **Phase 3 Step 2 (Line 134-135)**: コンフリクト検出アルゴリズムを明示
  - 現在: `5件のレビュー結果を比較し、同一のファイル・セクションに対して矛盾する指摘がないか確認する。`
  - 変更後: 以下に置き換え
```
5件のレビュー結果を比較し、コンフリクトを検出する:
1. 各レビュー結果の「重大な問題」「改善提案」を対象ファイル:セクション でグループ化する
2. 同一箇所（ファイル+セクション/行番号が一致）に対する指摘を抽出する
3. 以下の相反パターンを検出する:
   - 削除 vs 追加
   - 簡略化 vs 詳細化
   - インライン化 vs テンプレート化
   - 確認削減 vs 確認追加
4. 検出したコンフリクト（あれば）を次ステップで解決する
```

- **Phase 3 Step 4 (Line 156-157)**: Fast mode のフォーマットを明示
  - 現在: `Fast mode: 分類結果のサマリ（件数のみ）をテキスト出力する。コンフリクト未解決時のみ AskUserQuestion。`
  - 変更後: `Fast mode: 「検出: 重大 {N}件, 改善 {M}件, 良い点 {K}件」の形式でサマリをテキスト出力する。コンフリクト未解決時のみ AskUserQuestion。`

- **Phase 3 終了時 (Line 161 の後)**: findings.md 保存を追加
```
Phase 3 完了後、分類済みフィードバック（重大な問題 + 改善提案）を `{work_dir}/findings.md` に Write で保存する。
フォーマット:
```
## 重大な問題
{各重大な問題の内容}

## 改善提案
{各改善提案の内容}
```
```

- **Phase 4 (Line 174)**: {findings_text} を {findings_path} に変更
  - 現在: `{findings_text}`: 分類済みフィードバック（重大な問題 + 改善提案のみをテキストにまとめて提供）
  - 変更後: `{findings_path}`: `{work_dir}/findings.md` の絶対パス

- **Phase 1 Task呼び出し後 (Line 58)**: Task 失敗時処理を追加
  - 現在: `サブエージェント完了後、返答内容（サマリ）をテキスト出力する。`
  - 変更後: 以下に置き換え
```
サブエージェント完了後:
- 成功した場合: 返答内容（サマリ）をテキスト出力する
- 失敗した場合: エラー内容をテキスト出力し、AskUserQuestion で「リトライ」/「中止」を確認する。「リトライ」選択時は Phase 1 を再実行
```

- **Phase 4 Task呼び出し後 (Line 177)**: Task 失敗時処理を追加（Phase 1 と同様のパターン）

- **Phase 5 Task呼び出し後 (Line 198-202)**: Task 失敗時処理を追加（Phase 1 と同様のパターン）

- **Phase 6 Task呼び出し後 (Line 220-224)**: Task 失敗時処理を追加（Phase 1 と同様のパターン）

- **Phase 7 (Line 239-241)**: クリーンアップ失敗時処理を追加
  - 現在: `全メンバーのシャットダウン完了を確認する` の後
  - 変更後: 以下を追加
```
2. 各レビューアーに SendMessage で shutdown_request を送信する
   - 各送信が失敗した場合はエラーを無視し、次のレビューアーへ進む
3. TeamDelete でチームを削除する
   - TeamDelete が失敗した場合はエラーを無視し、完了サマリに「チームクリーンアップ失敗（手動で .claude/teams/si-{skill_name} の削除が必要）」を付記する
```

### 2. templates/apply-improvements.md（修正）
**対応フィードバック**: 改善-5

**変更内容**:
- **Line 29-33 (変更適用ルール)**: 二重適用チェックを追加
  - 現在の4つのルールの前に以下を追加:
```
- **二重適用チェック**: Edit 前に対象箇所の現在の内容が改善計画の「現在の記述」と一致するか確認する。一致しない場合（既に改善済みまたは別の変更あり）はその変更をスキップし、skipped リストに理由を記録する
```

### 3. templates/reviewer-stability.md（修正）
**対応フィードバック**: 改善-6

**変更内容**:
- **Line 37**: 曖昧表現を具体化
  - 現在: `再実行時にファイルが重複生成される箇所を検出する（「Write で保存」に既存チェックがない等）`
  - 変更後: `再実行時にファイルが重複生成される箇所を検出する（Write 前の Read 呼び出し、ファイル存在確認の条件分岐（if file exists）がない等）`

### 4-8. templates/reviewer-*.md（5ファイル：修正）
**対応フィードバック**: 改善-9

**変更内容**（全レビューアーテンプレートに共通）:
- **「出力」セクション冒頭に以下を追加**（SendMessage フォーマット指示の直前）:
```
**返答長の制限**:
- 重大な問題: 最大5件（超過する場合は重要度順に記載）
- 改善提案: 最大7件（超過する場合は重要度順に記載）
- 良い点: 最大3件

```

各ファイルの具体的な挿入位置:
- **reviewer-independence.md Line 44-45**: 「以下のフォーマットで」の前に追加
- **reviewer-stability.md Line 47-48**: 「以下のフォーマットで」の前に追加
- **reviewer-efficiency.md Line 46-47**: 「以下のフォーマットで」の前に追加
- **reviewer-ux.md Line 55-56**: 「以下のフォーマットで」の前に追加
- **reviewer-architecture.md Line 56-57**: 「以下のフォーマットで」の前に追加

## 新規作成ファイル
なし

## 削除推奨ファイル
なし

## 実装順序
1. **templates/reviewer-stability.md**: 曖昧表現の修正（独立した小さい変更）
2. **templates/reviewer-*.md (5ファイル)**: 返答長の上限指定追加（5ファイル並列で実施可能）
3. **templates/apply-improvements.md**: 二重適用チェック追加（独立した小さい変更）
4. **SKILL.md**: 主要な構造変更・ロジック追加（最後に実施。依存なし、大きい変更のため他の変更完了後に集中して対応）

## 注意事項
- SKILL.md の変更により行数が増加するが、Phase 1 の AskUserQuestion 削除（2-3行削減）と記述の簡潔化で256行→250行以下を目指す
- Phase 3 で findings.md を保存する変更により、Phase 4/6 のテンプレート（consolidate-findings.md, verify-improvements.md）も {findings_text} から {findings_path} への変更が必要だが、本計画では対象外（テンプレート側は現状のまま機能する設計）
- TeamCreate/TeamDelete 失敗時の処理追加により、既存チームの再利用時にも安定動作するようになる
- 部分失敗時の処理により、5レビューアーのうち2件が失敗してもスキルが継続可能になる（最低3件成功基準）
