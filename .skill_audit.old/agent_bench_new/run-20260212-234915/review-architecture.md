### アーキテクチャレビュー結果

#### 重大な問題
- [外部パス参照の不整合]: [SKILL.md 54,74,81,92,95,124,128,146,151,165,174,184,186,249,251,272,324,336行目] 全ての外部参照が `.claude/skills/agent_bench/` を指しているが、実際のスキルディレクトリは `.claude/skills/agent_bench_new/` である。このため Phase 0-6 の全てのフェーズで Read/Glob 失敗が発生し、スキルが正常に機能しない [impact: high] [effort: low]
- [Phase 3 の長いインラインプロンプト]: [SKILL.md 213-220行目] サブエージェントへの直接指示が8行ある。テンプレート外部化の原則（7行超）に違反しており、コンテキスト効率が低下する [impact: medium] [effort: medium]
- [Phase 6 Step 1 デプロイの長いインラインプロンプト]: [SKILL.md 308-313行目] サブエージェントへの直接指示が6行あり、短い処理のためテンプレート外部化は不要だが、モデル指定が haiku でファイル操作のみの単純処理には適切。ただしパターンとしては7行以下なので基準内 [impact: low] [effort: low]
- [Phase 0/1/2/5/6 のサブエージェント失敗時の処理フローが未定義]: [SKILL.md] Phase 3 と Phase 4 は失敗時の分岐フロー（再試行/除外/中断）が明示されているが、他のフェーズは「暗黙的にエラー伝播」と推測されるのみ。サブエージェント失敗時にスキルが異常終了する可能性がある [impact: high] [effort: medium]

#### 改善提案
- [perspective 自動生成 Step 2 のフォールバック不足]: [SKILL.md 74-76行目] `.claude/skills/agent_bench/perspectives/design/*.md` の Glob で1件も見つからない場合、`{reference_perspective_path}` が空になるがエラーハンドリングが明示されていない。テンプレート側で空参照に対応できるか不明確 [impact: medium] [effort: low]
- [Phase 0 初期化サブエージェント失敗時の処理]: [SKILL.md 122-130行目] knowledge.md 初期化の Task 失敗時の処理が未定義。初期化失敗時は Phase 1A に進めないため、エラー出力して終了すべき [impact: medium] [effort: low]
- [Phase 1B の audit 外部参照]: [SKILL.md 174行目] `.agent_audit/{agent_name}/audit-*.md` を参照しているが、これはスキルディレクトリ外の外部ファイル。agent_audit スキルの実行が前提となっており、audit 結果がない場合の処理が不明確。パラメータ化または条件分岐を明示すべき [impact: medium] [effort: medium]
- [Phase 2 の knowledge.md 参照タイミング]: [SKILL.md 189行目] Phase 2 サブエージェントに `{knowledge_path}` を渡しているが、Phase 1A では knowledge.md は Phase 0 で初期化されたばかりで有用な情報がない。Phase 1B でのみ必要なファイルを Phase 2 で常に参照させるのは非効率 [impact: low] [effort: low]
- [Phase 5 の必須セクション検証欠如]: [SKILL.md 268-279行目] Phase 5 サブエージェントが生成するレポートファイルの構造検証（必須セクション: 実行条件、スコアマトリクス、推奨判定、考察等）が SKILL.md に記載されていない。Phase 6 で7行サマリに依存しているため、サマリの形式が不正な場合に Phase 6 が失敗する [impact: medium] [effort: low]
- [Phase 6 の性能推移テーブル生成ロジック]: [SKILL.md 287-299行目] 親エージェントが knowledge.md から「ラウンド別スコア推移」を Read して性能推移テーブルを構成する記載があるが、具体的な処理手順（どのセクションをどう解析するか、初期スコアの扱い、改善率の計算式）が未定義。実装の曖昧さがある [impact: medium] [effort: low]
- [perspective-source.md と perspective.md の重複]: [SKILL.md 59-60行目] perspective-source.md から問題バンクを除いた内容を perspective.md に保存しているが、2ファイルの管理コストが増加する。Phase 4 で「問題バンクを含まない作業コピー」を必要とする理由（採点バイアス防止）は理解できるが、サブエージェントに「問題バンクセクションは無視」と指示する方が効率的 [impact: low] [effort: medium]

#### パターン準拠サマリ
| パターン | 状態 | 備考 |
|---------|------|------|
| テンプレート外部化 | 部分的 | Phase 3 の8行インラインプロンプトが違反。その他は適切にテンプレート化 |
| サブエージェント委譲 | 準拠 | 全フェーズで「Read template + follow instructions + path variables」パターンを使用。モデル指定も適切（haiku は単純ファイル操作、sonnet は判断/生成） |
| ナレッジ蓄積 | 準拠 | knowledge.md（有界サイズ: 効果テーブル、バリエーションステータス、20行の一般化原則）と proven-techniques.md（セクション別サイズ上限）で保持+統合方式を実装 |
| エラー耐性 | 部分的 | Phase 3/4 は失敗時の処理フロー明確。Phase 0/1/2/5/6 は未定義。並列実行の部分失敗にも対応 |
| 成果物の構造検証 | 部分的 | Phase 0 の perspective.md は検証あり。Phase 5 のレポート、Phase 6 の knowledge.md 更新結果の構造検証は未定義 |
| ファイルスコープ | 非準拠 | 全ての外部参照が `.claude/skills/agent_bench/` を指しており、実際のディレクトリ `.claude/skills/agent_bench_new/` と不整合。Phase 1B で `.agent_audit/` を参照 |

#### 良い点
- [サブエージェント間のファイル経由データ受け渡し]: Phase 1 → prompts/ → Phase 3、Phase 4 → scoring/ → Phase 5、Phase 5 → reports/ → Phase 6 の全てでファイル経由のデータフローが実装されており、3ホップパターンを回避している
- [バリエーションステータステーブルの明示的状態管理]: knowledge.md の「バリエーションステータス」テーブルで全 Variation ID を UNTESTED/EFFECTIVE/INEFFECTIVE/MARGINAL で管理し、暗黙的なカタログ突合を排除している
- [Phase 5 の7行サマリによるコンパクトな返答]: Phase 5 サブエージェントが7行の構造化サマリ（recommended, reason, convergence, scores, variants, deploy_info, user_summary）のみを返答し、詳細はファイルに保存することで親コンテキストを節約している
