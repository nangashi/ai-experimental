# 改善計画: agent_bench_new

## 変更対象ファイル
| # | ファイル | 変更種別 | 変更概要 | 対応フィードバック |
|---|---------|---------|---------|------------------|
| 1 | SKILL.md | 修正 | Phase 1A/1B 失敗時のエラーメッセージ追加 | C-1 |
| 2 | SKILL.md | 修正 | 「成功基準」セクションを冒頭に追加 | C-2 |
| 3 | SKILL.md | 修正 | 未使用変数 {existing_perspectives_summary} を削除 | C-8 |
| 4 | SKILL.md | 修正 | Phase 0 perspective 検証のインライン化（サブエージェント削除） | I-1 |
| 5 | SKILL.md | 修正 | Phase 0 perspective 自動生成のデフォルトを簡略版に変更 | C-9 |
| 6 | SKILL.md | 修正 | Phase 1B の audit パス参照前に存在確認を追加 | I-7 |
| 7 | SKILL.md | 修正 | Phase 1A/1B スキップ時のベースラインファイル存在確認 | I-6 |
| 8 | SKILL.md | 修正 | Phase 4 開始時に進捗メッセージを追加 | I-8 |
| 9 | SKILL.md | 修正 | Phase 6 開始時に進捗メッセージを追加 | I-9 |
| 10 | SKILL.md | 修正 | Phase 6 Step 2A で knowledge.md 更新の承認プロセス追加 | C-6 |
| 11 | SKILL.md | 修正 | Phase 6 の top-techniques 抽出を knowledge-update に統合 | I-2 |
| 12 | SKILL.md | 修正 | Phase 6 Step 2 の構造簡略化（A.2をAに統合） | I-3 |
| 13 | SKILL.md | 修正 | Phase 6 Step 2 を外部テンプレート化して行数削減 | C-5 |
| 14 | phase0-perspective-validation.md | 削除推奨 | Phase 0 でインライン化により不要 | I-1 |
| 15 | phase6-extract-top-techniques.md | 修正 | セクション名を「## 効果テーブル」に修正 | C-3 |
| 16 | phase6-extract-top-techniques.md | 削除推奨 | knowledge-update に統合により不要 | I-2 |
| 17 | phase4-scoring.md | 修正 | 返答フォーマットで小数第2位まで明示 | C-7 |
| 18 | phase6a-knowledge-update.md | 修正 | 返答に上位3件テクニック名を含める | I-2 |
| 19 | phase6a-knowledge-update.md | 修正 | 更新後にセクション検証ステップを追加 | I-5 |
| 20 | phase0-perspective-generation.md | 修正 | デフォルトを簡略版に変更し、エラー時フォールバック | C-9 |
| 21 | templates/phase6-step2-workflow.md | 新規作成 | Phase 6 Step 2 の外部化テンプレート | C-5, I-3 |

## 各ファイルの変更詳細

### 1. SKILL.md（修正）
**対応フィードバック**: C-1, C-2, C-5, C-6, C-8, C-9, I-1, I-2, I-3, I-6, I-7, I-8, I-9

**変更内容**:

- **冒頭に「成功基準」セクション追加** (C-2):
  ```markdown
  ## 成功基準

  以下のいずれかの条件を満たした場合、最適化を終了します:
  - 収束判定: 3ラウンド連続でベースラインが推奨された場合
  - 改善率上限: 初期スコアから +15% 以上の改善を達成した場合
  - ラウンド上限: 累計5ラウンドに達した場合
  - ユーザー判断: Phase 6 で「終了」を選択した場合
  ```

- **line 62: {existing_perspectives_summary} 変数を削除** (C-8):
  ```
  現在: - `{existing_perspectives_summary}`: Glob で...
  →削除
  ```

