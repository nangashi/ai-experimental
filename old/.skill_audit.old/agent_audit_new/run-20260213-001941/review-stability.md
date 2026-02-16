### 安定性レビュー結果

#### 重大な問題
- [条件分岐の完全性: Phase 1 部分失敗時の継続判定ロジックに未定義ケースが存在]: [SKILL.md] [L145-149] [「継続条件: 成功した次元数 ≧ 1、かつ（IC 次元が成功 または 成功数 ≧ 2）」] → [IC次元が成功かつ成功数が1の場合、継続条件に該当するが「中止条件」の定義（IC失敗 かつ 成功数=1）には該当せず、両方のブランチから漏れる。修正案: 「継続条件: (成功数 ≧ 2) または (成功数 = 1 かつ IC成功)、それ以外は中止」と明示的な排他的分岐にする] [impact: high] [effort: low]

- [参照整合性: group-classification.md の参照パスが相対パスで記述され、スキルディレクトリのルートからの解決方法が不明]: [SKILL.md] [L75] [「`group-classification.md` を参照する」] → [絶対パス構築ルールを明示する。「`.claude/skills/agent_audit_new/group-classification.md` を Read で読み込む」のように、スキルルートからの完全パスを指定する] [impact: high] [effort: low]

- [冪等性: Phase 1 の既存 findings ファイル検出で警告のみで上書きを許可するが、部分失敗時の再実行で失敗次元のファイルのみ再生成されるべき]: [SKILL.md] [L115] [「既存ファイルが1つ以上存在する場合、「⚠ 既存の findings ファイル {N}件を上書きします」とテキスト出力する」] → [既存ファイルの次元IDを確認し、今回の分析対象次元と照合。不要な次元のファイルが残っている場合は削除、または部分更新モードを明示的にサポートする] [impact: high] [effort: medium]

- [出力フォーマット決定性: Phase 2 Step 1 の findings 抽出ロジックが「`###` ブロック単位」と記述されているが、finding の境界検出ルールが不明]: [SKILL.md] [L174] [「各ファイルから severity が critical または improvement の finding（`###` ブロック単位）を抽出」] → [finding の境界を明示: 「`### {ID_PREFIX}-` で始まるブロックから次の `###` または `##` までを1 finding として抽出。severity は finding ブロック内の `[severity: {level}]` から抽出する」] [impact: high] [effort: low]

- [参照整合性: templates/apply-improvements.md で使用される変数 `{timestamp}` が SKILL.md のパス変数リストで定義されていない]: [SKILL.md, templates/apply-improvements.md] [SKILL.md L214-217, apply-improvements.md L4] [apply-improvements.md で `{backup_path}`: `{agent_path}.backup-{timestamp}` と記述されているが、`{timestamp}` の生成方法が不明] → [SKILL.md L209 で「`{backup_path}` を記録する」とあるため、親が生成した実際のパスを変数として渡す。apply-improvements.md のパス変数リストから `{timestamp}` を削除し、`{backup_path}` は完全な絶対パスとして記述する] [impact: high] [effort: low]

#### 改善提案
- [指示の具体性: Phase 1 エラーハンドリングの「エラー概要」抽出ロジックが曖昧]: [SKILL.md] [L141] [「Task ツールの返答から例外情報（エラーメッセージの要約。返答から "Error:" または "Exception:" を含む最初の文を抽出する）を抽出し」] → [抽出失敗時の代替処理を明示: 「"Error:" または "Exception:" を含む最初の文を抽出する。該当文がない場合は、Task返答の最初の100文字を使用する」] [impact: medium] [effort: low]

- [出力フォーマット決定性: Phase 1 のサブエージェント返答フォーマットで件数抽出の正規表現が「等」で曖昧]: [SKILL.md] [L140] [「正規表現 `critical: (\d+)` 等で抽出」] → [全パターンを明示: 「正規表現 `critical: (\d+)`, `improvement: (\d+)`, `info: (\d+)` で抽出」] [impact: medium] [effort: low]

- [冪等性: Phase 2 Step 3 の audit-approved.md 保存時に既存ファイルを上書きするが、Write前の存在確認がない]: [SKILL.md] [L201] [「`.agent_audit/{agent_name}/audit-approved.md` に Write で保存する」] → [「Write前に既存の audit-approved.md を Read で確認し、存在する場合は `.agent_audit/{agent_name}/audit-approved.backup-{timestamp}.md` にコピーしてから新規ファイルを Write する」] [impact: medium] [effort: low]

- [条件分岐の完全性: Phase 2 Step 2a の「Other」入力処理が「修正して承認」として扱うが、修正内容の記録方法が不明]: [SKILL.md] [L197] [「"Other" 入力は「修正して承認」として扱う」] → [「"Other" 入力の場合、ユーザー入力テキストを finding の「修正内容」フィールドに記録し、Step 3 の audit-approved.md に含める」] [impact: medium] [effort: low]

- [指示の具体性: Phase 2 検証ステップの「見出し行が1つ以上存在」が曖昧]: [SKILL.md] [L228] [「ファイル内に `## ` で始まる見出し行が1つ以上存在することを確認する」] → [「ファイル内に `## ` で始まる行（Markdown見出しレベル2以上）が1つ以上存在することを正規表現 `^## ` で確認する」] [impact: low] [effort: low]

- [参照整合性: agent定義ファイルの次元固有エージェント（evaluator/criteria-effectiveness.md等）が参照する detection-process-common.md のパスが相対パス]: [agents/evaluator/criteria-effectiveness.md] [L23] [「`.claude/skills/agent_audit_new/agents/shared/detection-process-common.md` を Read」] → [パス記述は正しいが、SKILL.md でサブエージェントに渡すパス変数リストに `{detection_process_common_path}` を追加し、ハードコーディングを避ける] [impact: low] [effort: medium]

- [冪等性: Phase 0 Step 6 で出力ディレクトリを作成するが、既存ディレクトリの扱いが不明]: [SKILL.md] [L87] [「出力ディレクトリを作成する: `mkdir -p .agent_audit/{agent_name}/`」] → [「`mkdir -p` は既存ディレクトリを許容するため、再実行時も安全。ただし、既存ファイルとの整合性チェック（Phase 1 L115 の警告）を Phase 0 で前倒し実施することを検討」] [impact: low] [effort: medium]

#### 良い点
- [出力フォーマット決定性]: サブエージェント返答フォーマットが全て具体的な行数・フィールド名で定義されている（Phase 1: 4行フォーマット、Phase 2 Step 4: 30行以内の変更サマリ）
- [参照整合性]: テンプレート内のプレースホルダ（`{agent_path}`, `{approved_findings_path}`, `{backup_path}`）がSKILL.md のパス変数リストおよびサブエージェント起動時の変数展開で全て定義されている
- [冪等性]: Phase 2 Step 4 でバックアップを明示的に作成し、検証失敗時のロールバック手順を提示している（L209, L230）
