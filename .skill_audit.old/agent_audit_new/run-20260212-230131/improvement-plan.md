# 改善計画: agent_audit_new

## 変更対象ファイル
| # | ファイル | 変更種別 | 変更概要 | 対応フィードバック |
|---|---------|---------|---------|------------------|
| 1 | SKILL.md | 修正 | パス変数定義セクション追加、外部パス修正、グループ判定委譲、Phase 0/2 の改善、サブエージェント返答フォーマット修正 | C-1, C-2, C-3, C-4, C-8, C-9, I-4, I-7, I-8, I-9 |
| 2 | SKILL.md (Phase 1) | 修正 | エラー通知の動的情報追加 | C-5 |
| 3 | SKILL.md (Phase 2) | 修正 | ユーザー確認の追加、承認粒度の改善、プレビュー追加、検証メッセージ具体化、改善適用失敗時フォールバック追加 | C-6, C-7, I-1, I-2, I-3, I-6 |
| 4 | group-classification.md | 修正 | グループ判定基準の具体化とエッジケース処理の追加 | I-8 |
| 5 | templates/apply-improvements.md | 修正 | なし（現状維持） | - |

## 各ファイルの変更詳細

### 1. SKILL.md（修正）
**対応フィードバック**:
- C-1: 外部パス参照のスキル名不一致
- C-2: パス変数定義の欠落
- C-3: Phase 0 Step 3 YAML 検証失敗後の処理未定義
- C-4: サブエージェント変数展開ルールの曖昧性
- C-8: agent_content の二重保持
- C-9: Phase 2 Step 4 バックアップファイルの無限増殖
- I-4: SKILL.md 行数超過
- I-7: 検証ステップの構造検証スコープ不足
- I-8: グループ判定基準の曖昧性
- I-9: サブエージェント返答フォーマットの区切り文字曖昧性

**変更内容**:

1. **パス変数定義セクション追加（C-2）**:
   - 位置: frontmatter 直後、「エージェント定義ファイルのコンテンツ...」の前
   - 追加内容:
```markdown
## パス変数

このスキルで使用されるパス変数と導出ルール:

- `{agent_path}`: エージェント定義ファイルの絶対パス（入力引数）
- `{agent_name}`: エージェント名。以下のルールで導出:
  - `.claude/` 配下の場合: `.claude/` からの相対パス（拡張子除去）
    - 例: `.claude/agents/security-design-reviewer.md` → `agents/security-design-reviewer`
  - それ以外: プロジェクトルートからの相対パス（拡張子除去）
    - 例: `my-agents/custom.md` → `my-agents/custom`
- `{agent_group}`: グループ判定結果（hybrid / evaluator / producer / unclassified）
- `{agent_content}`: エージェント定義ファイルの全文（Phase 0 では保持しない、Phase 2 検証時に Read）
- `{dim_count}`: 分析次元数（3〜5）
- `{dim_path}`: 各次元のサブエージェント相対パス（例: `evaluator/criteria-effectiveness`）
- `{ID_PREFIX}`: 各次元の Finding ID Prefix（IC, CE, SA, DC, WC, OF）
- `{findings_save_path}`: findings ファイルの絶対パス（`.agent_audit/{agent_name}/audit-{ID_PREFIX}.md`）
- `{approved_findings_path}`: 承認済み findings ファイルの絶対パス（`.agent_audit/{agent_name}/audit-approved.md`）
- `{backup_path}`: バックアップファイルの絶対パス（`{agent_path}.backup-{タイムスタンプ}`）

サブエージェントに渡す Task prompt では、これらの変数を実際の値に置換して指示を生成します。
```

2. **外部パス参照の修正（C-1）**:
   - 64行目: `.claude/skills/agent_audit/group-classification.md` → `.claude/skills/agent_audit_new/group-classification.md`
   - 115行目: `.claude/skills/agent_audit/agents/{dim_path}.md` → `.claude/skills/agent_audit_new/agents/{dim_path}.md`
   - 221行目: `.claude/skills/agent_audit/templates/apply-improvements.md` → `.claude/skills/agent_audit_new/templates/apply-improvements.md`

3. **Phase 0 Step 2 の変更（C-8）**:
   - 変更前: `Read で {agent_path} のファイルを読み込み、{agent_content} として保持する。`
   - 変更後: `Read で {agent_path} のファイルを読み込む（エージェント定義の存在確認のみ。内容はメモリに保持しない）。`

4. **Phase 0 Step 3 の変更（C-3）**:
   - 変更前: `存在しない場合、「⚠ このファイルには...」とテキスト出力する（処理は継続する）`
   - 変更後:
