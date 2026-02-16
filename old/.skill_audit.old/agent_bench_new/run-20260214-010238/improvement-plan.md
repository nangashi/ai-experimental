# 改善計画: agent_bench_new

## 変更対象ファイル
| # | ファイル | 変更種別 | 変更概要 | 対応フィードバック |
|---|---------|---------|---------|------------------|
| 1 | SKILL.md | 修正 | Phase 0 Step 4 統合フィードバック処理の明確化 | I-1, I-4, I-6, I-9 |
| 2 | SKILL.md | 修正 | Phase 3 再試行ループの無限再帰防止 | I-10 |
| 3 | SKILL.md | 修正 | Phase 5 → Phase 6 のフィールド名変換処理明記 | I-3 |
| 4 | SKILL.md | 修正 | Phase 6 Step 2A/2B 失敗時のユーザー通知明確化 | I-8 |
| 5 | SKILL.md | 修正 | Phase 6 Step 2C 最終サマリの情報取得ステップ追加 | I-2 |
| 6 | SKILL.md | 修正 | Phase 6 Step 2C 再試行後の処理フロー明確化 | I-5 |
| 7 | SKILL.md | 修正 | Phase 0 Step 2, Phase 1B カタログ読込最適化 | I-16, I-14 |
| 8 | templates/phase1a-variant-generation.md | 修正 | プロンプトファイル上書き確認の一括化 | I-7 |
| 9 | templates/phase1b-variant-generation.md | 修正 | プロンプトファイル上書き確認の一括化、audit_findings_paths空判定明確化、カタログ読込最適化 | I-7, I-11, I-14 |
| 10 | templates/phase2-test-document.md | 修正 | knowledge.md参照範囲最適化 | I-15 |
| 11 | knowledge-init-template.md | 修正 | approach_catalog_path冗長読込の排除 | I-12 |
| 12 | templates/perspective/generate-perspective.md | 修正 | 統合フィードバック判定結果の返答追加 | I-13 |

## 各ファイルの変更詳細

### 1. SKILL.md（修正）
**対応フィードバック**: I-1, I-3, I-4, I-6, I-8, I-9, I-10, I-2, I-5, I-14, I-16

**変更内容**:

- **行102-124（Phase 0 Step 4-5）**: 統合フィードバック処理の明確化
  - 現在: 統合ファイル（perspective-critique-completeness.md）のフォーマットと判定条件が暗黙的
  - 改善: Step 4 の各批評サブエージェント完了後に、Step 4.5「統合フィードバック取得と判定」を追加
    ```markdown
    **Step 4.5: 統合フィードバック取得と判定**
    - Read で `.agent_bench/{agent_name}/perspective-critique-completeness.md` を読み込む
    - 統合済みフィードバックのフォーマット: 「## 統合フィードバック」セクション内の重大な問題と改善提案リストを確認
    - 再生成判定: 「重大な問題」セクションに1件以上の項目がある、または「改善提案」セクションに3件以上の項目がある場合 → 再生成必要
    - 再生成不要の場合は Step 6 へスキップ
    ```

- **行81-85（Phase 0 Step 4c）**: ヒアリング後の処理フロー明確化
  - 現在: user_requirements追記後の再判定フローが不明確
  - 改善: 「追記完了後、Step 3（perspective初期生成）に戻る」を明記

- **行110（Phase 0 Step 4）**: {target} 変数の未導出リスク対応
  - 現在: フォールバック判定失敗時に {target} が未導出
  - 改善: Step 4 冒頭に「{target} が未導出の場合はデフォルト値 'design' を使用する」を追加

- **行127-130（Phase 0 Step 6）**: 検証失敗時の再試行フロー明示化
  - 現在: 手動修正後の再試行フローが暗黙的
  - 改善: AskUserQuestion の選択肢 (1) に「修正完了後、Enterキーを押して再検証」を追記し、(1)選択時は Step 6 の検証処理に戻る旨を明記

- **行245（Phase 3 再試行処理）**: 再試行回数カウンタの明示化
  - 現在: 「再試行（1回のみ）」の制御が暗黙的
  - 改善: 「再試行回数カウンタ（初期値=0）を保持し、カウンタ < 1 の場合のみ再試行を実行する。再試行実行後にカウンタをインクリメントする」を明記

