## 重大な問題

### C-1: Phase 2 Step 2a で "Other" 入力時の処理とデータフロー不整合 [stability, architecture]
- 対象: SKILL.md:193, templates/apply-improvements.md:27
- 内容: SKILL.md L193 では「ユーザーが "Other" で修正内容をテキスト入力した場合は「修正して承認」として扱い、改善計画に含める」と記載されているが、(1) AskUserQuestion ツールは選択肢 UI による制御を行うため「Other」でのテキスト入力は構造的に発生しない。(2) ユーザー修正内容を approved-findings.md に記録する処理ステップが SKILL.md に存在しない。apply-improvements.md L27 は「修正内容」フィールドを読み取る仕様だが、親が記録する処理がないためデータフローが断絶している。
- 推奨: (1) SKILL.md L193 の「Other」記述を削除し、選択肢を4つ明示（承認/スキップ/残りすべて承認/キャンセル）のみとする。(2) ユーザーが修正内容を入力する選択肢を実装する場合は、修正内容を approved-findings の該当 finding に追記する処理フローを SKILL.md に追加する。
- impact: high, effort: low

### C-2: templates/apply-improvements.md のパス変数展開ミスマッチ [stability]
- 対象: SKILL.md:235-236, templates/apply-improvements.md:4-5
- 内容: SKILL.md L233-236 でサブエージェント prompt 内で変数を展開している（「{実際の agent_path の絶対パス}」）が、テンプレート側では波括弧付きプレースホルダ `{agent_path}` と `{approved_findings_path}` を期待している。このミスマッチにより、サブエージェントがテンプレート内のプレースホルダを正しく置換できない。
- 推奨: SKILL.md L235-236 の変数展開を削除し、テンプレート側で使用される `{agent_path}` と `{approved_findings_path}` をそのまま波括弧付きで渡す。
- impact: high, effort: low

### C-3: Phase 1 サブエージェント返答フォーマットの抽出ロジックが複雑で失敗時挙動が不安定 [stability]
- 対象: SKILL.md:138
- 内容: 件数をファイル内の `## Summary` セクションから抽出し、抽出失敗時は Grep で `^### {ID_PREFIX}-` パターンを検索し、両方失敗した場合は `critical: 0, improvement: 0, info: 0` を使用する複雑なフォールバック処理。サブエージェントの返答フォーマットが暗黙的依存となっており、抽出失敗時の挙動が不定。
- 推奨: サブエージェントの返答フォーマットを必須とし、SKILL.md L130 の「エージェント定義内の「Return Format」セクションに従って返答してください」を「以下のフォーマットで必ず返答してください: `dim: {ID}\ncritical: {N}\nimprovement: {M}\ninfo: {K}`」に置き換える。findings ファイル内容からの推定フォールバックは削除し、サブエージェント失敗時は L139 のエラーハンドリング経路に統一する。
- impact: high, effort: medium

## 改善提案

### I-1: Phase 2 Step 2a で複数独立提案を一括承認させる「全て承認」オプション [ux]
- 対象: SKILL.md:176-178
- 内容: Phase 2 Step 2 で複数の独立した findings（異なる次元、異なる問題カテゴリ）を「全て承認 / キャンセル」の2択で一括承認させている。個別承認を推奨する品質基準に反する。
- 推奨: 「全て承認」オプションを削除し、per-item 承認（Step 2a）をデフォルト動作とする。または「全て承認」選択時に findings の一覧を表示し、「本当に全て承認しますか？」の再確認ステップを追加する。
- impact: medium, effort: medium

### I-2: Phase 0/Phase 2 で frontmatter 検証基準が重複し、Phase 2 検証の有用性が低い [effectiveness]
- 対象: SKILL.md:69-78, SKILL.md:249-254
- 内容: Phase 0 では frontmatter の簡易チェック（`---` と `description:` の存在確認）を行うが、Phase 2 の検証ステップでも同じ基準で検証している。Phase 0 で frontmatter 不在の警告を出しながら処理を継続した場合、Phase 2 の検証ステップで同じ警告が再度出力される可能性があり、ユーザーに混乱を与える。
- 推奨: Phase 2 の検証ステップでは「改善適用前の状態」と「改善適用後の状態」を比較し、frontmatter が破損したかどうかを判定する基準に変更する（例: バックアップファイルと改善適用後ファイルの frontmatter セクションを比較）。
- impact: medium, effort: low