```markdown
存在しない場合、「⚠ このファイルにはエージェント定義の frontmatter がありません。エージェント定義ではない可能性があります。」とテキスト出力し、`AskUserQuestion` で継続可否を確認する。ユーザーが「継続」を選択した場合、frontmatter なしで分析を継続する（後続の検証ステップでは frontmatter チェックをスキップする）。「中止」を選択した場合は処理を終了する。
```

5. **Phase 0 Step 4 のグループ判定委譲（I-4）**:
   - 変更前: 66-72行目の判定ルール（概要）を直接記述
   - 変更後:
```markdown
4. `{agent_content}` を分析し、`{agent_group}` を判定する:

   Read で `.claude/skills/agent_audit_new/group-classification.md` を読み込み、その基準に従ってグループを判定する。

   この判定はメインコンテキストで直接行う（サブエージェント不要）。
```

6. **Phase 1 サブエージェント指示の変更（C-4, I-9）**:
   - 変更前（115-118行目）:
```markdown
> `.claude/skills/agent_audit/agents/{dim_path}.md` を Read し、その指示に従って分析を実行してください。
> 分析対象: `{agent_path}`, agent_name: `{agent_name}`
> findings の保存先: `{findings_save_path}`（= `.agent_audit/{agent_name}/audit-{ID_PREFIX}.md` の絶対パス）
> 分析完了後、以下のフォーマットで返答してください: `dim: {次元名}, critical: {N}, improvement: {M}, info: {K}`
```
   - 変更後:
```markdown
> `.claude/skills/agent_audit_new/agents/{dim_path}.md` を Read し、その指示に従って分析を実行してください。
>
> 以下の変数を実際の値に置換して指示を生成する:
> - agent_path: {実際の agent_path の絶対パス}
> - agent_name: {実際の agent_name}
> - findings_save_path: {実際の .agent_audit/{agent_name}/audit-{ID_PREFIX}.md の絶対パス}
>
> 分析完了後、以下のフォーマットで返答してください（次元名を引用符で囲む）: `dim: "{次元名}", critical: {N}, improvement: {M}, info: {K}`
```

7. **Phase 2 Step 4 バックアップ作成の変更（C-9）**:
   - 変更前（217行目）:
```markdown
**バックアップ作成**: 改善適用前に Bash で `cp {agent_path} {agent_path}.backup-$(date +%Y%m%d-%H%M%S)` を実行し、`{backup_path}` を記録する。
```
   - 変更後:
```markdown
**バックアップ作成**: 改善適用前に以下を実行する:
1. Bash で `ls {agent_path}.backup-* 2>/dev/null | tail -1` を実行し、既存バックアップの有無を確認
2. 既存バックアップが存在する場合: 「最新バックアップは {パス} です。新しいバックアップを作成しますか？」と `AskUserQuestion` で確認。「いいえ」の場合は既存バックアップを再利用
3. 新規バックアップ作成時: `cp {agent_path} {agent_path}.backup-$(date +%Y%m%d-%H%M%S)` を実行し、`{backup_path}` を記録
```

8. **Phase 2 検証ステップの変更（I-7）**:
   - 変更前（232-233行目）:
```markdown
1. Read で `{agent_path}` を再読み込み
2. YAML frontmatter の存在確認（ファイル先頭が `---` で始まり、`description:` を含む）
```
   - 変更後:
```markdown
1. Read で `{agent_path}` を再読み込み
2. YAML frontmatter の存在確認（ファイル先頭が `---` で始まる）
3. frontmatter 内の必須フィールド検証: `description:` フィールドが存在し、空でないことを確認
4. Phase 0 Step 3 で frontmatter なしで継続した場合: 検証ステップをスキップし、「検証スキップ: frontmatter なしで分析を開始したため」とテキスト出力
```

### 2. SKILL.md (Phase 1)（修正）
**対応フィードバック**: C-5: エラー通知の動的情報不足

**変更内容**:

1. **Phase 1 エラーハンドリングの変更（125-127行目）**:
   - 変更前:
```markdown
- findings ファイルが存在しない、または空 → 失敗。Task ツールの返答から例外情報（エラーメッセージの要約）を抽出し、該当次元は「分析失敗（{エラー概要}）」として扱う
```
   - 変更後:
```markdown
- findings ファイルが存在しない、または空 → 失敗。Task ツールの返答から例外情報（エラーメッセージの要約、スタックトレースの最終行等）を抽出し、該当次元は「分析失敗（{エラー概要}）」として扱う。具体例: 「Read 失敗: ファイルが見つかりません」「解析エラー: YAML パースエラー」
```

2. **Phase 1 テキスト出力の変更（131-136行目）**:
   - 変更前:
```markdown
テキスト出力:
```
Phase 1 完了: {成功数}/{dim_count}
- {次元名}: critical {N}, improvement {M}, info {K}（または「分析失敗（{エラー概要}）」）
（各次元を1行ずつ表示）
```
```
   - 変更後:
