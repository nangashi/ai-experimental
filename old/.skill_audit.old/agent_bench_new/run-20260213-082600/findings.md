## 重大な問題

### C-1: Phase 0 Step 5 の条件分岐未定義 [architecture]
- 対象: SKILL.md:105-107
- 内容: フィードバック統合・再生成の判定基準が曖昧。「重大な問題または改善提案がある場合」の判定条件が明示されていない。4件の批評から「重大な問題」「改善提案」を分類するロジックが不明確で、実行時に親エージェントが一貫した判定を行えない
- 推奨: 判定基準を明示する（例: 「重大な問題が1件以上ある場合」）
- impact: high, effort: low

### C-2: Phase 3 の部分失敗時の判定基準未定義 [architecture]
- 対象: SKILL.md:241
- 内容: 「各プロンプトに最低1回の成功結果がある」場合に Phase 4 へ進むとあるが、この判定ロジックが曖昧。プロンプトAが Run1のみ成功、プロンプトBが Run2のみ成功の場合、各プロンプトの SD 計算が不可能になるが、その処理フローが未定義
- 推奨: 「Run1 または Run2 のいずれかが成功していれば最低1回とみなす」と明記し、SD 計算不可の場合の処理フローを定義する
- impact: high, effort: medium

### C-3: Phase 6 Step 2 の並列実行完了待ち [stability]
- 対象: SKILL.md:368-370
- 内容: Step 2B (proven-techniques 更新) と Step 2C (次アクション選択) を「同時に実行する」(342行) が、Step 2C の結果分岐 (369行) で「B) スキル知見フィードバックサブエージェントの完了を待ってから」と記載されており、並列起動と順次待機の意図が不明確
- 推奨: B と C を同一メッセージ内で並列起動し、両方の完了を待ってから分岐処理を行うことを明記する
- impact: high, effort: low

### C-4: Phase 0 Step 4b パターンマッチングの else 節欠落 [stability]
- 対象: SKILL.md:51-56
- 内容: `*-design-reviewer`, `*-code-reviewer` のパターンマッチングで、パターンに一致しない場合の処理が「いずれも見つからない場合: パースペクティブ自動生成」(56行)にのみ記述されているが、Step 4b で一致したが Read が失敗した場合の処理フローが不明確
- 推奨: 「一致したがファイル不在」を明示的に処理し、その場合も自動生成に進むことを明記する
- impact: medium, effort: low

### C-5: perspective ディレクトリの実在確認 [stability]
- 対象: SKILL.md:74
- 内容: `.claude/skills/agent_bench_new/perspectives/design/*.md` を Glob で列挙するが、このディレクトリがスキル内に実在するか未確認。「見つからない場合は {reference_perspective_path} を空とする」(76行) が記載されているが、空パスをテンプレートに渡した際の動作が未定義
- 推奨: 空パス時のテンプレート処理動作を明記する
- impact: medium, effort: low

### C-6: テンプレート内の未定義変数 [stability]
- 対象: phase1a-variant-generation.md:9
- 内容: `{user_requirements}` が SKILL.md の Phase 1A パス変数リスト (150-159行) に「エージェント定義が新規作成の場合:」という条件付きで記載されているが、テンプレート内では無条件に参照される可能性がある
- 推奨: SKILL.md で条件分岐を明確化し、既存エージェント更新の場合は `{user_requirements}` を空または未指定として渡すことを明記する
- impact: medium, effort: low

### C-7: Phase 6 Step 1 の条件分岐未完全 [architecture]
- 対象: SKILL.md:316-322
- 内容: ベースライン以外選択時にサブエージェント起動するが、ベースライン選択時の処理が「変更なし」のみで、knowledge.md 更新やレポート記録への反映処理が不明。ベースライン選択時もプロンプト選択結果として記録する必要があるが、その処理フローが欠落
- 推奨: ベースライン選択時の knowledge.md 更新とレポート記録の処理フローを明記する
- impact: medium, effort: medium

### C-8: perspective.md の二重読み込み [efficiency]
- 対象: SKILL.md Phase 1A:155, Phase 1B:179
- 内容: Phase 0 で perspective.md を生成済みだが、Phase 1A/1B のサブエージェントが再度読み込む。Phase 1A は perspective_source_path と perspective_path の両方を渡し、Phase 1B は perspective_path を渡す。バリアント生成時に perspective を参照する必要性は低い（approach-catalog.md と proven-techniques.md で十分）
- 推奨: Phase 1A/1B から perspective.md の読み込みを削除する
- impact: medium, effort: low

### C-9: knowledge.md の読み込みタイミング [efficiency]
- 対象: SKILL.md:333, templates/phase6a-knowledge-update.md:1
- 内容: Phase 5 サブエージェント (line 283) が knowledge_path を読み込み済み、Phase 6A サブエージェント (line 333) が再度読み込む。Phase 5 が knowledge.md を参照してレポートを生成し、その直後に Phase 6A がナレッジ更新で再読み込みする設計
- 推奨: Phase 5 の knowledge 読み込み削除または Phase 6A での report のみ参照に変更する
- impact: medium, effort: medium

## 改善提案

