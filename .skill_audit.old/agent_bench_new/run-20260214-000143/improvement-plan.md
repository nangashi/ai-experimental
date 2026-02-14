# 改善計画: agent_bench_new

## 変更対象ファイル
| # | ファイル | 変更種別 | 変更概要 | 対応フィードバック |
|---|---------|---------|---------|------------------|
| 1 | SKILL.md | 修正 | フォールバックパスを旧版から新版に修正 | C-1, C-2 |
| 2 | SKILL.md | 修正 | agent_audit 参照処理の明示化とパス変数修正 | C-3, C-4 |
| 3 | SKILL.md | 修正 | knowledge.md から累計ラウンド数を読み込む処理を明示化 | I-1 |
| 4 | SKILL.md | 修正 | perspectives/design/ の Glob パターンで old/ を除外 | I-7 |
| 5 | SKILL.md | 修正 | Phase 6 Step 2 の A と B を並列実行するよう変更 | I-9 |
| 6 | SKILL.md | 修正 | perspective 批評テンプレートへの変数定義追加 | I-4, I-5 |
| 7 | templates/phase1b-variant-generation.md | 修正 | パス変数名を audit_findings_paths に統一 | C-4 |
| 8 | templates/phase1b-variant-generation.md | 修正 | audit_findings_paths の条件分岐と Read 処理を明記 | I-2 |
| 9 | templates/phase1a-variant-generation.md | 修正 | perspective_path を Read するステップを削除 | I-6 |
| 10 | templates/phase2-test-document.md | 修正 | knowledge.md の参照範囲を明示 | I-8 |
| 11 | templates/phase5-analysis-report.md | 修正 | スコアサマリのみで比較レポート生成する旨を明記 | I-3 |
| 12 | templates/perspective/critic-completeness.md | 修正 | {target} プレースホルダの削除 | I-4 |

## 各ファイルの変更詳細

### 1. SKILL.md（修正）
**対応フィードバック**: C-1（外部参照 - 他スキルのフォールバックパス）, C-2（外部参照 - 他スキルのデータファイル）

**変更内容**:
- 54行目: `.claude/skills/agent_bench/perspectives/{target}/{key}.md` → `.claude/skills/agent_bench_new/perspectives/{target}/{key}.md`
- 74行目: `.claude/skills/agent_bench/perspectives/design/*.md` → `.claude/skills/agent_bench_new/perspectives/design/*.md`（ただし old/ ディレクトリを除外するパターンを追加）

### 2. SKILL.md（修正）
**対応フィードバック**: C-3（外部参照 - クロススキル参照）, C-4（参照整合性: 未定義変数）

**変更内容**:
- 174行目前に以下の処理を追加:
  ```
  - Glob で `.agent_audit/{agent_name}/audit-*.md` を検索する（`audit-approved.md` は除外）
  - 見つかった場合: 全ファイルのパスをカンマ区切りで `{audit_findings_paths}` として渡す
  - 見つからなかった場合: `{audit_findings_paths}` を空文字列として渡す
  ```

### 3. SKILL.md（修正）
**対応フィードバック**: I-1（knowledge.md の累計ラウンド数導出）

**変更内容**:
- 116-117行目を以下のように明示化:
  ```
  6. `.agent_bench/{agent_name}/knowledge.md` を Read で読み込む
     - **読み込み成功**: 以下の情報を抽出する
       - 累計ラウンド数（「累計ラウンド数: N」フィールドから取得）
       - バリエーションステータステーブル
       - 効果テーブル
       → Phase 1B へ
     - **読み込み失敗**（ファイル不在）→ knowledge.md を初期化して Phase 1A へ
  ```

### 4. SKILL.md（修正）
**対応フィードバック**: I-7（Phase 0 Step 2 の参照データ収集）

