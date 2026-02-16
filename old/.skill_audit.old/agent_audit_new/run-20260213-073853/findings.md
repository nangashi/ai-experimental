## 重大な問題

### C-1: SKILL.md超過 [efficiency]
- 対象: SKILL.md
- 内容: SKILL.md が369行で目標値（250行以下）を119行超過している。Phase 2の詳細な手順記述（特にStep 2a: Per-item承認の詳細フロー）が親コンテキストを消費している
- 推奨: Phase 2の詳細な手順記述をテンプレートに外部化する
- impact: medium, effort: medium

### C-2: 検証ステップの冗長性 [efficiency]
- 対象: SKILL.md:320-341, templates/validate-agent-structure.md
- 内容: 検証ステップの詳細がSKILL.mdとテンプレートの両方に記述されており、SKILL.mdでは検証詳細を保持する必要がない（サブエージェント委譲時の返答パース情報のみで十分）
- 推奨: SKILL.mdから検証詳細を削除し、テンプレートに一元化する
- impact: medium, effort: low

### C-3: 参照整合性: 未定義変数の使用 [stability]
- 対象: SKILL.md:328
- 内容: `{analysis_path}` プレースホルダが validate-agent-structure.md テンプレートに渡されているが、analysis.md が存在しない場合の挙動が不明確。Phase 2 検証ステップで "存在する場合のみ" と記載されているが、実際の渡し方（条件分岐の実装方法）が未指定
- 推奨: 具体的に「analysis.md が存在する場合は `- {analysis_path}: ...` を含める、存在しない場合はこの行を省略する」と明記する
- impact: high, effort: low

### C-4: 出力フォーマット決定性: サブエージェント返答の曖昧さ [stability]
- 対象: templates/apply-improvements.md:36-42
- 内容: サブエージェントの返答が「上限: 30行以内」となっているが、上限を超える場合の処理（切り捨て? エラー? 要約?）が未指定
- 推奨: 「30行を超える場合は重要度順に上位30行まで記載」等の明示的ルールを追加する
- impact: medium, effort: low

### C-5: 条件分岐の完全性: else節の欠落 [stability]
- 対象: SKILL.md:265-268
- 内容: Phase 2 Step 1 の整合性チェックで「存在する場合は」エラー出力とあるが、存在しない（正常）場合の処理が未記述
- 推奨: 「存在しない場合は次のステップへ進む」と明記する
- impact: medium, effort: low

### C-6: 冪等性: 既存ファイル上書き時のバックアップ不備 [stability]
- 対象: SKILL.md:163-167
- 内容: Phase 1 で既存 findings ファイルを `.prev` でバックアップするが、`.prev` 自体が既に存在する場合の処理が未指定（2回目の実行で前回のバックアップが上書きされる）
- 推奨: タイムスタンプ付きバックアップ（`.prev-{timestamp}`）に変更、または「.prev が既に存在する場合は .prev.1, .prev.2 とナンバリング」等の明示的ルールを追加する
- impact: high, effort: medium

### C-7: 参照整合性: ファイル実在確認の欠落 [stability]
- 対象: SKILL.md:102-106
- 内容: classify-agent-group.md テンプレートで `{classification_guide_path}` として `group-classification.md` を参照しているが、このファイルの実在確認（Read 失敗時の処理）が SKILL.md に記載されていない
- 推奨: Phase 0 Step 4 の前に「Bash で group-classification.md の存在確認を実行し、不在時はエラー出力して終了」を追加する
- impact: high, effort: low

## 改善提案

### I-1: findings-summary.md の生成が完全にサブエージェント委譲されている [architecture]
- 対象: SKILL.md Phase 2 Step 1
- 内容: collect-findings.md サブエージェントが findings-summary.md を生成するが、親は total/critical/improvement の件数のみを抽出し、findings の詳細を読み込まない。Step 2 で一覧提示するために findings-summary.md を Read する処理が SKILL.md に記載されていないため、テキスト出力（SKILL.md:272-279）が実現できない可能性がある
- 推奨: Phase 2 Step 1 完了後に findings-summary.md を Read する処理を明示的に追加する
- impact: high, effort: low

