# 改善計画: agent_bench_new

## 変更対象ファイル
| # | ファイル | 変更種別 | 変更概要 | 対応フィードバック |
|---|---------|---------|---------|------------------|
| 1 | SKILL.md | 修正 | 全ての外部パス参照を修正 + エラーハンドリング追加 + Phase 1B 変数名統一 + Phase 6 サマリ件数明確化 + 詳細手順の外部化 | C-1, C-2, C-4, C-5, C-6, C-7, C-9 |
| 2 | templates/phase1b-variant-generation.md | 修正 | パス変数名を SKILL.md と統一 + audit 統合時の承認フロー追加 | C-6, C-4 |
| 3 | templates/phase6a-knowledge-update.md | 修正 | 削除基準を明確化 | C-8 |
| 4 | templates/phase0-perspective-generation.md | 新規作成 | Phase 0 の perspective 自動生成手順を外部化 | C-7 |
| 5 | templates/phase3-error-handling.md | 新規作成 | Phase 3 のエラーハンドリングロジックを外部化 | C-5, C-7 |

## 各ファイルの変更詳細

### 1. SKILL.md（修正）
**対応フィードバック**: C-1, C-2, C-4, C-5, C-6, C-7, C-9

**変更内容**:

#### C-1: 外部パス参照の不整合
- 54行: `.claude/skills/agent_bench/perspectives/` → `.claude/skills/agent_bench_new/perspectives/`
- 74行: `.claude/skills/agent_bench/perspectives/design/` → `.claude/skills/agent_bench_new/perspectives/design/`
- 81行: `.claude/skills/agent_bench/templates/perspective/` → `.claude/skills/agent_bench_new/templates/perspective/`
- 92-95行: `.claude/skills/agent_bench/templates/perspective/critic-*.md` → `.claude/skills/agent_bench_new/templates/perspective/critic-*.md`
- 124行: `.claude/skills/agent_bench/templates/knowledge-init-template.md` → `.claude/skills/agent_bench_new/templates/knowledge-init-template.md`
- 128行: `.claude/skills/agent_bench/approach-catalog.md` → `.claude/skills/agent_bench_new/approach-catalog.md`
- 146行: `.claude/skills/agent_bench/templates/phase1a-variant-generation.md` → `.claude/skills/agent_bench_new/templates/phase1a-variant-generation.md`
- 151行: `.claude/skills/agent_bench/proven-techniques.md` → `.claude/skills/agent_bench_new/proven-techniques.md`
- 165行: `.claude/skills/agent_bench/templates/phase1b-variant-generation.md` → `.claude/skills/agent_bench_new/templates/phase1b-variant-generation.md`
- 184行: `.claude/skills/agent_bench/templates/phase2-test-document.md` → `.claude/skills/agent_bench_new/templates/phase2-test-document.md`
- 186行: `.claude/skills/agent_bench/test-document-guide.md` → `.claude/skills/agent_bench_new/test-document-guide.md`
- 249行: `.claude/skills/agent_bench/templates/phase4-scoring.md` → `.claude/skills/agent_bench_new/templates/phase4-scoring.md`
- 251行: `.claude/skills/agent_bench/scoring-rubric.md` → `.claude/skills/agent_bench_new/scoring-rubric.md`
- 272行: `.claude/skills/agent_bench/templates/phase5-analysis-report.md` → `.claude/skills/agent_bench_new/templates/phase5-analysis-report.md`
- 324行: `.claude/skills/agent_bench/templates/phase6a-knowledge-update.md` → `.claude/skills/agent_bench_new/templates/phase6a-knowledge-update.md`
- 336行: `.claude/skills/agent_bench/templates/phase6b-proven-techniques-update.md` → `.claude/skills/agent_bench_new/templates/phase6b-proven-techniques-update.md`

#### C-2: Phase 0/1/2/5/6 のサブエージェント失敗時の処理フロー
- Phase 0（64-112行）の perspective 自動生成 Step 3/5 に失敗ハンドリング追加:
  ```
  サブエージェント失敗時: エラー内容を出力してスキルを終了する
  ```
- Phase 0（120-129行）の knowledge.md 初期化に失敗ハンドリング追加:
  ```
  サブエージェント失敗時: エラー内容を出力してスキルを終了する
  ```
- Phase 1A（142-158行）にエラーハンドリング追加:
  ```
  サブエージェント失敗時: エラー内容を出力してスキルを終了する
  ```
- Phase 1B（162-176行）にエラーハンドリング追加:
  ```
  サブエージェント失敗時: エラー内容を出力してスキルを終了する
  ```
- Phase 2（180-193行）にエラーハンドリング追加:
  ```
  サブエージェント失敗時: AskUserQuestion で「再試行 / 中断」を選択（Phase 3 と同じパターン）
  ```
