## 重大な問題

### C-1: Phase 2 Step 1 での findings ID プレフィックス抽出ロジックが未定義 [effectiveness]
- 対象: SKILL.md Phase 2 Step 1
- 内容: L177 で「失敗次元の ID プレフィックスを含む finding が存在しないことを確認する」と記載されているが、各次元の ID プレフィックス（CE, IC, SA, DC, WC, OF）と次元パス（evaluator/criteria-effectiveness 等）の対応関係がワークフロー内で明示的に定義されていない。analysis.md の Findings ファイルインベントリから対応関係は推定可能だが、SKILL.md 自体にマッピングテーブルがないため、実装時に誤った判定ロジックになるリスクがある。整合性チェックが機能せず、失敗次元の findings が混入する可能性がある
- 推奨: Phase 0 の「分析次元セットの決定」テーブル（L93-98）に ID_PREFIX カラムを追加し、各次元のプレフィックスを明記する
- impact: high, effort: low

### C-2: Phase 1 部分失敗時の継続判定ロジックに未定義ケースが存在 [stability]
- 対象: SKILL.md L145-149
- 内容: 継続条件「成功した次元数 ≧ 1、かつ（IC 次元が成功 または 成功数 ≧ 2）」において、IC次元が成功かつ成功数が1の場合、継続条件に該当するが「中止条件」の定義（IC失敗 かつ 成功数=1）には該当せず、両方のブランチから漏れる
- 推奨: 継続条件を明示的な排他的分岐にする: 「継続条件: (成功数 ≧ 2) または (成功数 = 1 かつ IC成功)、それ以外は中止」
- impact: high, effort: low

### C-3: group-classification.md の参照パスが相対パスで記述され解決方法が不明 [stability]
- 対象: SKILL.md L75
- 内容: 「`group-classification.md` を参照する」と記述されているが、絶対パス構築ルールが明示されていない。スキルディレクトリのルートからの解決方法が不明
- 推奨: 絶対パス構築ルールを明示する。「`.claude/skills/agent_audit_new/group-classification.md` を Read で読み込む」のように、スキルルートからの完全パスを指定する
- impact: high, effort: low

### C-4: Phase 1 の既存 findings ファイル検出で部分失敗時の再実行動作が未定義 [stability]
- 対象: SKILL.md L115
- 内容: 「既存ファイルが1つ以上存在する場合、「⚠ 既存の findings ファイル {N}件を上書きします」とテキスト出力する」とあるが、部分失敗時の再実行で失敗次元のファイルのみ再生成されるべきかどうか、既存ファイルの次元IDと今回の分析対象次元の照合が行われるか不明
- 推奨: 既存ファイルの次元IDを確認し、今回の分析対象次元と照合。不要な次元のファイルが残っている場合は削除、または部分更新モードを明示的にサポートする
- impact: high, effort: medium

### C-5: Phase 2 Step 1 の findings 抽出における finding の境界検出ルールが不明 [stability]
- 対象: SKILL.md L174
- 内容: 「各ファイルから severity が critical または improvement の finding（`###` ブロック単位）を抽出」と記述されているが、finding の境界検出ルールが不明。どこからどこまでを1 finding として抽出するのか、severity の抽出方法が具体的でない
- 推奨: finding の境界を明示: 「`### {ID_PREFIX}-` で始まるブロックから次の `###` または `##` までを1 finding として抽出。severity は finding ブロック内の `[severity: {level}]` から抽出する」
- impact: high, effort: low

### C-6: templates/apply-improvements.md で使用される変数 {timestamp} が未定義 [stability]
- 対象: SKILL.md L214-217, apply-improvements.md L4
- 内容: apply-improvements.md で `{backup_path}`: `{agent_path}.backup-{timestamp}` と記述されているが、`{timestamp}` の生成方法が SKILL.md のパス変数リストで定義されていない
- 推奨: SKILL.md L209 で「`{backup_path}` を記録する」とあるため、親が生成した実際のパスを変数として渡す。apply-improvements.md のパス変数リストから `{timestamp}` を削除し、`{backup_path}` は完全な絶対パスとして記述する
- impact: high, effort: low

## 改善提案

### I-1: Phase 2 Step 1 の findings 収集を委譲してコンテキスト削減 [efficiency]
- 対象: SKILL.md L173-174
- 内容: 全次元の findings ファイルを親が Read して抽出している。findings 詳細（各150行前後 × 4-5次元 = 600-750行相当）が親コンテキストに展開される
- 推奨: findings 収集自体をサブエージェントに委譲し、承認対象テーブルのみを返答させれば、親は findings 詳細を保持しなくて済む
- impact: high, effort: medium

