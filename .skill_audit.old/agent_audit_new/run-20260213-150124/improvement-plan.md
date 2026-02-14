# 改善計画: agent_bench_new

## 変更対象ファイル
| # | ファイル | 変更種別 | 変更概要 | 対応フィードバック |
|---|---------|---------|---------|------------------|
| 1 | SKILL.md | 修正 | Phase 0: user_requirements を Phase 1A に明示的に渡す処理を追加 | I-1: Phase 0 エージェント定義ヒアリング |
| 2 | SKILL.md | 修正 | Phase 6 Step 1: デプロイキャンセル時の状態変数定義を追加 | I-2: Phase 6 Step 1 デプロイキャンセル時の状態変数 |
| 3 | SKILL.md | 修正 | Phase 1B: approach-catalog の読み込み条件（Deep モード時のみ）を明記 | I-3: Phase 1B の approach-catalog 読み込み条件 |
| 4 | templates/phase1b-variant-generation.md | 修正 | approach-catalog 読み込み条件の明確化 | I-3: Phase 1B の approach-catalog 読み込み条件 |
| 5 | SKILL.md | 修正 | Phase 6 Step 1: knowledge.md の重複 Read を削除 | I-4: Phase 6 Step 2: knowledge.md の二重 Read |
| 6 | templates/phase5-analysis-report.md | 修正 | scoring-rubric の推奨判定基準をテンプレート内に埋め込み | I-5: Phase 5: scoring-rubric の重複 Read |
| 7 | SKILL.md | 修正 | Phase 0 批評: SendMessage パース処理を明示化、ファイル保存方式に変更 | I-6: Phase 0 perspective 批評: SendMessage 返答のパース処理 |
| 8 | templates/perspective/critic-*.md | 修正 | 重大問題件数のみ返答、詳細はファイル保存に変更 | I-6: Phase 0 perspective 批評: SendMessage 返答のパース処理 |
| 9 | templates/phase3-evaluation.md | 新規作成 | Phase 3 評価実行インライン指示を外部化 | I-7: Phase 3 評価実行のインライン指示 |
| 10 | SKILL.md | 修正 | Phase 3: 外部化したテンプレートを参照 | I-7: Phase 3 評価実行のインライン指示 |
| 11 | SKILL.md | 修正 | Phase 0 Step 6: perspective.md 生成タイミングを明記 | I-8: 欠落ステップ: perspective.md の生成遅延 |
| 12 | SKILL.md | 修正 | Phase 0 Step 1: ヒアリング返答フォーマットを明示 | I-9: 出力フォーマット決定性: Phase 0 Step 1 の要件ヒアリング返答フォーマット |

## 各ファイルの変更詳細

### 1. SKILL.md（修正）
**対応フィードバック**: I-1: Phase 0 エージェント定義ヒアリングで収集した user_requirements が perspective 自動生成にのみ利用され Phase 1A に渡されない分岐がある

**変更内容**:
- Phase 0 自動生成フロー Step 1 (行96-99): 「ヒアリング後、`{user_requirements}` に追加する」→「ヒアリング後、`{user_requirements}` に追加し、後続の Phase 1A に渡すために保持する」
- Phase 0 自動生成スキップ時の処理追記（行82-89の分岐後に追加）: 「既存ファイルを使用し、自動生成をスキップする」→「既存ファイルを使用し、自動生成をスキップする。ただし `agent_exists = false` の場合、`{user_requirements}` が空ならば AskUserQuestion で要件をヒアリングし Phase 1A に渡す」
- Phase 1A のパス変数リスト（行207-216）に `{user_requirements}` が明記されているため、処理説明を追加

### 2. SKILL.md（修正）
**対応フィードバック**: I-2: Phase 6 Step 1 デプロイキャンセル時の状態変数が未定義

**変更内容**:
- Phase 6 Step 1 の「キャンセル」分岐（行387）: 「デプロイをスキップし、ステップ2（ナレッジ更新）に進む」→「デプロイをスキップし、`{deployed_prompt_name}` を `None`（デプロイなし）に設定し、ステップ2に進む」
- Phase 6 Step 2 の最終サマリ（行420以降）: `{deployed_prompt_name}` が `None` の場合は「変更なし（デプロイスキップ）」と表示する処理を追記

### 3. SKILL.md（修正）
**対応フィードバック**: I-3: Phase 1B の approach-catalog 読み込み条件と SKILL.md の記述の不一致