### I-3: Phase 1 失敗次元の扱いが Phase 3 サマリで曖昧 [effectiveness]
- 対象: SKILL.md:141, SKILL.md:280
- 内容: Phase 1 で一部次元が失敗した場合は Phase 2 へ進行するが、失敗した次元があることを Phase 3 のサマリに含めるかどうかが明確でない。Phase 3 L280 の「分析次元: {dim_count}件」が全次元数なのか成功次元数なのか曖昧。
- 推奨: Phase 3 サマリに「分析次元: {成功次元数}/{全次元数}」または「失敗次元: {失敗次元のID列挙}」を追加し、分析の完全性をユーザーが判断できるようにする。
- impact: medium, effort: low

### I-4: Phase 2 Step 4 改善適用後の構造検証が frontmatter のみで、大規模削除を検出できない [architecture]
- 対象: SKILL.md:249-254
- 内容: frontmatter 存在確認のみでは、評価基準セクションの大規模削除・破損を検出できない。承認 findings が1件でもエージェント定義の大半が削除される可能性がある。
- 推奨: 検証ステップに変更行数チェック（過度な削除・追加の検出）を追加する（例: 変更行数 > 元行数の50%で警告）。
- impact: medium, effort: low

### I-5: Phase 2 Step 2a の「残りすべて承認」も複数独立提案の一括承認に該当 [ux]
- 対象: SKILL.md:189
- 内容: per-item 承認ループ中に「残りすべて承認」を選択可能だが、これも複数独立提案の一括承認に該当する。ユーザーが途中で精査を放棄するリスクがある。
- 推奨: 「残りすべて承認」選択時に、残り findings の一覧を表示し、「本当に残り全て承認しますか？」の再確認ステップを追加する。または選択肢から削除する。
- impact: low, effort: low

### I-6: Phase 1 完了直後とPhase 2 Step 1 で findings ファイルを重複 Read [efficiency]
- 対象: SKILL.md:138, SKILL.md:161
- 内容: Phase 1 完了時に件数抽出のために findings を部分参照し、Phase 2 で再度 Read している。同じファイルを2回読むのは非効率。findings ファイルサイズは数KB程度と推定されるため、1回の Read で全内容を保持してもコンテキスト肥大化リスクは低い。
- 推奨: Phase 1 完了直後に全 findings ファイルを1回だけ Read し、findings 内容を変数に保持する。Phase 1 の件数表示とPhase 2 の抽出で同じデータを使用する。
- impact: medium, effort: low

### I-7: apply-improvements.md で「変更前に Read 必須」ルールが二重 Read を誘発 [efficiency]
- 対象: templates/apply-improvements.md:3-5, 24
- 内容: L3-5 で {agent_path} を Read するよう指示しているが、L24 で「変更前にファイルの Read を必ず実行する」とあり、{agent_path} が2回 Read される可能性がある。
- 推奨: apply-improvements.md の L3-5 で Read した内容を保持し、適用時の二重適用チェックではその保持内容を使うよう明示する。L24 を「変更前に Read した内容を参照し、二重適用チェックを行う」に変更する。
- impact: low, effort: low

### I-8: group-classification.md (21行) のインライン化検討 [architecture]
- 対象: group-classification.md
- 内容: group-classification.md は21行と短く、グループ分類はメインコンテキストで直接実行され、外部化による委譲コスト削減効果はない。21行をインライン化しても SKILL.md は318行となり、管理可能な範囲内。
- 推奨: group-classification.md の内容を SKILL.md の Phase 0（L71-83付近）にインライン化する。外部ファイル参照を減らすことでメンテナンス性が向上する。
- impact: low, effort: low

### I-9: 各次元エージェント定義の2フェーズ構造によるコンテキスト重複 [efficiency]
- 対象: agents 配下の全エージェント定義（IC, CE, SA, DC, WC, OF）
- 内容: 全エージェントが「Phase 1: Comprehensive Problem Detection」→「Phase 2: Organization & Reporting」の2段階構造を持ち、Phase 1 の非構造化リストは最終出力に含まれず、サブエージェントの内部作業メモリとして消費される。各エージェント定義の平均177行のうち、Phase 1/Phase 2 の構造説明が約60-80行を占めており、この構造自体がコンテキスト消費の主因となっている。Detection Strategy を直接検出→報告の単一パスに統合できれば、エージェント定義を平均120行程度に圧縮でき、Phase 1 サブエージェント実行時のコンテキスト予算を約30%削減できる。
- 推奨: 各次元エージェント定義を2フェーズ構造から単一パス（Detection Strategy → 直接報告）に再設計する。品質への影響を最小化するため、検出基準の具体性を維持しつつ、内部作業ステップの記述を削減する。
- impact: high, effort: high

---
注: 改善提案を 3 件省略しました（合計 12 件中上位 9 件を表示）。省略された項目は次回実行で検出されます。
