## 重大な問題

### C-1: Phase 5 から Phase 6 への Variation ID 情報欠落 [effectiveness]
- 対象: Phase 5 → Phase 6 のデータフロー
- 内容: Phase 5 のサブエージェントが返答する7行サマリには「variants」行に Variation ID が含まれると SKILL.md L296 で言及されているが、phase5-analysis-report.md テンプレート L19 では Variation ID を読み取る必要があるものの、パス変数に {prompts_dir} が含まれておらず、プロンプトファイルへのアクセス手段が与えられていない。Phase 6 Step 2A でも同様に {prompts_dir} が渡されておらず、phase6a-knowledge-update.md L12 で期待される Variation ID の Status 更新ができない。
- 推奨: phase5-analysis-report.md と phase6a-knowledge-update.md のパス変数に {prompts_dir} を追加し、サブエージェントがプロンプトファイルの Benchmark Metadata コメントから Variation ID を読み取れるようにする。
- impact: high, effort: medium

### C-2: Phase 0 perspective 自動生成 Step 5 の再生成処理フロー欠落 [effectiveness]
- 対象: Phase 0 Step 5
- 内容: SKILL.md L112 では「ユーザーが承認した場合、フィードバックを {user_requirements} に追記し、Step 3 と同じパターンで perspective を再生成する（1回のみ）」と記載されているが、Step 3 への再実行プロセスが明示的に記述されていない。特に、4件の批評結果をどのように {user_requirements} に統合するかの手順が欠落している。批評結果は SendMessage で送信されるため親コンテキストに保持されているが、フィードバック統合の具体的な処理手順（4批評の要約方法、{user_requirements} への追記形式）がない。
- 推奨: SKILL.md L112 に「4批評の重大な問題と改善提案を箇条書きで抽出し、{user_requirements} に追記する」処理を明示的に記述する。または批評結果を一時ファイルに保存させ、ファイル経由で再生成時に参照する設計に変更する。
- impact: high, effort: low

### C-3: agent_path 上書き時のガード欠落 [ux]
- 対象: Phase 6 Step 1
- 内容: agent_path のデプロイ時に、既存ファイルの上書き前にユーザー確認が配置されていない。ベースライン以外を選択した時点で上書きが確定しており、ファイル内容のプレビューや差分確認なしに実行される。
- 推奨: デプロイ直前に差分プレビューと最終確認を追加する。または phase6a-deploy.md に「既存ファイルと推奨プロンプトの差分を提示し、AskUserQuestion で確認する」処理を明記する。
- impact: high, effort: low

## 改善提案

### I-1: 入力バリデーション不足（空ファイル・不足判定基準） [effectiveness]
- 対象: Phase 0
- 内容: SKILL.md L41 で「引数から agent_path を取得する（未指定の場合は AskUserQuestion で確認）」と記載されているが、agent_path が指定されたもののファイルが存在しない場合の処理は L42 で「読み込み失敗時はエラー出力して終了」とあるのみ。しかし、ファイルが存在しても空ファイルである場合や、frontmatter のみで本文がない場合の処理が記述されていない。Phase 0 Step 1（要件抽出）で「エージェント定義が実質空または不足がある場合」の判定基準が明示されておらず、AskUserQuestion によるヒアリング発動条件が不明確。
- 推奨: Phase 0 に「agent_path が空ファイルまたは frontmatter のみの場合、新規作成モードとみなして AskUserQuestion でヒアリング開始」の分岐を追加する。
- impact: medium, effort: low

### I-2: Phase 3 の収束判定達成済み判定の参照手順欠如 [effectiveness]
- 対象: Phase 3
- 内容: SKILL.md L224-225 で「収束判定が達成済みの場合（前回ラウンドの Phase 5 で判定）: 各プロンプトを1回のみ実行」と記載されているが、収束判定達成済みかどうかを親がどのように判定するかの具体的手順（前回レポートまたは knowledge.md のどのフィールドを参照するか）が記述されていない。Phase 5 の返答には「convergence」行があるが、これが親コンテキストに保持され次ラウンドで参照可能かが不明。
- 推奨: SKILL.md L224 に「knowledge.md の最新レポートの convergence フィールドを参照し、達成済みの場合は1回実行」の手順を明記する。
- impact: medium, effort: low

### I-3: Phase 0 perspective 批評結果の集約処理が暗黙的依存 [architecture]
- 対象: Phase 0 Step 4
- 内容: 4並列の批評サブエージェントが SendMessage で報告するが、親が受け取った批評結果をどうやって集約するのか（ファイル経由か親のコンテキスト内か）の記述がない。批評結果をファイルに保存させて親がファイルから読み込む明示的なフローに変更すべき。
- 推奨: 批評サブエージェントに一時ファイルへの批評結果保存を指示し、親が4ファイルを読み込んで集約する設計に変更する。
- impact: medium, effort: medium

### I-4: Phase 4 の result_run2_path 不在時の処理フロー欠落 [stability, architecture]
- 対象: Phase 3 → Phase 4
- 内容: Run が1回のみのプロンプト（収束時）の SD 処理が曖昧。「Run が1回のみのプロンプトは SD = N/A とする」と記載されているが、Phase 4 採点時に result_run2_path が存在しない場合の処理が phase4-scoring.md に記述されていない。result_run2_path の Read 失敗時の処理フローをテンプレートに追記すべき。
- 推奨: テンプレート phase4-scoring.md に「result_run2_path が存在しない場合（収束時）は Run1 のみ採点し、SD = N/A とする」の条件分岐を追加する。
- impact: medium, effort: medium

### I-5: Phase 2 テスト文書生成でガイドファイル全文を毎回 Read [efficiency]
- 対象: templates/phase2-test-document.md
- 内容: line 4 で {test_document_guide_path} (254行) を読み込む。しかし、実際に使用する情報は入力型判定基準（セクション1）、文書構成（セクション2）、埋め込みガイドライン（セクション3）、正解キーフォーマット（セクション4）の4セクションのみ。品質チェックリスト（セクション5）、ラウンド間多様性（セクション6）は親エージェントまたはサブエージェント自身が直接参照可能。ガイドファイルの構造を見直し、サブエージェント用セクションと親用セクションを分離することで、サブエージェントのコンテキスト節約が可能。
- 推奨: test-document-guide.md をサブエージェント用（セクション1-4）と親用（セクション5-6）に分割し、phase2-test-document.md では前者のみ参照する。
- impact: medium, effort: medium

### I-6: Phase 5 でサブエージェントが knowledge.md 全文を Read [efficiency]
- 対象: templates/phase5-analysis-report.md
- 内容: line 5 で {knowledge_path} を読み込んでいるが、使用箇所は不明（レポート生成と推奨判定には過去スコアデータが必要だが、親が提供していない可能性がある）。knowledge.md の必要セクション（ラウンド別スコア推移）のみを抽出して渡す、または scoring_file_paths から過去スコアを推測する設計に変更することで、knowledge.md 全文の Read を回避可能。
- 推奨: phase5-analysis-report.md のパス変数に {past_scores} を追加し、親が knowledge.md から過去スコアテーブルを抽出してテキスト変数で渡す。
- impact: medium, effort: medium

---
注: 改善提案を 2 件省略しました（合計 8 件中上位 6 件を表示）。省略された項目は次回実行で検出されます。
