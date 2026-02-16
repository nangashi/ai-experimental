# 改善計画: agent_bench_new

## 変更対象ファイル
| # | ファイル | 変更種別 | 変更概要 | 対応フィードバック |
|---|---------|---------|---------|------------------|
| 1 | SKILL.md | 修正 | 全テンプレート参照パスを agent_bench → agent_bench_new に変更 | C-1: 外部スキル参照による実行失敗 |
| 2 | SKILL.md | 修正 | Phase 0: perspective.md 保存前に既存確認を追加 | C-2: perspective.md の冪等性違反 |
| 3 | SKILL.md | 修正 | Phase 1A/1B: プロンプト保存前に既存確認を追加 | C-3: バリアント再実行時の重複 |
| 4 | SKILL.md | 修正 | Phase 0: critic 返答集約ロジックを明示 | C-4: critic返答の集約ロジック未定義 |
| 5 | SKILL.md | 修正 | Phase 0: 出力ディレクトリ事前作成処理を追加 | C-5: 出力ディレクトリの存在確認欠落 |
| 6 | SKILL.md | 修正 | Phase 6 Step 2: A→B 逐次実行に変更 | I-1: Phase 6 Step 2 の並列実行依存関係 |
| 7 | SKILL.md | 修正 | Phase 0: エージェント定義不足の具体的判定基準を追加 | I-2: エージェント定義不足の判断基準曖昧 |
| 8 | SKILL.md | 修正 | Phase 0: フォールバック検索成功時の出力値を明示 | I-7: Phase 0 パースペクティブ出力値の未定義 |
| 9 | SKILL.md | 修正 | Phase 1A: 既存ファイル保持を明示 | I-8: Phase 1A デプロイ動作の未記述 |
| 10 | SKILL.md | 修正 | Phase 0: 批評結果をファイル保存に変更 | I-4: Phase 0 批評結果の親コンテキスト圧迫 |
| 11 | SKILL.md | 修正 | 使い方セクション: 最終成果物と成功基準を追加 | I-5: 最終成果物と成功基準の明示不足 |
| 12 | templates/phase1b-variant-generation.md | 修正 | Deep モード条件の具体的判定基準を追加 | I-6: Deep モード条件の暗黙的判定 |
| 13 | templates/phase6b-proven-techniques-update.md | 修正 | マージ判定の具体的基準を明示 | I-3: proven-techniques.mdのマージ基準曖昧 |
| 14 | templates/perspective/generate-perspective.md | 修正 | user_requirements の構成を明記 | I-9: user_requirements 変数の構成不明 |

## 各ファイルの変更詳細

### 1. SKILL.md（修正）
**対応フィードバック**: C-1: 外部スキル参照による実行失敗

**変更内容**:
- 全ての `.claude/skills/agent_bench/` 参照を `.claude/skills/agent_bench_new/` に変更する
  - 行74: perspectives 参照パス
  - 行81, 92: templates/perspective/ 参照パス
  - 行130, 135, 152, 156-157, 172, 177-178, 192, 194, 257, 259, 280, 282, 332, 340, 344: 各種テンプレート・カタログ参照パス

### 2. SKILL.md（修正）
**対応フィードバック**: C-2: perspective.md の冪等性違反

**変更内容**:
- Phase 0 行59-60: perspective.md への Write 前に既存確認を追加
  - 現在: `perspective-source.md から「## 問題バンク」セクション以降を除いた内容を .agent_bench/{agent_name}/perspective.md に Write で保存する`
  - 改善後: `Read で .agent_bench/{agent_name}/perspective.md の存在確認を行う。ファイルが存在しない場合のみ、perspective-source.md から「## 問題バンク」セクション以降を除いた内容を Write で保存する`

### 3. SKILL.md（修正）
**対応フィードバック**: C-3: バリアント再実行時の重複

**変更内容**:
- Phase 1A 行8-12、Phase 1B 行19: プロンプトファイル保存前に既存確認の条件分岐を追加
  - Phase 1A: 手順3「ベースラインを {prompts_dir}/v001-baseline.md として Write で保存する」の前に「Read で保存先パスの存在確認を行い、既に存在する場合はエラーを出力して終了する」を追加
  - Phase 1B: 手順3「ベースライン（比較用コピー）を {prompts_dir}/v{NNN}-baseline.md として保存する」の前に「Read で保存先パスの存在確認を行い、既に存在する場合はエラーを出力して終了する」を追加

### 4. SKILL.md（修正）
**対応フィードバック**: C-4: critic返答の集約ロジック未定義

