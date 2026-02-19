### 安定性レビュー結果

#### 重大な問題
- [参照整合性: 未定義変数の使用]: [SKILL.md] [line 105] `{reference_agent_path}` が定義されているが、line 12 の検出モードのパース例に "new" のハンドリングが不明確 → 明示的に「detection モードでは新規作成時も .claude/agents/ 配下を参照」と記載する [impact: medium] [effort: low]
- [条件分岐の完全性: else節不在]: [SKILL.md] [line 137] scenario モードで test-set.md 存在時は Phase 3 へスキップするが、detection モードの Phase 2 実行条件が「毎ラウンド実行」のみで、ファイル存在時の重複生成防止処理がない → 「detection モードでは test-document-round-{NNN}.md の存在確認を行い、存在すれば Phase 3 へ」と明記 [impact: high] [effort: low]
- [冪等性: ファイル重複生成のリスク]: [templates/phase1b-variant-generation.md] [line 14] バリアントファイル保存前に既存ファイルの存在確認がない。再実行時に同じラウンド番号で上書きされるが、ラウンド番号インクリメントのタイミングが Phase 6A のため、Phase 1B 失敗再実行時に重複の可能性 → 「既存ファイル確認後、存在すればエラー」または「Phase 0 でラウンド番号を確定してからプロンプトファイル生成」を明記 [impact: medium] [effort: medium]
- [出力フォーマット決定性: 行数不定]: [templates/phase1a-variant-generation.md] [line 9-24] 返答フォーマットが「構造分析結果」テーブルの行数を指定していない → 「6行（見出し数、サブ項目粒度、出力形式詳細度、原則/制約の明示度、具体例の有無、スコアリング基準の有無）」と明記 [impact: low] [effort: low]
- [条件分岐の完全性: 部分完了時の処理未定義]: [SKILL.md] [line 226-230] Phase 3 で「評価完了: {成功数}/{総数}」と報告するが、成功数 < 総数 の場合の後続処理（Phase 4 へ進むのか、エラー終了か、部分的に採点か）が未定義 → 「成功数 < 総数 の場合は、成功したタスクのみを Phase 4 で採点する。失敗したタスクについてはユーザーに通知」を明記 [impact: high] [effort: low]

#### 改善提案
- [指示の具体性: 曖昧表現]: [SKILL.md] [line 54] 「不足要素がある場合は AskUserQuestion でヒアリングする」→ 「不足要素（目的/ロール定義、実行基準、出力ガイドライン、行動姿勢）がある場合は、その不足要素を列挙し AskUserQuestion でヒアリングする」に変更 [impact: low] [effort: low]
- [指示の具体性: 曖昧表現]: [templates/phase1a-variant-generation.md] [line 7] 「ギャップが大きい次元の2つの独立変数を選定」→ 「ギャップスコアが最大の上位2次元から各1つの独立変数を選定」に変更 [impact: medium] [effort: low]
- [参照整合性: ファイルパス実在確認]: [SKILL.md] [line 105] `{reference_agent_path}` が `.claude/agents/security-design-reviewer.md` を指すが、このファイルの実在確認が必要 → Glob で確認し、存在しない場合は別の参考ファイルを使用するか、エラー通知 [impact: low] [effort: medium]
- [冪等性: 再実行時の状態整合性]: [templates/phase6a-knowledge-update.md] [line 8-14] 累計ラウンド数を +1 するが、Phase 6A が複数回実行された場合（Phase 6B 失敗後の再実行等）に重複カウントの可能性 → 「ラウンド別スコア推移テーブルの最終行のラウンド番号 + 1 を累計ラウンド数とする」を明記 [impact: low] [effort: low]
- [出力フォーマット決定性: フィールド順序不定]: [templates/phase5-analysis-report.md] [line 18-26] 7行サマリのフィールド順序は指定されているが、各フィールドの値の形式（特に variants の「変更内容要約」の文字数制限）が未指定 → 「variants: 各バリアントの変更内容要約は最大20単語」を追加 [impact: low] [effort: low]
- [条件分岐の完全性: デフォルト処理不在]: [templates/phase1b-variant-generation.md] [line 8-11] バリアント選定の条件分岐で、全ての UNTESTED が枯渇した場合の処理が未定義 → 「全バリエーションが TESTED の場合は、最も効果が高かった EFFECTIVE バリエーションの派生（カタログにない新規バリエーション）を生成する」を追加 [impact: medium] [effort: high]
- [指示の具体性: 判断基準不明]: [SKILL.md] [line 294] 収束判定で「該当する場合は『最適化が収束した可能性あり』を付記」→ scoring-rubric.md の収束判定基準を SKILL.md にも明記、または「scoring-rubric.md の Section 3 に従って収束判定を行う」と参照先を明示 [impact: low] [effort: low]

#### 良い点
- [冪等性: ファイル存在確認]: [SKILL.md] [line 72-74] knowledge.md の存在確認により初回/継続を判定し、冪等性を保証している
- [参照整合性: パス変数の一貫性]: 全テンプレートで `{variable}` プレースホルダが SKILL.md のパス変数リストと一致しており、参照漏れがない
- [出力フォーマット決定性: サブエージェント返答の構造化]: Phase 5 の7行サマリ、Phase 4 のスコアサマリ、Phase 6A/6B の確認メッセージが明確に指定されており、親が解析しやすい