- **line 88-95: Phase 0 perspective 検証をインライン化** (I-1):
  ```
  現在: Task ツールで phase0-perspective-validation.md を実行

  改善後:
  5. Read で `.agent_bench/{agent_name}/perspective.md` を読み込む
  6. Grep で以下の必須セクションを検証する:
     - パターン: `^##?\s*(評価観点|Evaluation Criteria)`
     - パターン: `^##?\s*(問題バンク|Problem Bank)`
  7. 検証結果に応じて処理する:
     - 全セクション存在: 次の処理へ進む
     - 不足あり: 以下のエラーメッセージを出力して終了
       ```
       エラー: perspective.md の必須セクションが不足しています
       - 不足セクション: {セクション名リスト}
       - ファイル: {perspective_path}
       - 対処法: perspective-source.md を修正するか、Phase 0 の perspective 自動生成を再実行してください
       ```
  ```

- **line 70-84: perspective 自動生成のデフォルトを簡略版に変更** (C-9):
  ```
  現在: `.claude/skills/agent_bench_new/templates/phase0-perspective-generation.md` を実行

  改善後:
  1. `.claude/skills/agent_bench_new/templates/phase0-perspective-generation-simple.md` を実行（簡略版）
  2. サブエージェント失敗時: 標準版（4並列批評）にフォールバック
     - `.claude/skills/agent_bench_new/templates/phase0-perspective-generation.md` を実行
     - フォールバックも失敗時: エラーメッセージを出力して終了
  ```

- **line 147, 177: Phase 1A/1B 失敗時のエラーメッセージ追加** (C-1):
  ```
  現在: サブエージェント失敗時: エラー内容を出力してスキルを終了する

  改善後:
  サブエージェント失敗時: 以下のエラーメッセージを出力してスキルを終了する
  ```
  エラー: Phase 1{A/B} のバリアント生成に失敗しました
  - 原因: {サブエージェントの失敗理由}
  - 対処法:
    1. knowledge.md のバリエーションステータステーブルを確認し、UNTESTED のバリエーションが存在するか確認する
    2. approach-catalog.md の定義と整合性を確認する
    3. 手動でプロンプトファイルを作成する場合: {prompts_dir}/v{NNN}-*.md に保存し、Benchmark Metadata を記載する
  ```
  ```

- **line 171-174: Phase 1B の audit パス参照前に存在確認を追加** (I-7):
  ```
  現在: Glob で `.agent_audit/{agent_name}/audit-*.md` を検索し...

  改善後:
  - Bash で `test -d .agent_audit/{agent_name}` を実行し、ディレクトリの存在を確認する
  - ディレクトリが存在する場合のみ Glob で `.agent_audit/{agent_name}/audit-*.md` を検索する
  - ディレクトリが存在しない場合: audit パス変数を全て空文字列 `""` として渡す
  ```

- **line 129-133, 156-160: Phase 1A/1B スキップ時のベースラインファイル存在確認** (I-6):
  ```
  現在:
  - Glob で `{prompts_dir}/v{NNN}-*.md` を検索し...
  - 「スキップ」の場合: Phase 1 をスキップして Phase 2 へ進む

  改善後:
  - Glob で `{prompts_dir}/v{NNN}-*.md` を検索し、既存ファイルがある場合:
    - AskUserQuestion でユーザーに確認する
    - 選択肢: 「上書き / スキップして Phase 2 へ」
    - 「スキップ」の場合:
      1. Glob で `{prompts_dir}/v{NNN}-baseline.md` を検索し、ベースラインファイルの存在を確認する
      2. 存在する場合: Phase 1 をスキップして Phase 2 へ進む
      3. 存在しない場合: 以下のエラーメッセージを出力して終了
         ```
         エラー: Phase 1 をスキップするにはベースラインファイルが必要です
         - 不在ファイル: {prompts_dir}/v{NNN}-baseline.md
         - 対処法: 「上書き」を選択してバリアント生成を実行してください
         ```
  ```

- **line 244: Phase 4 開始時に進捗メッセージを追加** (I-8):
  ```
  現在: ### Phase 4: 採点（サブエージェントの並列実行）

  改善後:
  ### Phase 4: 採点（サブエージェントの並列実行）

  Phase 4 開始時に以下をテキスト出力する:

  ```
  ## Phase 4: 採点
  - 採点タスク数: {N}（プロンプト数）
  - 採点プロンプト: {プロンプト名リスト}
  ```
  ```

- **line 290: Phase 6 開始時に進捗メッセージを追加** (I-9):
  ```
  現在: ### Phase 6: プロンプト選択・デプロイ・次アクション（親で実行）

  改善後:
  ### Phase 6: プロンプト選択・デプロイ・次アクション（親で実行）

  Phase 6 開始時に以下をテキスト出力する:

  ```
  ## Phase 6: デプロイ・知見蓄積
  - プロンプト選択とデプロイを実行します
  ```
  ```

- **line 316-373: Phase 6 Step 2 を外部テンプレート化** (C-5, I-3):
  ```
  現在: Phase 6 Step 2 の詳細手順が SKILL.md に記述されている（約60行）

  改善後:
  #### ステップ2: ナレッジ更新・スキル知見フィードバック・次アクション選択

  `Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

  `.claude/skills/agent_bench_new/templates/phase6-step2-workflow.md` を Read で読み込み、その内容に従って処理を実行してください。
  パス変数:
  - `{knowledge_path}`: `.agent_bench/{agent_name}/knowledge.md` の絶対パス
  - `{proven_techniques_path}`: `.claude/skills/agent_bench_new/proven-techniques.md` の絶対パス
  - `{report_save_path}`: `.agent_bench/{agent_name}/reports/round-{NNN}-comparison.md`
  - `{recommended_name}`, `{judgment_reason}`: Phase 5 のサブエージェント返答の recommended と reason
  - `{agent_name}`: Phase 0 で決定した値
  - `{round_number}`: 現在のラウンド番号

  サブエージェント返答: 以下の2行
  - 1行目: 効果のあったテクニック（上位3件、カンマ区切り）
  - 2行目: 次アクション選択結果（`next_round` / `end`）

  サブエージェント完了後、返答に応じて分岐:
  - `next_round` の場合: Phase 1B に戻る
  - `end` の場合: 最終サマリを出力してスキル完了
  ```