### I-2: データフロー: analysis_path 存在判定が未定義 [effectiveness, architecture]
- 対象: SKILL.md:328, Phase 2 検証ステップ
- 内容: `{analysis_path}` を "存在する場合のみ" 渡すと記載されているが、存在判定のロジック（いつ・どこで・どのように analysis.md の存在を確認するか）が SKILL.md に記述されていない。validate-agent-structure.md はオプショナルパラメータとして受け取れる設計だが、SKILL.md 側で「Bash で test -f .skill_audit/{skill_name}/run-{timestamp}/analysis.md を実行し、存在する場合のみパス変数に含める」等の明示的な手順が必要
- 推奨: Phase 2 検証ステップの前に明示的な存在判定ロジックを追加する
- impact: medium, effort: low

### I-3: Phase 1 部分失敗時の継続判定ロジックが長い [architecture]
- 対象: SKILL.md:209-217
- 内容: 10行を超える複雑な条件分岐がインライン記述されている。部分失敗時の継続判定ルール（IC成功 or 成功数≧2の判定、fast mode 分岐、AskUserQuestion 設計）が詳細に記述されている
- 推奨: この部分をテンプレート（例: templates/phase1-failure-handling.md）に外部化することで、SKILL.md の行数削減と可読性向上を図る
- impact: medium, effort: medium

### I-5: エッジケース: グループ分類サブエージェント失敗時の処理が未定義 [effectiveness]
- 対象: SKILL.md:100-107, Phase 0 Step 4
- 内容: グループ分類をサブエージェントに委譲しているが、サブエージェント失敗時（Task 失敗、返答フォーマット不正、agent_group/reasoning 抽出失敗）の処理が記述されていない。現状では unhandled exception となる可能性がある
- 推奨: 失敗時は「グループ分類に失敗しました。手動でグループを選択してください」として Step 5 の手動変更フローへ誘導するか、デフォルトグループ（unclassified）にフォールバックする処理を追加する
- impact: medium, effort: low

### I-6: Phase 3 の完了サマリが詳細すぎる [architecture]
- 対象: SKILL.md:345-369
- 内容: 完了サマリが複数の条件分岐（Phase 2 スキップ時/実行時、validation 失敗時、スキップされた critical findings 等）を含み、複雑な出力ロジックとなっている
- 推奨: この部分をテンプレート（例: templates/generate-completion-summary.md）に外部化することで、SKILL.md の行数削減と可読性向上を図る
- impact: medium, effort: medium

### I-7: 出力フォーマット決定性: 件数取得失敗時の処理不足 [stability]
- 対象: SKILL.md:199, Phase 2 Step 1
- 内容: 「抽出失敗時は『件数取得失敗』として記録し、Phase 2 Step 1 で findings ファイルから直接件数を再取得する」とあるが、Phase 2 Step 1 には findings ファイルから件数を抽出する指示が存在しない（collect-findings.md サブエージェントに委譲されているため、親が直接抽出する処理がない）
- 推奨: collect-findings.md テンプレートに「各 finding から critical/improvement を集計し、total/critical/improvement 件数をカウントする」指示を明記する
- impact: medium, effort: low

### I-8: 進捗可視性: Phase 1の並列タスク進捗情報の欠落 [ux]
- 対象: Phase 1
- 内容: 並列サブエージェント実行時に完了数がリアルタイムで表示されない。Task完了後に一覧表示されるが、実行中は「{dim_count}次元を並列分析中...」のメッセージのみで、何次元が完了したかがわからない
- 推奨: 並列実行時の進捗感を向上させるため、各サブエージェント完了時に「✓ {次元名} 完了」をリアルタイム出力する記述を追加する
- impact: medium, effort: low

### I-9: 進捗可視性: Phase 2 Step 4の改善適用中の詳細進捗欠落 [ux]
- 対象: Phase 2 Step 4
- 内容: 「改善を適用中（対象: {承認数}件）...」の後、サブエージェント処理が完了するまで進捗更新がない。承認数が多い場合（5件以上）、ユーザーは処理が停止したと誤解する可能性がある
- 推奨: サブエージェントに進捗メッセージ出力を指示するか、親が段階的な進捗（「N件目を処理中...」等）を出力する仕組みを追加する
- impact: medium, effort: medium

---
注: 改善提案を 11 件省略しました（合計 20 件中上位 9 件を表示）。省略された項目は次回実行で検出されます。