- **行88（Phase 0 Step 2）**: reference_perspective_path収集最適化
  - 現在: Glob で検索
  - 改善: 固定パスで参照に変更
    ```markdown
    - `.claude/skills/agent_bench_new/perspectives/design/security.md` を Read で確認
    - 見つかった場合は `{reference_perspective_path}` として使用（構造とフォーマットの参考用）
    - 見つからない場合は `{reference_perspective_path}` を空文字列とする
    ```

- **行336-337（Phase 6 Step 2A）**: Phase 5 → Phase 6 のフィールド名変換明記
  - 現在: recommended → recommended_name の変換が暗黙的
  - 改善: 変数渡しセクションに以下を追加
    ```markdown
    - `{recommended_name}`: Phase 5 サブエージェント返答の「recommended」フィールド値
    - `{judgment_reason}`: Phase 5 サブエージェント返答の「reason」フィールド値
    ```

- **行351-352（Phase 6 Step 2A/2B失敗時）**: ユーザー通知の明確化
  - 現在: 「警告を出力」の内容が不明
  - 改善: 「警告を出力: '{ステップ名}（knowledge.md更新/proven-techniques更新）に失敗しました。更新をスキップして次ステップに進みます。'」に変更

- **行353-364（Phase 6 Step 2C）**: 最終サマリの情報取得ステップ追加と再試行後の処理フロー明確化
  - 現在: 「効果のあったテクニック」の抽出処理が未記述、再試行後の失敗処理が未記述
  - 改善: Step 2C 冒頭に以下を追加
    ```markdown
    **C) 次アクション選択（親で実行）**

    1. A) と B) のサブエージェントタスクの完了を確認する（失敗時: 失敗ステップ名を出力し、該当更新をスキップ。再試行は行わず次アクション選択に進む）
    2. Read で `.agent_bench/{agent_name}/knowledge.md` を読み込み、「効果が確認された構造変化」テーブルから上位3件を抽出する
    3. `AskUserQuestion` でユーザーに確認する:
    ...
    ```
  - 最終サマリの「効果のあったテクニック」行に「{knowledge.md の「効果が確認された構造変化」上位3件}」を使用する旨を明記

- **行193-220（Phase 1B）**: カタログ読込最適化
  - 現在: approach-catalog.md を無条件に読込
  - 改善: Broad/Deep判定後の条件分岐を追加
    ```markdown
    2. knowledge.md の「バリエーションステータス」テーブルを使い、バリアントを選定する:
       - 累計ラウンド < 3 → Broad: UNTESTED カテゴリの基本バリエーション(a接尾辞)を選択
       - 累計ラウンド >= 3 かつ、4カテゴリ(S/C/N/M)のいずれかで基本バリエーション(a接尾辞)が全て UNTESTED → Broad（当該カテゴリの基本バリエーションを優先選択）
       - 累計ラウンド >= 3 かつ、全カテゴリに1つ以上の TESTED あり → Deep: 最も効果が高かった EFFECTIVE カテゴリを特定
    3. Broad/Deep 判定後に approach-catalog.md の読込みを判断する:
       - Broad モード: {approach_catalog_path} は読み込まない（バリエーションステータステーブルのみで判定可能）
       - Deep モード: {approach_catalog_path} を Read で読み込み、特定したカテゴリの UNTESTED バリエーションの詳細を確認
    ```
  - パス変数 `{selected_category}` を追加（Deep モード時のみ使用）

### 2. templates/phase1a-variant-generation.md（修正）
**対応フィードバック**: I-7

**変更内容**:

- **行3-10（プロンプトファイル上書き確認）**: 一括存在確認に変更
  - 現在: 手順3と手順8で個別にファイル存在確認を実行
  - 改善: 手順1の直後に手順1.5を追加
    ```markdown
    1.5. Glob で {prompts_dir}/v001-*.md を検索し、既存ファイルの有無を確認する。既存ファイルが1つ以上存在する場合、AskUserQuestion で以下の選択肢を提示する: (1) 全ての既存ファイルを上書きして続行、(2) 既存ファイルを削除してから再実行、(3) スキルを中断。(1)または(2)を選択した場合は該当操作を実行してから次の手順に進む
    ```
  - 手順3と手順8の個別確認処理を削除