- **Phase 6 Step 2A で knowledge.md 更新の承認プロセス追加** (C-6):
  上記の外部テンプレート化により、templates/phase6-step2-workflow.md 内で実装

### 2. phase0-perspective-validation.md（削除推奨）
**対応フィードバック**: I-1

**変更内容**: Phase 0 でインライン化されたため、このファイルは削除推奨

### 3. phase6-extract-top-techniques.md（削除推奨）
**対応フィードバック**: C-3, I-2

**変更内容**:
- line 6: セクション名を「## 効果テーブル」に修正（ただし、I-2 により削除推奨のため、修正は不要）
- knowledge-update に統合されるため、このファイルは削除推奨

### 4. phase4-scoring.md（修正）
**対応フィードバック**: C-7

**変更内容**:
- line 11-12: 返答フォーマットで小数第2位まで明示
  ```
  現在:
  {prompt_name}: Mean={X.X}, SD={X.X}
  Run1={X.X}(検出{X.X}+bonus{N}-penalty{N}), Run2={X.X}(検出{X.X}+bonus{N}-penalty{N})

  改善後:
  {prompt_name}: Mean={X.XX}, SD={X.XX}
  Run1={X.XX}(検出{X.XX}+bonus{N}-penalty{N}), Run2={X.XX}(検出{X.XX}+bonus{N}-penalty{N})

  注: 小数第2位まで表示（例: 7.50、8.30）
  ```

### 5. phase6a-knowledge-update.md（修正）
**対応フィードバック**: I-2, I-5

**変更内容**:

- **返答に上位3件テクニック名を含める** (I-2):
  ```
  現在: 3. 以下のフォーマットで確認のみ返答する:
  knowledge.md 更新完了（累計ラウンド数: {N}）

  改善後: 3. 効果テーブルから上位3件のテクニック名を抽出する:
     - 「総合効果スコア」列でソートし、ステータスが `EFFECTIVE` の行のみ対象
     - 総合効果スコアが同点の場合は、ラウンド数が多い方を優先
     - 上位3件のテクニック名をカンマ区切りで返答に含める
     - 3件未満の場合は存在する数のみ、0件の場合は `なし`
  4. 以下のフォーマットで返答する（2行）:
     1行目: knowledge.md 更新完了（累計ラウンド数: {N}）
     2行目: 効果のあったテクニック: {テクニック名（カンマ区切り）または「なし」}
  ```

- **更新後にセクション検証ステップを追加** (I-5):
  ```
  2.5. knowledge.md 更新後、Grep で以下の必須セクションを検証する:
     - パターン: `^##\s*効果テーブル`
     - パターン: `^##\s*バリエーションステータス`
     - パターン: `^##\s*改善のための考慮事項`
     - パターン: `^##\s*最新ラウンドサマリ`
     - パターン: `^##\s*ラウンド別スコア推移`
  3. 検証結果に応じて処理する:
     - 全セクション存在: 次の処理へ進む
     - 不足あり: エラーメッセージを出力して終了
       ```
       エラー: knowledge.md 更新後の検証に失敗しました
       - 不足セクション: {セクション名リスト}
       - ファイル: {knowledge_path}
       - 対処法: knowledge.md のセクション構造を修正してください
       ```
  ```

### 6. phase0-perspective-generation.md（修正）
**対応フィードバック**: C-9

**変更内容**:
- Step 2.5 の生成モード選択を削除（SKILL.md で簡略版をデフォルトとし、失敗時にこのテンプレートにフォールバックする設計に変更）
- Step 3 分岐を削除し、標準版（4並列批評）の手順のみ残す

### 7. templates/phase6-step2-workflow.md（新規作成）
**対応フィードバック**: C-5, C-6, I-2, I-3

**変更内容**: 新規テンプレートとして作成（内容は後述「新規作成ファイル」セクション参照）

## 新規作成ファイル

### templates/phase6-step2-workflow.md
**目的**: Phase 6 Step 2 のワークフロー外部化（SKILL.md の行数削減）
**対応フィードバック**: C-5, C-6, I-2, I-3

**ファイル内容**:
```markdown
# Phase 6 Step 2: ナレッジ更新・スキル知見フィードバック・次アクション選択

以下の手順で Phase 6 Step 2 を実行してください:

## パス変数
- `{knowledge_path}`: knowledge.md の絶対パス
- `{proven_techniques_path}`: proven-techniques.md の絶対パス
- `{report_save_path}`: 比較レポートの絶対パス
- `{recommended_name}`: Phase 5 の推奨プロンプト名
- `{judgment_reason}`: Phase 5 の判定理由
- `{agent_name}`: エージェント名
- `{round_number}`: 現在のラウンド番号

## 手順

### Step 1: ナレッジ更新

`Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

`.claude/skills/agent_bench_new/templates/phase6a-knowledge-update.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{knowledge_path}`: {knowledge_path}
- `{report_save_path}`: {report_save_path}
- `{recommended_name}`: {recommended_name}
- `{judgment_reason}`: {judgment_reason}

サブエージェント失敗時: エラー内容を出力してスキルを終了する

サブエージェント返答（2行）:
- 1行目: 更新完了通知
- 2行目: 効果のあったテクニック（上位3件、カンマ区切り）

返答の2行目を `{top_techniques}` 変数として保持する

### Step 2: knowledge.md 更新サマリの提示と承認

1. Read で {knowledge_path} を読み込む
2. 以下のセクションを抽出してサマリを作成する:
   - `## 最新ラウンドサマリ`: 今回のラウンド結果
   - `## 効果テーブル`: 上位5件
   - `## 改善のための考慮事項`: 全原則（最大20行）