### I-1: Phase 0 perspective 自動生成 Step 4 の返答形式未定義 [architecture]
- 対象: SKILL.md:88-103
- 内容: 4並列の批評エージェントの返答形式が未定義。テンプレート critic-effectiveness.md では SendMessage で報告とあるが、親エージェントがどの形式で受け取り、どのフィールドから「重大な問題」「改善提案」を抽出するかが不明。4件の返答を統合する処理ロジックも未記載
- 推奨: 批評エージェントの返答形式を SKILL.md または批評テンプレートに明記する
- impact: medium, effort: medium

### I-2: Phase 1B の audit ファイル検索の曖昧性 [architecture, effectiveness]
- 対象: SKILL.md:180-183
- 内容: Glob で `.agent_audit/{agent_name}/audit-*.md` を検索し、最新ファイルを選定するとあるが、「最新」の判定基準（ファイル名のタイムスタンプ?ファイルシステムの mtime?）が未定義。audit-ce-alpha.md と audit-ce-beta.md が両方存在する場合の選定ロジックが不明確。テンプレート phase1b-variant-generation.md では audit_dim1_path, audit_dim2_path の参照方法が「空でない場合 Read で読み込む」としか記載されておらず、親エージェントが最新ファイル選定と変数展開を行う必要があるが、その基準が曖昧
- 推奨: SKILL.md Phase 1B に「Glob で得られた複数ファイルから最新ファイルを選定する基準（ファイル名のタイムスタンプ部分で判定、または最終更新日時で判定）」を明記する
- impact: medium, effort: low

### I-3: Phase 6B の昇格条件判定の複雑性 [architecture]
- 対象: phase6b-proven-techniques-update.md:15-26
- 内容: Tier 1/2/3 の昇格条件が複雑で、サブエージェントの判定負荷が高い。特に「2+ エージェントの出典」の判定では proven-techniques.md の既存エントリを全て照合する必要があり、処理失敗リスクが高い
- 推奨: 昇格条件の簡略化または判定ロジックの明示化を検討する
- impact: medium, effort: high

### I-4: Phase 2 のラウンド番号導出の曖昧性 [architecture]
- 対象: SKILL.md:203
- 内容: テスト文書保存パスに `{NNN} = 累計ラウンド数 + 1` とあるが、Phase 0 で knowledge.md 読み込み成功時にラウンド数を抽出する処理が SKILL.md に記載されていない。親コンテキストに累計ラウンド数を保持する処理フローが明示的に記述されていない
- 推奨: Phase 0 に knowledge.md からラウンド数を抽出する処理を明記する
- impact: low, effort: low

### I-5: Phase 1B audit ファイル不在時のフォールバック戦略 [effectiveness]
- 対象: Phase 1B, SKILL.md:180-183
- 内容: audit ファイルが見つからない場合、パス変数を空文字列で渡すとあるが、テンプレート phase1b-variant-generation.md 側では「空でない場合 Read で読み込む」とのみ記載されている。空の場合に audit 情報を使わずにバリアント生成を継続するのか、またはその場合のフォールバック戦略が SKILL.md に記述されていない
- 推奨: SKILL.md Phase 1B に「audit ファイルが見つからない場合は knowledge.md の過去知見のみでバリアント生成を行う」と明記する
- impact: low, effort: low

### I-6: Phase 0 Step 2 perspective 検索のファイル不在 [effectiveness]
- 対象: Phase 0, SKILL.md:73-76
- 内容: perspective 検索 Step 2 で「Glob で列挙し、最初に見つかったファイルを使用する」とあるが、Glob が0件の場合の処理が記述されていない（Step 2b の fallback として自動生成 Step が存在するため実質的には問題ないが、Step 2 内で「見つからない場合は Step 2 をスキップして Step c へ」と明記すべき）
- 推奨: SKILL.md Phase 0 Step 4 の記述を「a. ... 見つからない場合は b. へ / b. ... 見つからない場合は c. へ / c. いずれも見つからない場合: パースペクティブ自動生成」と分岐を明示する
- impact: low, effort: low

### I-7: Phase 3 の並列実行時の Run 番号の一意性 [architecture]
- 対象: SKILL.md:222-236
- 内容: 各プロンプトを2回ずつ並列実行するが、Run 番号（1 または 2）の割り当てロジックが未定義。同一プロンプトの2回実行を並列起動した場合、両方が Run1 として保存される競合リスクがあるが、防止策が記載されていない
- 推奨: Run 番号の割り当てロジックを明記する（例: 同一プロンプトの2回実行は順次起動、または Run 番号を明示的にパラメータで渡す）
- impact: low, effort: low

### I-8: Phase 5 の返答形式の行数検証欠如 [architecture]
- 対象: SKILL.md:288
- 内容: Phase 5 サブエージェントの返答が「7行サマリ」とあるが、実際に7行であることを検証する処理がない。フィールド欠落時のフォールバック処理も未定義。Phase 6 Step 1 でフィールドを参照するため、構造検証が必要
- 推奨: Phase 5 返答の構造検証処理を追加する
- impact: low, effort: low

### I-9: Phase 6 Step 2A のバックアップタイムスタンプ形式未統一 [architecture]
- 対象: phase6a-knowledge-update.md:4
- 内容: バックアップファイル名に `{timestamp}` を YYYYMMDD-HHMMSS 形式で付与するとあるが、SKILL.md にこの形式の生成指示がない。サブエージェントがタイムスタンプ生成を独自に行う必要があり、形式の一貫性が保証されない
- 推奨: SKILL.md にタイムスタンプ形式の生成指示を追加する
- impact: low, effort: low
