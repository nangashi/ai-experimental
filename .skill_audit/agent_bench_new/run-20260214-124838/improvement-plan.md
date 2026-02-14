# 改善計画: agent_bench_new

## 変更対象ファイル
| # | ファイル | 変更種別 | 変更概要 | 対応フィードバック |
|---|---------|---------|---------|------------------|
| 1 | SKILL.md | 修正 | Phase 1B のパス変数定義を修正 | C-1 |
| 2 | templates/phase1b-variant-generation.md | 修正 | audit パス変数の参照方法を修正（存在確認パターンに変更） | C-1, C-3 |
| 3 | SKILL.md | 修正 | perspectives ディレクトリの外部参照を明示化 | C-2 |
| 4 | SKILL.md | 修正 | 「使い方」セクションに最適化継続判断基準を追記 | I-1 |
| 5 | SKILL.md | 修正 | Phase 1A のベースライン保存の冪等性を明示 | I-3 |
| 6 | SKILL.md | 修正 | Phase 1A で user_requirements を常に定義する処理を追加 | I-4 |
| 7 | templates/knowledge-init-template.md | 修正 | 構造分析スナップショットセクションを追加 | I-5 |
| 8 | templates/phase6a-knowledge-update.md | 修正 | 構造分析スナップショットの更新処理を追加 | I-5 |
| 9 | templates/phase1a-variant-generation.md | 修正 | 構造分析結果を knowledge.md に保存する処理を追加 | I-5 |

## 変更ステップ

### Step 1: C-1: Phase 1B のパス変数定義に不一致あり
**対象ファイル**: /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.claude/skills/agent_bench_new/SKILL.md, /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.claude/skills/agent_bench_new/templates/phase1b-variant-generation.md
**変更内容**:
- SKILL.md 行174: `{audit_findings_paths}` を `{audit_dim1_path}`, `{audit_dim2_path}` の2つの個別変数に分割
  - 変更前: `Glob で .agent_audit/{agent_name}/audit-*.md を検索し（audit-approved.md は除外）、見つかった全ファイルのパスをカンマ区切りで {audit_findings_paths} として渡す`
  - 変更後: `Glob で .agent_audit/{agent_name}/audit-dim1-*.md を検索し、見つかった場合は {audit_dim1_path} として渡す（見つからない場合は空文字列）。同様に .agent_audit/{agent_name}/audit-dim2-*.md を検索し {audit_dim2_path} として渡す`
- templates/phase1b-variant-generation.md 行8-9: パス変数の参照方法はそのまま維持（変更なし）

### Step 2: C-3: 外部スキル実行への暗黙的依存
**対象ファイル**: /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.claude/skills/agent_bench_new/templates/phase1b-variant-generation.md
**変更内容**:
- templates/phase1b-variant-generation.md 行8-9: 条件付き Read パターンに変更
  - 変更前: `{audit_dim1_path} が指定されている場合: Read で読み込む（agent_audit の基準有効性分析結果 — 改善推奨をバリアント生成の参考にする）`
  - 変更後: `{audit_dim1_path} が指定されている場合かつパスが空文字列でない場合: Read で読み込む（agent_audit の基準有効性分析結果 — 改善推奨をバリアント生成の参考にする。ファイル不在時はスキップ）`
  - 同様に行9の audit_dim2_path も変更

### Step 3: C-2: 外部スキルディレクトリへの参照
**対象ファイル**: /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.claude/skills/agent_bench_new/SKILL.md
**変更内容**:
- SKILL.md 行54: 外部参照であることを明示化し、依存関係を記載
  - 変更前: `一致した場合: .claude/skills/agent_bench/perspectives/{target}/{key}.md を Read で確認する`
  - 変更後: `一致した場合: .claude/skills/agent_bench/perspectives/{target}/{key}.md を Read で確認する（注: 外部スキルディレクトリへの参照。agent_bench スキルの perspectives ディレクトリに依存）`

### Step 4: I-1: 反復的最適化の終了条件が曖昧
**対象ファイル**: /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.claude/skills/agent_bench_new/SKILL.md
**変更内容**:
- SKILL.md 行6-16（使い方セクション）: 最適化継続の判断基準を追記
  - 変更前（行16の直後）: （セクション終了）
  - 変更後（行16の直後に追加）:
    ```

    **最適化継続の判断**:
    - 各ラウンド終了時（Phase 6 Step 2-C）に「次ラウンド」か「終了」を選択します
    - 収束判定が「収束の可能性あり」の場合や累計ラウンド数が3以上の場合は目安として表示されますが、最終的な継続判断はユーザーに委ねられます
    ```

