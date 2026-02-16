# 改善計画: agent_bench_new

## 変更対象ファイル
| # | ファイル | 変更種別 | 変更概要 | 対応フィードバック |
|---|---------|---------|---------|------------------|
| 1 | SKILL.md | 修正 | Phase 0 Step 5 の再生成判定基準を明示化 | C-1 |
| 2 | SKILL.md | 修正 | Phase 3 の部分失敗時の判定基準とSD計算不可時の処理フローを定義 | C-2 |
| 3 | SKILL.md | 修正 | Phase 6 Step 2 の並列実行と完了待ちの意図を明確化 | C-3 |
| 4 | SKILL.md | 修正 | Phase 0 Step 4b のパターンマッチング失敗時の処理を明記 | C-4 |
| 5 | SKILL.md | 修正 | Phase 0 Step 2 の perspective 検索で空パス時のテンプレート処理動作を明記 | C-5, I-6 |
| 6 | SKILL.md | 修正 | Phase 1A のパス変数リストで user_requirements の条件を明確化 | C-6 |
| 7 | SKILL.md | 修正 | Phase 6 Step 1 でベースライン選択時の処理フローを明記 | C-7 |
| 8 | SKILL.md | 修正 | Phase 1A/1B から perspective_path パラメータを削除 | C-8 |
| 9 | SKILL.md | 修正 | Phase 5 から knowledge_path パラメータを削除 | C-9 |
| 10 | SKILL.md | 修正 | Phase 0 perspective 自動生成 Step 4 の返答形式を定義 | I-1 |
| 11 | SKILL.md | 修正 | Phase 1B の audit ファイル最新選定基準を明記 | I-2 |
| 12 | SKILL.md | 修正 | Phase 1B の audit ファイル不在時のフォールバック戦略を明記 | I-5 |
| 13 | SKILL.md | 修正 | Phase 2 のラウンド番号導出処理を Phase 0 に明記 | I-4 |
| 14 | SKILL.md | 修正 | Phase 3 の Run 番号割り当てロジックを明記 | I-7 |
| 15 | SKILL.md | 修正 | Phase 5 の返答形式検証処理を追加 | I-8 |
| 16 | SKILL.md | 修正 | Phase 6 Step 2A のバックアップタイムスタンプ形式の生成指示を追加 | I-9 |
| 17 | templates/phase1a-variant-generation.md | 修正 | perspective_path パラメータの参照を削除 | C-8 |
| 18 | templates/phase1b-variant-generation.md | 修正 | perspective_path パラメータの参照を削除 | C-8 |
| 19 | templates/phase5-analysis-report.md | 修正 | knowledge_path パラメータの参照を削除 | C-9 |
| 20 | templates/perspective/critic-effectiveness.md | 修正 | 返答形式の定義を追加 | I-1 |
| 21 | templates/perspective/critic-completeness.md | 修正 | 返答形式の定義を追加 | I-1 |
| 22 | templates/perspective/critic-clarity.md | 修正 | 返答形式の定義を追加 | I-1 |
| 23 | templates/perspective/critic-generality.md | 修正 | 返答形式の定義を追加 | I-1 |
| 24 | templates/phase6b-proven-techniques-update.md | 修正 | 昇格条件の簡略化または明示化 | I-3 |

## 各ファイルの変更詳細

### 1. SKILL.md（修正）
**対応フィードバック**: C-1, C-2, C-3, C-4, C-5, C-6, C-7, C-8, C-9, I-1, I-2, I-4, I-5, I-6, I-7, I-8, I-9

**変更内容**:
- **行 105-107 (C-1)**: `重大な問題または改善提案がある場合` → `4件の批評のうち1件以上で「重大な問題」フィールドが空でない場合`
- **行 73-76 (C-5, I-6)**: Glob が0件の場合の処理を明記: `見つからない場合は {reference_perspective_path} を空とする。空パス時は generate-perspective.md テンプレートが参照観点なしでフォーマットを独自生成する`
- **行 51-56 (C-4)**: パターンマッチング後の処理を明記: `一致したがファイル不在の場合: パースペクティブ自動生成（後述）を実行する`
- **行 88-103 (I-1)**: Step 4 の返答形式を追加:
  ```
  各批評エージェントは以下の形式で SendMessage で報告する:
  - 重大な問題: {あればリスト、なければ「なし」}
  - 改善提案: {あればリスト、なければ「なし」}
  ```
