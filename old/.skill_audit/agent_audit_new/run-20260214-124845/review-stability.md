### 安定性レビュー結果

#### 重大な問題
なし

#### 改善提案
- [条件分岐の適正化: Phase 1 のグループ判定後の else 節が欠落]: [SKILL.md] [Phase 0 Step 4] グループ分類の判定ルール（ルール1→2→3→4の順）が記述されているが、4つの条件全てに該当しない場合の動作が定義されていない。現在の判定ルールでは「ルール4: 上記いずれにも該当しない → unclassified」があるため理論上は全ケースをカバーしているが、group-classification.md との不整合時（例: group-classification.md のルールが変更された場合）にフォールバック動作がない → group-classification.md のルールと SKILL.md の分岐が一致していることを確認するか、「判定失敗時は unclassified として扱う」旨を明記する [impact: low] [effort: low]

- [条件分岐の適正化: Phase 1 のエラーハンドリングで全件数抽出失敗時の二次処理が過剰]: [SKILL.md] [Phase 1 行126-127] 「件数はファイル内の `## Summary` セクションから抽出する（抽出失敗時は findings ファイル内の `### {ID_PREFIX}-` ブロック数から推定する）」という二次フォールバック処理が記述されている。品質基準のエッジケース処理方針の階層2に該当（LLMが自然にエラー報告・スキップで対応できる）ため、この二次処理記述は削除を推奨 → `## Summary` セクションから件数を抽出する、と記述するのみで十分。抽出失敗時は LLM が自然に「件数不明」または findings ブロック数でカウントする [impact: low] [effort: low]

- [参照整合性: SKILL.md 内の外部パス参照が旧パス]: [SKILL.md] [行64] 「分類基準の詳細は `.claude/skills/agent_audit/group-classification.md` を参照」とあるが、実際のファイルパスは `/home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.claude/skills/agent_audit_new/group-classification.md` である（旧スキル `agent_audit` への参照）→ `.claude/skills/agent_audit_new/group-classification.md` に修正する [impact: low] [effort: low]

- [参照整合性: テンプレートが SKILL.md のパス変数で定義されていない]: [SKILL.md] [Phase 2 Step 4 行221-224] apply-improvements テンプレートが `{agent_path}` と `{approved_findings_path}` を使用しているが、SKILL.md にパス変数セクションが存在しない。現在は Phase 2 Step 4 の Task prompt 内で直接パス変数を埋め込んでいるが、SKILL.md 冒頭にパス変数セクションを追加し、全パス変数を一元定義すべき（例: `{agent_path}`, `{agent_name}`, `{agent_content}`, `{approved_findings_path}`, `{findings_save_path}`, `{backup_path}`） [impact: medium] [effort: low]

- [冪等性: Phase 0 Step 6 のディレクトリ作成で既存チェック不要]: [SKILL.md] [Phase 0 Step 6 行81] `mkdir -p .agent_audit/{agent_name}/` が記述されている。`-p` フラグにより既にディレクトリが存在しても成功するため冪等性は保証されているが、findings ファイル（`.agent_audit/{agent_name}/audit-{ID_PREFIX}.md`）の再実行時の重複・上書きに関する方針が記述されていない → Phase 1 の各サブエージェントが findings ファイルを Write で上書きする仕様であることを明記するか、既存 findings の保存（タイムスタンプ付きリネーム）を行うかを決定すべき [impact: medium] [effort: low]

- [冪等性: Phase 2 Step 4 のバックアップが再実行時に重複生成される]: [SKILL.md] [Phase 2 Step 4 行217] バックアップファイルが `$(date +%Y%m%d-%H%M%S)` のタイムスタンプで生成されるため、再実行時に複数バックアップが蓄積される。意図的な仕様であればこのままで問題ないが、旧バックアップのクリーンアップ方針が記述されていない → 「再実行時は新しいバックアップが追加生成される」旨を明記するか、「最新1件のみ保持」等のクリーンアップルールを追加する [impact: low] [effort: low]

- [参照整合性: apply-improvements テンプレート内の未定義パス変数]: [templates/apply-improvements.md] [行3-5] テンプレートが `{approved_findings_path}` と `{agent_path}` を参照しているが、これらの変数は SKILL.md のパス変数リストに定義されていない（前述の指摘と重複）。SKILL.md にパス変数セクションを追加し、全パス変数を定義すべき [impact: medium] [effort: low]

#### 良い点
- [出力先の決定性]: 全サブエージェント（Phase 1 の次元エージェント、Phase 2 Step 4 の改善適用エージェント）の出力先が明確に定義されている。Phase 1 は findings ファイル（`.agent_audit/{agent_name}/audit-{ID_PREFIX}.md`）への保存 + 1行返答、Phase 2 Step 4 は変更サマリ返答のみ、とファイル経由のデータフローが一貫している

- [冪等性: バックアップ・検証ステップの存在]: Phase 2 Step 4 で改善適用前に自動バックアップを作成し、適用後に frontmatter 構造検証を行う設計。破壊的変更に対するガードが適切に配置されている

- [参照整合性: テンプレートファイルの実在性]: SKILL.md で参照されているテンプレート（`templates/apply-improvements.md`）およびエージェント定義ファイル（`agents/shared/instruction-clarity.md`, `agents/evaluator/criteria-effectiveness.md` 等）が全てスキルディレクトリ内に実在し、パスも正確である