```markdown
テキスト出力:
```
Phase 1 完了: {成功数}/{dim_count}
- {次元名}: critical {N}, improvement {M}, info {K}（または「分析失敗（{エラー概要}）」）
（各次元を1行ずつ表示）

失敗した次元がある場合は、以下を追加表示:
```
リトライ方法: `/agent_audit {agent_path}` を再実行してください
失敗の原因として、サブエージェント定義ファイルの不在、findings ファイル保存権限の不足等が考えられます。
```
```

### 3. SKILL.md (Phase 2)（修正）
**対応フィードバック**:
- C-6: Phase 2 Step 4 サブエージェント失敗時のフォールバック未定義
- C-7: ユーザー確認の欠落
- I-1: 一括承認パターンの粒度不足
- I-2: ユーザー入力内容のプレビュー不足
- I-3: 検証失敗時のメッセージ具体性不足
- I-6: Phase 2 Step 4 改善適用失敗時のリトライ判定基準不足

**変更内容**:

1. **Phase 2 Step 2 承認方針の変更（163-166行目）** (I-1):
   - 変更前:
```markdown
続けて `AskUserQuestion` で承認方針を確認:
- **「全て承認」**: 全 findings を承認として Step 3 へ進む
- **「1件ずつ確認」**: Step 2a の per-item 承認ループに入る
- **「キャンセル」**: 改善適用なしで Phase 3 へ直行する
```
   - 変更後:
```markdown
続けて `AskUserQuestion` で承認方針を確認:
- **「全て承認」**: 全 findings を承認として Step 3 へ進む
- **「critical のみ承認」**: critical findings のみ承認、improvement は除外して Step 3 へ進む
- **「improvement のみ承認」**: improvement findings のみ承認、critical は除外して Step 3 へ進む
- **「1件ずつ確認」**: Step 2a の per-item 承認ループに入る（推奨）
- **「キャンセル」**: 改善適用なしで Phase 3 へ直行する
```

2. **Phase 2 Step 2a ユーザー入力プレビュー追加（180-185行目）** (I-2):
   - 変更前:
```markdown
続けて `AskUserQuestion` で方針確認（選択肢は以下の4つ。ユーザーが "Other" で修正内容をテキスト入力した場合は「修正して承認」として扱い、改善計画に含める）:
```
   - 変更後:
```markdown
続けて `AskUserQuestion` で方針確認（選択肢は以下の4つ）:
```

   - 185行目の後に追加:
```markdown

ユーザーが "Other" で修正内容をテキスト入力した場合:
1. 入力内容を以下の形式でテキスト出力してプレビュー:
   ```
   【修正内容のプレビュー】
   {ユーザー入力内容}
   ```
2. `AskUserQuestion` で「この内容で適用しますか？」と確認
3. 「はい」の場合: 「修正して承認」として扱い、改善計画に含める
4. 「いいえ」の場合: 「スキップ」として扱い、次の指摘へ進む
```

3. **Phase 2 Step 3 保存前確認追加（188-209行目）** (C-7):
   - 変更前:
```markdown
#### Step 3: 承認結果の保存

承認された指摘（ユーザー修正内容を含む）を `.agent_audit/{agent_name}/audit-approved.md` に Write で保存する。
```
   - 変更後:
```markdown
#### Step 3: 承認結果の保存

承認された指摘（ユーザー修正内容を含む）を以下のフォーマットで整形し、テキスト出力してプレビューする:

（現行のフォーマット内容を表示）

続けて `AskUserQuestion` で「以上の内容を {.agent_audit/{agent_name}/audit-approved.md の絶対パス} に保存します。よろしいですか？」と確認する。

「はい」の場合: Write で `.agent_audit/{agent_name}/audit-approved.md` に保存する。
「いいえ」の場合: 「保存をキャンセルしました。」とテキスト出力し、Phase 3 へ直行する。
```

4. **Phase 2 Step 4 改善適用失敗時フォールバック追加（226行目の後）** (C-6, I-6):
   - 追加内容:
```markdown

**失敗時のフォールバック**:
サブエージェント完了後、返答内容を解析し、以下の判定を行う:
- 返答に "modified: 0" が含まれる、または "Error" / "Failed" 等のエラー文言がある → 失敗と判定
- 失敗時の処理:
  1. 失敗理由をテキスト出力（TaskOutput から抽出: Edit の old_string 不一致、ファイル読み込みエラー、構文エラー等）
  2. 失敗内容に応じた対処方針を表示:
     - **Edit の old_string 不一致**: 「改善対象箇所が既に変更されています。スキップします。」
     - **ファイル読み込みエラー**: 「ファイルアクセスに失敗しました。権限を確認して `/agent_audit {agent_path}` を再実行してください。」
     - **構文エラー**: 「改善内容の適用に失敗しました。バックアップからロールバックします: `cp {backup_path} {agent_path}`」
  3. バックアップからロールバックコマンドを表示: `cp {backup_path} {agent_path}`
  4. ユーザーに手動修正を促す: 「手動で {agent_path} を確認してください。」