- Phase 5（268-279行）にエラーハンドリング追加:
  ```
  サブエージェント失敗時: エラー内容を出力してスキルを終了する
  ```
- Phase 6 Step 2A（318-329行）にエラーハンドリング追加:
  ```
  サブエージェント失敗時: エラー内容を出力してスキルを終了する
  ```
- Phase 6 Step 2B（332-342行）にエラーハンドリング追加:
  ```
  サブエージェント失敗時: 警告を出力して続行（proven-techniques.md 更新は任意のため）
  ```

#### C-5: Phase 3 エラーハンドリングの条件分岐不完全
- 229-236行を以下に置き換え:
  ```
  全サブエージェント完了後、成功数を集計し分岐する:

  - **成功数 = 総数**: Phase 4 へ進む
  - **ベースラインが全失敗（両Run失敗）**: AskUserQuestion で確認する
    - **再試行**: ベースラインのみ再実行（1回のみ）
    - **中断**: エラー内容を出力してスキルを終了する
  - **ベースラインは最低1回成功 かつ、各バリアントプロンプトに最低1回の成功結果がある**: 警告を出力し Phase 4 へ進む（採点は成功した Run のみで実施。Run が1回のみのプロンプトは SD = N/A とする）
  - **いずれかのバリアントプロンプトで成功結果が0回**: AskUserQuestion で確認する
    - **再試行**: 失敗したタスクのみ再実行する（1回のみ）
    - **該当プロンプトを除外して続行**: 成功結果があるプロンプトのみで Phase 4 へ進む
    - **中断**: エラー内容を出力してスキルを終了する
  ```

#### C-6: Phase 1B パス変数の未定義
- 174行を以下に変更:
  ```
  - Glob で `.agent_audit/{agent_name}/audit-*.md` を検索し（`audit-approved.md` は除外）、見つかった全ファイルを以下の変数として渡す:
    - `{audit_dim1_path}`: `audit-ce-*.md` に一致する最初のファイルのパス（見つからない場合は空）
    - `{audit_dim2_path}`: `audit-sa-*.md` に一致する最初のファイルのパス（見つからない場合は空）
  ```

#### C-7: SKILL.md が目標行数を超過
- 64-112行の perspective 自動生成手順を `templates/phase0-perspective-generation.md` に外部化し、SKILL.md では以下のように簡略化:
  ```
  #### パースペクティブ自動生成（perspective 未検出の場合）

  `Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

  `.claude/skills/agent_bench_new/templates/phase0-perspective-generation.md` を Read で読み込み、その内容に従って処理を実行してください。
  パス変数:
  - `{agent_path}`: エージェント定義ファイルの絶対パス
  - `{agent_name}`: Phase 0 で決定した値
  - `{perspective_save_path}`: `.agent_bench/{agent_name}/perspective-source.md` の絶対パス

  サブエージェント失敗時: エラー内容を出力してスキルを終了する
  ```

- 229-236行のエラーハンドリング詳細を `templates/phase3-error-handling.md` に外部化（C-5 の修正内容を含める）

#### C-9: Phase 6 サマリの上位項目件数が未定義
- 364行を以下に変更:
  ```
  - 効果のあったテクニック: {knowledge.md の効果テーブル上位3件}
  ```

### 2. templates/phase1b-variant-generation.md（修正）
**対応フィードバック**: C-6, C-4

**変更内容**:

#### C-6: パス変数名の統一
- 8-9行を以下に変更:
  ```
     - {audit_dim1_path} が指定されている場合: Read で読み込む（agent_audit の基準有効性分析結果 — 改善推奨をバリアント生成の参考にする）
     - {audit_dim2_path} が指定されている場合: Read で読み込む（agent_audit のスコープ整合性分析結果 — スコープ改善をバリアント生成の参考にする）
  ```

#### C-4: audit 統合時の承認フロー追加
- 9行の後に以下を挿入:
  ```
     - audit ファイルを読み込んだ場合: 検出された改善提案のリスト（各項目: 次元、カテゴリ、指摘内容）を生成し、ファイル末尾に `## Audit 統合候補` セクションとして記載する
  ```

- 19行の後に以下を挿入:
  ```
  ## Audit 統合候補
  （audit ファイルを読み込んだ場合のみ記載。以下のフォーマット）
  | # | 次元 | カテゴリ | 指摘内容 |
  |---|------|---------|---------|
  | 1 | CE  | 曖昧性 | 「セキュリティリスク」の定義が不明確 |
  | 2 | SA  | スコープ境界 | 設計レビューと実装レビューの境界が曖昧 |
  ```

- SKILL.md 側（Phase 1B の後、177行付近）に以下を追加:
  ```
  サブエージェント完了後:
  - 返答に「## Audit 統合候補」セクションが含まれる場合:
    - AskUserQuestion でユーザーに提示する
    - 選択肢: 「全て統合 / 個別選択 / 統合をスキップ」
    - 「個別選択」の場合: 各項目に対して AskUserQuestion で承認/却下を選択させる
    - 承認された項目を再度サブエージェントに渡し、バリアント生成に反映させる（再実行）
  - セクションが含まれない場合: 通常通り Phase 2 へ進む
  ```

### 3. templates/phase6a-knowledge-update.md（修正）
**対応フィードバック**: C-8

**変更内容**:

- 16-22行を以下に変更:
  ```
     - 「改善のための考慮事項」を以下のルールで更新する:
       - 既存の原則を全て保持する（削除しない）
       - 新ラウンドで得られた知見を既存原則に統合する（矛盾する場合は新しい知見で更新し、旧原則を修正する）
       - 新たに一般化可能な原則があれば追加する
       - 各原則は「[原則] （根拠: Round N, バリアントX, 効果±Xpt, SD=±Xpt）」の形式とする
       - 20行を超える場合は、削除基準に基づき統合または削除する:
         1. 効果pt（絶対値）が最小かつ SD が最大の原則を優先的に統合/削除
         2. 同一カテゴリ（S/C/N/M）の原則を統合可能な場合は統合する
         3. 統合後も20行を超える場合、effect pt の絶対値が最小の原則を削除する
       - 個別ラウンドの詳細分析は記載しない（詳細はレポートファイルに存在する）
  ```

### 4. templates/phase0-perspective-generation.md（新規作成）
**対応フィードバック**: C-7

**ファイル内容**:
```markdown
以下の手順で perspective を自動生成してください:

## パス変数
- `{agent_path}`: エージェント定義ファイルの絶対パス
- `{agent_name}`: エージェント名
- `{perspective_save_path}`: `.agent_bench/{agent_name}/perspective-source.md` の絶対パス

## 手順

**Step 1: 要件抽出**
- Read で {agent_path} を読み込み、エージェント定義ファイルの内容（目的、評価基準、入力/出力の型、スコープ情報）を `{user_requirements}` として構成する
- エージェント定義が実質空または不足がある場合: AskUserQuestion で以下をヒアリングし `{user_requirements}` に追加する
  - エージェントの目的・役割
  - 想定される入力と期待される出力
  - 使用ツール・制約事項

**Step 2: 既存 perspective の参照データ収集**
- Glob で `.claude/skills/agent_bench_new/perspectives/design/*.md` を列挙する
- 最初に見つかったファイルを `{reference_perspective_path}` として使用する（構造とフォーマットの参考用）
- 見つからない場合は `{reference_perspective_path}` を空とする

**Step 3: perspective 初期生成**
`Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

`.claude/skills/agent_bench_new/templates/perspective/generate-perspective.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{agent_path}`: {agent_path}
- `{user_requirements}`: {user_requirements}
- `{perspective_save_path}`: {perspective_save_path}
- `{reference_perspective_path}`: {reference_perspective_path}

サブエージェント失敗時: エラー内容を返答に含めて終了する

**Step 4: 批判レビュー（4並列）**
以下の4つの `Task` を同一メッセージ内で並列起動する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

各エージェントへのプロンプト:
`.claude/skills/agent_bench_new/templates/perspective/{テンプレート名}` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{perspective_path}`: {perspective_save_path}
- `{agent_path}`: {agent_path}

| テンプレート | 焦点 |
|-------------|------|
| `critic-effectiveness.md` | 品質寄与度 + 他観点との境界 |
| `critic-completeness.md` | 網羅性 + 未考慮事項検出 + 問題バンク |
| `critic-clarity.md` | 表現明確性 + AI動作一貫性 |
| `critic-generality.md` | 汎用性 + 業界依存性フィルタ |

サブエージェント失敗時: エラー内容を返答に含めて終了する

**Step 5: フィードバック統合・再生成**
- 4件の批評から「重大な問題」「改善提案」を分類する
- 重大な問題または改善提案がある場合: フィードバックを `{user_requirements}` に追記し、Step 3 と同じパターンで perspective を再生成する（1回のみ）
- 改善不要の場合: 現行 perspective を維持する

**Step 6: 検証**
- Read で {perspective_save_path} を読み込み、必須セクション（`## 概要`, `## 評価スコープ`, `## スコープ外`, `## ボーナス/ペナルティの判定指針`, `## 問題バンク`）の存在を確認する
- 検証成功 → 以下の1行を返答する:
  ```
  perspective 自動生成完了: {perspective_save_path}
  ```
