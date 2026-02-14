### 安定性レビュー結果

#### 重大な問題

- [参照整合性: 未定義変数]: [SKILL.md] [41行目] [`{user_requirements}`変数がPhase 0でメモリに保持されるとあるがパス変数リストに未定義] → [Phase 0のパス変数リストに`{user_requirements}: Phase 0でヒアリングした要件テキスト（エージェント定義が不足時のみ設定）`を追加する] [impact: high] [effort: low]

- [出力フォーマット決定性: 返答行数未指定]: [templates/phase1a-variant-generation.md] [9行目] [「以下のフォーマットで結果サマリのみ返答する」とあるが、実際の行数カウントは不定。構造分析テーブルの行数が可変] → [返答フォーマットを「## エージェント定義（2行）、## 構造分析結果（テーブル6行固定）、## 生成したバリアント（2バリアント×4行=8行）の合計16-20行で返答する」と明示する] [impact: medium] [effort: low]

- [出力フォーマット決定性: 返答行数未指定]: [templates/phase1b-variant-generation.md] [21行目] [「以下のフォーマットで結果サマリのみ返答する」とあるが、Audit統合候補セクションの有無と行数が可変] → [返答フォーマットを「## 選定プロセス（2行）、## 生成したバリアント（2バリアント×5行=10行）、## Audit統合候補（あればテーブルヘッダ1行+最大5件=最大6行、なければ省略）の合計12-18行で返答する」と明示する] [impact: medium] [effort: low]

- [参照整合性: ファイルパス不在]: [SKILL.md] [224行目] [`templates/phase3-error-handling.md`を参照しているが、これは手順書でありサブエージェントテンプレートではない。親が直接Readして分岐ロジックを実行すべき] → [Phase 3のワークフローを「全サブエージェント完了後、Read で templates/phase3-error-handling.md を読み込み、その内容の分岐ロジックに従ってエラーハンドリングを実行する（親が実行）」と明示する] [impact: high] [effort: medium]

- [冪等性: ファイル上書き確認不足]: [templates/phase6a-knowledge-update.md] [6行目] [knowledge.mdの更新処理でWrite保存するが、更新前のRead→Edit パターンではなくWrite全体置換。並行実行時の競合リスクあり] → [「Read→Editパターンで各セクションを個別に更新する」または「更新前にknowledge.mdのバックアップを作成する」を明示する] [impact: medium] [effort: high]

#### 改善提案

- [指示の具体性: 曖昧表現]: [SKILL.md] [40行目] [「ファイルが実質空（行数 < 10）または必要セクション不足の場合」の「必要セクション」が具体的に列挙されていない] → [「必要セクション不足（目的・入力型・出力型のいずれかが欠落）の場合」と具体化する] [impact: low] [effort: low]

- [出力フォーマット決定性: サブエージェント返答形式]: [templates/phase2-test-document.md] [15-26行目] [テスト文書サマリのテーブル行数が「埋め込み問題の数」に依存し可変。親が行数を予測できない] → [「埋め込み問題一覧は最大10件（超過する場合は重要度順）、ボーナス問題リストは最大5件」と上限を明示する] [impact: medium] [effort: low]

- [条件分岐の完全性: else節欠落]: [SKILL.md] [161-164行目] [`.agent_audit/{agent_name}/audit-*.md`を検索し変数に渡すとあるが、「見つからない場合は空」の処理がテンプレート側に委譲され、SKILL.md側のフロー記述がない] → [「見つからない場合は空文字列を渡す。テンプレート側で空チェックを実施する」と明示する] [impact: low] [effort: low]

- [参照整合性: プレースホルダ不一致]: [templates/phase0-perspective-generation.md] [11行目] [`{user_requirements}`がヒアリング結果を指すが、SKILL.md 41行目では「メモリに保持する」とあり、パス変数として渡す方式と矛盾] → [SKILL.md Phase 0のパス変数リストに`{user_requirements}`を追加し、「Phase 0でヒアリングした要件テキスト（存在する場合のみ）」と記載する] [impact: medium] [effort: low]

- [冪等性: 再実行時のファイル重複]: [SKILL.md] [118-121行目] [Phase 1A実行前に既存ファイル確認→AskUserQuestionで上書き/スキップ選択。スキップ時はPhase 2へ進むが、既存ファイルの整合性検証（バージョン番号・メタデータ）がない] → [「スキップ選択時は、既存プロンプトファイルの先頭コメントから Variation ID を読み込み、knowledge.mdのバリエーションステータスと整合性を確認する」ステップを追加する] [impact: medium] [effort: medium]

- [指示の具体性: 数値基準なし]: [templates/phase6b-proven-techniques-update.md] [35行目] [「最も類似する2エントリをマージ」とあるが、類似度判定の基準が不明確] → [「Variation ID のカテゴリ（S/C/N/M）が同一かつ、テクニック概要に50%以上の単語重複がある場合を類似とみなす」と具体化する] [impact: low] [effort: low]

- [出力フォーマット決定性: 条件付き出力]: [templates/perspective/critic-completeness.md] [94-104行目] [返答フォーマットに「Missing Element Detection Evaluation」テーブルが「exactly 5-8 rows」と指定されているが、他の批評テンプレート（clarity, effectiveness, generality）は行数制限なし。統一されていない] → [全批評テンプレートで出力行数の上限を統一する（例: 各セクション最大10件）] [impact: low] [effort: medium]

#### 良い点

- [Phase 5のサブエージェント返答が7行固定フォーマット]: SKILL.md 272行目でPhase 5の返答形式が`recommended`, `reason`, `convergence`, `scores`, `variants`, `deploy_info`, `user_summary`の7行固定と明示されており、親エージェントでのパース処理が安定する

- [パス変数の命名規則が一貫]: 全テンプレートで`{variable_name}`形式のプレースホルダが使用され、SKILL.md各Phaseで「パス変数:」セクションとして明示的に列挙されている。変数名も`_path`/`_save_path`の接尾辞で役割が明確

- [エラーハンドリングの分岐が詳細]: templates/phase3-error-handling.mdで全成功/ベースライン全失敗/部分失敗/バリアント全失敗の4分岐が明示され、各分岐の条件・処理・次ステップが具体的に記載されている
