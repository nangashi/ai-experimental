# 改善計画: agent_bench_new

## 変更対象ファイル
| # | ファイル | 変更種別 | 変更概要 | 対応フィードバック |
|---|---------|---------|---------|------------------|
| 1 | SKILL.md | 修正 | 外部スキルディレクトリへの参照を agent_bench_new 内のファイルに変更（9箇所） | I-1 |
| 2 | SKILL.md | 修正 | Phase 6 Step 1 のデプロイサブエージェント削除、親で直接実行に変更 | I-2 |

## 変更ステップ

### Step 1: I-1: 参照整合性: 外部スキルディレクトリへの依存
**対象ファイル**: /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.claude/skills/agent_bench_new/SKILL.md

**変更内容**:
- SKILL.md 行58: `.claude/skills/agent_bench/perspectives/{target}/{key}.md` → `.claude/skills/agent_bench_new/perspectives/{target}/{key}.md`
  - コメントの削除: `（注: 外部スキルディレクトリへの参照。agent_bench スキルの perspectives ディレクトリに依存）` を削除
- SKILL.md 行78: `.claude/skills/agent_bench/perspectives/design/*.md` → `.claude/skills/agent_bench_new/perspectives/design/*.md`
- SKILL.md 行131: `.claude/skills/agent_bench/approach-catalog.md` → `.claude/skills/agent_bench_new/approach-catalog.md`
- SKILL.md 行155: `.claude/skills/agent_bench/proven-techniques.md` → `.claude/skills/agent_bench_new/proven-techniques.md`
- SKILL.md 行176: `.claude/skills/agent_bench/proven-techniques.md` → `.claude/skills/agent_bench_new/proven-techniques.md`
- SKILL.md 行190: `.claude/skills/agent_bench/test-document-guide.md` → `.claude/skills/agent_bench_new/test-document-guide.md`
- SKILL.md 行254: `.claude/skills/agent_bench/scoring-rubric.md` → `.claude/skills/agent_bench_new/scoring-rubric.md`
- SKILL.md 行278: `.claude/skills/agent_bench/scoring-rubric.md` → `.claude/skills/agent_bench_new/scoring-rubric.md`
- SKILL.md 行342: `.claude/skills/agent_bench/proven-techniques.md` → `.claude/skills/agent_bench_new/proven-techniques.md`

### Step 2: I-2: Phase 6 Step 1 デプロイサブエージェントの粒度
**対象ファイル**: /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.claude/skills/agent_bench_new/SKILL.md

**変更内容**:
- SKILL.md 行310-318: サブエージェント委譲の記述を削除し、親での直接実行に変更
  - 現在の記述（行310-318）:
    ```
    ユーザーの選択に応じて:
    - **ベースライン以外を選択した場合**: `Task` ツールで以下を実行する（`subagent_type: "general-purpose"`, `model: "haiku"`）:
      ```
      以下の手順でプロンプトをデプロイしてください:
      1. Read で {selected_prompt_path} を読み込む
      2. ファイル先頭の <!-- Benchmark Metadata ... --> ブロックを除去する
      3. {agent_path} に Write で上書き保存する
      4. 「デプロイ完了: {agent_path}」とだけ返答する
      ```
    - **ベースラインを選択した場合**: 変更なし
    ```
  - 改善後の記述:
    ```
    ユーザーの選択に応じて:
    - **ベースライン以外を選択した場合**: 以下の手順でプロンプトをデプロイする
      1. Read で選択されたプロンプトファイル（`{selected_prompt_path}`）を読み込む
      2. ファイル先頭の `<!-- Benchmark Metadata ... -->` ブロック（開始タグから終了タグまで、改行含む）を除去する
      3. Edit または Write で `{agent_path}` に上書き保存する
      4. 「デプロイ完了: {agent_path}」をテキスト出力する
    - **ベースラインを選択した場合**: 変更なし。「デプロイ不要（ベースライン選択）」をテキスト出力する
    ```

## 新規作成ファイル

（該当なし）

## 削除推奨ファイル

（該当なし）