### 3. templates/phase1b-variant-generation.md（修正）
**対応フィードバック**: I-7, I-11, I-14

**変更内容**:

- **行3-23（プロンプトファイル上書き確認）**: 一括存在確認に変更
  - 現在: 手順3と手順4で個別にファイル存在確認を実行
  - 改善: 手順1の直後に手順1.5を追加
    ```markdown
    1.5. 累計ラウンド数を knowledge.md から取得し、NNN = 累計ラウンド数 + 1 とする。Glob で {prompts_dir}/v{NNN}-*.md を検索し、既存ファイルの有無を確認する。既存ファイルが1つ以上存在する場合、AskUserQuestion で以下の選択肢を提示する: (1) 全ての既存ファイルを上書きして続行、(2) 既存ファイルを削除してから再実行、(3) スキルを中断。(1)または(2)を選択した場合は該当操作を実行してから次の手順に進む
    ```
  - 手順3と手順4の個別確認処理を削除

- **行8-13（audit_findings_paths空判定）**: 空文字列の場合の動作明確化
  - 現在: 「空でない場合」の処理のみ記述
  - 改善: 手順1に以下を追記
    ```markdown
    - {audit_findings_paths} が空文字列の場合: Read をスキップし、agent_audit の分析結果は参照しない
    ```

- **行19-20（カタログ読込最適化）**: Broad/Deep モード判定後の条件分岐追加
  - 現在: 手順2の説明に「approach-catalog.md の読込みを判断する」とあるが、指示が曖昧
  - 改善: SKILL.md の修正内容に合わせて、手順2を以下に置換
    ```markdown
    2. knowledge.md の「バリエーションステータス」テーブルを使い、バリアントを選定する:
       - 累計ラウンド < 3 → Broad: UNTESTED カテゴリの基本バリエーション(a接尾辞)を選択
       - 累計ラウンド >= 3 かつ、4カテゴリ(S/C/N/M)のいずれかで基本バリエーション(a接尾辞)が全て UNTESTED → Broad（当該カテゴリの基本バリエーションを優先選択）
       - 累計ラウンド >= 3 かつ、全カテゴリに1つ以上の TESTED あり → Deep: 最も効果が高かった EFFECTIVE カテゴリを特定する
    2.5. Broad/Deep 判定後に approach-catalog.md の読込みを判断する:
       - Broad モード: {approach_catalog_path} は読み込まない（バリエーションステータステーブルのみで判定可能）
       - Deep モード: {approach_catalog_path} を Read で読み込み、特定したカテゴリの UNTESTED バリエーションの詳細を確認する
    3. proven-techniques.md の「回避すべきアンチパターン」に該当するテクニックは選択しない
    4. ベースライン（比較用コピー）を保存する（手順番号を繰り下げ）
    ...
    ```

### 4. templates/phase2-test-document.md（修正）
**対応フィードバック**: I-15

**変更内容**:

- **行7（knowledge.md参照範囲）**: 全文読込から該当セクション渡しに変更
  - 現在: `{knowledge_path}` を Read で読み込む
  - 改善: SKILL.md 側で該当セクションを抽出して渡すように変更
    - SKILL.md Phase 2 の変数リストに以下を追加:
      ```markdown
      - `{test_history_summary}`: Phase 2 開始前に親が `.agent_bench/{agent_name}/knowledge.md` を Read で読み込み、「テスト対象文書履歴」セクションの内容を抽出して渡す。ファイルが存在しないまたはセクションが空の場合は空文字列を渡す
      ```
    - phase2-test-document.md の手順1から `{knowledge_path}` の読込指示を削除し、手順7に以下を追記:
      ```markdown
      7. 以下のフォーマットで問題サマリのみ返答する:
         - {test_history_summary} が空でない場合: 過去と異なるドメインを選択する
      ...
      ```

### 5. knowledge-init-template.md（修正）
**対応フィードバック**: I-12

**変更内容**:

