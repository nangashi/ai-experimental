# 改善計画: agent_bench_new

## 変更対象ファイル
| # | ファイル | 変更種別 | 変更概要 | 対応フィードバック |
|---|---------|---------|---------|------------------|
| 1 | SKILL.md | 修正 | パス変数リストに {audit_dim1_path}, {audit_dim2_path} 追加、{audit_findings_paths} の記述を {audit_dim1_path}, {audit_dim2_path} に修正、perspective 自動生成の再生成条件明確化、perspective-source.md 存在確認追加、Phase 6 Step 2C の実行順序修正、外部参照パスを agent_bench_new 内に変更、外部依存の明示 | C-1, C-2, C-3, C-4, C-5, I-1, I-3, I-4 |
| 2 | templates/phase1b-variant-generation.md | 修正 | パス変数リスト追加、外部ディレクトリへの直接参照を変数に置換 | C-1, C-2, I-5 |
| 3 | templates/phase2-test-document.md | 修正 | perspective_path の Read 削除 | I-6 |
| 4 | templates/phase4-scoring.md | 修正 | 採点詳細保存の目的を明記 | I-2 |
| 5 | templates/phase6b-proven-techniques-update.md | 修正 | 類似性判定基準とエビデンス弱さ判定基準の明確化 | I-7, I-8 |

## 各ファイルの変更詳細

### 1. SKILL.md（修正）
**対応フィードバック**:
- C-1: 参照整合性: 未定義変数の参照
- C-2: データフロー: 変数名の不一致
- C-3: 条件分岐の完全性: perspective 自動生成の再生成条件が曖昧
- C-4: 冪等性: perspective 自動生成で再実行時の上書き挙動が未定義
- C-5: データフロー: Phase 6 Step 2C の完了待機
- I-1: 外部スキルディレクトリへの参照
- I-3: 参照整合性: 外部ディレクトリへの参照
- I-4: 外部ディレクトリへの参照の依存関係明示

**変更内容**:

1. **Phase 0 Step 4b (行54)**: 外部パス参照を agent_bench_new 内に変更
   - 現在: `.claude/skills/agent_bench/perspectives/{target}/{key}.md` を Read で確認する
   - 改善: `.claude/skills/agent_bench_new/perspectives/{target}/{key}.md` を Read で確認する

2. **Phase 0 Step 2 (行73-74)**: 外部パス参照を agent_bench_new 内に変更
   - 現在: `.claude/skills/agent_bench/perspectives/design/*.md` を Glob で列挙する
   - 改善: `.claude/skills/agent_bench_new/perspectives/design/*.md` を Glob で列挙する

3. **Phase 0 Step 1 (パースペクティブ自動生成冒頭)**: perspective-source.md 存在確認を追加
   - 現在: (チェックなし)
   - 改善: Step 1 の前に「既に {perspective_source_path} が存在する場合は自動生成をスキップし、既存ファイルを使用する」を追加

4. **Phase 0 Step 5 (行105-106)**: 再生成条件の明確化
   - 現在: 「重大な問題または改善提案がある場合」
   - 改善: 「4件の批評ファイルのいずれかに「## 重大な問題」セクションの項目が1件以上存在する場合」

5. **Phase 1B (行174)**: パス変数リストに変数定義追加、変数名の統一
   - 現在: 「Glob で `.agent_audit/{agent_name}/audit-*.md` を検索し（`audit-approved.md` は除外）、見つかった全ファイルのパスをカンマ区切りで `{audit_findings_paths}` として渡す」
   - 改善: 「Glob で `.agent_audit/{agent_name}/audit-*.md` を検索し、以下のパス変数を定義する（該当ファイルが存在しない場合は空文字列）:
     - `{audit_dim1_path}`: `audit-ce-*.md` にマッチする最初のファイルパス（基準有効性分析）
     - `{audit_dim2_path}`: `audit-sa-*.md` にマッチする最初のファイルパス（スコープ整合性分析）

   **外部依存の明示**: `.agent_audit/{agent_name}/` は agent_audit スキルが生成するディレクトリです。agent_bench_new は agent_audit の後に実行することを推奨します」

6. **Phase 6 Step 2 (行330-352)**: 実行順序の修正
   - 現在: 「**次に** 以下の2つを同時に実行する: (B と C を列挙)」および「B) スキル知見フィードバックサブエージェントの完了を待ってから」
   - 改善: 「**次に** スキル知見フィードバック更新を実行する: (B のみを記述)」「**最後に** 次アクション選択を実行する: (C のみを記述、B の完了待機記述は削除)」

### 2. templates/phase1b-variant-generation.md（修正）
**対応フィードバック**:
- C-1: 参照整合性: 未定義変数の参照
- C-2: データフロー: 変数名の不一致
- I-5: テンプレート内の外部ディレクトリ参照

**変更内容**:

1. **手順1 (行8-9)**: パス変数リストを追加し、外部パス直接参照を削除
   - 現在:
     ```
     - {audit_dim1_path} が指定されている場合: Read で読み込む（agent_audit の基準有効性分析結果 — 改善推奨をバリアント生成の参考にする）
     - {audit_dim2_path} が指定されている場合: Read で読み込む（agent_audit のスコープ整合性分析結果 — スコープ改善をバリアント生成の参考にする）
     ```
   - 改善:
     ```
     - {audit_dim1_path} が指定されている場合（空文字列でない場合）: Read で読み込む（基準有効性分析結果 — 改善推奨をバリアント生成の参考にする）
     - {audit_dim2_path} が指定されている場合（空文字列でない場合）: Read で読み込む（スコープ整合性分析結果 — スコープ改善をバリアント生成の参考にする）
     ```

