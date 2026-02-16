### アーキテクチャレビュー結果

#### 重大な問題
なし

#### 改善提案
- [SKILL.md Phase 0 Step 4 | long-inline-prompt]: Task ツール呼び出しに含まれる 3 行のインライン指示をテンプレート化すべき [impact: low] [effort: low]
  - 現状: `.claude/skills/agent_audit_new/group-classification.md` を Read し、その指示に従ってグループ分類を実行してください。分析対象: `{agent_path}` 分類完了後、以下のフォーマットで返答してください: `group: {agent_group}`（3行）
  - 推奨: テンプレートファイル group-classification.md の末尾に「## 返答フォーマット」セクションを追加し、`group: {agent_group}` の指示を外部化する
  - 理由: 現在は短い3行だが、テンプレート外部化の一貫性を保つため、返答フォーマットはテンプレート内で定義すべき（7行以下のため critical ではない）

- [SKILL.md Phase 1 | long-inline-prompt]: Task ツール呼び出しに含まれる 8 行のインライン指示を完全にテンプレート化すべき [impact: medium] [effort: low]
  - 現状: 各次元エージェント用の Task prompt が SKILL.md 内に 8 行のインライン指示として埋め込まれている（行 123-127）
  - 推奨: 各次元エージェントファイル（例: agents/evaluator/criteria-effectiveness.md）の末尾に「## 呼び出し方法」または「## 返答フォーマット」セクションを追加し、パス変数の受け渡しと返答形式をテンプレート内で定義する
  - 理由: 8 行は 7 行の閾値を超えており、パス変数の説明が既に各次元エージェント内に存在する（"### Input Variables" セクション）ため、指示の重複を避けるべき

- [SKILL.md Phase 2 Step 4 | long-inline-prompt]: Task ツール呼び出しに含まれる 29 行のインライン指示をテンプレート参照パターンに統一すべき [impact: high] [effort: low]
  - 現状: 改善適用サブエージェント用の指示が SKILL.md 内に 29 行のインラインブロックとして記述されている（行 231-261）
  - 推奨: 「`.claude/skills/agent_audit_new/templates/apply-improvements.md` を Read し、その指示に従って改善を適用してください。パス変数: `{agent_path}`: {絶対パス}, `{approved_findings_path}`: {絶対パス}` 完了後、以下のフォーマットで返答してください: modified: {N}件 ... skipped: {K}件 ...」形式に変更する
  - 理由: apply-improvements.md が既に存在し、29 行の指示の大部分と重複している。SKILL.md では「Read template + follow instructions + path variables」パターンを使用すべき。現在の SKILL.md の指示はテンプレートファイルのコピーになっており、2 箇所でメンテナンスが必要

- [analysis-framework.md | unused-knowledge-file]: 反復的な最適化ループがないスキルで knowledge 蓄積ファイルが存在しない（過剰設計ではない） [impact: low] [effort: low]
  - 現状: agent_audit_new スキルは単一実行型（1回のファイル分析で完了）で、反復的な最適化ループを持たない
  - 推奨: 現状維持（ナレッジ蓄積ファイルは不要）
  - 理由: 反復ループがないため、ナレッジ蓄積の仕組みは不要と判定（設計は適切）

#### パターン準拠サマリ
| パターン | 状態 | 備考 |
|---------|------|------|
| テンプレート外部化 | 部分的 | Phase 2 Step 4 で 29 行のインライン指示あり（改善提案3件） |
| サブエージェント委譲 | 準拠 | 「Read template + follow instructions + path variables」パターンが部分的に使用されているが、Phase 2 Step 4 でテンプレート参照が不完全 |
| ナレッジ蓄積 | 不要 | 反復的な最適化ループがないため、ナレッジ蓄積の仕組みは不要（設計は適切） |
| エラー耐性 | 準拠 | Phase 1 で部分失敗時の続行処理（N 中 M 成功で Phase 2 へ進む）が明示されている。Phase 0 グループ分類失敗時の処理は未定義だが、分類失敗は「中止して報告」がデフォルト動作として十分 |
| 成果物の構造検証 | 準拠 | Phase 2 検証ステップでエージェント定義の frontmatter、必須セクション、グループ別構造を検証している（行 270-278） |
| ファイルスコープ | 準拠 | 全ての外部参照がスキルディレクトリ内（`.claude/skills/agent_audit_new/`）に収まっている。analysis.md の「## C. 外部参照の検出」セクションで確認済み |

#### 良い点
- [Phase 0 グループ分類のサブエージェント委譲]: エージェント内容の読み込みと分類をサブエージェント（haiku）に委譲し、親コンテキストに agent_content を保持しない設計（コンテキスト節約の原則に準拠）
- [Phase 1 並列分析]: 3-5 次元のサブエージェントを同一メッセージ内で並列起動し、返答を 4 行のサマリに制限（詳細はファイルに保存）。3 ホップパターンを回避し、ファイル経由でデータを受け渡している
- [Phase 2 検証ステップ]: 改善適用後にエージェント定義の構造検証（frontmatter、必須セクション、グループ別必須要素）を実行し、検証失敗時にロールバックコマンドを提示する設計