- **行 116-118**: Phase 0 の knowledge.md 読み込み時に累計ラウンド数を抽出する処理を追加 (I-4): `読み込み成功時は「## メタデータ」セクションから累計ラウンド数を抽出し、変数 {current_round} に保持する`
- **行 150-159 (C-6)**: `{user_requirements}` のパス変数説明を条件分岐明確化: `エージェント定義が新規作成の場合（agent_path が存在しない）: {user_requirements} を Phase 0 で収集した要件テキストとして渡す。既存エージェント更新の場合: このパラメータは渡さない（テンプレート側で未定義として扱う）`
- **行 155, 179 (C-8)**: Phase 1A/1B のパス変数リストから `{perspective_path}` を削除
- **行 180-183 (I-2, I-5)**: audit ファイル検索に最新選定基準とフォールバック戦略を追加: `最新ファイルはファイル名の run タイムスタンプまたは更新日時で判定する。見つからない場合は空文字列を渡し、Phase 1B は knowledge.md の過去知見のみでバリアント生成を行う`
- **行 222-236 (I-7)**: Run 番号割り当てロジックを明記: `各プロンプトの1回目実行を Run1、2回目実行を Run2 として結果ファイル名を生成する。並列起動時は各サブエージェントが受け取ったパラメータの Run 番号をそのまま使用する（競合なし）`
- **行 241 (C-2)**: 部分失敗時の判定基準を明記: `各プロンプトに最低1回の成功結果がある場合、Run1 または Run2 のいずれかが成功していれば最低1回とみなす。SD 計算は両 Run が成功している場合のみ実施し、1回のみ成功の場合は SD = N/A とする`
- **行 283 (C-9)**: Phase 5 のパス変数リストから `{knowledge_path}` を削除
- **行 288 (I-8)**: Phase 5 返答の構造検証処理を追加: `返答が7行（recommended, reason, convergence, scores, variants, deploy_info, user_summary）の形式であることを確認する。不一致の場合は1回リトライする`
- **行 316-322 (C-7)**: ベースライン選択時の処理フローを追加: `ベースライン選択時も Phase 6 Step 2A のナレッジ更新処理で「推奨: baseline」としてラウンド結果を記録する`
- **行 333 (I-9)**: バックアップタイムスタンプ形式の生成指示を追加: `パス変数に {timestamp_format} = "YYYYMMDD-HHMMSS" を追加し、サブエージェントが Bash の date コマンドで生成する`
- **行 342, 368-370 (C-3)**: 並列実行と完了待ちを明確化: `B と C を同一メッセージ内で並列起動し、両方の完了を待ってから次アクション分岐処理（Phase 1B へ戻る/終了）を実行する`

### 2. templates/phase1a-variant-generation.md（修正）
**対応フィードバック**: C-8

**変更内容**:
- **行 3-10**: パス変数リストから `{perspective_path}` を削除。行 10 の `{perspective_path} が存在することを Read で確認する` を削除

### 3. templates/phase1b-variant-generation.md（修正）
**対応フィードバック**: C-8

**変更内容**:
- **行 3-9**: パス変数リストから `{perspective_path}` を削除。行 7 の `{perspective_path} （観点定義 — バリアント生成時の参考）` を削除

### 4. templates/phase5-analysis-report.md（修正）
**対応フィードバック**: C-9

**変更内容**:
- パス変数リストから `{knowledge_path}` を削除。knowledge.md を参照する手順を削除（レポートのみから推奨判定を行う）

### 5. templates/perspective/critic-effectiveness.md（修正）
**対応フィードバック**: I-1

**変更内容**:
- 返答形式セクションを追加:
  ```markdown
  ## 返答形式

  以下の形式で SendMessage で報告してください:

  - 重大な問題: {あればリスト、なければ「なし」}
  - 改善提案: {あればリスト、なければ「なし」}
  ```

### 6. templates/perspective/critic-completeness.md（修正）
**対応フィードバック**: I-1

**変更内容**:
- 返答形式セクションを追加（critic-effectiveness.md と同じ形式）

### 7. templates/perspective/critic-clarity.md（修正）
**対応フィードバック**: I-1

**変更内容**:
- 返答形式セクションを追加（critic-effectiveness.md と同じ形式）

### 8. templates/perspective/critic-generality.md（修正）
**対応フィードバック**: I-1

**変更内容**:
- 返答形式セクションを追加（critic-effectiveness.md と同じ形式）

### 9. templates/phase6b-proven-techniques-update.md（修正）
**対応フィードバック**: I-3

**変更内容**:
- **行 15-26**: 昇格条件を簡略化:
  ```
  現在の条件: Tier 1→2: 2エージェントで効果確認、Tier 2→3: 4エージェント以上で効果確認
  簡略化案: Tier 1→2: 1エージェントで効果確認（+1.0pt以上）、Tier 2→3: 3エージェント以上で効果確認（平均+1.5pt以上）
  ```
  または昇格条件判定ロジックを明示的に記載する

## 新規作成ファイル
なし

## 削除推奨ファイル
なし

## 実装順序
1. **templates/perspective/critic-*.md（4ファイル）**: 返答形式定義を追加（Phase 0 Step 4 で使用されるため先に修正）
2. **templates/phase1a-variant-generation.md, templates/phase1b-variant-generation.md**: perspective_path パラメータの削除（Phase 1A/1B で使用）
3. **templates/phase5-analysis-report.md**: knowledge_path パラメータの削除（Phase 5 で使用）
4. **templates/phase6b-proven-techniques-update.md**: 昇格条件の簡略化（Phase 6B で使用）
5. **SKILL.md**: 全ての修正を統合（メインワークフロー定義のため最後に実施し、一貫性を確保）

依存関係の検出方法:
- テンプレートファイルはサブエージェントが参照するため、SKILL.md よりも先に修正する
- SKILL.md はテンプレートを呼び出す親プロセスのため、テンプレート修正完了後に整合性を確保しながら修正する

## 注意事項
- Phase 1A/1B から perspective_path を削除する際、バリアント生成時に perspective を参照する必要性がないことを確認する（approach-catalog.md と proven-techniques.md で十分）
- Phase 5 から knowledge_path を削除する際、レポート生成に必要な情報が report のみで足りることを確認する
- Phase 0 の累計ラウンド数抽出処理を追加する際、knowledge.md の「## メタデータ」セクションのフォーマットを確認する
- Phase 6 Step 2 の並列実行と完了待ちを明確化する際、B と C の両方が完了するまで次アクション分岐を実行しないことを明記する
- Phase 3 の部分失敗時の処理で SD = N/A とする場合、Phase 4 の採点テンプレートでも SD = N/A の処理フローを確認する
- 批評エージェントの返答形式を統一する際、SKILL.md の Phase 0 Step 5 で4件の返答を統合する処理ロジックも明記する