**変更内容**:
- Phase 1B のパス変数リスト（行227-237）: `{approach_catalog_path}` の行に「（Deep モード時のみサブエージェントが Read。Broad モード時は未使用）」の注記を追加
- Phase 1B のバリアント選定処理説明（行240-243）に「Broad モード時は approach-catalog を参照せず、knowledge.md のステータステーブルから基本バリエーション名のみで生成可能」と明記

### 4. templates/phase1b-variant-generation.md（修正）
**対応フィードバック**: I-3: Phase 1B の approach-catalog 読み込み条件と SKILL.md の記述の不一致

**変更内容**:
- 行25: 「Deep モードでバリエーションの詳細が必要な場合のみ {approach_catalog_path} を Read で読み込む」→「Broad モード時は approach-catalog を Read しない。Deep モード時のみ {approach_catalog_path} を Read で読み込み、バリエーションの詳細（構造変更・例文）を参照する」

### 5. SKILL.md（修正）
**対応フィードバック**: I-4: Phase 6 Step 2: knowledge.md の二重 Read

**変更内容**:
- Phase 6 Step 1（行356）: 「`.agent_bench/{agent_name}/knowledge.md` を Read で読み込み、「ラウンド別スコア推移」セクションから過去ラウンドのスコアデータを取得する」→ 削除
- Phase 6 Step 1 の AskUserQuestion 提示内容（行357-372）に「ラウンド別性能推移テーブル」が含まれているため、これを Phase 6A サブエージェント完了後に取得するよう変更:
  - Step 1 では Phase 5 の7行サマリのみでプロンプト選択 UI を構成
  - Step 2A 完了後に knowledge.md から性能推移データを Read し、最終サマリで表示

### 6. templates/phase5-analysis-report.md（修正）
**対応フィードバック**: I-5: Phase 5: scoring-rubric の重複 Read

**変更内容**:
- 行3-4: 「Read で {scoring_rubric_path} （採点基準 — 推奨判定基準・収束判定を含む）を読み込む」→ 削除し、推奨判定基準を以下のように埋め込む:
  - **推奨判定基準**:
    - ベースライン vs バリアント: バリアントが Mean で +0.5pt 以上 かつ SD がベースライン以下なら推奨
    - バリアント同士: Mean が高い方を推奨（同点なら SD が小さい方）
    - SD = N/A の場合: Mean のみで判定
  - **収束判定基準**:
    - 3ラウンド連続で全バリアントがベースライン +0.3pt 以内 → 「収束の可能性あり」
    - それ以外 → 「継続推奨」
- 行2の「scoring_rubric.md」読み込み指示を削除し、上記基準を直接記載

### 7. SKILL.md（修正）
**対応フィードバック**: I-6: Phase 0 perspective 批評: SendMessage 返答のパース処理

**変更内容**:
- Phase 0 Step 4（行116-133）: 4並列批評エージェントへの指示を変更
  - 「SendMessage で報告する」→「詳細フィードバックを `.agent_bench/{agent_name}/perspective-feedback-{批評観点}.md` に保存し、SendMessage では「重大な問題: {N}件」とだけ返答する」
- Phase 0 Step 5（行134-141）: フィードバック統合処理を変更
  - 「各批評メッセージから「## 重大な問題」セクションを抽出」→「各 SendMessage から重大問題件数を取得。合計が1件以上の場合、保存された4ファイルを Read してフィードバックを統合」
  - コンテキスト節約量: 親メッセージ内容の保持が不要になり、200-400行削減

### 8. templates/perspective/critic-*.md（修正）
**対応フィードバック**: I-6: Phase 0 perspective 批評: SendMessage 返答のパース処理

**変更内容**:
- critic-effectiveness.md, critic-clarity.md, critic-completeness.md, critic-generality.md の4ファイル全てに以下の変更を適用:
  - 末尾の返答指示: 「SendMessage で報告する」→「詳細フィードバック（## 重大な問題、## 改善提案セクションを含む）を Write で `{feedback_save_path}` に保存し、SendMessage では以下の1行のみ返答する: `重大な問題: {N}件`」
  - パス変数に `{feedback_save_path}` を追加（SKILL.md 側で `.agent_bench/{agent_name}/perspective-feedback-{観点名}.md` として渡す）

### 9. templates/phase3-evaluation.md（新規作成）
**対応フィードバック**: I-7: Phase 3 評価実行のインライン指示（11行）

**変更内容**:
- 新規ファイルを作成し、以下の内容を記述:

```markdown
## パス変数
- `{prompt_path}`: 評価対象プロンプトの絶対パス
- `{test_doc_path}`: テスト入力文書の絶対パス
- `{result_path}`: 評価結果の保存先パス

以下の手順でタスクを実行してください:

1. Read で {prompt_path} を読み込み、その内容に従ってタスクを実行してください
2. Read で {test_doc_path} を読み込み、処理対象としてください
3. 処理結果を Write で {result_path} に保存してください
4. 最後に「保存完了: {result_path}」とだけ返答してください
```

### 10. SKILL.md（修正）
**対応フィードバック**: I-7: Phase 3 評価実行のインライン指示（11行）

**変更内容**:
- Phase 3 評価実行サブエージェント指示（行280-289）: インラインブロックを削除し、以下に置換:

```
各サブエージェントへの指示:

`.claude/skills/agent_bench_new/templates/phase3-evaluation.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{prompt_path}`: 評価対象プロンプトの絶対パス
- `{test_doc_path}`: `.agent_bench/{agent_name}/test-document-round-{NNN}.md`
- `{result_path}`: `.agent_bench/{agent_name}/results/v{NNN}-{name}-run{R}.md`
```

### 11. SKILL.md（修正）
**対応フィードバック**: I-8: 欠落ステップ: perspective.md の生成遅延が明記されていない

**変更内容**:
- Phase 0 Step 6（行143-146）: 検証成功後の処理を追加
  - 「検証成功 → perspective 解決完了」→「検証成功 → perspective-source.md から「## 問題バンク」セクション以降を除いた内容を `.agent_bench/{agent_name}/perspective.md` に Write で保存（Phase 4 採点時のバイアス防止のため問題バンクを含めない作業コピー）。perspective 解決完了」
- 行75-77 の既存 perspective 検出時の処理と同一内容のため、重複記述となるが自動生成フローの完全性のため明記

### 12. SKILL.md（修正）
**対応フィードバック**: I-9: 出力フォーマット決定性: Phase 0 Step 1 の要件ヒアリング返答フォーマットが未定義

**変更内容**:
- Phase 0 Step 1（行96-99）: ヒアリング後の処理に返答フォーマット指定を追加
  - 「AskUserQuestion で以下をヒアリングし `{user_requirements}` に追加する」→「AskUserQuestion で以下をヒアリングし、箇条書き形式（各項目を `- ` で開始）で構造化して `{user_requirements}` に追加する。複数項目がある場合は各項目を改行で区切る」

## 新規作成ファイル
| ファイル | 目的 | 対応フィードバック |
|---------|------|------------------|
| templates/phase3-evaluation.md | Phase 3 評価実行の11行インライン指示を外部化 | I-7: Phase 3 評価実行のインライン指示 |

## 削除推奨ファイル
なし

## 実装順序
1. **templates/phase3-evaluation.md（新規作成）** — Phase 3 の外部化テンプレート作成（SKILL.md 変更の前提）
2. **templates/perspective/critic-*.md（4ファイル修正）** — 批評エージェントの返答フォーマット変更（SKILL.md Phase 0 変更の前提）
3. **templates/phase1b-variant-generation.md（修正）** — approach-catalog 読み込み条件の明確化（独立変更）
4. **templates/phase5-analysis-report.md（修正）** — 推奨判定基準の埋め込み（独立変更）
5. **SKILL.md（修正）** — 全フィードバックに対応する変更を一括適用（上記1-4の成果物を参照）

依存関係の検出方法:
- テンプレート新規作成（1）→ SKILL.md でのテンプレート参照追加（5）→ 1が先
- テンプレート変更（2-4）→ SKILL.md での呼び出し方変更（5）→ 2-4が先（並列実施可能）

## 注意事項
- Phase 0 の批評フィードバックファイル保存により、`.agent_bench/{agent_name}/perspective-feedback-*.md` が新たに生成されるようになる（一時ファイル、再生成フロー完了後は削除可能）
- Phase 6 Step 1 の knowledge.md Read 削除により、ラウンド別性能推移テーブルの表示タイミングが Step 2A 完了後に変更される（ユーザー体験への影響を確認）
- templates/phase5-analysis-report.md への推奨判定基準の埋め込みにより、scoring-rubric.md の該当セクション変更時は phase5 テンプレートも同期更新が必要（メンテナンス負債）
- Phase 3 評価実行の外部化により、テンプレートファイル数が12個→13個に増加