3. AskUserQuestion でサマリを提示し、ユーザーに承認を求める:
   - 質問: "knowledge.md を以下の内容で更新しました。承認しますか？"
   - サマリ: 上記で抽出した内容
   - 選択肢:
     - **承認**: 次の処理へ進む
     - **却下（修正を要求）**: ユーザーに修正内容をヒアリングし、knowledge.md を再度更新する
4. 却下の場合: AskUserQuestion で修正内容を確認し、手動で knowledge.md を Edit で修正する
5. 再度サマリを提示し、承認を得る（1回のみ）

### Step 3: スキル知見フィードバックと次アクション選択（並列実行）

以下の2つを Task ツールで並列実行する:

**A) スキル知見フィードバックサブエージェント**

`Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

`.claude/skills/agent_bench_new/templates/phase6b-proven-techniques-update.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{proven_techniques_path}`: {proven_techniques_path}
- `{knowledge_path}`: {knowledge_path}
- `{report_save_path}`: {report_save_path}
- `{agent_name}`: {agent_name}

サブエージェント失敗時: 警告を出力して続行（proven-techniques.md 更新は任意のため）

**B) 次アクション選択（親で実行、A と並列）**

AskUserQuestion でユーザーに確認する:
- 質問: "次のアクションを選択してください"
- 選択肢:
  1. **次ラウンドへ** — 続けて最適化を実行する
  2. **終了** — 最適化を終了する
- 収束判定が「収束の可能性あり」の場合はその旨を付記する
- 累計ラウンド数が3以上の場合は「目標ラウンド数に達しました」を付記する

ユーザー選択を `{next_action}` 変数として保持する

### Step 4: 返答

A) の完了を待ってから、以下のフォーマットで返答する（2行のみ）:

1行目: {top_techniques}
2行目: {next_action が「次ラウンド」の場合: `next_round`、「終了」の場合: `end`}
```

## 削除推奨ファイル

| ファイル | 理由 | 対応フィードバック |
|---------|------|------------------|
| templates/phase0-perspective-validation.md | Phase 0 でインライン化により不要 | I-1 |
| templates/phase6-extract-top-techniques.md | phase6a-knowledge-update.md に統合により不要 | I-2 |

## 実装順序

1. **templates/phase6-step2-workflow.md を新規作成** (C-5)
   - 理由: SKILL.md の Phase 6 Step 2 外部化で参照される

2. **phase6a-knowledge-update.md を修正** (I-2, I-5)
   - 理由: templates/phase6-step2-workflow.md から参照される

3. **phase4-scoring.md を修正** (C-7)
   - 理由: 他ファイルへの依存なし

4. **SKILL.md を修正** (C-1, C-2, C-5, C-6, C-8, C-9, I-1, I-2, I-3, I-6, I-7, I-8, I-9)
   - 理由: templates/phase6-step2-workflow.md、phase6a-knowledge-update.md の変更を参照

5. **phase0-perspective-generation.md を修正** (C-9)
   - 理由: SKILL.md の変更後に整合性確認

6. **phase0-perspective-validation.md を削除** (I-1)
   - 理由: SKILL.md の変更完了後に削除

7. **phase6-extract-top-techniques.md を削除** (I-2)
   - 理由: phase6a-knowledge-update.md の変更完了後に削除

## 注意事項

- **変更によって既存のワークフローが壊れないこと**:
  - Phase 0 の perspective 検証インライン化により、サブエージェント起動コストが削減されるが、検証ロジックは同等
  - Phase 6 Step 2 の外部化により、SKILL.md の行数が約60行削減されるが、実行ロジックは同等
  - Phase 6 の top-techniques 抽出統合により、サブエージェント起動が1回削減されるが、返答フォーマットは拡張

- **テンプレート外部化の場合、SKILL.md の参照箇所も同時に更新すること**:
  - templates/phase6-step2-workflow.md の新規作成に伴い、SKILL.md の Phase 6 Step 2 を参照箇所に書き換え

- **新規テンプレートのパス変数が SKILL.md で定義されていること**:
  - templates/phase6-step2-workflow.md で使用するパス変数は全て SKILL.md の Phase 6 で定義済み