**変更内容**:
- Phase 0 Step 5 行106-109: フィードバック統合ロジックを明示
  - 現在: `4件の批評から「重大な問題」「改善提案」を分類する`
  - 改善後: `4件の批評結果を Read で読み込み（.agent_bench/{agent_name}/perspective-critique-{名前}.md）、各ファイルから「重大な問題」「改善提案」のセクションを抽出して統合する。重複する指摘は最も具体的な記述を採用する`

### 5. SKILL.md（修正）
**対応フィードバック**: C-5: 出力ディレクトリの存在確認欠落

**変更内容**:
- Phase 0 共通処理（行117の前）: ディレクトリ事前作成処理を追加
  - `必要なディレクトリを Bash ツールで事前作成する: mkdir -p .agent_bench/{agent_name}/prompts .agent_bench/{agent_name}/results .agent_bench/{agent_name}/reports`

### 6. SKILL.md（修正）
**対応フィードバック**: I-1: Phase 6 Step 2 の並列実行依存関係

**変更内容**:
- Phase 6 Step 2 行326-358: 並列実行から逐次実行に変更
  - 現在: `以下の3つを同時に実行する: A) ナレッジ更新サブエージェント B) スキル知見フィードバックサブエージェント C) 次アクション選択（親で実行）`
  - 改善後: `以下を順に実行する: A) ナレッジ更新サブエージェント（完了待ち） → B) スキル知見フィードバックサブエージェント（完了待ち） → C) 次アクション選択（親で実行）`

### 7. SKILL.md（修正）
**対応フィードバック**: I-2: エージェント定義不足の判断基準曖昧

**変更内容**:
- Phase 0 行67-71: 具体的な判定基準を追加
  - 現在: `エージェント定義が実質空または不足がある場合`
  - 改善後: `エージェント定義が以下のいずれかに該当する場合: (1) ファイルサイズが200文字未満、(2) 見出し（#で始まる行）が2個以下、(3) 目的・入力・出力のいずれかのキーワードを含むセクションがない`

### 8. SKILL.md（修正）
**対応フィードバック**: I-7: Phase 0 パースペクティブ出力値の未定義

**変更内容**:
- Phase 0 行142-144: フォールバック検索成功時の出力値を明示
  - 現在の3行出力に、パースペクティブ解決状況の詳細を追加
  - 改善後: `- パースペクティブ: {既存（perspective-source.md） / 既存（フォールバック: {target}/{key}.md） / 自動生成}`

### 9. SKILL.md（修正）
**対応フィードバック**: I-8: Phase 1A デプロイ動作の未記述

**変更内容**:
- Phase 1A 行11-12: 既存ファイル保持を明示
  - 現在: `エージェント定義ファイルが存在しなかった場合: ベースラインの内容（Benchmark Metadata コメントを除く）を {agent_path} に Write で保存する（初期デプロイ）`
  - 改善後: `エージェント定義ファイルが存在しなかった場合: ベースラインの内容（Benchmark Metadata コメントを除く）を {agent_path} に Write で保存する（初期デプロイ）。存在した場合: 既存ファイルを保持し、デプロイは行わない`

### 10. SKILL.md（修正）
**対応フィードバック**: I-4: Phase 0 批評結果の親コンテキスト圧迫

**変更内容**:
- Phase 0 Step 4 行88-104: 批評結果のファイル保存方式に変更
  - 各 critic サブエージェントへの指示を変更: テンプレート末尾に以下を追加
    - `処理結果を .agent_bench/{agent_name}/perspective-critique-{名前}.md に Write で保存してください（{名前} = effectiveness/completeness/clarity/generality）`
    - `最後に「保存完了: {ファイルパス}」とだけ返答してください`
  - Step 5 でファイルから読み込む方式に変更（変更内容4を参照）

### 11. SKILL.md（修正）
**対応フィードバック**: I-5: 最終成果物と成功基準の明示不足

**変更内容**:
- 使い方セクション（行8-16）: 最終成果物と期待される成果物を追加
  - 行16の後に以下を追加:

```markdown
## 最終成果物

- エージェント定義ファイル（{agent_path}）の最適化版
- `.agent_bench/{agent_name}/knowledge.md`: ラウンド別の効果分析と知見
- `.agent_bench/{agent_name}/reports/round-{NNN}-comparison.md`: 各ラウンドの比較レポート

## 成功基準

- 初期スコアからの改善: +1.0pt 以上（+15%以上）
- 収束判定: 直近3ラウンドで最高スコア更新なし、かつ最新バリアントがベースラインとの差 < 0.5pt
- knowledge.md に3件以上の EFFECTIVE テクニックが記録されている
```

### 12. templates/phase1b-variant-generation.md（修正）
**対応フィードバック**: I-6: Deep モード条件の暗黙的判定

