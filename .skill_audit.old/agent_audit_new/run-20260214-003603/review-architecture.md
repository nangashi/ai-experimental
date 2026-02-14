### アーキテクチャレビュー結果

#### 重大な問題
- [C-1: スキルディレクトリ外への参照]: [SKILL.md] [Line 174: agent_bench 出力ディレクトリへの直接参照] Phase 1 で `.agent_audit/{agent_name}/audit-*.md` を参照しているが、これは `.agent_bench/` スキルの成果物を外部参照している。2つのスキルが結合しており、agent_bench 単独での動作が不可能。agent_audit_new スキル内で独立した構造にすべき [impact: high] [effort: high]
- [C-2: 大規模外部スキル埋め込み]: [agent_audit_new/agent_bench/] [agent_bench スキル全体が内包] agent_audit_new ディレクトリ内に agent_bench スキル全体（372行のSKILL.md + 20個以上のテンプレート・補助ファイル）が埋め込まれている。これは「スキルディレクトリ外のパスを参照する代わりにスキル内へのコピー」の原則を誤適用したもの。別スキルは独立ディレクトリに配置すべき [impact: high] [effort: high]

#### 改善提案
- [I-1: group-classification.md の統合完了]: [group-classification.md が未削除] SKILL.md L32-60 でグループ定義と分類基準を直接記述しているが、group-classification.md（22行）が残存している。resolved-issues.md によると「I-8: グループ分類の判定基準参照の曖昧性」で埋め込み済み。冗長ファイルを削除すべき [impact: low] [effort: low]
- [I-2: Phase 1 サブエージェント指示の簡潔性]: [SKILL.md L136-142] Phase 1のサブエージェント起動プロンプト（7行）は「Read template + follow + path variables」パターンに準拠しているが、返答フォーマット指定（L141-142）が詳細すぎる。返答フォーマットは各次元エージェントの末尾セクションに統一定義されているため、親からの重複指示は削除可能 [impact: low] [effort: low]
- [I-3: 次元エージェントの返答フォーマット統一性検証]: [agents/*/] 全7次元エージェント（IC, CE, SA×2, DC, WC, OF）で返答フォーマット定義の有無を確認すべき。現在、SKILL.md L141-142 で返答フォーマットを親側で指定しているが、テンプレート側に定義がない場合は一貫性欠如のリスク [impact: medium] [effort: low]
- [I-4: Phase 0 Step 7a 冪等性処理の過剰記述]: [SKILL.md L102] 「既存の findings ファイルを削除する」処理の説明が詳細すぎる（「Phase 1の再実行時に重複を防ぐため、冪等性を保証する」）。LLM は `rm -f` の意図を自然に理解できるため、冪等性の説明は階層2（LLM委任）に該当し削除可能 [impact: low] [effort: low]
- [I-5: antipattern 参照の外部化パターン]: [agents/*/*.md] 全7次元エージェントが Detection Strategy 5 でアンチパターンカタログを絶対パス参照している（例: `.claude/skills/agent_audit_new/antipatterns/instruction-clarity.md`）。このパターンは適切だが、パス変数化していないため agent_audit_new のディレクトリ名変更時に全ファイル修正が必要。Phase 1 起動時に `{antipattern_path}` をパス変数として渡すことで保守性向上 [impact: low] [effort: medium]
- [I-6: Phase 2 Step 4 バックアップコマンドの脆弱性]: [SKILL.md L238] バックアップコマンドが `$(date +%Y%m%d-%H%M%S)` を使用しているが、並列実行時の衝突リスクあり。ただし agent_audit は並列実行を想定しない設計のため実害なし。より堅牢にするには `$$` (PID) を併用可能 [impact: low] [effort: low]

#### パターン準拠サマリ
| パターン | 状態 | 備考 |
|---------|------|------|
| テンプレート外部化 | 準拠 | apply-improvements.md（43行）のみが外部化。Phase 1 の7行プロンプトはパス変数パターンに準拠 |
| サブエージェント委譲 | 準拠 | Phase 1（7並列）、Phase 2 Step 4（1並列）で「Read template + follow + path variables」パターンを一貫使用。モデル指定は全て sonnet（分析・生成タスクのため適切） |
| ナレッジ蓄積 | 不要 | 反復最適化ループなし。1回の監査実行で完結する設計のためナレッジ蓄積は不要 |
| エラー耐性 | 準拠 | Phase 1 で部分失敗時の続行閾値を明示（全失敗→終了、部分失敗→警告継続）。Phase 2 Step 4 で apply-improvements 失敗時の AskUserQuestion 確認あり。二次的フォールバックの過剰記述なし |
| 成果物の構造検証 | 準拠 | Phase 2 検証ステップ（L251-263）で agent_path の frontmatter と audit-approved.md の構造検証を実施。検証失敗時のロールバック確認も実装済み |
| ファイルスコープ | 非準拠 | C-1, C-2: agent_bench スキル全体を内包し、その成果物ディレクトリを参照している。スキル間の独立性が損なわれている |

#### 良い点
- [L102: 冪等性の明示的実装]: Phase 1 開始前に既存 findings ファイルを削除する設計により、再実行時のファイル重複を防止している。resolved-issues.md の C-4 対応として適切に実装済み
- [L148-152: 部分失敗時の続行ロジック]: Phase 1 でサブエージェント成否判定を findings ファイル存在確認のみで行い、全失敗→終了、部分失敗→警告継続のロジックを明示。過剰なエラー判定を避け、簡潔で堅牢
- [L169-211: Per-item 承認フローの設計]: Phase 2 で「全承認/1件ずつ確認/キャンセル」の3方針を提供し、1件ずつ確認時に4選択肢（承認/スキップ/残りすべて承認/キャンセル）を用意。ユーザーの柔軟な判断を可能にする UX 設計
