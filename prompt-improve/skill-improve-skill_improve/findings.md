## 重大な問題

### C-1: [曖昧表現] SKILL.md L39
- 観点: stability
- 対象: SKILL.md Phase 0
- "SKILL.md を含むスキルディレクトリ" → SKILL.md が存在することの具体的な確認基準が不明（ディレクトリとして含まれていれば良いのか、ファイルパスとして .../SKILL.md で終わる必要があるのか）

### C-2: [曖昧表現] analyze-skill-structure.md L14
- 観点: stability
- 対象: templates/analyze-skill-structure.md
- "20ファイル超の場合は SKILL.md + templates/ ディレクトリ内を優先し、残りは先頭5ファイルのみ読み込む" → "先頭5ファイル" の並び順が未定義（Glob の結果は保証された順序を持たない）

### C-3: [暗黙的条件] SKILL.md L103-104
- 観点: stability
- 対象: SKILL.md Phase 2
- 成功数が3件以上なら続行と記述されているが、成功数が「ちょうど3件」の場合のフローが不明瞭（103行目の「3件以上」と104行目の「2件以下」の間に隙間がある）

### C-4: [条件分岐の不完全性] SKILL.md L199-202
- 観点: stability
- 対象: SKILL.md Phase 6
- retry_count が 0 または 1 の場合のみ処理が定義されているが、retry_count が 2 以上の場合の処理が未定義（ユーザーが追加修正を複数回選択した場合）

### C-5: [フォーマット決定性の欠如] SKILL.md L144
- 観点: stability
- 対象: SKILL.md Phase 3
- Fast mode でのコンフリクト提示フォーマット（選択肢、トレードオフ情報の構造）が未定義

## 改善提案

### I-1: [参照整合性] SKILL.md L55 相対パス表記
- 観点: stability
- 対象: SKILL.md Phase 1
- `.claude/skills/skill_improve/templates/analyze-skill-structure.md` の参照が相対パス表記。サブエージェント実行環境での解決を確実にするため `{skill_path}` を使った絶対パス構築にすべき

### I-2: [冪等性] Phase 0 work_dir クリーンアップ不在
- 観点: stability
- 対象: SKILL.md Phase 0
- work_dir の存在確認や既存ファイル（analysis.md, findings.md 等）のクリーンアップ処理がない。再実行時に前回の結果が残っていると Phase 3 等で誤読する可能性

### I-3: [曖昧表現] apply-improvements.md L19 "50%以上"
- 観点: stability
- 対象: templates/apply-improvements.md
- "変更が広範囲に及ぶ場合（ファイルの50%以上を書き換える場合）は Write で全体を書き換える" → "50%以上" を「変更対象行数 / 総行数 > 0.5」等と明示すべき

### I-4: [曖昧表現] consolidate-findings.md L51 依存関係
- 観点: stability
- 対象: templates/consolidate-findings.md
- "依存関係がある場合は依存元を先に実施する" → 依存関係の検出方法を明示（例: 「改善Aの成果物を改善Bが参照する場合」）

### I-5: [暗黙的条件] SKILL.md L146-148 問題0件判定
- 観点: stability
- 対象: SKILL.md Phase 3
- 良い点のみが存在する場合とレビューファイル自体が空の場合の区別がない

### I-6: [出力フォーマット決定性] verify-improvements.md L70
- 観点: stability
- 対象: templates/verify-improvements.md
- details フィールドの列挙フォーマット（箇条書き？カンマ区切り？）が未定義

### I-7: [条件分岐の不完全性] SKILL.md L174 「修正要望あり」
- 観点: stability
- 対象: SKILL.md Phase 4
- 「修正要望あり」選択時の処理フロー（再度 Phase 4 に戻る？直接 improvement-plan.md を編集？）が未定義

### I-8: [Phase 3統合処理の非効率性+テンプレート外部化]
- 観点: efficiency + architecture
- 対象: SKILL.md Phase 3
- Phase 3では4つのreview-*.mdを親が直接Readしてフィードバック分類・コンフリクト検出を実行。約35行の密な処理ロジックをサブエージェント+テンプレートに委譲推奨（親コンテキスト-30行削減）

### I-9: [Phase 6検証レポートの二重読み込み]
- 観点: efficiency
- 対象: SKILL.md Phase 6
- サブエージェント返答（5行サマリ）で十分。verification.md の Read は NEEDS_ATTENTION 時のみに制限可能

### I-10: [Phase 4改善計画のサマリ先行出力] (コンフリクト解決済み: UX優先)
- 観点: efficiency + ux
- 対象: SKILL.md Phase 4
- サマリを先行出力してから本文表示。改善計画の概要をまず提示し、その後に全文を表示する方式

### I-11: [リトライパターン重複+全フェーズ化]
- 観点: efficiency + architecture
- 対象: SKILL.md Phase 1/4/5/6
- 同一のエラーハンドリングパターンが4箇所で重複。共通処理セクションとして冒頭に記載し、retry_count 管理を全サブエージェントに拡張

### I-12: [テンプレート読み込み指示の冗長性]
- 観点: efficiency
- 対象: SKILL.md 全フェーズ
- 「Read template + follow instructions + path variables」パターンが7回繰り返し。定型文を共通セクションに記載

### I-13: [Phase 2レビューアー起動の記述冗長性]
- 観点: efficiency
- 対象: SKILL.md Phase 2
- 4つのレビューアーの同一プロンプトフォーマットをテーブル形式に統合

### I-14: [Phase 0 モード選択時の情報不足]
- 観点: ux
- 対象: SKILL.md Phase 0
- Fast mode がスキップする具体的な確認項目を明示

### I-15: [失敗時のコンテキスト不足]
- 観点: ux
- 対象: SKILL.md Phase 1/4/5/6
- エラー原因を AskUserQuestion の質問文に含める

### I-16: [Phase 2 部分完了時の判断材料不足]
- 観点: ux
- 対象: SKILL.md Phase 2
- 失敗レビューアー名を AskUserQuestion の質問文に含める

### I-17: [Phase 6 再試行時のコンテキスト不明]
- 観点: ux
- 対象: SKILL.md Phase 6
- Phase 5 へ戻る際に AskUserQuestion で追加修正の方針を確認

### I-18: [Phase 7 完了サマリの欠落情報]
- 観点: ux
- 対象: SKILL.md Phase 7
- verdict: NEEDS_ATTENTION の場合は details を抜粋出力

### I-19: [Phase 5 モデル指定]
- 観点: architecture
- 対象: SKILL.md Phase 5
- Phase 5（改善適用）は Edit/Write の機械的実行であり haiku で十分な可能性

### I-20: [Phase 3 コンフリクト解決の自己検証不在]
- 観点: architecture
- 対象: SKILL.md Phase 3
- findings.md の妥当性検証が不在。簡易レビュー（haiku）で論理矛盾や解決漏れを検出

### I-21: [ナレッジ蓄積の欠如]
- 観点: architecture
- 対象: 新規追加
- 反復改善のラウンド間で知見（適用パターン、失敗事例、拒否提案）を蓄積する仕組みがない

### I-22: [quality-criteria.md 参照パスの明示化]
- 観点: architecture
- 対象: SKILL.md
- quality-criteria.md の参照パスが暗黙的に `.claude/skills/skill_improve/` を前提。パス変数化を推奨