**変更内容**:
- 74行目: `.claude/skills/agent_bench_new/perspectives/design/*.md` を Glob で列挙する際、old/ ディレクトリを除外する処理を追加:
  ```
  - Glob で `.claude/skills/agent_bench_new/perspectives/design/*.md` を列挙し、パスに `/old/` を含むファイルを除外する
  - 最初に見つかったファイルを `{reference_perspective_path}` として使用する（構造とフォーマットの参考用）
  - 見つからない場合は `{reference_perspective_path}` を空とする
  ```

### 5. SKILL.md（修正）
**対応フィードバック**: I-9（Phase 6 Step 2 の並列実行順序）

**変更内容**:
- 318-352行目: A と B の実行順序を並列化
  ```
  **ステップ2: ナレッジ更新・スキル知見フィードバック・次アクション選択**

  以下の3つを同時に実行する:

  **A) ナレッジ更新サブエージェント**
  （現状のまま）

  **B) スキル知見フィードバックサブエージェント**
  （現状のまま）

  **C) 次アクション選択（親で実行）**
  （現状のまま）

  A) と B) の両方の完了を待ってから:
  - 「次ラウンド」の場合: Phase 1B に戻る
  - 「終了」の場合: 以下の最終サマリを出力してスキル完了
  ```

### 6. SKILL.md（修正）
**対応フィードバック**: I-4（perspective 批評テンプレートの未定義変数）, I-5（perspective 自動生成 Step 4 の critic テンプレート読込）

**変更内容**:
- Step 4 のパス変数に以下を追加（現在の79行目付近）:
  ```
  - `{target}`: perspective 判定で導出した target（design/code）
  - `{existing_perspectives_summary}`: Glob で `.claude/skills/agent_bench_new/perspectives/{target}/*.md` を列挙し（`/old/` を含むパスは除外）、各ファイルの概要セクションを抽出してサマリとして結合
  ```

### 7. templates/phase1b-variant-generation.md（修正）
**対応フィードバック**: C-4（参照整合性: 未定義変数）

**変更内容**:
- 8-9行目: パス変数名を統一
  ```
  現在:
     - {audit_dim1_path} が指定されている場合: Read で読み込む（agent_audit の基準有効性分析結果 — 改善推奨をバリアント生成の参考にする）
     - {audit_dim2_path} が指定されている場合: Read で読み込む（agent_audit のスコープ整合性分析結果 — スコープ改善をバリアント生成の参考にする）

  変更後:
     - {audit_findings_paths} が空でない場合: カンマ区切りで各パスを Read で読み込む（agent_audit の基準有効性・スコープ整合性分析結果 — 改善推奨をバリアント生成の参考にする）
  ```

### 8. templates/phase1b-variant-generation.md（修正）
**対応フィードバック**: I-2（Phase 1B の条件付きファイル読込）

**変更内容**:
- 8-9行目を以下のように明示化:
  ```
     - {audit_findings_paths} が空でない場合:
       - カンマ区切りでパスを分割する
       - 各パスについて Read で読み込む
       - 読み込んだ内容をバリアント生成時の参考にする（基準有効性・スコープ整合性の改善推奨を考慮）
     - {audit_findings_paths} が空の場合: agent_audit の分析結果は参照しない
  ```

### 9. templates/phase1a-variant-generation.md（修正）
**対応フィードバック**: I-6（Phase 1A の perspective_path 参照）

**変更内容**:
- 10行目を削除:
  ```
  削除:
  3. {perspective_path} が存在することを Read で確認する

  理由: perspective は Phase 0 で既に解決されており、Phase 1A での確認は不要
  ```

### 10. templates/phase2-test-document.md（修正）
**対応フィードバック**: I-8（Phase 2 の knowledge.md 読込）

**変更内容**:
- 7行目を明示化:
  ```
  現在:
     - {knowledge_path} （過去の知見 — テスト対象文書履歴を確認し、過去と異なるドメインを選択する）

  変更後:
     - {knowledge_path} （過去の知見 — 「テストセット履歴」セクションのみを参照し、過去と異なるドメインを選択する）
  ```

### 11. templates/phase5-analysis-report.md（修正）
**対応フィードバック**: I-3（Phase 5 の採点ファイル読込）

**変更内容**:
- 6-7行目を明示化:
  ```
  現在:
     - 以下の採点結果ファイル:
       {scoring_file_paths}

  変更後:
     - 以下の採点結果ファイル（スコアサマリのみを使用）:
       {scoring_file_paths}

  注記: 各採点結果ファイルから「スコアサマリ」セクションのみを抽出し、比較レポートを生成する。問題別の詳細検出結果は参照しない
  ```

### 12. templates/perspective/critic-completeness.md（修正）
**対応フィードバック**: I-4（perspective 批評テンプレートの未定義変数）

**変更内容**:
- 22行目: `{target}` プレースホルダを削除し、一般的な表現に変更
  ```
  現在:
  - [ ] List 5+ essential design elements for this perspective's domain in {target} documents

  変更後:
  - [ ] List 5+ essential design elements for this perspective's domain in the target document type (design/code)
  ```

## 新規作成ファイル
（該当なし）

## 削除推奨ファイル
（該当なし）

## 実装順序
1. **SKILL.md**: 全ての変更内容（フォールバックパス修正、agent_audit 参照処理、knowledge.md 読込明示化、perspectives Glob パターン修正、並列実行順序変更、perspective 批評変数定義）
   - 理由: 親スキル定義を先に修正することで、テンプレート側の変数参照が整合する
2. **templates/phase1b-variant-generation.md**: パス変数名統一と条件分岐明示
   - 理由: SKILL.md で定義された audit_findings_paths 変数を参照するため
3. **templates/phase1a-variant-generation.md**: perspective_path 確認ステップ削除
   - 理由: 他のファイルと依存関係なし、単独で実施可能
4. **templates/phase2-test-document.md**: knowledge.md 参照範囲明示
   - 理由: 他のファイルと依存関係なし、単独で実施可能
5. **templates/phase5-analysis-report.md**: スコアサマリ使用の明記
   - 理由: 他のファイルと依存関係なし、単独で実施可能
6. **templates/perspective/critic-completeness.md**: {target} プレースホルダ削除
   - 理由: SKILL.md で {target} 変数が定義されるが、このテンプレートでは使わない方針に変更

## 注意事項
- SKILL.md の変更は複数箇所にまたがるため、行番号がずれないよう注意する
- フォールバックパスの変更により、agent_bench（旧版）への依存が完全に削除される
- agent_audit 参照は optional として扱い、ファイルが見つからない場合は空文字列を渡す設計を維持する
- Phase 6 Step 2 の並列実行変更により、A と B の完了を両方待つ処理が必要になる
- perspectives/design/old/ ディレクトリは除外パターンで対応し、削除は行わない（履歴保存のため）
