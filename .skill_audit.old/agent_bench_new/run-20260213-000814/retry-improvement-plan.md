# 改善計画: agent_bench_new

## 変更対象ファイル
| # | ファイル | 変更種別 | 変更概要 | 対応フィードバック |
|---|---------|---------|---------|------------------|
| 1 | SKILL.md | 修正 | phase3-error-handling.md のパス参照を修正 | R-1: phase3-error-handling.md 参照欠如 |
| 2 | templates/phase0-perspective-generation.md | 修正 | 簡略版自動生成パスの追加 | I-9: 4並列批評の複雑性 |
| 3 | templates/phase0-perspective-generation-simple.md | 新規作成 | 簡略版 perspective 自動生成テンプレート | I-9: 4並列批評の複雑性 |

## 各ファイルの変更詳細

### 1. SKILL.md（修正）
**対応フィードバック**: R-1: リグレッション: phase3-error-handling.md 参照欠如

**変更内容**:
- 224行目: テンプレートパス参照を絶対パスから相対パスに修正
  - 現在: `全サブエージェント完了後、.claude/skills/agent_bench_new/templates/phase3-error-handling.md を Read で読み込み、その内容に従ってエラーハンドリングを実行する`
  - 改善後: `全サブエージェント完了後、templates/phase3-error-handling.md を Read で読み込み、その内容に従ってエラーハンドリングを実行する`

**理由**: SKILL.md 内の他のテンプレート参照はすべて `templates/` からの相対パスを使用している（例: phase1a-variant-generation.md, phase2-test-document.md 等）。phase3-error-handling.md だけが絶対パス形式で記述されており、一貫性がない。相対パスに統一することで、スキル全体のポータビリティと保守性が向上する。

### 2. templates/phase0-perspective-generation.md（修正）
**対応フィードバック**: I-9: phase0-perspective-generation における4並列批評の複雑性

**変更内容**:
- Step 3 の前に分岐ロジックを追加:
  - 現在: 常に generate-perspective.md を使用して初期生成
  - 改善後: AskUserQuestion で生成モード選択（標準/簡略）→ 簡略モード選択時は phase0-perspective-generation-simple.md を使用

具体的な追加内容（Step 2 と Step 3 の間に挿入）:

```markdown
**Step 2.5: 生成モード選択**
AskUserQuestion で以下を確認する:
- 質問: "perspective 自動生成のモードを選択してください"
- 選択肢:
  - **標準（4並列批評 + 再生成）**: 高品質な perspective を生成（推奨、初回実行時）
  - **簡略（批評スキップ）**: 迅速に perspective を生成（フォールバック、時間制約がある場合）
- ユーザー選択を `{generation_mode}` に格納する

**Step 3 分岐**:
- `{generation_mode}` が「標準」の場合: Step 3（標準版）を実行
- `{generation_mode}` が「簡略」の場合: Step 3（簡略版）を実行

**Step 3（標準版）: perspective 初期生成**
（既存の Step 3 の内容をそのまま維持）

**Step 3（簡略版）: perspective 簡易生成**
`Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

`.claude/skills/agent_bench_new/templates/phase0-perspective-generation-simple.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{agent_path}`: {agent_path}
- `{user_requirements}`: {user_requirements}
- `{perspective_save_path}`: {perspective_save_path}
- `{reference_perspective_path}`: {reference_perspective_path}

簡略版では Step 4（4並列批評）と Step 5（再生成）をスキップし、Step 6（検証）に直接進む
```

### 3. templates/phase0-perspective-generation-simple.md（新規作成）
**対応フィードバック**: I-9: phase0-perspective-generation における4並列批評の複雑性

**ファイル内容**:
```markdown
以下の手順で perspective を簡易生成してください（批評レビューなし）:

## パス変数
- `{agent_path}`: エージェント定義ファイルの絶対パス
- `{user_requirements}`: エージェントの要件情報
- `{perspective_save_path}`: `.agent_bench/{agent_name}/perspective-source.md` の絶対パス
- `{reference_perspective_path}`: 既存 perspective の参照パス（空の場合あり）

## 手順

**Step 1: perspective 生成**
`Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "sonnet"`）:

`.claude/skills/agent_bench_new/templates/perspective/generate-perspective.md` を Read で読み込み、その内容に従って処理を実行してください。
パス変数:
- `{agent_path}`: {agent_path}
- `{user_requirements}`: {user_requirements}
- `{perspective_save_path}`: {perspective_save_path}
- `{reference_perspective_path}`: {reference_perspective_path}

サブエージェント失敗時: エラー内容を返答に含めて終了する

**Step 2: 検証**
- Read で {perspective_save_path} を読み込み、必須セクション（`## 概要`, `## 評価スコープ`, `## スコープ外`, `## ボーナス/ペナルティの判定指針`, `## 問題バンク`）の存在を確認する
- 検証成功 → 以下の**1行のみ**を返答する（他のテキストは含めない）:
  ```
  perspective 簡易生成完了: {perspective_save_path}
  ```
- 検証失敗 → エラー内容を返答に含めて終了する
```

**設計方針**:
- 4並列批評（Step 4）と再生成（Step 5）を省略し、初回生成のみで完了
- perspective/generate-perspective.md を再利用して生成処理の一貫性を保つ
- 検証（Step 2）は標準版と同じ基準を適用
- フォールバック時や時間制約がある場合に使用
- 標準版が失敗した場合の代替手段として機能

## 新規作成ファイル
| ファイル | 目的 | 対応フィードバック |
|---------|------|------------------|
| templates/phase0-perspective-generation-simple.md | 簡略版 perspective 自動生成テンプレート（4並列批評スキップ） | I-9: 4並列批評の複雑性 |

## 削除推奨ファイル
（該当なし）

## 実装順序
1. **templates/phase0-perspective-generation-simple.md（新規作成）**
   - 理由: phase0-perspective-generation.md が新テンプレートを参照するため、先に作成する必要がある

2. **templates/phase0-perspective-generation.md（修正）**
   - 理由: 新テンプレートが作成された後、分岐ロジックを追加

3. **SKILL.md（修正）**
   - 理由: テンプレート参照パスの修正は独立した変更であり、他の変更と並行可能だが、ワークフロー全体の一貫性確認のため最後に実施

## 注意事項
- phase0-perspective-generation.md の変更により、既存のワークフローに「生成モード選択」という新しいユーザーインタラクションポイントが追加される
- 簡略版は品質が標準版より劣る可能性があるため、AskUserQuestion のプロンプトで「推奨、初回実行時」と明示
- SKILL.md のパス修正は、実行時の動作に影響しないことを確認（現在のワーキングディレクトリがスキルルートであることを前提）
- 新規テンプレートは perspective/generate-perspective.md を再利用することで、コードの重複を避ける
