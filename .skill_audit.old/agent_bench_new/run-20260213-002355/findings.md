## 重大な問題

### C-1: Phase 0 → Phase 1A の user_requirements 参照不整合 [effectiveness]
- 対象: SKILL.md Phase 0, Phase 1A, templates/phase1a-variant-generation.md
- 内容: Phase 0 ステップ2で「ファイルが実質空の場合、AskUserQuestion で要件をヒアリングし `{user_requirements}` としてメモリに保持する」とあるが、SKILL.md の Phase 1A セクション（行124-136）ではパス変数として `{user_requirements}` が定義されていない。テンプレート (phase1a-variant-generation.md) は `{user_requirements}` の存在を前提としているが、親がこの変数を提供する記述が SKILL.md に欠落している
- 推奨: Phase 1A のパス変数リストに `{user_requirements}` を追加し、Phase 0 でヒアリングした要件テキストをサブエージェントに渡す処理を明示する
- impact: high, effort: low

### C-2: Phase 5 の scoring_file_paths の生成方法が不明 [effectiveness]
- 対象: SKILL.md Phase 4, Phase 5
- 内容: SKILL.md 行267では「`{scoring_file_paths}`: Phase 4 で保存された採点ファイルのパス一覧」とあるが、Phase 4 のセクション（行233-256）ではサブエージェントの返答が「スコアサマリ」のテキスト出力のみで、親がどのようにファイルパス一覧を構築するかの記述がない。Phase 4 のサブエージェントは各プロンプトの採点結果を `{scoring_save_path}` に保存するが、親がこれを収集して Phase 5 に渡すプロセスが明示されていない
- 推奨: Phase 4 セクションに「サブエージェント完了後、親が `{scoring_save_path}` のパスを配列に追加し、全プロンプトの採点完了後に `{scoring_file_paths}` を構築する」処理を明示する
- impact: high, effort: low

### C-3: 未定義変数 user_requirements [stability]
- 対象: SKILL.md 41行目
- 内容: `{user_requirements}`変数がPhase 0でメモリに保持されるとあるがパス変数リストに未定義。Phase 0 のパス変数リストに存在しない
- 推奨: Phase 0のパス変数リストに`{user_requirements}: Phase 0でヒアリングした要件テキスト（エージェント定義が不足時のみ設定）`を追加する
- impact: high, effort: low

### C-4: phase3-error-handling.md の参照整合性 [stability]
- 対象: SKILL.md 224行目
- 内容: `templates/phase3-error-handling.md`を参照しているが、これは手順書でありサブエージェントテンプレートではない。親が直接Readして分岐ロジックを実行すべきだが、サブエージェント委譲のように記述されている
- 推奨: Phase 3のワークフローを「全サブエージェント完了後、Read で templates/phase3-error-handling.md を読み込み、その内容の分岐ロジックに従ってエラーハンドリングを実行する（親が実行）」と明示する
- impact: high, effort: medium

### C-5: SKILL.md 行数超過 [efficiency]
- 対象: SKILL.md
- 内容: 362行で目標250行を大幅超過（約112行分の浪費）。主に冗長な説明テキストとサブエージェント失敗時のエラーメッセージ記述が原因
- 推奨: Phase 0-6 の手順詳細をテンプレートに外部化し、SKILL.md は「テンプレート読み込み + パス変数」のみに簡素化
- impact: high, effort: medium

## 改善提案

### I-1: 外部スキルディレクトリへの直接参照 [architecture]
- 対象: SKILL.md 161行目, templates/phase1b-variant-generation.md 11行目
- 内容: `.agent_audit/{agent_name}/audit-*.md` を直接参照している。agent_audit スキルの実行状態に依存する設計となっており、agent_bench_new 単独での再現性・可搬性が低下する
- 推奨: agent_audit の結果をスキル内にコピーするか、パス変数として明示的に受け取る設計に変更する
- impact: medium, effort: medium

### I-2: Phase 0 の perspective 検証ロジックの欠落 [architecture]
- 対象: SKILL.md Phase 0
- 内容: Phase 0 最終ステップで perspective.md の必須セクション検証が実行される記述が SKILL.md に存在しない。templates/phase0-perspective-generation.md と phase0-perspective-generation-simple.md には検証ステップが記載されているが、SKILL.md 本体には「Step 4 作業コピー作成まで」の記載しかない。perspective.md が不完全な状態で Phase 1 以降に進む可能性がある
- 推奨: SKILL.md の Phase 0 に「perspective.md の必須セクション検証ステップ」を明示的に追加する
- impact: medium, effort: low

### I-3: 最終サマリで宣言された「効果テーブル上位3件」の取得方法が不明 [effectiveness]
- 対象: SKILL.md Phase 6 行356
- 内容: 「効果のあったテクニック: {knowledge.md の効果テーブル上位3件}」を出力すると宣言されているが、Phase 6 の処理フローには knowledge.md の効果テーブルを読み込み・解析するステップが記述されていない。Phase 6A でナレッジ更新を行うが、その後に効果テーブルを再読み込みして上位3件を抽出する処理が欠落している
- 推奨: Phase 6A 完了後に「Read で knowledge.md を読み込み、効果テーブルをパースして上位3件を抽出する」ステップを追加する
- impact: medium, effort: low

### I-4: Phase 1B の audit ファイル不在時の挙動が曖昧 [effectiveness]
- 対象: SKILL.md 行161-163, templates/phase1b-variant-generation.md
- 内容: Glob で `.agent_audit/{agent_name}/audit-*.md` を検索し、見つかった全ファイルを変数として渡す（見つからない場合は空）とあるが、phase1b-variant-generation.md では「指定されている場合: Read で読み込む」という条件分岐のみで、空の場合の処理が明示されていない
- 推奨: テンプレート側で空文字列を受け取った場合の処理を明記する（例: 「audit ファイルが空の場合、audit 統合ステップをスキップし、Deep/Fast モード選定のみ実行する」）
- impact: medium, effort: low

---
注: 改善提案を 18 件省略しました（合計 22 件中上位 4 件を表示）。省略された項目は次回実行で検出されます。
