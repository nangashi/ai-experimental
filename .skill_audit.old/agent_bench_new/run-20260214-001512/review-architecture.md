### アーキテクチャレビュー結果

#### 重大な問題
- [外部参照: 他スキルのテンプレートファイル]: [SKILL.md:81,92他] Phase 0 perspective自動生成およびPhase 1〜6の全テンプレート参照が `.claude/skills/agent_bench/templates/` を指している。`agent_bench_new` ディレクトリ内に同一テンプレートが存在しているが参照されていない。 [複数フェーズでRead失敗を引き起こす可能性] [impact: high] [effort: low]

#### 改善提案
- [Phase 3評価実行の長大インライン指示]: [SKILL.md:222-228] Phase 3の各サブエージェントへの指示（7行）がインライン記述されている。このパターンは Phase 3のみ。テンプレート外部化パターンとの一貫性のため、`templates/phase3-evaluation.md` への外部化を推奨。 [他フェーズとのパターン一貫性] [impact: low] [effort: low]
- [Phase 6 Step 1デプロイの長大インライン指示]: [SKILL.md:316-321] デプロイ指示（6行）がインライン記述されている。短いがテンプレート外部化の一貫性のため `templates/phase6-deploy.md` への外部化を検討。 [パターン一貫性] [impact: low] [effort: low]
- [Phase 0 Step 1要件抽出の長大インライン指示]: [SKILL.md:67-71] AskUserQuestion でのヒアリング項目（4行）がインライン記述されている。この処理は perspective 自動生成の前提条件であり、テンプレート外部化すべき。 [impact: low] [effort: low]

#### パターン準拠サマリ
| パターン | 状態 | 備考 |
|---------|------|------|
| テンプレート外部化 | 部分的 | Phase 3, Phase 6 Step 1, Phase 0 Step 1 の7行前後の指示がインライン記述。他は適切に外部化 |
| サブエージェント委譲 | 非準拠 | 全フェーズで「Read template + follow instructions + path variables」パターンを使用しているが、外部参照先が `.claude/skills/agent_bench/` となっており、自スキル内のテンプレートを参照していない（重大な問題） |
| ナレッジ蓄積 | 準拠 | 反復最適化ループあり。`knowledge.md` による有界サイズのナレッジ蓄積（改善のための考慮事項: 最大20行制限）、保持+統合方式（Phase 6A で明示）、`proven-techniques.md` のエージェント横断知見蓄積（Phase 6B、Tier制度・preserve+integrate統合・セクション別サイズ上限） |
| エラー耐性 | 準拠 | Phase 3/4で部分失敗時の再試行/除外/中断の3択を明示。Phase 0でperspective生成フォールバックを定義。過剰なエラーハンドリング記述なし |
| 成果物の構造検証 | 部分的 | Phase 0 Step 6でperspective検証（必須セクション確認）を実装。knowledge.md、テスト文書、レポート等の他の最終成果物に対する構造検証記述なし |
| ファイルスコープ | 非準拠 | 全テンプレート参照が `.claude/skills/agent_bench/` を指しており、スキルディレクトリ外の参照となっている（重大な問題）。Phase 1Bで `.agent_audit/` への参照あり（これは明示的なクロススキル参照として許容される設計） |

#### 良い点
- コンテキスト節約原則（SKILL.md:18-24）の明示的な記述により、サブエージェント設計の指針が明確
- サブエージェント間のデータ受け渡しが一貫してファイル経由（3ホップパターンの回避）
- ナレッジ蓄積システムが2層構造（エージェント単位の `knowledge.md` とスキル横断の `proven-techniques.md`）で設計され、有界サイズ・保持+統合方式を採用