2. **パス変数リスト追加**: ファイル冒頭（手順1の前）に以下を追加
   ```
   ## パス変数
   - `{knowledge_path}`: knowledge.md の絶対パス
   - `{agent_path}`: デプロイ済みベースラインの絶対パス
   - `{proven_techniques_path}`: proven-techniques.md の絶対パス
   - `{perspective_path}`: perspective.md の絶対パス
   - `{prompts_dir}`: プロンプト保存ディレクトリの絶対パス
   - `{approach_catalog_path}`: approach-catalog.md の絶対パス
   - `{audit_dim1_path}`: agent_audit の基準有効性分析ファイル（空文字列の場合あり）
   - `{audit_dim2_path}`: agent_audit のスコープ整合性分析ファイル（空文字列の場合あり）
   ```

### 3. templates/phase2-test-document.md（修正）
**対応フィードバック**: I-6: Phase 2 での perspective_path と perspective_source_path の二重 Read

**変更内容**:

1. **手順1 (行5)**: perspective_path の Read を削除
   - 現在:
     ```
     - {perspective_path} （観点定義 — 問題バンクを含まない作業コピー）
     - {perspective_source_path} （観点定義ソース — 問題バンクを含む。テスト文書の問題埋め込み時に参考にする）
     ```
   - 改善:
     ```
     - {perspective_source_path} （観点定義ソース — 問題バンクを含む。入力型判定と問題埋め込みに使用）
     ```

2. **手順2 (行8)**: 参照元を perspective.md から perspective_source_path に修正
   - 現在: 「perspective.md の概要からエージェントの入力型を判定する」
   - 改善: 「perspective_source_path の概要からエージェントの入力型を判定する」

### 4. templates/phase4-scoring.md（修正）
**対応フィードバック**: I-2: Phase 4 の採点詳細保存の必要性

**変更内容**:

1. **手順6 (行8)**: 採点詳細保存の目的を明記
   - 現在: 「詳細な採点結果（問題別検出マトリクス、ボーナス/ペナルティ詳細）を Write で {scoring_save_path} に保存する」
   - 改善: 「詳細な採点結果（問題別検出マトリクス、ボーナス/ペナルティ詳細）を Write で {scoring_save_path} に保存する（監査・デバッグ用。Phase 5 の分析で参照）」

### 5. templates/phase6b-proven-techniques-update.md（修正）
**対応フィードバック**:
- I-7: 曖昧表現: 「最も類似する」の判定基準が未定義
- I-8: 曖昧表現: 「エビデンスが最も弱い」の判定基準が未定義

**変更内容**:

1. **サイズ制限 Section 1/2 (行37)**: 類似性判定基準を明確化
   - 現在: 「超過時は最も類似する2エントリをマージして1つにする」
   - 改善: 「超過時は同一カテゴリ内で効果範囲が最も重複する2エントリをマージして1つにする（判定基準: テクニック名と適用対象の類似度。例: 「セクション構造化」と「階層化」、「コード」と「実装」など）」

2. **サイズ制限 Section 3 (行40)**: エビデンス弱さ判定基準を明確化
   - 現在: 「超過時はエビデンスが最も弱いエントリを削除する」
   - 改善: 「超過時はエビデンスが最も弱いエントリを削除する（判定基準: 1. 出典エージェント数が最小、2. |effect| が最小、3. ラウンド数が最小、の順に優先）」

## 新規作成ファイル
（なし）

## 削除推奨ファイル
（なし）

## 実装順序

1. **templates/phase1b-variant-generation.md** — パス変数リスト追加（他ファイルが参照する前に定義を明確化）
2. **SKILL.md** — Phase 0, 1B, 6 の変更（パス変数定義を使用）
3. **templates/phase2-test-document.md** — 独立した変更（perspective 参照の整理）
4. **templates/phase4-scoring.md** — 独立した変更（説明文追加）
5. **templates/phase6b-proven-techniques-update.md** — 独立した変更（基準明確化）

依存関係の検出方法:
- 改善1（phase1b-variant-generation.md でのパス変数リスト追加）の成果物を改善2（SKILL.md での変数使用）が参照するため、1 を先に実施
- 改善3, 4, 5 は独立しているため実装順序は任意

## 注意事項
- SKILL.md の Phase 1B における Glob 検索ロジックは、`audit-ce-*.md` と `audit-sa-*.md` の命名規則に依存します。agent_audit スキルがこの命名規則を変更した場合、SKILL.md も更新が必要です
- 外部パス参照（`.claude/skills/agent_bench/` → `.claude/skills/agent_bench_new/`）の変更後、perspectives/ ディレクトリ内のファイルが agent_bench_new に存在することを確認してください
- Phase 6 Step 2 の実行順序変更により、Step 2C（次アクション選択）は Step 2B（proven-techniques 更新）の完了を待つようになります。AskUserQuestion のタイミングが変わることに注意してください
- perspective 自動生成のスキップロジック追加により、既存の perspective-source.md が存在する場合は自動生成が実行されなくなります。再生成が必要な場合は手動でファイルを削除してください