- 検証失敗 → エラー内容を返答に含めて終了する
```

### 5. templates/phase3-error-handling.md（新規作成）
**対応フィードバック**: C-5, C-7

**ファイル内容**:
```markdown
# Phase 3 エラーハンドリング詳細

以下の条件に基づき分岐を判定してください:

## 分岐ロジック

全サブエージェント完了後、成功数を集計し分岐する:

### 1. 全成功
- **条件**: 成功数 = 総数
- **処理**: Phase 4 へ進む

### 2. ベースライン全失敗
- **条件**: ベースラインが全失敗（両Run失敗）
- **処理**: AskUserQuestion で確認する
  - 選択肢:
    - **再試行**: ベースラインのみ再実行（1回のみ）→ 成功したら Phase 4 へ、失敗したら中断
    - **中断**: エラー内容を出力してスキルを終了する

### 3. ベースライン成功・バリアント部分失敗
- **条件**: ベースラインは最低1回成功 かつ、各バリアントプロンプトに最低1回の成功結果がある
- **処理**: 警告を出力し Phase 4 へ進む
  - 警告内容: 「一部の実行が失敗しました。採点は成功した Run のみで実施します。Run が1回のみのプロンプトは SD = N/A とします」
  - 採点は成功した Run のみで実施
  - Run が1回のみのプロンプトは SD = N/A とする

### 4. バリアント全失敗
- **条件**: いずれかのバリアントプロンプトで成功結果が0回
- **処理**: AskUserQuestion で確認する
  - 選択肢:
    - **再試行**: 失敗したタスクのみ再実行する（1回のみ）→ 条件1/3に該当すれば Phase 4 へ、それ以外は再度確認
    - **該当プロンプトを除外して続行**: 成功結果があるプロンプトのみで Phase 4 へ進む（ベースラインが含まれることを確認）
    - **中断**: エラー内容を出力してスキルを終了する

## 出力

分岐判定後、以下のフォーマットで状況を出力する:

```
評価完了: {成功数}/{総数} タスク成功。Phase 4（採点）に進みます。
{警告があれば警告メッセージ}
```
```

## 新規作成ファイル

| ファイル | 目的 | 対応フィードバック |
|---------|------|------------------|
| templates/phase0-perspective-generation.md | Phase 0 の perspective 自動生成手順を外部化（64-112行を移動） | C-7 |
| templates/phase3-error-handling.md | Phase 3 のエラーハンドリングロジックを外部化（229-236行を拡張・移動） | C-5, C-7 |

## 削除推奨ファイル

（なし）

## 実装順序

1. **templates/phase0-perspective-generation.md（新規作成）**
   - 理由: SKILL.md の Phase 0 から参照されるため、先に作成する必要がある

2. **templates/phase3-error-handling.md（新規作成）**
   - 理由: SKILL.md の Phase 3 から参照されるため、先に作成する必要がある

3. **templates/phase6a-knowledge-update.md（修正）**
   - 理由: 他ファイルへの依存なし、独立した修正

4. **templates/phase1b-variant-generation.md（修正）**
   - 理由: SKILL.md から参照されるが、SKILL.md の修正前に完了する必要がある

5. **SKILL.md（修正）**
   - 理由: 新規テンプレートと修正済みテンプレートを参照するため、最後に実施

依存関係の詳細:
- phase0-perspective-generation.md（新規）→ SKILL.md 64-112行で参照 → phase0 を先に作成
- phase3-error-handling.md（新規）→ SKILL.md 229-236行付近で参照 → phase3 を先に作成
- phase1b-variant-generation.md（修正）→ SKILL.md 165行で参照 → phase1b を先に修正
- phase6a-knowledge-update.md（修正）→ SKILL.md 324行で参照 → phase6a を先に修正

## 注意事項

1. **パス変数の整合性**: 全ての外部参照で `.claude/skills/agent_bench/` → `.claude/skills/agent_bench_new/` への変更を漏れなく実施すること
2. **エラーハンドリングの一貫性**: Phase 0/1/2/5/6 のエラーハンドリングは Phase 3/4 のパターンに準拠すること
3. **テンプレート外部化の検証**: 外部化したテンプレートが SKILL.md から正しく参照されることを確認すること
4. **変数名の統一**: `{audit_findings_paths}` → `{audit_dim1_path}`, `{audit_dim2_path}` への変更を SKILL.md とテンプレート両方で実施すること
5. **audit 統合の承認フロー**: Phase 1B で audit ファイルを読み込んだ場合、必ず承認フローを実行すること（スキップしない）
6. **削除基準の明確性**: phase6a-knowledge-update.md の削除基準が数値ベースで明確に定義されていることを確認すること
7. **サマリ件数の固定**: Phase 6 最終サマリで「上位3件」と具体的に指定すること
