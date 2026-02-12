### アーキテクチャレビュー結果

#### 重大な問題
なし

#### 改善提案
- [Phase 3 シナリオ評価のインライン指示（SKILL.md L188-198、11行）]: テンプレート外部化を推奨。Phase 3 の scenario 評価指示は11行と長く、7行閾値を超過している。独立したテンプレートファイル（phase3-scenario-eval.md）に外部化し、「Read template + follow instructions + path variables」パターンに統一すべき [impact: low] [effort: low]

- [Phase 3 detection 評価のインライン指示（SKILL.md L204-213、10行）]: テンプレート外部化を推奨。Phase 3 の detection 評価指示は10行と長く、7行閾値を超過している。独立したテンプレートファイル（phase3-detection-eval.md）に外部化し、「Read template + follow instructions + path variables」パターンに統一すべき [impact: low] [effort: low]

- [Phase 6 Step 1 デプロイのインライン指示（SKILL.md L300-306、7行）]: インライン化またはテンプレート外部化の判断が境界線上。7行ちょうどで、単純なファイル操作（Read→メタデータ除去→Write）のため haiku サブエージェントに委譲されている。ただし、メタデータ除去の詳細（正規表現パターン等）が明示されていない。処理が単純ならインライン化（5行以下に圧縮）、処理が複雑なら外部化してパターンを明記すべき [impact: low] [effort: low]

- [Phase 3 のエラー耐性フローが不十分]: Phase 3 で並列実行の部分失敗時の処理フローが「{成功数}/{総数} タスク成功」の報告のみで、続行/中止の判定基準と処理フローが明示されていない。例えば「3/6タスク成功（50%未満）」の場合に Phase 4 採点を続行するか中止するかの基準が不明。推奨: 成功率 < 50% で中止、50-80% で警告付き続行、80%+ で正常続行のような閾値ベースの判定基準を定義すべき [impact: medium] [effort: medium]

- [Phase 2 scenario のテストセット承認が単一確認]: Phase 2 scenario で生成されたテストセット全体を AskUserQuestion で一括承認する設計（SKILL.md L150）。品質基準 Section 3 の「提案ごとの個別承認」に照らすと、シナリオが5-8個ある場合に全承認/全却下の二択になる。推奨: サブエージェントがシナリオごとの表形式サマリを提示し、ユーザーが修正要求するシナリオを選択できる対話フローに変更すべき [impact: low] [effort: medium]

- [Phase 2 detection のテスト文書承認が欠落]: Phase 2 detection ではテスト対象文書と正解キーを毎ラウンド生成するが、ユーザー承認プロセスがない（SKILL.md L152-167）。scenario モードは承認があるが、detection モードには承認ステップがない。問題の埋め込み状況や難易度バランスをユーザーが確認できるよう、Phase 2 完了後に「テスト文書サマリ（埋め込み問題一覧、ドメイン、行数）」を提示し、AskUserQuestion で承認を得る処理を追加すべき [impact: medium] [effort: low]

- [Phase 0 scenario の新規作成時ヒアリングが一括]: Phase 0 scenario 新規作成モードで「目的・役割、入力と出力、使用ツール・制約」を1回の AskUserQuestion で全て収集している（SKILL.md L49-53）。品質基準 Section 3 の「提案ごとの個別承認」に照らすと、複数要素を同時に確認する一括方式。推奨: 各要素を段階的にヒアリングする設計に変更し、ユーザーが要素ごとに明確に回答できるようにすべき [impact: low] [effort: medium]

#### パターン準拠サマリ
| パターン | 状態 | 備考 |
|---------|------|------|
| テンプレート外部化 | 部分的 | Phase 3 と Phase 6 Step 1 に7行以上のインライン指示が3箇所存在（11行、10行、7行）。その他の主要処理は全てテンプレート外部化済み |
| サブエージェント委譲 | 準拠 | 全サブエージェントで「Read template + follow instructions + path variables」パターンを一貫使用。モデル選択は適切（Phase 0/1/2/4/5/6A/6B=sonnet、Phase 6 Step 1 デプロイ=haiku） |
| ナレッジ蓄積 | 準拠 | 反復最適化ループあり。knowledge.md で知見蓄積（有界サイズ: 各テーブル行数上限、「改善のための考慮事項」最大20行）。保持+統合方式採用（phase6a-knowledge-update.md L16-22: 既存原則保持+統合、削除は根拠が弱い場合のみ） |
| エラー耐性 | 部分的 | Phase 0 のファイル不在処理は適切。Phase 3 並列実行の部分失敗時に続行/中止の判定基準と処理フローが未定義。サブエージェント失敗時のフォールバック処理も明示されていない |
| 批判的レビュー | 部分的 | Phase 2 scenario でテストセット承認あり。Phase 5 で推奨判定・収束判定あり。ただし Phase 2 detection ではテスト文書承認が欠落。生成されたプロンプト自体の構造検証（必須セクション存在確認等）は未実装 |
| ファイルスコープ | 準拠 | スキルディレクトリ内のファイル参照に統一済み。perspectives/ ディレクトリと templates/ ディレクトリは全て .claude/skills/agent_create/ 配下に存在。作業ディレクトリ（prompt-improve/）への出力は正常なスキル動作。外部参照なし |

#### 良い点
- [テンプレート外部化の一貫性]: Phase 0 初期化、Phase 1A/1B バリアント生成、Phase 2 テスト生成、Phase 4 採点、Phase 5 分析、Phase 6A/6B ナレッジ更新の全主要処理がテンプレートファイルに外部化され、「Read template + follow instructions + path variables」パターンを一貫使用している

- [ナレッジ蓄積の多層設計]: knowledge.md（エージェント単位の知見）と proven-techniques.md（スキル横断の知見）の2層構造で知見を管理し、phase6b-proven-techniques-update.md で昇格条件（Tier 1: 即時昇格、Tier 2: 条件付き、Tier 3: 昇格なし）を明確に定義。サイズ制限（Section 1/2: 最大8件、Section 3: 最大7件）と統合ルール（preserve + integrate）により、有界サイズと保持+統合方式を実現している

- [eval_mode 分岐の明示的設計]: scenario / detection の2モードを単一スキルで実現し、Phase 0 で eval_mode を判定後、各フェーズで mode 固有の処理を明示的に分岐している（Phase 2: テスト生成、Phase 4: 採点基準）。テンプレートファイル内でもモード別セクション見出しで明確に分岐しており、統一ワークフローの模範例
