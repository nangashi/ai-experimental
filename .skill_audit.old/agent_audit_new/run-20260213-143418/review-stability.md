### 安定性レビュー結果

#### 重大な問題
なし

#### 改善提案
- [出力フォーマット決定性: Phase 0 グループ抽出フォーマット未指定]: [SKILL.md] [Phase 0 Step 4 (行69-75)] [サブエージェント返答から `{agent_group}` を「抽出する」が、抽出失敗時の処理が未定義] → [抽出方法を明示する: 「返答から `group: {agent_group}` の形式で {agent_group} を抽出する。抽出失敗時（返答が形式に従わない場合）は `unclassified` をデフォルト値として使用する」] [impact: medium] [effort: low]
- [条件分岐の完全性: Phase 2 Step 1 findings 抽出方法が未定義]: [SKILL.md] [Phase 2 Step 1 (行155-158)] [「`###` ブロック単位」で finding を抽出するとあるが、ブロックの境界判定や必須フィールド（ID, severity, title, description 等）の有無による抽出成否判定が未定義。形式不正時の処理が不明確] → [抽出ロジックを明示する: 「各 `###` で始まるブロックを finding として抽出。ブロック内に `[severity: critical]` または `[severity: improvement]` を含むもののみ対象。ID は `###` 直後のトークン（例: `CE-01`）、title は ID の後のテキスト、description/evidence/recommendation は各見出し（`- 内容:`, `- 根拠:`, `- 推奨:`）の後のテキストから取得。必須フィールドが欠落している場合は警告を表示し、そのブロックをスキップする」] [impact: medium] [effort: medium]
- [条件分岐の完全性: Phase 2 Step 2a Other 再確認後の不明確処理]: [SKILL.md] [Phase 2 Step 2a (行189)] [2回目の入力が不明確な場合はスキップとして扱うとあるが、「不明確」の判定基準が曖昧（「2行以下で具体性なし、文脈不明」だけでは判定が揺らぐ可能性）] → [判定基準を具体化する: 「以下のいずれかに該当する場合は不明確と判定: (1) 入力が空または2行以下かつ具体的な修正指示を含まない、(2) 推奨内容への言及がなく、指摘IDやファイル名への参照もない、(3) Yes/No のみの単語応答」] [impact: low] [effort: low]
- [参照整合性: テンプレート内の未定義プレースホルダ]: [templates/apply-improvements.md] [行4, 5] [`{approved_findings_path}` と `{agent_path}` プレースホルダが使用されているが、SKILL.md の「パス変数リスト」セクションで定義されていない（Phase 2 Step 4 のインライン Task prompt 内で定義されている）] → [SKILL.md に「## パス変数」セクションを追加し、全プレースホルダを一覧で定義する。テンプレートファイルと SKILL.md で使用される全変数を統一的に管理する] [impact: medium] [effort: medium]
- [冪等性: Phase 0 Step 6 既存 findings ファイルの上書き警告が不十分]: [SKILL.md] [Phase 0 Step 6 (行84)] [「既存の findings ファイルが上書きされる可能性があることに注意」とあるが、注意喚起のみで具体的な回避方法（タイムスタンプ付きサブディレクトリの使用、既存ファイルの確認とバックアップ等）の提示がない] → [冪等性確保の手順を追加する: 「既に `.agent_audit/{agent_name}/` が存在する場合、Bash で `ls .agent_audit/{agent_name}/audit-*.md 2>/dev/null` を実行し、既存 findings ファイルを列挙する。ファイルが存在する場合、`mkdir -p .agent_audit/{agent_name}/run-$(date +%Y%m%d-%H%M%S)/` のようにタイムスタンプ付きサブディレクトリを作成し、findings の保存先を `{run_dir}/audit-{ID_PREFIX}.md` に変更する」] [impact: medium] [effort: high]

#### 良い点
- サブエージェント返答の行数・フィールドが明示されている（Phase 0: 1行, Phase 1: 4行, Phase 2: 可変）
- 主要な条件分岐（全承認/1件ずつ/キャンセル、Approve/Skip/Approve all/Cancel/Other）が具体的な選択肢で定義されている
- バックアップ作成・存在確認・最終確認の3段階で不可逆操作前のガードが配置されている