### I-2: Phase 1 findings カウント処理の冗長性削減 [efficiency]
- 対象: SKILL.md L140-141
- 内容: 正規表現抽出失敗時に findings ファイルを再読み込みしてブロック数をカウントする。各次元で最大1回、計4-5回の Read が発生する可能性
- 推奨: カウント処理自体をサブエージェント返答に含めさせれば Read が1回で済む
- impact: medium, effort: low

### I-3: Phase 2 検証ステップの検証範囲を拡張 [architecture]
- 対象: SKILL.md L225-230
- 内容: 現在の検証ステップは YAML frontmatter と見出し行の存在のみを確認している。改善適用後のエージェント定義が意味的に一貫性を持つか（例: 削除された評価基準への参照が残っていないか、追加されたセクションが既存構造と矛盾しないか）は検証されない
- 推奨: より深い検証（セクション参照整合性、内部リンク有効性等）を検討する。ただし、検証コストと改善効果のトレードオフを考慮すべき
- impact: medium, effort: high

### I-4: analysis.md 生成ステップの依存関係を明示 [effectiveness]
- 対象: SKILL.md Phase 0-1
- 内容: 構造分析ドキュメント（analysis.md）が .skill_audit ディレクトリに配置されることが外部から期待されているが、このファイルを生成するステップが SKILL.md 内に存在しない。analysis.md は skill_audit スキル（別スキル）が生成する前提と推測されるが、SKILL.md の「使い方」「期待される成果物」セクションに analysis.md への言及がないため、agent_audit_new 単独での実行時にこのファイルが存在しない場合の動作が不明確
- 推奨: スキル間の依存関係を「使い方」セクションまたは「前提条件」として明示する
- impact: medium, effort: low

### I-5: 成功基準を明示化 [effectiveness]
- 対象: SKILL.md L1-10
- 内容: SKILL.md の説明文で「内容レベルの問題を特定・改善します」「グループに応じた分析次元セットで深い分析を行います」と記載されているが、「改善された」「深い分析」の具体的な成功基準（例: 特定カテゴリの問題を90%検出、critical findings を0件にする等）が明記されていない。ワークフロー完了後に「目的を達成した」と判定する条件が推定できない
- 推奨: Phase 3 の完了サマリに「全基準が有効と判定されました」という記述（L245）があるが、この判定ロジック自体を定義する
- impact: medium, effort: low

### I-6: バリデーション警告の具体性向上 [ux]
- 対象: SKILL.md Phase 0 Step 3 L67
- 内容: YAML frontmatter 不在時に「警告を出力するが処理は継続する」とあるが、警告メッセージの具体的内容（原因説明、YAML frontmatter の例示、影響範囲）が SKILL.md に記載されていない。サブエージェントが実装時に曖昧なメッセージ（"Warning: frontmatter not found"）を出力する可能性があり、ユーザーが対処法を理解できない
- 推奨: 警告メッセージのテンプレートを SKILL.md に明記する
- impact: medium, effort: low

### I-7: Phase 1 部分失敗時の対処選択肢を提供 [ux]
- 対象: SKILL.md Phase 1 L157-158
- 内容: 部分失敗時に失敗次元リストを出力するが、ユーザーへの対処選択肢（「継続」/「中止して再試行」/「失敗次元のみ手動確認」）を提示せず、自動的に Phase 2 へ継続する。継続条件を満たす場合でも、ユーザーが中止して問題を解決したい場合に選択機会がない
- 推奨: AskUserQuestion でユーザーに継続/中止の選択を確認する
- impact: medium, effort: medium

### I-8: Phase 1 エラーハンドリングの「エラー概要」抽出ロジックを明確化 [stability]
- 対象: SKILL.md L141
- 内容: 「Task ツールの返答から例外情報（エラーメッセージの要約。返答から "Error:" または "Exception:" を含む最初の文を抽出する）を抽出し」と記載されているが、抽出失敗時の代替処理が不明
- 推奨: 抽出失敗時の代替処理を明示: 「"Error:" または "Exception:" を含む最初の文を抽出する。該当文がない場合は、Task返答の最初の100文字を使用する」
- impact: medium, effort: low

### I-9: Phase 2 Step 4 でのバックアップ作成失敗時の処理を明示 [effectiveness]
- 対象: SKILL.md Phase 2 Step 4 L209
- 内容: 「バックアップ作成」としてコマンド実行と {backup_path} 記録が記載されているが、バックアップ作成失敗時の処理記述がない。また、バックアップ作成がサブエージェント起動前に実行される必要があるが、フローが明示的でない
- 推奨: バックアップ作成を Phase 2 Step 4 の冒頭に明示的に配置し、失敗時の処理（エラー出力＋Phase 2 Step 4 中止）を記述する
- impact: medium, effort: low
