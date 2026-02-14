### アーキテクチャレビュー結果

#### 重大な問題
なし

#### 改善提案
- [外部スキルディレクトリへの直接参照]: SKILL.md 161行目と templates/phase1b-variant-generation.md 11行目で `.agent_audit/{agent_name}/audit-*.md` を直接参照している。agent_audit スキルの実行状態に依存する設計となっており、agent_bench_new 単独での再現性・可搬性が低下する。[推奨パターン] agent_audit の結果をスキル内にコピーするか、パス変数として明示的に受け取る設計に変更する [impact: medium] [effort: medium]

- [Phase 0 の perspective 検証ロジックの欠落]: Phase 0 最終ステップで perspective.md の必須セクション検証が実行される記述が SKILL.md に存在しない。templates/phase0-perspective-generation.md と phase0-perspective-generation-simple.md には検証ステップが記載されているが、SKILL.md 本体には「Step 4 作業コピー作成まで」の記載しかない。perspective.md が不完全な状態で Phase 1 以降に進む可能性がある [推奨パターン] SKILL.md の Phase 0 に「perspective.md の必須セクション検証ステップ」を明示的に追加する [impact: medium] [effort: low]

- [Phase 3 のエラーハンドリング実行方法が曖昧]: SKILL.md 224行目で「templates/phase3-error-handling.md を Read で読み込み、その内容に従ってエラーハンドリングを実行する」とあるが、親が直接実行するのか、サブエージェントに委譲するのかが不明確。phase3-error-handling.md は分岐ロジックを記述した参照ドキュメントであり、サブエージェントへの指示テンプレートではない。AskUserQuestion を含む処理であるため親が実行すべきだが、記述が曖昧 [推奨パターン] 「親が Read で phase3-error-handling.md の分岐ロジックを参照し、条件に応じて AskUserQuestion と処理分岐を実行する」と明示する [impact: low] [effort: low]

- [Phase 4 のエラーハンドリングの一部がインライン記述]: SKILL.md 248-255行目の Phase 4 失敗時の処理分岐ロジックが8行のインラインブロックで記述されている。phase3-error-handling.md のように外部テンプレート化されていない。Phase 3 と Phase 4 のエラーハンドリングパターンに一貫性がない [推奨パターン] templates/phase4-error-handling.md を作成し、Phase 3 と同様に外部化する [impact: low] [effort: medium]

- [Phase 6 ステップ2の並列実行順序が不明瞭]: SKILL.md 302-343行目で「A) ナレッジ更新の完了を待ってから B) proven-techniques 更新と C) 次アクション選択を並列実行」とあるが、C) の結果に応じて Phase 1B ループまたは終了に分岐する記述があり、B) の完了を待つ理由が不明確。B) は警告出力で続行する任意処理であるため、C) の分岐判定に B) の結果は不要。並列実行の意図と実行順序の設計根拠が曖昧 [推奨パターン] B) と C) を完全に並列実行し、C) の分岐前に B) の完了を待つ必要性を明記するか、または B) を完全に非同期タスク（バックグラウンド実行）として切り離す [impact: low] [effort: low]

- [最終成果物の構造検証が部分的]: perspective.md に対しては必須セクション検証がテンプレートに記載されているが、knowledge.md、prompts/{variant}.md、reports/{round}-comparison.md 等の他の最終成果物に対する構造検証の記述がない。特に knowledge.md は Phase 6A で更新されるが、更新後のセクション存在確認やフィールド検証の記述が欠落している [推奨パターン] knowledge.md 更新後の検証ステップを phase6a-knowledge-update.md に追加する。プロンプトファイルの Benchmark Metadata ブロック検証を phase1a/1b テンプレートに追加する [impact: low] [effort: medium]

- [Phase 6 ステップ1のサブエージェント返答形式が不明確]: SKILL.md 280-288行目で phase6-performance-table.md の返答が「選択されたプロンプト名（ベースライン or バリアント名）」とあるが、テンプレート自体は性能推移テーブル生成のみを指示しており、プロンプト選択ロジックが記載されていない。AskUserQuestion による選択は親が実行すべきだが、サブエージェントとの役割分担が曖昧 [推奨パターン] phase6-performance-table.md をテーブル生成専用に変更し、親が AskUserQuestion でプロンプト選択を実行するよう SKILL.md を修正する [impact: low] [effort: low]

#### パターン準拠サマリ
| パターン | 状態 | 備考 |
|---------|------|------|
| テンプレート外部化 | 準拠 | 全 Phase で「Read template + follow instructions + path variables」パターンを採用。Phase 4 の失敗時分岐ロジック（8行）のみインライン記述だが、7行超のため外部化推奨 |
| サブエージェント委譲 | 準拠 | 全 Phase でサブエージェント委譲を使用。モデル指定も適切（sonnet: 判断/生成、haiku: Phase 6 デプロイのみ） |
| ナレッジ蓄積 | 準拠 | 反復ループありで knowledge.md と proven-techniques.md による2層蓄積を実装。サイズ制限（knowledge.md: 20行、proven-techniques.md: セクション別上限）と保持+統合方式を採用 |
| エラー耐性 | 部分的 | Phase 0-6 全体で失敗時の処理フローを定義。Phase 3 はテンプレート外部化、Phase 4 はインライン記述で一貫性に欠ける。並列実行時の部分失敗も対応済み |
| 成果物の構造検証 | 部分的 | perspective.md の必須セクション検証は存在するが、knowledge.md、プロンプトファイル、レポート等の他の成果物に対する検証記述が欠落 |
| ファイルスコープ | 部分的 | スキルディレクトリ外の `.agent_audit/{agent_name}/` への直接参照が存在。agent_audit スキルへの暗黙的依存を発生させている |

#### 良い点
- 全 Phase で「Read template + follow instructions + path variables」パターンを一貫して使用し、親のコンテキスト節約原則を徹底している
- knowledge.md の有界サイズ管理（20行制限、統合/削除ルール）と proven-techniques.md の3層構造（実証済み/アンチパターン/条件付き）による知見蓄積設計が優れている
- Phase 3/4 の並列実行時の部分失敗に対するエラーハンドリングが詳細に定義されており（ベースライン成功/失敗の分岐、再試行/除外/中断の選択肢）、実運用での堅牢性が高い
