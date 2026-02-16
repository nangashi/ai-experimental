## 重大な問題

### C-1: 参照整合性: SKILL.md で定義されていない変数参照 [stability, effectiveness]
- 対象: phase1b-variant-generation.md:8-9
- 内容: テンプレートは `{audit_dim1_path}`, `{audit_dim2_path}` を参照しているが、SKILL.md Phase 1B (174行) は `{audit_findings_paths}` のみを定義。変数名の不一致により実行時エラーが発生する
- 推奨: SKILL.md 174行を `{audit_findings_paths}` をカンマ区切りで渡すのではなく、個別の変数 `{audit_dim1_path}` (`.agent_audit/{agent_name}/audit-dim1.md` または空文字列), `{audit_dim2_path}` (`.agent_audit/{agent_name}/audit-dim2.md` または空文字列) に変更する。Glob で見つかった2ファイルを個別に割り当てる（dim1 = audit-dim1.md, dim2 = audit-dim2.md のパターンマッチ）
- impact: high, effort: low

### C-2: 参照整合性: 参照先ファイルパスが実在しない [stability]
- 対象: phase1a-variant-generation.md:10
- 内容: テンプレートは `{perspective_path}` の存在確認を Read で行うが、SKILL.md Phase 0 (60行) では perspective.md は perspective-source.md から生成されるため Phase 1A 開始時点では存在しない可能性が高い
- 推奨: Phase 0 の perspective 解決完了後、`.agent_bench/{agent_name}/perspective.md` の生成を明示的に記載する、または phase1a-variant-generation.md の確認手順を削除する
- impact: high, effort: low

### C-3: 条件分岐の完全性: デフォルト処理が未定義 [stability]
- 対象: SKILL.md Phase 0:51-55
- 内容: reviewer パターンのフォールバック検索で、ファイル名が `*-design-reviewer` または `*-code-reviewer` に一致しない場合の処理が明示されていない
- 推奨: 「一致しない場合はパースペクティブ自動生成（後述）を実行する」を追加する
- impact: high, effort: low

### C-4: 冪等性: 再実行時のファイル重複・破壊 [stability]
- 対象: SKILL.md Phase 1A:144
- 内容: ベースラインが存在しない場合、ベースラインを生成して `v001-baseline.md` に保存するが、既に `v001-baseline.md` が存在する場合（Phase 1A の再実行）の処理が未定義。Write 前に Read で確認する指示がない
- 推奨: Phase 1A 開始前に「`.agent_bench/{agent_name}/prompts/` に既存ファイルがある場合は Phase 1B へ分岐する」を追加する
- impact: high, effort: medium

### C-5: 出力フォーマット決定性: 返答フォーマットが未定義 [stability]
- 対象: SKILL.md Phase 0:66-72
- 内容: エージェント定義が空または不足時の `AskUserQuestion` ヒアリングで、ユーザーからどのようなフォーマットで回答を得るかが未指定。構造化されていない回答では `{user_requirements}` の構成が不安定になる
- 推奨: AskUserQuestion の選択肢または回答フォーマット（「目的:」「入力:」「出力:」「制約:」等のフィールド）を明示する
- impact: high, effort: low

### C-6: ユーザー確認の欠落: perspective 自動生成前の確認なし [ux]
- 対象: SKILL.md Phase 0 Step 3-6
- 内容: 自動生成は高コスト処理（初期生成1回 + 批評4並列 + 再生成最大1回 = 計6タスク）だが、実行前の AskUserQuestion による確認がない
- 推奨: ユーザーの意図しない大規模なリソース消費を防ぐため、実行前に確認を追加する
- impact: high, effort: low

### C-7: エラー通知: Phase 3/4 失敗時の動的情報不足 [ux]
- 対象: SKILL.md Phase 3:237, Phase 4:263
- 内容: AskUserQuestion の選択肢に「再試行/除外/中断」が明記されているが、エラーメッセージに失敗したタスク名・エラー内容・成功/失敗数を含めるべきことが記載されていない
- 推奨: ユーザーが問題の原因を特定し適切な選択肢を選べるよう、エラーメッセージに詳細情報を含める
- impact: high, effort: low

### C-8: エラー通知: Phase 2-6サブエージェント失敗時の通知欠落 [ux]
- 対象: SKILL.md Phase 2, Phase 5, Phase 6A/6B
- 内容: サブエージェント失敗時のエラーメッセージに関する記述がない。Phase 3/4 は失敗処理が定義されているが、他のフェーズでサブエージェントが失敗した場合のユーザー通知方法が不明確
- 推奨: 失敗したフェーズ・原因・対処法をユーザーが把握できるよう、各フェーズに失敗処理フローを追加する
- impact: high, effort: medium

## 改善提案