- **行3（approach_catalog_path読込）**: カタログ全文読込から ID リスト渡しに変更
  - 現在: Read で {approach_catalog_path} を読み込む
  - 改善: SKILL.md 側で ID リストを抽出して渡すように変更
    - SKILL.md Phase 0 knowledge初期化の変数リストに以下を追加:
      ```markdown
      - `{variation_ids}`: Phase 0 で親が `.claude/skills/agent_bench_new/approach-catalog.md` を Read で読み込み、全バリエーション ID（S1a, S1b, ... M3c 等）をカンマ区切りで抽出して渡す
      ```
    - knowledge-init-template.md の手順1と手順3を以下に置換:
      ```markdown
      1. （削除: approach_catalog_path の読込不要）
      2. Read で {perspective_source_path} を読み込み、概要セクションからエージェントの目的を抽出する
      3. {variation_ids}（カンマ区切り）を分割し、バリエーション ID リストを取得する
      4. 以下のテンプレートの変数を置換し、バリエーションステータステーブルに全 ID を UNTESTED で記入して {knowledge_path} として Write で保存する
      5. 「knowledge.md 初期化完了（バリエーション数: {N}）」とだけ返答する
      ```

### 6. templates/perspective/generate-perspective.md（修正）
**対応フィードバック**: I-13

**変更内容**:

- **返答フォーマット（ファイル末尾）**: 再生成判定結果の追加
  - 現在: 4行サマリのみ返答（観点数、評価スコープ行数、ボーナス/ペナルティ指針数、問題バンク数）
  - 改善: 5行目に「regeneration_needed: {yes/no}」を追加
    ```markdown
    7. 以下のフォーマットで**5行のサマリのみ**返答する:

    perspectives: {N}
    scope_lines: {M}
    bonus_penalty_rules: {K}
    problem_bank_items: {L}
    regeneration_needed: {yes/no}
    ```
  - SKILL.md Phase 0 Step 5 に「サブエージェント返答の regeneration_needed フィールドを参照し、yes の場合のみ再生成を実行」を追加

## 新規作成ファイル

なし

## 削除推奨ファイル

なし

## 実装順序

1. **templates/perspective/generate-perspective.md** — Step 5 の再生成判定最適化の前提（返答フォーマット変更）
2. **knowledge-init-template.md** — SKILL.md Phase 0 での変数渡し変更の参照先
3. **templates/phase2-test-document.md** — SKILL.md Phase 2 での変数渡し変更の参照先
4. **templates/phase1a-variant-generation.md, templates/phase1b-variant-generation.md** — SKILL.md Phase 1A/1B での処理フロー変更の参照先
5. **SKILL.md** — 全ての参照先テンプレートの変更後に統合実施（Phase 0, 1A/1B, 2, 3, 5, 6 の複数箇所を一括修正）

依存関係の検出方法:
- テンプレートファイルの返答フォーマット変更（1）→ SKILL.md での返答解釈処理変更（5）→ 1が先
- テンプレートファイルへの変数渡し変更（5）→ テンプレート側の変数参照変更（2, 3, 4）→ 4が先（逆順）
- 複数テンプレートへの同一変更パターン（4）→ SKILL.md での統合処理変更（5）→ 4が先

## 注意事項

- Phase 0 Step 4.5 の統合フィードバック判定基準（重大な問題1件以上、または改善提案3件以上）は、templates/perspective/critic-completeness.md の統合フィードバック生成ロジックと整合させる必要がある
- Phase 1B のカタログ読込最適化により、Broad モード時のコンテキスト使用量が削減される（approach-catalog.md: 202行 → 0行）
- Phase 2 の knowledge.md 参照範囲最適化により、サブエージェントのコンテキスト使用量が削減される（knowledge.md 全文 → テスト対象文書履歴セクションのみ）
- knowledge-init-template.md のカタログ読込排除により、初期化サブエージェントのコンテキスト使用量が削減される（approach-catalog.md: 202行 → variation_ids: 約50文字）
- Phase 0 Step 6 の検証失敗時の再試行フローは、ユーザーが手動修正を完了するまで待機する（AskUserQuestion でブロック）
- Phase 3 の再試行回数カウンタは親コンテキストで保持し、再試行後に確実にインクリメントすること
