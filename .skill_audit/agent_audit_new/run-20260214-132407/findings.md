## 重大な問題

### C-1: バックアップ作成失敗時の処理欠落 [effectiveness]
- 対象: SKILL.md:Phase 2 Step 4
- 内容: 改善適用前のバックアップコマンド (`cp {agent_path} {agent_path}.backup-...`) の失敗を検出する処理が記述されていない。バックアップ失敗時にエージェント定義の破壊的変更が進行し、ロールバック不能になる
- 推奨: バックアップコマンド実行後にファイル存在確認を追加し、失敗時は「バックアップ作成に失敗しました。改善適用を中止します。」とエラー出力して Phase 3 へ直行する
- impact: high, effort: low

### C-2: データフロー断絶リスク: frontmatter_warning 変数の状態保持 [effectiveness]
- 対象: SKILL.md:Phase 0 → Phase 3
- 内容: Phase 0 で設定される `{frontmatter_warning}` フラグが Phase 3 で参照されるが、Phase 1-2 の長時間サブエージェント処理を経て親コンテキストに確実に保持される保証がない。Phase 3 で警告表示が欠落する可能性がある
- 推奨: Phase 0 で frontmatter 欠落時に `.agent_audit/{agent_name}/frontmatter-warning.txt` を作成し、Phase 3 でファイル存在確認に変更する
- impact: medium, effort: low

### C-3: Phase 0 の再実行時のファイル削除の不完全性 [stability]
- 対象: SKILL.md:114行目
- 内容: `rm -f .agent_audit/{agent_name}/audit-*.md` を実行して既存 findings を削除しているが、`findings-summary.md` と `audit-approved.md` は削除されない。Phase 2 が再実行されない場合（全次元の分析が失敗）、前回実行時の findings-summary.md が残存し、誤読される可能性がある
- 推奨: 114行目の削除コマンドを `rm -rf .agent_audit/{agent_name}/*` に変更し、出力ディレクトリ全体をクリアしてから Phase 1 で再生成する
- impact: medium, effort: low

### C-4: バックアップファイル名の重複チェック [architecture]
- 対象: SKILL.md:263行目
- 内容: バックアップファイル名は `{agent_path}.backup-$(date +%Y%m%d-%H%M%S)` だが、同一秒内で複数回実行した場合にファイルが上書きされるリスクがある。冪等性を保証するため、既存バックアップの存在確認を追加するか、`-n` オプションで上書き回避を指定すべき
- 推奨: バックアップ作成前に同名ファイルの存在を確認し、存在する場合はミリ秒精度のタイムスタンプまたは連番で区別する
- impact: medium, effort: low

### C-5: frontmatter 検証の精度 [architecture]
- 対象: SKILL.md:286行目
- 内容: 検証ステップで「ファイル先頭が `---` で始まり、`description:` を含む」を確認しているが、これは Phase 0 の frontmatter チェックと同じ基準。改善適用後の検証では、編集によって破損した可能性のある構造（YAML 終了マーカー `---` の存在、必須フィールドの形式等）をより詳細に確認すべき
- 推奨: 検証ステップで開始マーカー・終了マーカーの両方の存在、YAML ブロックの閉じ忘れ、description フィールドの値が空でないことを確認する
- impact: medium, effort: low

## 改善提案

### I-1: Phase 2 Step 2a の per-item 承認ループで findings 詳細の参照方法 [efficiency]
- 対象: SKILL.md:Phase 2 Step 2a
- 内容: 各 finding の description/evidence/recommendation は findings-summary.md に含まれていないため、親が audit-*.md を個別に読み込むか、事前に全 findings の詳細を収集する必要がある。collect-findings.md の出力を拡張して詳細も含めれば、1回のファイル参照で完結する
- 推奨: collect-findings.md テンプレートで findings-summary.md に各 finding の description/evidence/recommendation を含めるよう拡張する
- impact: medium, effort: medium
