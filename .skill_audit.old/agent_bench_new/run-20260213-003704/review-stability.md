### 安定性レビュー結果

#### 重大な問題
- [参照整合性: 未定義変数の使用]: [SKILL.md] [line 62] `{existing_perspectives_summary}` → サブエージェントに渡されるが、phase0-perspective-resolution.md テンプレート内で使用されていない [impact: medium] [effort: low]
- [出力フォーマット決定性: 採点サブエージェント返答の曖昧性]: [phase4-scoring.md] [line 11-12] サマリ出力で "Mean={X.X}, SD={X.X}" の有効桁数が曖昧。一方で実際の例は小数第1位だが、他箇所では第2位が使われている → 統一された桁数指定が必要（例: "Mean={X.XX}（小数第2位まで）"） [impact: medium] [effort: low]
- [参照整合性: 存在しないセクション参照]: [phase6-extract-top-techniques.md] [line 6] `## 効果テーブル` セクションを参照しているが、knowledge-init-template.md で初期化される knowledge.md には「## 効果が確認された構造変化」「## 効果が限定的/逆効果だった構造変化」セクションのみが存在し、`## 効果テーブル` セクションが存在しない → phase6a-knowledge-update.md で効果テーブルが生成されることが前提だが、テンプレートに明記されていない [impact: high] [effort: medium]
- [条件分岐の完全性: 存在確認なしの Read]: [phase0-perspective-validation.md] [line 8-9] 必須セクション確認で "# パースペクティブ" または "# Perspective" および "## 評価観点" または "## Evaluation Criteria" を確認しているが、実際の perspective ファイルには "## 概要"、"## 評価スコープ"、"## スコープ外" が存在する（line 82参照: phase0-perspective-generation.md）。セクション名の不一致により検証失敗の可能性 [impact: high] [effort: low]
- [冪等性: ファイル存在確認の欠如]: [phase1a-variant-generation.md, phase1b-variant-generation.md] Phase 1A/1B でプロンプトファイルの上書き確認は SKILL.md で実施されるが、テンプレート内で Write 前に既存ファイルの Read 確認指示がない。サブエージェントが独立して再実行された場合、既存ファイルの意図しない上書きが発生する可能性 [impact: low] [effort: low]

#### 改善提案
- [指示の具体性: 曖昧な基準表現]: [phase1a-variant-generation.md] [line 14] 「構造分析のギャップに基づき、approach-catalog.md からギャップが大きい次元の2つの独立変数を選定する」→ 「ギャップが大きい」の定義が不明確。具体的な基準（例: 「ギャップ列の値が "大" または数値で最大の2次元」）を明示すべき [impact: medium] [effort: low]
- [参照整合性: パス変数の命名不統一]: [SKILL.md] [line 62] `{existing_perspectives_summary}` はテンプレートで使用されていないが、親で生成されている。命名ミスまたは使用予定の変数が未実装の可能性。使用しない場合は削除すべき [impact: low] [effort: low]
- [指示の具体性: "最大N行"の解釈曖昧性]: [phase6a-knowledge-update.md] [line 21-26] 「改善のための考慮事項」の削除基準で「20行を超える場合」の "行" の定義が不明確。リストアイテム数を意味するのか、実際のMarkdown行数を意味するのか明確にすべき [impact: low] [effort: low]
- [出力フォーマット決定性: エラーメッセージのフォーマット不統一]: [SKILL.md] [line 77-84, 94] エラーメッセージが複数フェーズで記述されているが、フォーマットが統一されていない（見出し "エラー:" の有無、箇条書き形式の違い）→ 統一テンプレート化を推奨 [impact: low] [effort: medium]
- [条件分岐の完全性: audit統合の個別選択フロー詳細不足]: [SKILL.md] [line 183-184] 「個別選択」時に各項目を承認/却下する処理が記述されているが、承認項目をサブエージェントに渡す具体的な方法（ファイル経由 or 引数）が明記されていない [impact: medium] [effort: medium]
- [指示の具体性: "再実行"の具体性欠如]: [phase0-perspective-generation.md] [line 78] 「フィードバックを `{user_requirements}` に追記し、Step 3 と同じパターンで perspective を再生成する（1回のみ）」→ "同じパターン" が具体的にどのサブエージェントを指すか曖昧（generate-perspective.md or phase0-perspective-generation-simple.md?）。明示的なテンプレート名を指定すべき [impact: low] [effort: low]
- [冪等性: 再実行時の累計ラウンド数管理]: [SKILL.md] Phase 6 で累計ラウンド数を +1 更新するが、Phase 2 以降で失敗して再開した場合の累計数管理ルールが不明確。累計数の決定タイミング（Phase 0 終了時 or Phase 6 完了時）を明記すべき [impact: medium] [effort: medium]

#### 良い点
- [参照整合性: サブエージェント間のファイル経由データ受け渡し]: 全フェーズでサブエージェント間のデータ受け渡しがファイル経由で行われ、親コンテキストの肥大化を防いでいる
- [出力フォーマット決定性: サブエージェント返答行数の明示]: 各サブエージェントの返答行数・フィールド名が SKILL.md のサブエージェント一覧（G. サブエージェント一覧）で明示され、親がパース可能な形式になっている
- [条件分岐の完全性: Phase 3 エラーハンドリングの詳細分岐]: phase3-error-handling.md で全失敗・部分失敗・バリアント全失敗の4パターンが網羅され、else節も明示されている