### I-1: Phase 0 エラー耐性: perspective生成失敗時の処理フロー欠落 [architecture]
- 対象: SKILL.md:66-112
- 内容: 自動生成 Step 1-6 で、Step 3（初期生成）・Step 4（批評）・Step 5（再生成）のいずれかがサブエージェント失敗した場合の処理フロー（リトライ/中断の分岐と判定基準）が未定義
- 推奨: Step 3/5 の生成失敗時は中断、Step 4 の批評失敗時は警告+現行 perspective 維持とする処理フローを追加する
- impact: medium, effort: low

### I-2: Phase 1A/1B バリアント生成失敗時の処理フロー欠落 [architecture]
- 対象: SKILL.md Phase 1A:142-158, Phase 1B:162-176
- 内容: サブエージェント失敗時の処理フロー（リトライ/中断の分岐）が未定義。Phase 2 のテスト文書生成失敗時も同様
- 推奨: 生成系フェーズ（Phase 1A/1B/2）は再試行1回→失敗時は中断とする処理フローを追加する
- impact: medium, effort: low

### I-3: Phase 5 分析レポート失敗時の処理フロー欠落 [architecture]
- 対象: SKILL.md:268-279
- 内容: Phase 5 でサブエージェント失敗時の処理フロー（リトライ/中断の分岐）が未定義。Phase 5 は Phase 4 の採点結果に依存する必須フェーズ
- 推奨: 失敗時は再試行1回→失敗時は中断とする処理フローを追加する
- impact: medium, effort: low

### I-4: Phase 6 ナレッジ更新失敗時の処理フロー欠落 [architecture]
- 対象: SKILL.md:316-352
- 内容: Phase 6 Step 2 で A) ナレッジ更新、B) スキル知見フィードバックのいずれかがサブエージェント失敗した場合の処理フロー（リトライ/続行/中断の分岐）が未定義
- 推奨: A) は knowledge.md 更新が必須のため失敗時は中断、B) は proven-techniques.md 更新が副次的効果のため警告+続行とする処理フローを追加する
- impact: medium, effort: low

### I-5: Phase 3評価実行: デプロイ対象の構造検証欠落 [architecture]
- 対象: SKILL.md Phase 6 Step 1
- 内容: ベースライン以外を選択した場合、haiku サブエージェントがメタデータブロック除去を行うが、除去後のファイル構造（必須セクションの存在確認）を検証する記述がない。エージェント定義ファイルが破損したまま上書きされるリスクがある
- 推奨: Write 後に必須セクションの存在を確認する検証ステップをテンプレート化し、Phase 6 Step 1 に組み込む
- impact: medium, effort: low

### I-6: Phase 0のperspective生成手順の冗長性 [efficiency, ux]
- 対象: SKILL.md:64-112
- 内容: perspective自動生成プロセスは6ステップに分解されているが、各ステップの詳細説明(要件抽出、参照データ収集、批評統合など)はテンプレートファイルに記載すべき。また、各ステップの進捗表示がない
- 推奨: 親は「perspective解決失敗→テンプレート呼び出し→検証」のみに簡略化し、テンプレート呼び出し前後に「perspective 初期生成中...」「批評レビュー実行中（4並列）...」等の進捗テキスト出力を追加する（CONF-1 両立解決）
- impact: high, effort: medium

### I-7: 条件分岐の完全性: 部分失敗時の分岐不足 [stability]
- 対象: SKILL.md Phase 3:229-236
- 内容: 「いずれかのプロンプトで成功結果が0回」の分岐はあるが、「全プロンプト失敗」の極端ケースの処理が明示されていない（AskUserQuestion の選択肢「中断」で対応できるが、自動中止すべきかユーザー確認すべきかが不明瞭）
- 推奨: 「全プロンプト失敗の場合はユーザー確認なしで中断し、Phase 3 失敗を報告する」を追加する
- impact: medium, effort: low

### I-8: 冪等性: 再実行可能性の欠如 [stability]
- 対象: SKILL.md Phase 2-6
- 内容: Phase 3 で一部のプロンプトが成功した後にスキルが中断された場合、再開時に Phase 3 の成功済みタスクを再実行するか、成功結果を再利用するかが未定義
- 推奨: 「Phase 3 開始時、{result_path} が既に存在する場合はスキップする」等の再開ロジックを追加する
- impact: medium, effort: high

### I-9: エッジケース処理記述: Phase 3/4 の再試行後の失敗処理が未定義 [effectiveness]
- 対象: SKILL.md Phase 3:234, Phase 4:262
- 内容: 再試行が1回のみと記載されているが、再試行後も失敗した場合の処理が明記されていない（「再試行: 失敗したタスクのみ再実行する（1回のみ）」の後の分岐がない）
- 推奨: 再試行後も失敗した場合は自動的に「除外」オプションに進むか、再度ユーザー確認を行うかを明記する
- impact: medium, effort: low

---
注: 改善提案を 7 件省略しました（合計 16 件中上位 9 件を表示）。省略された項目は次回実行で検出されます。
