## コンフリクト

### CONF-1: SKILL.md Phase 3 行224 - phase3-error-handling.md の実行方法
- 側A: [architecture] Phase 3 のエラーハンドリング実行方法が曖昧。「templates/phase3-error-handling.md を Read で読み込み、その内容に従ってエラーハンドリングを実行する」とあるが、親が直接実行するのか、サブエージェントに委譲するのかが不明確
- 側B: [stability] `templates/phase3-error-handling.md`を参照しているが、これは手順書でありサブエージェントテンプレートではない。親が直接Readして分岐ロジックを実行すべき
- 対象findings: C-4

### CONF-2: SKILL.md Phase 4 行248-255 - エラーハンドリングの外部化
- 側A: [architecture] Phase 4 のエラーハンドリングの一部がインライン記述。Phase 4 失敗時の処理分岐ロジックが8行のインラインブロックで記述されている。phase3-error-handling.md のように外部テンプレート化されていない。Phase 3 と Phase 4 のエラーハンドリングパターンに一貫性がない
- 側B: [efficiency] Phase 3 error-handling テンプレートを SKILL.md に統合。error-handling.md は42行だがロジックのみで外部ファイル参照なし。SKILL.md 内に記述しても250行制約内に収まる
- 対象findings: （改善提案レベルのため省略）

### CONF-3: Phase 0 の perspective 解決処理 - 統合 vs 分離
- 側A: [efficiency] Phase 0 の perspective 解決と生成を1テンプレートに統合。現在3ファイル（resolution, generation, generation-simple）に分散。条件分岐を1テンプレート内で処理すれば効率化（約20行削減 + サブエージェント呼び出し1回削減）
- 側B: [ux] perspective 自動生成モード選択（標準/簡略）の AskUserQuestion が SKILL.md に存在しない。簡略版テンプレートが存在する（templates/phase0-perspective-generation-simple.md）にもかかわらず選択肢がないのは矛盾している。選択肢を追加するか、簡略版を削除すべき
- 対象findings: （改善提案レベルのため省略）
