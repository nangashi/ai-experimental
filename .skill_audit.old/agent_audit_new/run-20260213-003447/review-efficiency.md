### 効率性レビュー結果

#### 重大な問題
- [SKILL.md 行数超過]: [SKILL.md] [推定102行のコンテキスト浪費] SKILL.md は352行で、目標の250行を102行超過している。主な原因: Phase 2 Step 1 のサブエージェント prompt が17行（L224-240）、Phase 2 Step 2a の詳細ロジックが3行（L279）、検証ステップの詳細ロジックが15行（L311-323）。これらを外部化すべき [impact: high] [effort: medium]
- [7行超の inline prompt]: [SKILL.md:224-240] Phase 2 Step 1 のサブエージェント prompt が17行の inline 記述。テンプレート外部化の原則（7行超はテンプレート化）に違反 [impact: medium] [effort: low]

#### 改善提案
- [テンプレートの細分化不足]: [SKILL.md] Phase 2 Step 1 の findings 収集ロジック（境界検出、severity 抽出、title/次元名抽出、ソート、フォーマット）が17行の inline prompt に含まれる。これを `templates/collect-findings.md` に外部化することで SKILL.md を17行削減可能。同様に検証ステップ（L311-323）も `templates/validate-agent-structure.md` に外部化すれば15行削減可能。合計32行削減で目標（250行）に近づく [impact: high] [effort: medium]
- [Phase 0 グループ分類の inline 処理]: [SKILL.md:100-108] グループ分類は group-classification.md を参照するが、判定ロジック自体は親コンテキストで実行される。agent_content は平均157行（分析ドキュメントより）あるため、これを保持すると親コンテキストが肥大化する。グループ分類をサブエージェント委譲に変更すれば、返答は `group: {agent_group}` の1行のみで済む（推定150行のコンテキスト節約） [impact: medium] [effort: medium]
- [Phase 1 件数抽出の fallback 重複]: [SKILL.md:183] サブエージェント返答から件数抽出失敗時は「Phase 2 Step 1 で findings ファイルから再取得」とあるが、Phase 2 Step 1 は独立した findings 収集サブエージェントであり、Phase 1 の件数再取得とは無関係。この fallback は実際には使用されず、デッドコードの可能性がある。Phase 1 返答のパース失敗時は findings ファイルから直接件数を取得するロジックを明示すべき [impact: low] [effort: low]
- [バックアップパスの冗長記述]: [SKILL.md:291, 303, 307, 322, 343] `{backup_path}` の説明が5箇所に分散（「完全な絶対パス」「例: /path/to/...」の繰り返し）。変数定義セクションに一度記載すれば4箇所削減可能（推定8行削減） [impact: low] [effort: low]
- [Phase 3 の条件分岐冗長性]: [SKILL.md:336-349] Phase 3 サマリの条件分岐（Phase 2 スキップ時、実行時、validation_failed 時、critical スキップ時）が全て inline で記述されている。条件数が4つあり、各分岐の出力フォーマットが異なるため、これを `templates/completion-summary.md` に外部化すれば10行程度削減可能 [impact: low] [effort: medium]
- [analysis.md 参照の条件分岐]: [SKILL.md:318-320] analysis.md が存在する場合のみ外部参照整合性検証を実施する。この条件分岐により、検証ステップの記述が複雑化している（存在チェック + 条件分岐 + 検証ロジック）。検証を `templates/validate-agent-structure.md` に外部化し、テンプレート内で analysis.md の存在を判定する方が親の記述を簡潔にできる [impact: low] [effort: low]
- [並列化可能なサブエージェント呼び出し]: [SKILL.md] Phase 2 Step 4 と検証ステップは直列実行されているが、検証ロジックは改善適用の結果に依存しない（エージェント定義の構造検証のみ）。検証を Phase 2 Step 4 と並列実行すれば処理時間を短縮できる可能性がある（ただし、改善適用失敗時の検証スキップが必要なため、並列化の利益は限定的） [impact: low] [effort: high]

#### コンテキスト予算サマリ
- SKILL.md: 352行（目標: ≤250行、超過: 102行）
- テンプレート: 平均43行/ファイル（1個のみ、apply-improvements.md）
- 3ホップパターン: 0件（全データフロー正常にファイル経由）
- 並列化可能: 1件（Phase 2 Step 4 と検証ステップ、ただし利益は限定的）

#### 良い点
- ファイル経由のデータ受け渡しが一貫している: サブエージェントは全て findings/summary/approved ファイルに保存し、親は Read で取得。3ホップパターンは一切存在しない
- サブエージェント返答が最小限: Phase 1 は4行、Phase 2 Step 1 は3行、Phase 2 Step 4 は10行程度。詳細はファイルに保存され、親コンテキストには要約のみ保持される
- 並列実行の活用: Phase 1 で次元数（3-5個）のサブエージェントを同一メッセージ内で並列起動。並列化可能な箇所を適切に識別している