```

5. **Phase 2 検証失敗時メッセージ具体化（234-235行目）** (I-3):
   - 変更前（234-235行目）:
```markdown
3. 検証成功時: 「✓ 検証完了: エージェント定義の構造は正常です」とテキスト出力
4. 検証失敗時: 「✗ 検証失敗: エージェント定義が破損している可能性があります。以下のコマンドでロールバックできます: `cp {backup_path} {agent_path}`」とテキスト出力し、Phase 3 でも警告を表示
```
   - 変更後:
```markdown
5. 検証成功時: 「✓ 検証完了: エージェント定義の構造は正常です」とテキスト出力
6. 検証失敗時: 失敗内容を具体的に表示する:
   - frontmatter がない場合: 「✗ 検証失敗: frontmatter が見つかりません（ファイル先頭が `---` で始まらない）。以下のコマンドでロールバックできます: `cp {backup_path} {agent_path}`」
   - description フィールドがない場合: 「✗ 検証失敗: frontmatter 内に `description:` フィールドが見つかりません。以下のコマンドでロールバックできます: `cp {backup_path} {agent_path}`」
   - description が空の場合: 「✗ 検証失敗: `description:` フィールドが空です。以下のコマンドでロールバックできます: `cp {backup_path} {agent_path}`」
   - Phase 3 でも同じ警告を表示する
```

### 4. group-classification.md（修正）
**対応フィードバック**: I-8: グループ判定基準の曖昧性

**変更内容**:

1. **判定基準の具体化（1-3行目の後に追加）**:
   - 追加内容:
```markdown

## 判定時の注意事項

**主たる機能の特定方法**:
1. frontmatter の `description` フィールドを優先的に参照
2. description がない場合: ファイル内の最初の見出し（`# {タイトル}`）直後の段落を参照
3. 複数機能が併記されている場合: 最初に言及された機能を主たる機能とする

**エッジケース処理**:
- evaluator 特徴数 = producer 特徴数 = 2 の場合: `unclassified`
- evaluator 特徴数 = producer 特徴数 = 3 の場合: `hybrid`（ルール1に該当）
- 同数で境界線上のケース: 以下の優先順位で分類
  1. hybrid（両方の特徴を持つ）
  2. evaluator（分析・検出が主体）
  3. producer（生成・変換が主体）
  4. unclassified（いずれにも該当しない）
```

2. **特徴カウントの明確化（17-21行目の後に追加）**:
   - 追加内容:
```markdown

## 特徴カウントのルール

各特徴項目について、エージェント定義内に該当する記述があれば 1 カウントする。
- 「評価基準・チェックリスト・検出ルールが定義されている」→ いずれか1つでも定義があれば 1 カウント（複数あっても 1 カウント）
- 部分的な記述も含む: 例えば「エラーがあれば報告する」程度の記述でも「問題点を出力する構造」として 1 カウント
```

### 5. templates/apply-improvements.md（修正）
**対応フィードバック**: なし

**変更内容**: なし（現状維持）

## 新規作成ファイル
（なし）

## 削除推奨ファイル
（なし）

## 実装順序

1. **group-classification.md** — グループ判定基準の具体化。SKILL.md が参照するため先に修正
2. **SKILL.md (全体)** — パス変数定義追加、外部パス修正、Phase 0/1/2 の改善を一括適用。他ファイルへの依存関係がないため、group-classification.md 完了後に実施

依存関係の説明:
- SKILL.md の 64 行目が group-classification.md を参照するため、group-classification.md を先に修正
- SKILL.md 内の変更は互いに独立しているため、一括で適用可能

## 注意事項
- SKILL.md の行数が 279 行から増加する見込み（パス変数セクション追加、Phase 2 の拡張等）。増加行数は約 50-70 行と推定
- Phase 2 Step 2 の承認方針に「critical のみ承認」「improvement のみ承認」を追加するため、既存のワークフローテストがある場合は更新が必要
- Phase 2 Step 3 と Step 2a でユーザー確認が増えるため、実行時間が増加する可能性がある
- Phase 2 Step 4 のバックアップ作成時に既存バックアップを確認するため、初回実行時と 2 回目以降で挙動が異なる
- Phase 2 検証ステップで必須フィールド検証を追加するため、description が空のエージェント定義は検証失敗になる
- サブエージェント返答フォーマットに引用符を追加するため、Phase 1 サブエージェント定義ファイル（agents/*/**.md）も同時に更新が必要な場合がある（ただし、今回の findings には含まれていない）
