### 安定性レビュー結果

#### 重大な問題
- [参照整合性: ディレクトリ名の不整合]: [SKILL.md] [64行目、221行目] [`.claude/skills/agent_audit/group-classification.md` と `.claude/skills/agent_audit/templates/apply-improvements.md` を参照] → [正しいパスは `.claude/skills/agent_audit_new/group-classification.md` と `.claude/skills/agent_audit_new/templates/apply-improvements.md` に修正。現在は旧ディレクトリ（agent_audit）を参照しているため、新ディレクトリ（agent_audit_new）で動作させた場合に不正なファイルを参照する可能性がある] [impact: high] [effort: low]
- [参照整合性: テンプレートパスの不整合]: [SKILL.md] [115行目] [`.claude/skills/agent_audit/agents/{dim_path}.md` を参照] → [正しいパスは `.claude/skills/agent_audit_new/agents/{dim_path}.md` に修正。dim_path の例として evaluator/criteria-effectiveness が使われているが、このパスプレフィックスがスキルディレクトリ名と異なる] [impact: high] [effort: low]
- [条件分岐の完全性: Phase 1 サブエージェント失敗時の件数推定ロジック]: [SKILL.md] [126行目] [「抽出失敗時は findings ファイル内の `### {ID_PREFIX}-` ブロック数から推定する」とあるが、推定処理の具体的な実装方法が明示されていない] → [ブロック数の数え方（Grep または Read+パターンマッチング）を明示する。または推定失敗時のデフォルト値（例: 「件数不明」）を定義する] [impact: medium] [effort: low]
- [冪等性: バックアップファイルの重複生成]: [SKILL.md] [217行目] [`cp {agent_path} {agent_path}.backup-$(date +%Y%m%d-%H%M%S)` を実行するが、同一セッション内で Phase 2 を再実行した場合に複数のバックアップファイルが生成される] → [バックアップ作成前に既存のバックアップファイルを確認し、存在する場合は新規作成をスキップするか、既存のバックアップパスを使用する条件分岐を追加する] [impact: low] [effort: medium]

#### 改善提案
- [指示の具体性: 「簡易チェック」の基準が曖昧]: [SKILL.md] [58行目] [「ファイル先頭に YAML frontmatter」とあるが、ファイル先頭の定義（先頭N行以内、空行を含むか等）が不明確] → [具体的な検証方法を明示する（例: 「先頭10行以内に `---` で始まる行があり、その後の100行以内に `description:` を含む行がある」）] [impact: low] [effort: low]
- [条件分岐の完全性: グループ分類失敗時の処理が未定義]: [SKILL.md] [62-72行目] [グループ分類判定ルールに従って分類するが、全ての特徴が2つ以下の場合は unclassified になる。しかし、エージェント定義の内容が極端に少ない場合（空ファイルに近い等）の扱いが不明確] → [エージェント定義の最小要件（例: 100文字以上、または特定のセクション必須）を定義し、要件を満たさない場合の処理フロー（警告出力+継続 or エラー出力+終了）を明示する] [impact: low] [effort: medium]
- [参照整合性: テンプレートプレースホルダの未定義変数]: [templates/apply-improvements.md] [3-5行目] [`{approved_findings_path}` と `{agent_path}` はパス変数として使用されているが、SKILL.md のパス変数リストには明示されていない] → [SKILL.md に「パス変数」セクションを追加し、全テンプレートで使用されるプレースホルダを一覧化する] [impact: medium] [effort: low]
- [出力フォーマット決定性: Phase 1 サブエージェント返答の抽出失敗時の挙動]: [SKILL.md] [126行目] [「件数はファイル内の `## Summary` セクションから抽出する（抽出失敗時は findings ファイル内の `### {ID_PREFIX}-` ブロック数から推定する）」とあるが、両方失敗した場合のフォールバック処理が不明確] → [両方失敗した場合のデフォルト値（例: `critical: 0, improvement: 0, info: 0` または「件数不明」）を明示する] [impact: low] [effort: low]
- [条件分岐の完全性: Step 2a の Other 入力時の扱い]: [SKILL.md] [181行目] [「ユーザーが "Other" で修正内容をテキスト入力した場合は「修正して承認」として扱い、改善計画に含める」とあるが、Other 入力が不明確または空の場合の処理が未定義] → [Other 入力の検証ルール（最小文字数、必須フィールド等）を定義し、検証失敗時は再入力を促すか、スキップ扱いとするかを明示する] [impact: low] [effort: medium]

#### 良い点
- [冪等性]: Phase 1 で findings ファイルの存在・非空チェックにより、サブエージェント失敗時も処理を継続できる設計になっている
- [参照整合性]: テンプレート内のプレースホルダ（{agent_path}, {approved_findings_path}）が SKILL.md の Task prompt 内で明示的に定義されており、サブエージェントへの変数受け渡しが明確である
- [条件分岐の完全性]: Phase 2 の承認方針選択（全て承認 / 1件ずつ確認 / キャンセル）と per-item 承認（承認 / スキップ / 残りすべて承認 / キャンセル）で全分岐が明示されている
