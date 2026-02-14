### 安定性レビュー結果

#### 重大な問題
なし

#### 改善提案
- [出力先の決定性: サブエージェント返答フィールドの抽出優先順位が不定]: [SKILL.md] [Phase 1 の件数抽出処理（L207）で「Summary セクションから抽出（抽出失敗時は finding ブロック数から推定）」と記述されているが、Summary セクションの存在と形式はサブエージェント側の責務に依存し、親が抽出パターンをハードコードする構造。サブエージェントが Summary セクションを省略しても動作するべきだが、優先順位が曖昧なため抽出ロジックのバリエーションが増える] → [サブエージェントの返答を `dim: {ID}, critical: N, improvement: M, info: K` 形式のみに限定し、親はこのフォーマットからのみ抽出する（findings ファイルへの Summary セクション記載は推奨だが抽出には使用しない）ことで、依存箇所を単一化する] [impact: low] [effort: low]

- [条件分岐の適正化: Phase 2 Step 4 エラーハンドリングの過剰な分岐]: [SKILL.md] [L318-322 で「失敗キーワード検出 → AskUserQuestion でリトライ/ロールバック/強制進行の3択を確認 → リトライは1回のみ」と詳細な分岐が定義されている。2次分岐テストを適用すると、LLM は自然に「エラー報告して停止」または「失敗を報告して Phase 3 へ進む」を選択できる。リトライ回数の明示化・3択の分岐定義・リトライカウンタは階層2（LLM委任）に該当する過剰なエッジケース処理] → [Phase 2 Step 4 のエラーハンドリング分岐を削除し、「改善適用サブエージェントが失敗を報告した場合、LLM が適切にエラーを報告して Phase 3 へ進む」に簡略化する。ロールバックが必要な場合は Phase 3 のサマリでロールバックコマンドを提示する構造で十分] [impact: low] [effort: low]

- [条件分岐の適正化: Phase 1 部分失敗時の成否判定ロジックが詳細すぎる]: [SKILL.md] [L206-210 で「findings ファイルの存在・非空チェック → Summary セクション抽出 → 抽出失敗時は finding ブロック数から推定 → 全失敗時はエラー終了、部分失敗時は成功次元のみで続行」と段階的なフォールバック処理が定義されている。これは階層2（LLM委任）に該当する。LLM は findings ファイルの存在確認で成否を自然に判定できる] → [Phase 1 の成否判定を「findings ファイルが存在するか確認する」のみに簡略化する。件数抽出はサブエージェント返答から行い、抽出失敗時のフォールバック処理は削除する] [impact: low] [effort: low]

- [参照整合性: templates/collect-findings.md で言及されたディレクトリパスが SKILL.md で未定義]: [templates/collect-findings.md] [L12 で `.agent_audit/{agent_name}/audit-*.md` を Glob で検索する指示があるが、SKILL.md のパス変数リストに `.agent_audit/{agent_name}/` ディレクトリの定義がない。実際には Phase 0 Step 6 で `mkdir -p .agent_audit/{agent_name}/` が実行されているが、テンプレート側で使用するパスが変数定義されていない] → [SKILL.md のパス変数リストに `{findings_dir}` = `.agent_audit/{agent_name}/` を追加し、templates/collect-findings.md でこの変数を参照する形に統一する] [impact: low] [effort: low]

- [冪等性: Phase 0 Step 6 のディレクトリ作成が再実行を前提とした設計だが Phase 1 の findings ファイル上書きルールが不明瞭]: [SKILL.md] [L113-114 で「Phase 1 の各サブエージェントは既存の findings ファイルを Write で上書きする（再実行時は前回の findings は削除される）」と記述されているが、この動作はサブエージェント側の実装依存。SKILL.md には「既存ファイルを Write で上書き」という指示が Phase 1 のサブエージェントプロンプトに含まれていない。findings ファイルの冪等性がサブエージェントの暗黙的な動作に依存している] → [Phase 1 のサブエージェントプロンプトに「既存の findings ファイルが存在する場合は Write で上書きする」旨を明示する、または Phase 0 Step 6 で既存の findings ファイルを削除する処理を追加する] [impact: medium] [effort: low]

#### 良い点
- [出力先の明示]: 全サブエージェントの出力先（返答形式またはファイル保存先）が明確に定義されている。Phase 1 は findings ファイル保存+返答サマリ、Phase 2 Step 1 は findings-summary.md 保存+返答サマリ、Phase 2 Step 4 は Edit による変更+返答サマリの構造が一貫している
- [参照整合性の高さ]: SKILL.md で定義されたパス変数が Phase 1, Phase 2 Step 1, Phase 2 Step 4 のサブエージェントプロンプトで正しく参照されている。外部ファイル（group-classification.md, common-rules.md, agents/*/〇〇.md, templates/*.md）のパスも全て実在する
- [冪等性の設計]: Phase 0 Step 6 で出力ディレクトリを `mkdir -p` で作成し、Phase 2 Step 4 でバックアップを `{agent_path}.backup-$(date +%Y%m%d-%H%M%S)` で一意なファイル名に保存する設計。再実行時のファイル重複リスクが低い