**変更内容**:
- 行17-18: Deep モード条件の具体的判定基準を追加
  - 現在: `Deep モードでバリエーションの詳細が必要な場合のみ {approach_catalog_path} を Read で読み込む`
  - 改善後: `Deep モードの場合、選定したカテゴリの UNTESTED バリエーションの詳細を確認するために {approach_catalog_path} を Read で読み込む。Broad モードではカタログ読み込みは不要（knowledge.md のバリエーションステータステーブルのみで判定可能）`

### 13. templates/phase6b-proven-techniques-update.md（修正）
**対応フィードバック**: I-3: proven-techniques.mdのマージ基準曖昧

**変更内容**:
- 行36-40: マージ判定の具体的基準を明示
  - 現在: `Section 1: 最大8エントリ。超過時は最も類似する2エントリをマージして1つにする`
  - 改善後: `Section 1: 最大8エントリ。超過時は以下の基準で最も類似する2エントリを判定してマージする: (1) Variation ID のカテゴリ（S/C/N/M）が同一、(2) 効果範囲の記述に共通キーワード（見出し/粒度/例示/形式）が2つ以上含まれる、(3) 出典エージェント数の合計が最も少ない組み合わせを優先`

### 14. templates/perspective/generate-perspective.md（修正）
**対応フィードバック**: I-9: user_requirements 変数の構成不明

**変更内容**:
- 行56-58: user_requirements の構成を明記
  - 現在の「## ユーザー要件」セクションの前に以下を追加:

```markdown
## user_requirements の構成

この変数は以下の情報を含むテキスト形式です:

- **エージェントの目的・役割**: 何を評価/実行するか（1-2文）
- **想定される入力**: 入力の種類とフォーマット（例: Markdown形式の設計書、Pythonコードファイル）
- **期待される出力**: 出力の種類と形式（例: 指摘リスト、改善案、スコア）
- **評価基準・制約**: あれば評価軸や制約条件（例: セキュリティ重視、特定の規約準拠）
- **使用ツール・その他**: あれば利用可能なツールやその他の情報

SKILL.md の Phase 0 Step 1 でエージェント定義ファイルから抽出されます。
```

## 新規作成ファイル

（なし）

## 削除推奨ファイル

（なし）

## 実装順序

1. **SKILL.md 行74, 81, 92, 130等 — テンプレート参照パス修正（C-1）**
   - 理由: 最も重大な問題。全フェーズの実行に影響するため、最初に修正すべき

2. **SKILL.md Phase 0 — ディレクトリ事前作成（C-5）**
   - 理由: 他の変更処理が依存する基盤処理

3. **SKILL.md Phase 0 — 冪等性・既存確認処理（C-2, C-3, I-8）**
   - 理由: 再実行時の安定性向上。他のフェーズに依存しない

4. **templates/perspective/generate-perspective.md — user_requirements 構成明記（I-9）**
   - 理由: Phase 0 Step 3 で参照されるテンプレートの改善

5. **SKILL.md Phase 0 — 批評結果ファイル保存方式（I-4, C-4）**
   - 理由: perspective 自動生成の改善。テンプレート改善後に実施

6. **SKILL.md Phase 0 — エージェント定義不足判定基準（I-2）、出力値明示（I-7）**
   - 理由: Phase 0 の細部改善

7. **SKILL.md Phase 1A — デプロイ動作明示（I-8）**
   - 理由: Phase 1A の細部改善

8. **templates/phase1b-variant-generation.md — Deep モード条件明示（I-6）**
   - 理由: Phase 1B で参照されるテンプレートの改善

9. **templates/phase6b-proven-techniques-update.md — マージ基準明示（I-3）**
   - 理由: Phase 6B で参照されるテンプレートの改善

10. **SKILL.md Phase 6 Step 2 — 逐次実行への変更（I-1）**
    - 理由: テンプレート改善後に実施

11. **SKILL.md 使い方セクション — 最終成果物と成功基準追加（I-5）**
    - 理由: ドキュメント改善。ワークフロー変更後に実施

## 注意事項

- **パス変数の一貫性**: SKILL.md とテンプレート間でパス変数名を統一すること（特に {perspective_critique_path} 等の新規変数）
- **既存ワークフローの保持**: 批評結果のファイル保存方式変更（I-4）は、Phase 0 Step 4 のサブエージェント起動方法は変更せず、各 critic テンプレートに保存処理を追加する形で実装すること
- **テンプレート外部化の影響**: critic テンプレートへの保存処理追加時、SKILL.md で critic テンプレートへ渡すパス変数リストに `{critique_save_path}` を追加すること
- **並列→逐次実行への変更（I-1）**: C) 次アクション選択は A) と B) の完了後に実行するが、AskUserQuestion の前に A) と B) の両方の完了を明示的に記述すること
