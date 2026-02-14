## 重大な問題

### C-1: Phase 2 Step 1 における長いインライン指示 [architecture]
- 対象: SKILL.md:182-196
- 内容: Phase 2 Step 1 のサブエージェント指示が15行のインラインブロックで記述されている。7行超の指示はテンプレートに外部化すべき
- 推奨: テンプレートファイルに外部化し、「Read template + path variables」パターンに統一する
- impact: medium, effort: low

## 改善提案

### I-1: Phase 1 サブエージェントの common-rules.md 参照の重複 [efficiency]
- 対象: 各次元エージェント定義
- 内容: 全7個の次元エージェント定義ファイルが common-rules.md（44行）を参照している。Phase 1 で 3-5 個のサブエージェントが並列起動されるため、各サブエージェントが同一の common-rules.md を重複して読み込む（推定節約量: 約44行 × サブエージェント数 = 132-220行/実行）
- 推奨: common-rules の内容を親から各サブエージェントのプロンプトに埋め込むか、または Task パラメータで渡す設計に変更する
- impact: high, effort: medium

### I-2: Phase 2 Step 1 の haiku サブエージェントの返答長制約不足 [efficiency]
- 対象: SKILL.md:182-195
- 内容: Phase 2 Step 1 の findings 収集サブエージェントの返答フォーマットはテーブル形式（可変長）。findings が多数ある場合（30件以上）、テーブル全体が親コンテキストに保持される（推定節約量: 可変、findings 件数に依存）
- 推奨: 返答を「total, critical, improvement の件数のみ」に制限し、詳細はファイルに保存させる設計に変更する。Phase 2 Step 2 での表示は親が当該ファイルを Read する
- impact: high, effort: medium

### I-3: Phase 2 Step 4 のサブエージェント失敗時処理の欠落 [effectiveness]
- 対象: Phase 2 Step 4
- 内容: サブエージェントが改善適用に失敗した場合の処理が記述されていない。検証ステップは適用後の構造検証のみを行い、適用自体の失敗（サブエージェントのエラー、Edit 失敗等）に対するエラーハンドリングが存在しない。失敗時に検証ステップが実行されると、適用が部分的に完了した状態でのバックアップ指示のみが表示され、ユーザーが状況を把握できない
- 推奨: AskUserQuestion でリトライまたは中止の確認をするか、エラー検出時のロールバック自動実行を追加する
- impact: high, effort: medium

---
注: 改善提案を 4 件省略しました（合計 8 件中上位 4 件を表示）。省略された項目は次回実行で検出されます。