### Step 5: I-3: Phase 1Aのベースライン保存の冪等性が未定義
**対象ファイル**: /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.claude/skills/agent_bench_new/SKILL.md
**変更内容**:
- SKILL.md 行140-158（Phase 1A セクション）: ベースライン保存の冪等性を明示
  - 変更前（行146の直後、パス変数リストの後）: （パス変数リスト終了）
  - 変更後（行157の直後、user_requirements の後に追記）:
    ```
    - 冪等性: Phase 1A は初回専用であり、knowledge.md が存在する場合は Phase 1B に分岐するため、ベースラインファイル（v001-baseline.md）の重複保存は発生しない
    ```

### Step 6: I-4: テンプレート内の未使用変数
**対象ファイル**: /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.claude/skills/agent_bench_new/SKILL.md
**変更内容**:
- SKILL.md 行146-157（Phase 1A パス変数リスト）: user_requirements を常に定義
  - 変更前（行155-156）:
    ```
    - エージェント定義が新規作成の場合:
      - `{user_requirements}`: Phase 0 で収集した要件テキスト
    ```
  - 変更後:
    ```
    - `{user_requirements}`: Phase 0 で収集した要件テキスト（エージェント定義が存在する場合は空文字列）
    ```

### Step 7: I-5: Phase 1A/1B の構造分析の重複（knowledge.md テンプレート修正）
**対象ファイル**: /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.claude/skills/agent_bench_new/templates/knowledge-init-template.md
**変更内容**:
- templates/knowledge-init-template.md 行45-48（最新ラウンドサマリセクションの後）: 構造分析スナップショットセクションを追加
  - 変更前（行47の後）: `（まだラウンドは実施されていません）`
  - 変更後（行47の後に追加）:
    ```

    ## 構造分析スナップショット

    ### 6次元構造分析（Phase 1A で生成、Phase 1B で参照）
    | 構造次元 | 現状 | 最適状態 | ギャップ |
    |---------|------|---------|---------|

    （Phase 1A で初回分析結果を保存。Phase 6A で構造変化時に更新）
    ```

### Step 8: I-5: Phase 1A/1B の構造分析の重複（Phase 6A 更新処理追加）
**対象ファイル**: /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.claude/skills/agent_bench_new/templates/phase6a-knowledge-update.md（※ファイル未読のため概念的変更）
**変更内容**:
- templates/phase6a-knowledge-update.md: 構造分析スナップショットの更新処理を追加
  - 追加位置: バリエーションステータステーブル更新処理の後
  - 追加内容:
    ```
    - 構造分析スナップショット: デプロイされたプロンプトがベースラインと異なる場合、構造次元の変化を記録（任意、20行上限の範囲内で）
    ```

### Step 9: I-5: Phase 1A/1B の構造分析の重複（Phase 1A で保存処理追加）
**対象ファイル**: /home/toyama-ryosuke/ghq/github.com/nangashi/ai-experimental/.claude/skills/agent_bench_new/templates/phase1a-variant-generation.md
**変更内容**:
- templates/phase1a-variant-generation.md 行21-41（結果サマリ返答フォーマットの前）: knowledge.md への構造分析保存処理を追加
  - 変更前（ステップ8の後、ステップ9の前）: `8. 各バリアントを {prompts_dir}/v001-variant-{name}.md として保存する`
  - 変更後（ステップ8の後に新ステップ追加）:
    ```
    8. 各バリアントを {prompts_dir}/v001-variant-{name}.md として保存する
    9. Read で {knowledge_path} を読み込み、「構造分析スナップショット」セクションに6次元分析結果テーブルを Write で保存する（preserve + integrate 方式、既存セクションの順序維持）
    10. 以下のフォーマットで結果サマリのみ返答する（プロンプト本文は含めない）:
    ```
  - 既存のステップ9を新ステップ10に繰り下げ

## 新規作成ファイル
（該当なし）

## 削除推奨ファイル
（該当なし）
